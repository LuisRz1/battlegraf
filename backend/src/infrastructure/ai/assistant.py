"""Asistente de BattleGraph con memoria persistente por cuenta.

Usa el proveedor OpenAI configurado (Luna) con fallback local si no hay clave.
La memoria de largo plazo vive en Supabase (`account_memory`); Redis sigue
siendo la memoria caliente opcional.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

from src.infrastructure.config import get_settings

logger = logging.getLogger(__name__)


def _system_prompt(role: str, context: dict) -> str:
    school = context.get("school_name") or "el colegio"
    base = (
        "Eres el asistente pedagogico de BattleGraph, una plataforma escolar de "
        "aprendizaje gamificado por grafos. Responde en espanol, claro y breve. "
        "No inventes datos del colegio; si falta informacion, indicalo."
    )
    if role in {"teacher", "professor", "tutor"}:
        return (
            base
            + f" Ayudas a docentes de {school} a planificar clases, crear material y "
            "revisar el avance de sus alumnos. Ofrece ideas concretas y accionables."
        )
    if role in {"owner", "director", "subdirector", "coordinator"}:
        return (
            base + f" Ayudas a la direccion de {school} con analisis de desempeno por "
            "aula y docente, y con decisiones pedagogicas."
        )
    return (
        base + " Ayudas a estudiantes a estudiar, entender sus materias y prepararse "
        "para las batallas. Motiva sin presionar."
    )


def _fallback_reply(role: str, prompt: str) -> str:
    return (
        "Soy tu asistente BattleGraph. Aun no tengo conexion con el modelo de IA, "
        "pero puedo ayudarte con ideas: organiza el tema en pasos, propone ejemplos "
        "y practica con preguntas. Vuelve a intentarlo cuando la IA este activa."
    )


def _context_block(context: dict) -> str:
    parts: list[str] = []
    if context.get("summary"):
        parts.append(f"Resumen de la cuenta: {context['summary']}")
    if context.get("grade"):
        parts.append(f"Grado: {context['grade']}")
    if context.get("subjects"):
        parts.append("Cursos: " + ", ".join(map(str, context["subjects"][:10])))
    if context.get("study_goal"):
        parts.append(f"Meta de estudio: {context['study_goal']}")
    return "\n".join(parts)


async def assistant_reply(
    role: str,
    prompt: str,
    context: dict | None = None,
    history: list[dict] | None = None,
) -> str:
    """Genera la respuesta del asistente usando el contexto persistente."""
    context = context or {}
    history = history or []
    settings = get_settings()
    if not settings.openai_api_key:
        return _fallback_reply(role, prompt)
    try:
        from langchain_openai import ChatOpenAI
        from pydantic import SecretStr

        kwargs: dict[str, Any] = {
            "api_key": SecretStr(settings.openai_api_key),
            "model": settings.openai_model,
            "temperature": 0.4,
        }
        if settings.openai_base_url:
            kwargs["base_url"] = settings.openai_base_url
        llm = ChatOpenAI(**kwargs)

        system = _system_prompt(role, context)
        block = _context_block(context)
        if block:
            system += "\n\nContexto de la cuenta:\n" + block
        convo = "\n".join(
            f"{'Usuario' if item.get('role') == 'user' else 'Asistente'}: "
            f"{str(item.get('content') or '')[:800]}"
            for item in history[-6:]
            if item.get("content")
        )
        history_block = f"Conversacion previa:\n{convo}\n\n" if convo else ""
        prompt_text = (
            f"{system}\n\n{history_block}Usuario: {prompt}\nAsistente:"
        )

        response = await asyncio.to_thread(llm.invoke, prompt_text)
        content = response.content
        return content if isinstance(content, str) else str(content)
    except Exception as exc:  # noqa: BLE001
        logger.warning("assistant fallback por error del proveedor: %s", exc)
        return _fallback_reply(role, prompt)
