"""Question bank endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.application.question_bank.use_cases import (
    ApproveQuestion,
    CreateQuestionBank,
    GenerateQuestions,
    ListQuestions,
    UploadMaterial,
)
from src.domain.entities.question import Question
from src.domain.enums import Role, Subject
from src.infrastructure.ai import build_question_agent
from src.infrastructure.auth.dependencies import require_role
from src.infrastructure.database.repositories import (
    SQLAlchemyQuestionBankRepository,
    SQLAlchemyQuestionRepository,
)
from src.infrastructure.database.session import get_db
from src.infrastructure.storage import LocalStorageService
from src.presentation.schemas.requests.question_requests import (
    CreateQuestionBankRequest,
    GenerateQuestionsRequest,
    UpdateQuestionBankRequest,
    UpdateQuestionRequest,
)
from src.presentation.schemas.responses.question_responses import (
    QuestionBankResponse,
    QuestionResponse,
)

router = APIRouter(prefix="/questions", tags=["Question Banks"])
teacher_access = require_role(
    Role.PROFESSOR,
    Role.TUTOR,
    Role.DIRECTOR,
    Role.SUBDIRECTOR,
)


def _require_bank_school(payload: dict, school_id: UUID) -> None:
    if payload.get("school_id") != str(school_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Question bank belongs to another school",
        )


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
    payload: dict = Depends(teacher_access),
):
    """List question banks for the current user's school."""
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    school_id = payload.get("school_id")
    if not school_id:
        raise HTTPException(status_code=400, detail="Usuario sin colegio asignado")
    banks = await bank_repo.list_by_school(UUID(school_id))
    return [_bank_response(b) for b in banks]


