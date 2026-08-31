"""Task creation, submission, and grading endpoints."""

from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.application.progression import ProgressionService
from src.domain.entities import Task, TaskSubmission
from src.domain.enums import Role, TaskType
from src.infrastructure.auth.permissions import get_current_user, require_role
from src.infrastructure.database.repositories import (
    SQLAlchemyRankRepository,
    SQLAlchemySectionRepository,
    SQLAlchemyTaskRepository,
    SQLAlchemyTaskSubmissionRepository,
    SQLAlchemyUserRepository,
    SQLAlchemyXPTransactionRepository,
)
from src.infrastructure.database.session import get_db
from src.infrastructure.storage import LocalStorageService
from src.presentation.schemas.requests.task_requests import (
    CreateTaskRequest,
    GradeSubmissionRequest,
    SubmitTaskRequest,
    UpdateTaskRequest,
)
from src.presentation.schemas.responses.task_responses import (
    TaskResponse,
    TaskSubmissionResponse,
)

router = APIRouter(prefix="/tasks", tags=["Tasks"])
teacher_access = require_role(
    Role.DIRECTOR,
    Role.SUBDIRECTOR,
    Role.TUTOR,
    Role.PROFESSOR,
)


def _task_response(task: Task, *, reveal_answer: bool) -> TaskResponse:
    return TaskResponse(
        id=str(task.id),
        creator_id=str(task.creator_id),
        section_id=str(task.section_id),
        subject=task.subject.value,
        title=task.title,
        description=task.description,
        task_type=task.task_type.value,
        due_date=task.due_date,
        xp_reward=task.xp_reward,
        status=task.status,
        options=task.options,
        correct_option=task.correct_option if reveal_answer else None,
        created_at=task.created_at,
    )


def _submission_response(
    submission: TaskSubmission,
) -> TaskSubmissionResponse:
    return TaskSubmissionResponse(
        id=str(submission.id),
        task_id=str(submission.task_id),
        student_id=str(submission.student_id),
        answer=submission.answer,
        file_url=submission.file_url,
        is_graded=submission.is_graded,
        score=submission.score if submission.is_graded else None,
        feedback=submission.feedback,
        xp_awarded=submission.xp_awarded,
        submitted_at=submission.submitted_at,
        graded_at=submission.graded_at,
    )


async def _require_section_school(
    session: AsyncSession,
    section_id: UUID,
    payload: dict,
):
    section = await SQLAlchemySectionRepository(session).get_by_id(section_id)
    if section is None:
        raise HTTPException(status_code=404, detail="Section not found")
    if payload.get("school_id") != str(section.school_id):
        raise HTTPException(status_code=403, detail="Section belongs to another school")
    return section


def _can_manage_task(payload: dict, task: Task) -> bool:
    role = Role(payload["role"])
    return UUID(payload["sub"]) == task.creator_id or role in {
        Role.DIRECTOR,
        Role.SUBDIRECTOR,
        Role.TUTOR,
    }


async def _award_submission_xp(
    session: AsyncSession,
    submission: TaskSubmission,
    task: Task,
) -> TaskSubmission:
    target_xp = round(task.xp_reward * submission.score / 100)
    progression = ProgressionService(
        SQLAlchemyUserRepository(session),
        SQLAlchemyRankRepository(session),
        SQLAlchemyXPTransactionRepository(session),
    )
    await progression.award_xp(
        submission.student_id,
        target_xp,
        "task_submission",
        submission.id,
        f"Tarea: {task.title}",
    )
    submission.xp_awarded = target_xp
    return await SQLAlchemyTaskSubmissionRepository(session).update(submission)


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    body: CreateTaskRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    await _require_section_school(session, UUID(body.section_id), payload)
    if body.publish and body.due_date and body.due_date <= datetime.now(UTC):
        raise HTTPException(
            status_code=400, detail="Published task due date is in the past"
        )
    task = Task(
        creator_id=UUID(payload["sub"]),
        section_id=UUID(body.section_id),
        subject=body.subject,
        title=body.title.strip(),
        description=body.description.strip(),
        task_type=body.task_type,
        due_date=body.due_date,
        xp_reward=body.xp_reward,
        status="published" if body.publish else "draft",
        options=body.options,
        correct_option=body.correct_option,
    )
    created = await SQLAlchemyTaskRepository(session).create(task)
    await session.commit()
    return _task_response(created, reveal_answer=True)


