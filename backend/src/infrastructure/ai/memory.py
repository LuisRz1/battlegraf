"""Memoria del agente IA basada en Redis.

Arquitectura hibrida recomendada para el agente de BattleGraph:

- Redis: memoria CALIENTE de corta duracion (TTL) por colegio.
  * contexto de la conversacion/acciones del agente (lista con TTL)
  * cache de preguntas ya generadas por materia (evita duplicados)
  * contadores y rate-limit de generacion
- Postgres/Supabase: fuente de verdad persistente de largo plazo
  (colegios, secciones, anios, preguntas, estudiantes).

Redis es escalable horizontalmente (clusters/sentinel) y es el estandar de la
industria para memoria de agentes (LangChain RedisChatMessageHistory, etc.).
Para el hackathon basta un Redis local (portable/Memurai/contendor docker);
para produccion se usa la misma imagen redis del docker-compose o un Redis
gestionado (Upstash/Redis Cloud) que se conecta por URL.
"""

from __future__ import annotations

import json
import logging
from typing import Any

from src.infrastructure.config import get_settings

logger = logging.getLogger(__name__)

PREFIX = "battlegraf:agent"
CTX_TTL_SECONDS = 60 * 60 * 6  # 6h de contexto caliente por colegio
MSG_MAX_LEN = 4000  # limite por mensaje almacenado


class AgentMemory:
    """Memoria del agente IA por colegio, con fallback no-op si Redis cae."""

    def __init__(self) -> None:
        self._client: Any = None
        self._available = False
        self._lazy_init()

    def _lazy_init(self) -> None:
        try:
            from redis import asyncio as aioredis

            settings = get_settings()
            self._client = aioredis.from_url(
                settings.redis_url, decode_responses=True
            )
            self._available = True
        except Exception as exc:  # pragma: no cover - entorno sin redis
            logger.warning("AgentMemory sin Redis: %s (modo no-op)", exc)
            self._available = False

    # ---- utilidades ----
    @staticmethod
    def _key(school_id: str, kind: str) -> str:
        return f"{PREFIX}:{school_id}:{kind}"

    async def ping(self) -> bool:
        if not self._available:
            return False
        try:
            return bool(await self._client.ping())
        except Exception:
            self._available = False
            return False

    # ---- contexto del colegio ----
    async def get_context(self, school_id: str) -> dict[str, Any]:
        """Devuelve el contexto recordado para un colegio (dict vacio si no hay)."""
        if not self._available:
            return {}
        try:
            raw = await self._client.get(self._key(school_id, "context"))
            return json.loads(raw) if raw else {}
        except Exception as exc:
            logger.warning("AgentMemory.get_context error: %s", exc)
            return {}

    async def save_context(self, school_id: str, context: dict[str, Any]) -> None:
        """Guarda/actualiza el contexto del colegio con TTL renovado."""
        if not self._available:
            return
        try:
            key = self._key(school_id, "context")
            current = await self.get_context(school_id)
            current.update(context)
            await self._client.set(key, json.dumps(current, ensure_ascii=False), ex=CTX_TTL_SECONDS)
        except Exception as exc:
            logger.warning("AgentMemory.save_context error: %s", exc)

    # ---- historial de mensajes/acciones del agente ----
    async def add_message(
        self,
        school_id: str,
        role: str,
        content: str,
        ttl: int = CTX_TTL_SECONDS,
    ) -> None:
        """Agrega una entrada al historial del colegio (cola con TTL)."""
        if not self._available:
            return
        try:
            entry = {"role": role, "content": content[:MSG_MAX_LEN]}
            key = self._key(school_id, "messages")
            pipe = self._client.pipeline()
            pipe.rpush(key, json.dumps(entry, ensure_ascii=False))
            pipe.ltrim(key, -50, -1)  # retener ultimas 50 entradas
            pipe.expire(key, ttl)
            await pipe.execute()
        except Exception as exc:
            logger.warning("AgentMemory.add_message error: %s", exc)

    async def get_messages(self, school_id: str, last: int = 10) -> list[dict[str, str]]:
        """Devuelve los ultimos `last` mensajes del historial del colegio."""
        if not self._available:
            return []
        try:
            raw = await self._client.lrange(self._key(school_id, "messages"), -last, -1)
            return [json.loads(x) for x in raw]
        except Exception as exc:
            logger.warning("AgentMemory.get_messages error: %s", exc)
            return []

    # ---- cache de preguntas generadas (evita duplicados por materia) ----
    async def remember_generated(
        self, school_id: str, subject: str, question_keys: list[str]
    ) -> None:
        """Registra un conjunto de preguntas generadas para una materia."""
        if not self._available:
            return
        try:
            key = self._key(school_id, f"generated:{subject}")
            pipe = self._client.pipeline()
            for qk in question_keys:
                pipe.sadd(key, qk)
            pipe.expire(key, 60 * 60 * 24)  # 24h de memoria de generacion
            await pipe.execute()
        except Exception as exc:
            logger.warning("AgentMemory.remember_generated error: %s", exc)

    async def already_generated(self, school_id: str, subject: str) -> set[str]:
        """Devuelve las claves de preguntas ya generadas para una materia."""
        if not self._available:
            return set()
        try:
            members = await self._client.smembers(self._key(school_id, f"generated:{subject}"))
            return set(members)
        except Exception as exc:
            logger.warning("AgentMemory.already_generated error: %s", exc)
            return set()

    # ---- contador de generaciones (rate-limit suave) ----
    async def bump_generation_counter(self, school_id: str) -> int:
        """Incrementa el contador de generaciones del colegio y lo devuelve."""
        if not self._available:
            return 0
        try:
            key = self._key(school_id, "generations")
            n = await self._client.incr(key)
            await self._client.expire(key, 60 * 60 * 24)
            return int(n)
        except Exception as exc:
            logger.warning("AgentMemory.bump_generation_counter error: %s", exc)
            return 0


def build_agent_memory() -> AgentMemory:
    """Factory de la memoria del agente (singleton ligero por proceso)."""
    return AgentMemory()