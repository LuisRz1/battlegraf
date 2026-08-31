"""Public endpoints for the battle game (no authentication).

Estos endpoints sirven datos de solo lectura que el JUEGO (web y movil)
consume directamente sin login del estudiante: las preguntas aprobadas
del colegio en el formato compacto {t, q, a, c} que espera Godot.

Fuente de datos: la tabla `question_bank` de Supabase (la misma que usa
el panel y la IA generadora), NO la tabla ORM `questions` que esta vacia
para los colegios reales.
"""

import uuid
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status

from src.infrastructure.config import get_settings
from src.infrastructure.database.supabase_admin import supabase_admin

router = APIRouter(prefix="/public", tags=["Public"])

SUBJECT_ALIASES = {
    "matematica": "Matemática",
    "matematicas": "Matemática",
    "comunicacion": "Comunicación",
    "ciencia y tecnologia": "Ciencia y Tecnología",
    "ciencia": "Ciencia y Tecnología",
    "personal social": "Personal Social",
    "arte y cultura": "Arte y Cultura",
    "ingles": "Inglés",
    "historia": "Historia",
    "fisica": "Física",
    "quimica": "Química",
    "literatura": "Literatura",
    "geografia": "Geografía",
    "educacion fisica": "Educación Física",
    "religion": "Religión",
}


def _normalize_subject(name: str) -> str:
    """Normaliza el nombre de la materia para que coincida con los topics del juego."""
    key = name.strip().lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u")
    return SUBJECT_ALIASES.get(key, name.strip())


@router.get("/questions")
async def school_questions(
    school_id: Optional[str] = Query(default=None, description="ID del colegio"),
    subject: Optional[str] = Query(default=None, description="Materia (opcional)"),
    limit: int = Query(default=100, ge=1, le=500),
) -> dict:
    """Devuelve las preguntas APROBADAS de un colegio en formato juego.

    Lee de la tabla `question_bank` (Supabase) — las preguntas que el
    panel y la IA generadora escriben. Solo status=approved.
    """
    if not school_id:
        return {"questions": [], "school_id": None, "count": 0}

    try:
        school_uuid = uuid.UUID(str(school_id))
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="school_id debe ser un UUID valido",
        )

    try:
        supabase = supabase_admin()
        # materias del colegio para resolver el nombre
        subjects_rows = (
            supabase.table("subjects")
            .select("id, name")
            .eq("school_id", str(school_uuid))
            .execute()
            .data
            or []
        )
        name_by_id = {str(s["id"]): s["name"] for s in subjects_rows}

        # preguntas aprobadas del colegio (mas recientes primero)
        q_rows = (
            supabase.table("question_bank")
            .select("id, subject_id, question, options, correct_index, status, created_at")
            .eq("school_id", str(school_uuid))
            .eq("status", "approved")
            .order("created_at", False)
            .limit(limit)
            .execute()
            .data
            or []
        )

        subject_filter = None
        if subject:
            subject_filter = _normalize_subject(subject).lower()

        questions = []
        for q in q_rows:
            raw_name = name_by_id.get(str(q.get("subject_id")), "")
            topic = _normalize_subject(raw_name or "General")
            if subject_filter and topic.lower() != subject_filter:
                continue
            try:
                options = q.get("options") or []
                if isinstance(options, str):
                    options = __import__("json").loads(options)
                if not isinstance(options, list) or len(options) < 2:
                    continue
                correct = int(q.get("correct_index") or 0)
                correct = max(0, min(correct, len(options) - 1))
                questions.append(
                    {
                        "t": topic,
                        "q": (q.get("question") or "").strip(),
                        "a": [str(o) for o in options[:4]],
                        "c": correct,
                    }
                )
            except Exception:  # noqa: BLE001 - fila malformada, se omite
                continue

        return {
            "questions": questions,
            "school_id": str(school_uuid),
            "count": len(questions),
        }
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error cargando preguntas: {exc}",
        )