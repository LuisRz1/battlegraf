"""Asistente IA del panel con memoria persistente por cuenta (account_memory)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated, Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from src.infrastructure.database.supabase_admin import supabase_admin
from src.presentation.api.routes.panel import (
    Msg,
    _current_uid,
    _first,
    _own_student_profile,
    _require_member,
)

router = APIRouter(prefix="/panel", tags=["Panel assistant"])

STAFF_ROLES = ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"]


class MemoryUpdateIn(BaseModel):
    summary: str | None = Field(default=None, max_length=2000)
    context: dict | None = None


class AssistantIn(BaseModel):
    prompt: str = Field(min_length=1, max_length=2000)


def _get_memory(supabase: Any, school_id: str, member: dict) -> dict:
    row = _first(
        supabase.table("account_memory")
        .select("*")
        .eq("membership_id", member["id"])
        .limit(1)
        .execute()
        .data
    )
    if row:
        return row
    return {
        "membership_id": member["id"],
        "school_id": school_id,
        "kind": member.get("role"),
        "context": {},
        "summary": None,
    }


def _enrich_context(supabase: Any, school_id: str, member: dict) -> dict:
    context: dict = {}
    role = member.get("role")
    if role == "student":
        student = _own_student_profile(supabase, school_id, member["id"])
        if student:
            context["student_profile_id"] = student["id"]
            if student.get("section_id"):
                section = _first(
                    supabase.table("sections")
                    .select("grade, display_name")
                    .eq("id", student["section_id"])
                    .limit(1)
                    .execute()
                    .data
                )
                context["grade"] = (section or {}).get("grade")
                context["section"] = (section or {}).get("display_name")
                subjects = (
                    supabase.table("section_subjects")
                    .select("subjects(name)")
                    .eq("section_id", student["section_id"])
                    .execute()
                    .data
                    or []
                )
                context["subjects"] = [
                    (row.get("subjects") or {}).get("name")
                    for row in subjects
                    if (row.get("subjects") or {}).get("name")
                ]
    elif role in {"teacher", "professor", "tutor"}:
        staff = _first(
            supabase.table("staff_profiles")
            .select("id")
            .eq("school_id", school_id)
            .eq("membership_id", member["id"])
            .limit(1)
            .execute()
            .data
        )
        if staff:
            links = (
                supabase.table("subject_teachers")
                .select("subjects(name)")
                .eq("school_id", school_id)
                .eq("staff_id", staff["id"])
                .execute()
                .data
                or []
            )
            context["subjects"] = [
                (row.get("subjects") or {}).get("name")
                for row in links
                if (row.get("subjects") or {}).get("name")
            ]
    return context


@router.get("/{school_id}/me/memory")
async def get_memory(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    """Memoria persistente de la cuenta (contexto + resumen + historial)."""
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, STAFF_ROLES + ["student"])
    row = _get_memory(supabase, school_id, member)
    context = row.get("context") or {}
    return {
        "membership_id": member["id"],
        "role": member.get("role"),
        "summary": row.get("summary"),
        "context": context,
        "messages": context.get("messages") or [],
    }


@router.put("/{school_id}/me/memory", response_model=Msg)
async def update_memory(
    school_id: str, body: MemoryUpdateIn, uid: Annotated[str, Depends(_current_uid)]
):
    """Actualiza el resumen/contexto persistente de la cuenta."""
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, STAFF_ROLES + ["student"])
    row = _get_memory(supabase, school_id, member)
    context = dict(row.get("context") or {})
    if body.context:
        context.update(body.context)
    payload = {
        "school_id": school_id,
        "membership_id": member["id"],
        "kind": member.get("role"),
        "context": context,
        "summary": body.summary if body.summary is not None else row.get("summary"),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if row.get("id"):
        supabase.table("account_memory").update(payload).eq("id", row["id"]).execute()
    else:
        supabase.table("account_memory").insert(payload).execute()
    return Msg(detail="Memoria actualizada")


@router.post("/{school_id}/me/assistant")
async def assistant(
    school_id: str, body: AssistantIn, uid: Annotated[str, Depends(_current_uid)]
):
    """Chat del asistente con memoria persistente por cuenta."""
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, STAFF_ROLES + ["student"])
    row = _get_memory(supabase, school_id, member)
    context = dict(row.get("context") or {})
    context.update(_enrich_context(supabase, school_id, member))
    context["school_id"] = school_id
    history = list(context.get("messages") or [])

    from src.infrastructure.ai.assistant import assistant_reply

    reply = await assistant_reply(
        member.get("role", "student"), body.prompt, context, history
    )

    messages = (
        history
        + [
            {"role": "user", "content": body.prompt},
            {"role": "assistant", "content": reply},
        ]
    )[-20:]
    context["messages"] = messages
    payload = {
        "school_id": school_id,
        "membership_id": member["id"],
        "kind": member.get("role"),
        "context": context,
        "summary": row.get("summary") or body.prompt[:120],
        "last_interaction_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if row.get("id"):
        supabase.table("account_memory").update(payload).eq("id", row["id"]).execute()
    else:
        supabase.table("account_memory").insert(payload).execute()
    return {"reply": reply, "messages": messages}
