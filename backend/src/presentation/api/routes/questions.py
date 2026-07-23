"""Question bank endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pathlib import Path
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.enums import Role, Subject
from src.infrastructure.ai import build_question_agent
from src.infrastructure.auth.dependencies import get_current_user, require_role
from src.infrastructure.database.repositories import (
    SQLAlchemyQuestionBankRepository,
    SQLAlchemyQuestionRepository,
)
from src.infrastructure.database.session import get_db
from src.infrastructure.storage import LocalStorageService
from src.application.question_bank.use_cases import (
    ApproveQuestion,
    CreateQuestionBank,
    GenerateQuestions,
    ListQuestions,
    UploadMaterial,
)
from src.presentation.schemas.requests.question_requests import (
    CreateQuestionBankRequest,
    GenerateQuestionsRequest,
)
from src.presentation.schemas.responses.question_responses import (
    QuestionBankResponse,
    QuestionResponse,
)

router = APIRouter(prefix="/questions", tags=["Question Banks"])


def _bank_response(bank) -> QuestionBankResponse:
    return QuestionBankResponse(
        id=str(bank.id),
        school_id=str(bank.school_id),
        subject=bank.subject.value,
        total_generated=bank.total_generated,
        total_approved=bank.total_approved,
        created_at=bank.created_at,
    )


def _question_response(question) -> QuestionResponse:
    return QuestionResponse(
        id=str(question.id),
        bank_id=str(question.bank_id),
        school_id=str(question.school_id),
        creator_id=str(question.creator_id),
        subject=question.subject.value,
        text=question.text,
        option_a=question.option_a,
        option_b=question.option_b,
        option_c=question.option_c,
        option_d=question.option_d,
        correct_option=question.correct_option,
        explanation=question.explanation,
        is_approved=question.is_approved,
        usage_count=question.usage_count,
        created_at=question.created_at,
    )


@router.get("/banks", response_model=list[QuestionBankResponse])
async def list_banks(
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    """List question banks for the current user's school."""
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    school_id = payload.get("school_id")
    if not school_id:
        raise HTTPException(status_code=400, detail="Usuario sin colegio asignado")
    banks = await bank_repo.list_by_school(UUID(school_id))
    return [_bank_response(b) for b in banks]


@router.post("/banks", response_model=QuestionBankResponse, status_code=status.HTTP_201_CREATED)
async def create_bank(
    body: CreateQuestionBankRequest,
    session: AsyncSession = Depends(get_db),
    _=Depends(require_role(Role.PROFESSOR, Role.TUTOR, Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    use_case = CreateQuestionBank(bank_repo)
    try:
        subject = Subject(body.subject)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Materia invalida") from exc
    bank = await use_case.execute(UUID(body.school_id), subject)
    await session.commit()
    return _bank_response(bank)


@router.post("/banks/{bank_id}/upload", response_model=dict)
async def upload_material(
    bank_id: str,
    file: UploadFile = File(...),
    _=Depends(require_role(Role.PROFESSOR, Role.TUTOR, Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    storage = LocalStorageService()
    use_case = UploadMaterial(storage)
    file_path = await use_case.execute(file)
    return {"bank_id": bank_id, "file_path": file_path}


def _resolve_file_path(storage: LocalStorageService, file_path: str) -> str:
    if file_path and Path(file_path).exists():
        return file_path
    return storage.get_default_material()


@router.post("/banks/{bank_id}/generate", response_model=list[QuestionResponse])
async def generate_questions(
    bank_id: str,
    body: GenerateQuestionsRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    question_repo = SQLAlchemyQuestionRepository(session)
    storage = LocalStorageService()
    resolved_path = _resolve_file_path(storage, body.file_path)
    use_case = GenerateQuestions(bank_repo, question_repo, build_question_agent())
    try:
        questions = await use_case.execute(
            UUID(bank_id), UUID(payload["sub"]), resolved_path, body.count
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    await session.commit()
    return [_question_response(q) for q in questions]


@router.get("/banks/{bank_id}/questions", response_model=list[QuestionResponse])
async def list_questions(
    bank_id: str,
    session: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    question_repo = SQLAlchemyQuestionRepository(session)
    use_case = ListQuestions(question_repo)
    questions = await use_case.execute(UUID(bank_id))
    return [_question_response(q) for q in questions]


@router.post("/{question_id}/approve", response_model=QuestionResponse)
async def approve_question(
    question_id: str,
    session: AsyncSession = Depends(get_db),
    _=Depends(require_role(Role.PROFESSOR, Role.TUTOR, Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    question_repo = SQLAlchemyQuestionRepository(session)
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    use_case = ApproveQuestion(question_repo, bank_repo)
    try:
        question = await use_case.execute(UUID(question_id))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    await session.commit()
    return _question_response(question)