@router.get("", response_model=list[TaskResponse])
async def list_tasks(
    section_id: str | None = None,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    repo = SQLAlchemyTaskRepository(session)
    role = Role(payload["role"])
    if role == Role.STUDENT:
        own_section_id = payload.get("section_id")
        if own_section_id is None:
            return []
        if section_id is not None and section_id != own_section_id:
            raise HTTPException(status_code=403, detail="Cannot view another section")
        tasks = await repo.list_by_section(
            UUID(own_section_id),
            published_only=True,
        )
        return [_task_response(task, reveal_answer=False) for task in tasks]

    if section_id:
        await _require_section_school(session, UUID(section_id), payload)
        tasks = await repo.list_by_section(UUID(section_id))
    else:
        tasks = await repo.list_by_creator(UUID(payload["sub"]))
    return [_task_response(task, reveal_answer=True) for task in tasks]


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    task = await SQLAlchemyTaskRepository(session).get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    await _require_section_school(session, task.section_id, payload)
    role = Role(payload["role"])
    if role == Role.STUDENT and (
        payload.get("section_id") != str(task.section_id) or task.status != "published"
    ):
        raise HTTPException(status_code=403, detail="Task is not available")
    return _task_response(task, reveal_answer=role != Role.STUDENT)


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    body: UpdateTaskRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    repo = SQLAlchemyTaskRepository(session)
    task = await repo.get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    await _require_section_school(session, task.section_id, payload)
    if not _can_manage_task(payload, task):
        raise HTTPException(status_code=403, detail="Cannot edit this task")
    if task.status != "draft":
        raise HTTPException(status_code=409, detail="Only draft tasks can be edited")
    fields = body.model_fields_set
    if "title" in fields and body.title is not None:
        task.title = body.title.strip()
    if "description" in fields and body.description is not None:
        task.description = body.description.strip()
    if "due_date" in fields:
        task.due_date = body.due_date
    if "xp_reward" in fields and body.xp_reward is not None:
        task.xp_reward = body.xp_reward
    updated = await repo.update(task)
    await session.commit()
    return _task_response(updated, reveal_answer=True)


@router.post("/{task_id}/publish", response_model=TaskResponse)
async def publish_task(
    task_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    repo = SQLAlchemyTaskRepository(session)
    task = await repo.get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    await _require_section_school(session, task.section_id, payload)
    if not _can_manage_task(payload, task):
        raise HTTPException(status_code=403, detail="Cannot publish this task")
    if task.due_date and task.due_date <= datetime.now(UTC):
        raise HTTPException(status_code=400, detail="Task due date is in the past")
    task.status = "published"
    updated = await repo.update(task)
    await session.commit()
    return _task_response(updated, reveal_answer=True)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def close_task(
    task_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
) -> None:
    repo = SQLAlchemyTaskRepository(session)
    task = await repo.get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    await _require_section_school(session, task.section_id, payload)
    if not _can_manage_task(payload, task):
        raise HTTPException(status_code=403, detail="Cannot close this task")
    task.status = "closed"
    await repo.update(task)
    await session.commit()


async def _create_submission(
    session: AsyncSession,
    payload: dict,
    task: Task,
    *,
    answer: str = "",
    file_url: str | None = None,
) -> TaskSubmission:
    if Role(payload["role"]) != Role.STUDENT:
        raise HTTPException(status_code=403, detail="Only students submit tasks")
    if payload.get("section_id") != str(task.section_id):
        raise HTTPException(status_code=403, detail="Task belongs to another section")
    if task.status != "published":
        raise HTTPException(status_code=409, detail="Task is not open")
    submission_repo = SQLAlchemyTaskSubmissionRepository(session)
    student_id = UUID(payload["sub"])
    existing = await submission_repo.get_by_task_and_student(task.id, student_id)
    if existing is not None:
        raise HTTPException(status_code=409, detail="Task was already submitted")

    if task.task_type == TaskType.FILE_UPLOAD and file_url is None:
        raise HTTPException(status_code=400, detail="This task requires a file")
    if task.task_type != TaskType.FILE_UPLOAD and not answer.strip():
        raise HTTPException(status_code=400, detail="Answer cannot be empty")

    submission = TaskSubmission(
        task_id=task.id,
        student_id=student_id,
        answer=answer.strip(),
        file_url=file_url,
    )
    if task.task_type == TaskType.MULTIPLE_CHOICE:
        normalized = answer.strip().upper()
        if normalized not in task.options:
            raise HTTPException(status_code=400, detail="Answer must be A, B, C, or D")
        submission.answer = normalized
        submission.score = 100 if normalized == task.correct_option else 0
        submission.is_graded = True
        submission.graded_at = datetime.now(UTC)

    submission = await submission_repo.create(submission)
    if submission.is_graded:
        submission = await _award_submission_xp(session, submission, task)
    return submission


async def _prevalidate_file_submission(
    session: AsyncSession,
    payload: dict,
    task: Task,
) -> None:
    """Reject invalid uploads before writing their contents to local storage."""
    if Role(payload["role"]) != Role.STUDENT:
        raise HTTPException(status_code=403, detail="Only students submit tasks")
    if payload.get("section_id") != str(task.section_id):
        raise HTTPException(status_code=403, detail="Task belongs to another section")
    if task.status != "published":
        raise HTTPException(status_code=409, detail="Task is not open")
    if task.task_type != TaskType.FILE_UPLOAD:
        raise HTTPException(status_code=400, detail="This task does not accept a file")
    existing = await SQLAlchemyTaskSubmissionRepository(
        session
    ).get_by_task_and_student(task.id, UUID(payload["sub"]))
    if existing is not None:
        raise HTTPException(status_code=409, detail="Task was already submitted")


@router.post(
    "/{task_id}/submissions",
    response_model=TaskSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_task(
    task_id: str,
    body: SubmitTaskRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    task = await SQLAlchemyTaskRepository(session).get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    submission = await _create_submission(
        session,
        payload,
        task,
        answer=body.answer,
    )
    await session.commit()
    return _submission_response(submission)


@router.post(
    "/{task_id}/submissions/file",
    response_model=TaskSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_task_file(
    task_id: str,
    file: UploadFile = File(...),
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    task = await SQLAlchemyTaskRepository(session).get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    await _prevalidate_file_submission(session, payload, task)
    storage = LocalStorageService()
    try:
        file_url = await storage.save(file, folder="task-submissions")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    submission = await _create_submission(
        session,
        payload,
        task,
        file_url=file_url,
    )
    await session.commit()
    return _submission_response(submission)


@router.get(
    "/{task_id}/submissions",
    response_model=list[TaskSubmissionResponse],
)
async def list_task_submissions(
    task_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    task = await SQLAlchemyTaskRepository(session).get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    await _require_section_school(session, task.section_id, payload)
    repo = SQLAlchemyTaskSubmissionRepository(session)
    if Role(payload["role"]) == Role.STUDENT:
        submission = await repo.get_by_task_and_student(
            task.id,
            UUID(payload["sub"]),
        )
        return [_submission_response(submission)] if submission else []
    return [
        _submission_response(submission)
        for submission in await repo.list_by_task(task.id)
    ]


@router.post(
    "/{task_id}/submissions/{submission_id}/grade",
    response_model=TaskSubmissionResponse,
)
async def grade_task_submission(
    task_id: str,
    submission_id: str,
    body: GradeSubmissionRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    task = await SQLAlchemyTaskRepository(session).get_by_id(UUID(task_id))
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    await _require_section_school(session, task.section_id, payload)
    if not _can_manage_task(payload, task):
        raise HTTPException(status_code=403, detail="Cannot grade this task")
    repo = SQLAlchemyTaskSubmissionRepository(session)
    submission = await repo.get_by_id(UUID(submission_id))
    if submission is None or submission.task_id != task.id:
        raise HTTPException(status_code=404, detail="Submission not found")
    if submission.is_graded:
        raise HTTPException(
            status_code=409,
            detail="Submission is already graded; regrading is not yet supported",
        )
    submission.score = body.score
    submission.feedback = body.feedback.strip()
    submission.is_graded = True
    submission.graded_at = datetime.now(UTC)
    submission = await repo.update(submission)
    submission = await _award_submission_xp(session, submission, task)
    await session.commit()
    return _submission_response(submission)
