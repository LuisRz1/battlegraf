"""Public endpoints for the battle game (no authentication).

Estos endpoints sirven datos de solo lectura que el JUEGO (web y movil)
consume directamente sin login del estudiante: las preguntas aprobadas
del colegio en el formato compacto {topic, question, answers, correct}.
"""

import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.infrastructure.database import repositories
from src.infrastructure.database.session import get_db

router = APIRouter(prefix="/public", tags=["Public"])


def _question_to_game(question) -> dict:
    """Convierte una Question aprobada al formato del juego Godot:
    {"t": materia, "q": texto, "a": [4 opciones], "c": indice correcto}
    """
    answers = [
        question.option_a,
        question.option_b,
        question.option_c,
        question.option_d,
    ]
    correct_map = {"A": 0, "B": 1, "C": 2, "D": 3}
    correct = correct_map.get((question.correct_option or "A").upper(), 0)
    subject = question.subject
    return {
        "t": subject.value if hasattr(subject, "value") else str(subject),
        "q": question.text,
        "a": answers,
        "c": correct,
    }


@router.get("/questions")
async def school_questions(
    school_id: Optional[str] = Query(default=None, description="ID del colegio"),
    subject: Optional[str] = Query(default=None, description="Materia (opcional)"),
    limit: int = Query(default=100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Devuelve las preguntas APROBADAS de un colegio en formato juego.

    Sin autenticacion: el juego web/movil solo necesita el school_id.
    """
    if subject:
        from src.domain.enums.subject import Subject

        subject_value = Subject(subject).value
    else:
        subject_value = None

    if not school_id:
        return {"questions": [], "school_id": None, "count": 0}

    try:
        school_uuid = uuid.UUID(str(school_id))
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="school_id debe ser un UUID valido",
        )

    questions_repo = repositories.SQLAlchemyQuestionRepository(db)
    all_questions = await questions_repo.list_by_school(school_uuid)

    approved = [
        q
        for q in all_questions
        if q.is_approved
        and (subject_value is None or q.subject.value == subject_value)
    ]

    approved = sorted(
        approved, key=lambda q: getattr(q, "created_at", None) or "", reverse=True
    )
    approved = approved[:limit]

    return {
        "questions": [_question_to_game(q) for q in approved],
        "school_id": str(school_uuid),
        "count": len(approved),
    }
