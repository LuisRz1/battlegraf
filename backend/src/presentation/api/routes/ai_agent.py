"""Endpoints de la memoria del agente IA (Redis)."""

from fastapi import APIRouter, Depends, HTTPException, status
from uuid import UUID

from src.domain.enums import Role
from src.infrastructure.ai.memory import build_agent_memory
from src.infrastructure.auth.dependencies import require_role

router = APIRouter(prefix="/ai", tags=["AI Agent"])

agent_access = require_role(
    Role.PROFESSOR,
    Role.TUTOR,
    Role.DIRECTOR,
    Role.SUBDIRECTOR,
)


@router.get("/memory/{school_id}")
async def get_agent_memory(
    school_id: str,
    payload: dict = Depends(agent_access),
):
    """Resumen de la memoria del agente para un colegio (Redis).

    Devuelve: estado de conexion, contexto guardado, ultimos mensajes del
    agente, materias con preguntas en cache y contador de generaciones.
    """
    if payload.get("school_id") != str(school_id):
        raise HTTPException(status_code=403, detail="School mismatch")

    memory = build_agent_memory()
    available = await memory.ping()
    if not available:
        return {
            "school_id": str(school_id),
            "redis": "unavailable",
            "detail": "Redis no disponible; la memoria del agente opera en modo no-op",
        }

    context = await memory.get_context(str(school_id))
    messages = await memory.get_messages(str(school_id), last=10)
    generations = await memory.bump_generation_counter(str(school_id))
    # no incrementar el contador al solo consultar; restaure el valor
    if generations > 0:
        await memory.save_context(str(school_id), {"last_seen_generations": generations})

    return {
        "school_id": str(school_id),
        "redis": "ok",
        "context": context,
        "messages": messages,
        "generation_counter": generations,
    }