@router.post(
    "/banks", response_model=QuestionBankResponse, status_code=status.HTTP_201_CREATED
)
async def create_bank(
    body: CreateQuestionBankRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    use_case = CreateQuestionBank(bank_repo)
    try:
        subject = Subject(body.subject)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Materia invalida") from exc
    school_id = UUID(body.school_id)
    _require_bank_school(payload, school_id)
    bank = await use_case.execute(school_id, subject)
    await session.commit()
    return _bank_response(bank)


@router.post("/banks/{bank_id}/upload", response_model=dict)
async def upload_material(
    bank_id: str,
    file: UploadFile = File(...),
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    bank = await SQLAlchemyQuestionBankRepository(session).get_by_id(UUID(bank_id))
    if bank is None:
        raise HTTPException(status_code=404, detail="Question bank not found")
    _require_bank_school(payload, bank.school_id)
    storage = LocalStorageService()
    use_case = UploadMaterial(storage)
    try:
        file_path = await use_case.execute(file)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"bank_id": bank_id, "file_path": file_path}


def _resolve_file_path(storage: LocalStorageService, file_path: str) -> str:
    if not file_path:
        return storage.get_default_material()
    return storage.resolve_material_path(file_path)


@router.post("/banks/{bank_id}/generate", response_model=list[QuestionResponse])
async def generate_questions(
    bank_id: str,
    body: GenerateQuestionsRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    question_repo = SQLAlchemyQuestionRepository(session)
    storage = LocalStorageService()
    bank = await bank_repo.get_by_id(UUID(bank_id))
    if bank is None:
        raise HTTPException(status_code=404, detail="Question bank not found")
    _require_bank_school(payload, bank.school_id)
    try:
        resolved_path = _resolve_file_path(storage, body.file_path)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    use_case = GenerateQuestions(bank_repo, question_repo, build_question_agent())
    try:
        questions = await use_case.execute(
            UUID(bank_id), UUID(payload["sub"]), resolved_path, body.count
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    await session.commit()

    # Memoria del agente (Redis): registrar el evento y cachear claves de preguntas
    from src.infrastructure.ai.memory import build_agent_memory

    memory = build_agent_memory()
    try:
        if await memory.ping():
            school_key = str(bank.school_id)
            subject_label = (
                bank.subject.value if hasattr(bank.subject, "value") else str(bank.subject)
            )
            question_keys = [q["text"][:64] for q in questions]
            await memory.remember_generated(school_key, subject_label, question_keys)
            await memory.add_message(
                school_key,
                "agent",
                f"Generadas {len(questions)} preguntas de {subject_label} para el banco {bank_id}.",
            )
            await memory.bump_generation_counter(school_key)
    except Exception as exc:  # la memoria nunca debe romper la generacion
        import logging

        logging.getLogger(__name__).warning("AgentMemory post-generate error: %s", exc)

    return [_question_response(q) for q in questions]


@router.get("/banks/{bank_id}/questions", response_model=list[QuestionResponse])
async def list_questions(
    bank_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    bank = await SQLAlchemyQuestionBankRepository(session).get_by_id(UUID(bank_id))
    if bank is None:
        raise HTTPException(status_code=404, detail="Question bank not found")
    _require_bank_school(payload, bank.school_id)
    question_repo = SQLAlchemyQuestionRepository(session)
    use_case = ListQuestions(question_repo)
    questions = await use_case.execute(UUID(bank_id))
    return [_question_response(q) for q in questions]


@router.post("/{question_id}/approve", response_model=QuestionResponse)
async def approve_question(
    question_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    question_repo = SQLAlchemyQuestionRepository(session)
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    use_case = ApproveQuestion(question_repo, bank_repo)
    existing = await question_repo.get_by_id(UUID(question_id))
    if existing is None:
        raise HTTPException(status_code=404, detail="Question not found")
    _require_bank_school(payload, existing.school_id)
    try:
        question = await use_case.execute(UUID(question_id))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    await session.commit()
    return _question_response(question)


@router.get("/banks/{bank_id}", response_model=QuestionBankResponse)
async def get_bank(
    bank_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    bank = await SQLAlchemyQuestionBankRepository(session).get_by_id(UUID(bank_id))
    if bank is None:
        raise HTTPException(status_code=404, detail="Question bank not found")
    _require_bank_school(payload, bank.school_id)
    return _bank_response(bank)


@router.patch("/banks/{bank_id}", response_model=QuestionBankResponse)
async def update_bank(
    bank_id: str,
    body: UpdateQuestionBankRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    bank = await bank_repo.get_by_id(UUID(bank_id))
    if bank is None:
        raise HTTPException(status_code=404, detail="Question bank not found")
    _require_bank_school(payload, bank.school_id)
    if body.subject is not None:
        try:
            new_subject = Subject(body.subject)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="Materia invalida") from exc
        bank.subject = new_subject
    saved = await bank_repo.update(bank)
    await session.commit()
    return _bank_response(saved)


@router.delete("/banks/{bank_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_bank(
    bank_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    bank_repo = SQLAlchemyQuestionBankRepository(session)
    bank = await bank_repo.get_by_id(UUID(bank_id))
    if bank is None:
        raise HTTPException(status_code=404, detail="Question bank not found")
    _require_bank_school(payload, bank.school_id)
    await bank_repo.delete(bank.id)
    await session.commit()


@router.get("/{question_id}", response_model=QuestionResponse)
async def get_question(
    question_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    question = await SQLAlchemyQuestionRepository(session).get_by_id(UUID(question_id))
    if question is None:
        raise HTTPException(status_code=404, detail="Question not found")
    _require_bank_school(payload, question.school_id)
    return _question_response(question)


@router.patch("/{question_id}", response_model=QuestionResponse)
async def update_question(
    question_id: str,
    body: UpdateQuestionRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    question_repo = SQLAlchemyQuestionRepository(session)
    question = await question_repo.get_by_id(UUID(question_id))
    if question is None:
        raise HTTPException(status_code=404, detail="Question not found")
    _require_bank_school(payload, question.school_id)

    import dataclasses

    updated = dataclasses.replace(question)
    if body.text is not None:
        updated.text = body.text
    if body.option_a is not None:
        updated.option_a = body.option_a
    if body.option_b is not None:
        updated.option_b = body.option_b
    if body.option_c is not None:
        updated.option_c = body.option_c
    if body.option_d is not None:
        updated.option_d = body.option_d
    if body.correct_option is not None:
        if body.correct_option.upper() not in ("A", "B", "C", "D"):
            raise HTTPException(status_code=400, detail="Respuesta correcta invalida (A/B/C/D)")
        updated.correct_option = body.correct_option.upper()
    if body.explanation is not None:
        updated.explanation = body.explanation
    if body.is_approved is not None:
        updated.is_approved = body.is_approved

    saved = await question_repo.update(updated)
    await session.commit()
    return _question_response(saved)


@router.delete("/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_question(
    question_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(teacher_access),
):
    question_repo = SQLAlchemyQuestionRepository(session)
    question = await question_repo.get_by_id(UUID(question_id))
    if question is None:
        raise HTTPException(status_code=404, detail="Question not found")
    _require_bank_school(payload, question.school_id)
    await question_repo.delete(question.id)
    await session.commit()