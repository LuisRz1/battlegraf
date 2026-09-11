"""Endpoints extra del panel: recompensas, misiones, metas de estudio,
reportes por clase/docente y carga de material con IA (Supabase)."""

from __future__ import annotations

import io
import uuid
from datetime import datetime, timezone
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel, Field

from src.infrastructure.ai.openai_agent import build_question_agent
from src.infrastructure.database.supabase_admin import supabase_admin
from src.presentation.api.routes.panel import (
    Msg,
    _current_uid,
    _first,
    _own_student_profile,
    _require_member,
    _require_student_access,
)

router = APIRouter(prefix="/panel", tags=["Panel extras"])

STAFF_ROLES = ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"]
LEAD_ROLES = ["owner", "director", "subdirector", "coordinator"]


# ---------------------------------------------------------------- modelos


class BadgeIn(BaseModel):
    code: str = Field(min_length=2, max_length=60)
    name: str = Field(min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    icon_code: str = Field(default="M", max_length=3)
    category: str = Field(default="general", max_length=40)
    points: int = Field(default=15, ge=0, le=1000)
    criteria: dict | None = None
    is_active: bool = True


class PowerupIn(BaseModel):
    code: str = Field(min_length=2, max_length=60)
    name: str = Field(min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    icon_code: str = Field(default="icon_half", max_length=40)
    effect: str = Field(default="half", max_length=40)
    duration_seconds: int = Field(default=0, ge=0, le=3600)
    rarity: str = Field(default="tactico", max_length=20)
    cost_points: int = Field(default=20, ge=0, le=100000)
    is_active: bool = True


class MissionIn(BaseModel):
    title: str = Field(min_length=3, max_length=160)
    description: str | None = Field(default=None, max_length=800)
    scope: Literal["school", "grade", "section", "subject"] = "section"
    grade: str | None = None
    section_id: str | None = None
    subject_id: str | None = None
    goal_type: Literal[
        "tasks_completed",
        "tasks_graded",
        "battles_won",
        "battles_played",
        "attendance_streak",
        "grade_average",
        "xp_earned",
        "correct_answers",
    ] = "tasks_completed"
    goal_value: float = Field(default=1, ge=0)
    reward_points: int = Field(default=0, ge=0, le=100000)
    reward_badge_id: str | None = None
    reward_powerup_id: str | None = None
    reward_powerup_qty: int = Field(default=0, ge=0, le=100)
    starts_on: str | None = None
    ends_on: str | None = None
    status: Literal["draft", "active", "closed"] = "active"


class StudyGoalIn(BaseModel):
    grade: str = Field(min_length=1, max_length=20)
    subject_id: str | None = None
    academic_period_id: str | None = None
    title: str = Field(min_length=3, max_length=160)
    objectives: list[str] = Field(default_factory=list)
    topics: list[str] = Field(default_factory=list)
    competences: list[str] = Field(default_factory=list)
    status: Literal["active", "archived"] = "active"


class AwardBadgeIn(BaseModel):
    badge_id: str | None = None
    code: str | None = None
    note: str | None = Field(default=None, max_length=300)


# ---------------------------------------------------------------- utils


def _csv(headers: list[str], rows: list[list[Any]]) -> str:
    def cell(value: Any) -> str:
        return '"' + str(value if value is not None else "").replace('"', '""') + '"'

    lines = [",".join(cell(h) for h in headers)]
    lines += [",".join(cell(c) for c in row) for row in rows]
    return "\ufeff" + "\r\n".join(lines)


def _export_or_json(
    export: bool, filename: str, headers: list[str], rows: list[list[Any]], data: Any
) -> Any:
    if not export:
        return data
    return Response(
        content=_csv(headers, rows),
        media_type="text/csv; charset=utf-8",
        headers={"content-disposition": f'attachment; filename="{filename}"'},
    )


def _extract_text(path: str, suffix: str) -> str:
    """Extrae texto de PDF/DOCX/PPTX/TXT (sincrono)."""
    try:
        if suffix == ".pdf":
            from pypdf import PdfReader

            reader = PdfReader(path)
            return "\n".join((page.extract_text() or "") for page in reader.pages)
        if suffix == ".docx":
            import docx

            document = docx.Document(path)
            return "\n".join(p.text for p in document.paragraphs)
        if suffix == ".pptx":
            from pptx import Presentation

            presentation = Presentation(path)
            chunks = []
            for slide in presentation.slides:
                for shape in slide.shapes:
                    if hasattr(shape, "text"):
                        chunks.append(shape.text)
            return "\n".join(chunks)
        if suffix == ".txt":
            with open(path, encoding="utf-8", errors="ignore") as handle:
                return handle.read()
    except Exception:  # noqa: BLE001
        return ""
    return ""


# ---------------------------------------------------------------- catalogo


@router.get("/{school_id}/rewards/catalog")
async def rewards_catalog(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, STAFF_ROLES + ["student"])
    badges = (
        supabase.table("badges").select("*").eq("school_id", school_id).execute().data
        or []
    )
    powerups = (
        supabase.table("reward_powerups")
        .select("*")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    ranks = (
        supabase.table("rank_definitions")
        .select("*")
        .eq("school_id", school_id)
        .order("min_xp")
        .execute()
        .data
        or []
    )
    settings = (
        _first(
            supabase.table("school_settings")
            .select("reward_rules")
            .eq("school_id", school_id)
            .limit(1)
            .execute()
            .data
        )
        or {}
    )
    return {
        "badges": badges,
        "powerups": powerups,
        "ranks": ranks,
        "reward_rules": settings.get("reward_rules") or {},
    }


@router.post("/{school_id}/badges", response_model=Msg)
async def create_badge(
    school_id: str, body: BadgeIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, LEAD_ROLES + ["tutor", "teacher"])
    payload = body.model_dump()
    payload.update({"school_id": school_id, "is_demo": False})
    result = supabase.table("badges").insert(payload).execute().data or []
    return Msg(
        id=str(result[0].get("id")) if result else None, detail="Insignia creada"
    )


@router.patch("/badges/{badge_id}", response_model=Msg)
async def update_badge(
    badge_id: str, body: BadgeIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("badges")
            .select("school_id")
            .eq("id", badge_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(
        supabase, uid, row.get("school_id", ""), LEAD_ROLES + ["tutor", "teacher"]
    )
    supabase.table("badges").update(body.model_dump(exclude_none=True)).eq(
        "id", badge_id
    ).execute()
    return Msg(detail="Insignia actualizada")


@router.delete("/badges/{badge_id}", response_model=Msg)
async def delete_badge(badge_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("badges")
            .select("school_id")
            .eq("id", badge_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(supabase, uid, row.get("school_id", ""), LEAD_ROLES)
    supabase.table("badges").delete().eq("id", badge_id).execute()
    return Msg(detail="Insignia eliminada")


@router.post("/{school_id}/powerups", response_model=Msg)
async def create_powerup(
    school_id: str, body: PowerupIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, LEAD_ROLES + ["tutor", "teacher"])
    payload = body.model_dump()
    payload.update({"school_id": school_id, "is_demo": False})
    result = supabase.table("reward_powerups").insert(payload).execute().data or []
    return Msg(id=str(result[0].get("id")) if result else None, detail="Poder creado")


@router.patch("/powerups/{powerup_id}", response_model=Msg)
async def update_powerup(
    powerup_id: str, body: PowerupIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("reward_powerups")
            .select("school_id")
            .eq("id", powerup_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(
        supabase, uid, row.get("school_id", ""), LEAD_ROLES + ["tutor", "teacher"]
    )
    supabase.table("reward_powerups").update(body.model_dump(exclude_none=True)).eq(
        "id", powerup_id
    ).execute()
    return Msg(detail="Poder actualizado")


@router.delete("/powerups/{powerup_id}", response_model=Msg)
async def delete_powerup(powerup_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("reward_powerups")
            .select("school_id")
            .eq("id", powerup_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(supabase, uid, row.get("school_id", ""), LEAD_ROLES)
    supabase.table("reward_powerups").delete().eq("id", powerup_id).execute()
    return Msg(detail="Poder eliminado")


# ---------------------------------------------------------------- misiones


@router.get("/{school_id}/missions")
async def list_missions(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, STAFF_ROLES + ["student"])
    rows = (
        supabase.table("missions")
        .select("*")
        .eq("school_id", school_id)
        .order("created_at", ascending=False)
        .execute()
        .data
        or []
    )
    return {"missions": rows, "count": len(rows)}


@router.post("/{school_id}/missions", response_model=Msg)
async def create_mission(
    school_id: str, body: MissionIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, STAFF_ROLES)
    payload = body.model_dump()
    payload.update({"school_id": school_id, "created_by_membership_id": member["id"]})
    result = supabase.table("missions").insert(payload).execute().data or []
    return Msg(id=str(result[0].get("id")) if result else None, detail="Mision creada")


@router.patch("/missions/{mission_id}", response_model=Msg)
async def update_mission(
    mission_id: str, body: MissionIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("missions")
            .select("school_id")
            .eq("id", mission_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(supabase, uid, row.get("school_id", ""), STAFF_ROLES)
    supabase.table("missions").update(body.model_dump(exclude_none=True)).eq(
        "id", mission_id
    ).execute()
    return Msg(detail="Mision actualizada")


@router.delete("/missions/{mission_id}", response_model=Msg)
async def delete_mission(mission_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("missions")
            .select("school_id")
            .eq("id", mission_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(supabase, uid, row.get("school_id", ""), STAFF_ROLES)
    supabase.table("missions").delete().eq("id", mission_id).execute()
    return Msg(detail="Mision eliminada")


@router.get("/{school_id}/missions/{mission_id}/progress")
async def mission_progress(
    school_id: str, mission_id: str, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, STAFF_ROLES)
    rows = (
        supabase.table("student_missions")
        .select(
            "progress, completed, claimed, student_profiles(id, full_name, section_id)"
        )
        .eq("mission_id", mission_id)
        .execute()
        .data
        or []
    )
    return {"progress": rows, "count": len(rows)}


# ---------------------------------------------------------------- metas


@router.get("/{school_id}/study-goals")
async def list_study_goals(
    school_id: str,
    uid: Annotated[str, Depends(_current_uid)],
    grade: str | None = None,
    subject_id: str | None = None,
):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, STAFF_ROLES + ["student"])
    query = supabase.table("study_goals").select("*").eq("school_id", school_id)
    if grade:
        query = query.eq("grade", grade)
    if subject_id:
        query = query.eq("subject_id", subject_id)
    rows = query.order("grade").execute().data or []
    return {"study_goals": rows, "count": len(rows)}


@router.post("/{school_id}/study-goals", response_model=Msg)
async def create_study_goal(
    school_id: str, body: StudyGoalIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, STAFF_ROLES)
    payload = body.model_dump()
    payload.update(
        {
            "school_id": school_id,
            "created_by_membership_id": member["id"],
            "is_demo": False,
        }
    )
    result = supabase.table("study_goals").insert(payload).execute().data or []
    return Msg(id=str(result[0].get("id")) if result else None, detail="Meta creada")


@router.patch("/study-goals/{goal_id}", response_model=Msg)
async def update_study_goal(
    goal_id: str, body: StudyGoalIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("study_goals")
            .select("school_id")
            .eq("id", goal_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(supabase, uid, row.get("school_id", ""), STAFF_ROLES)
    payload = body.model_dump(exclude_none=True)
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()
    supabase.table("study_goals").update(payload).eq("id", goal_id).execute()
    return Msg(detail="Meta actualizada")


@router.delete("/study-goals/{goal_id}", response_model=Msg)
async def delete_study_goal(goal_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        _first(
            supabase.table("study_goals")
            .select("school_id")
            .eq("id", goal_id)
            .execute()
            .data
        )
        or {}
    )
    await _require_member(supabase, uid, row.get("school_id", ""), STAFF_ROLES)
    supabase.table("study_goals").delete().eq("id", goal_id).execute()
    return Msg(detail="Meta eliminada")


# ---------------------------------------------------------------- alumno


@router.get("/{school_id}/students/{student_id}/rewards")
async def student_rewards(
    school_id: str, student_id: str, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_student_access(supabase, uid, school_id, student_id)
    badges = (
        supabase.table("student_badges")
        .select("id, awarded_at, badges(code, name, description, icon_code, category)")
        .eq("student_profile_id", student_id)
        .execute()
        .data
        or []
    )
    powerups = (
        supabase.table("student_powerups")
        .select(
            "quantity, powerups:reward_powerups(code, name, icon_code, effect, rarity, cost_points)"
        )
        .eq("student_profile_id", student_id)
        .execute()
        .data
        or []
    )
    points = (
        supabase.table("points_ledger")
        .select("amount, reason, created_at")
        .eq("student_profile_id", student_id)
        .order("created_at", ascending=False)
        .limit(50)
        .execute()
        .data
        or []
    )
    return {
        "badges": badges,
        "powerups": powerups,
        "points_history": points,
        "points_balance": sum(int(p.get("amount") or 0) for p in points),
    }


@router.post("/{school_id}/students/{student_id}/badges", response_model=Msg)
async def award_badge(
    school_id: str,
    student_id: str,
    body: AwardBadgeIn,
    uid: Annotated[str, Depends(_current_uid)],
):
    supabase = supabase_admin()
    member, _ = await _require_student_access(
        supabase, uid, school_id, student_id, write=True
    )
    badge_id = body.badge_id
    if not badge_id and body.code:
        row = _first(
            supabase.table("badges")
            .select("id")
            .eq("school_id", school_id)
            .eq("code", body.code)
            .limit(1)
            .execute()
            .data
        )
        badge_id = (row or {}).get("id")
    if not badge_id:
        raise HTTPException(status_code=404, detail="Insignia no encontrada")
    from src.infrastructure.rewards import award_badge_by_code  # local import

    badge = (
        _first(
            supabase.table("badges")
            .select("code")
            .eq("id", badge_id)
            .limit(1)
            .execute()
            .data
        )
        or {}
    )
    if badge.get("code"):
        award_badge_by_code(
            supabase,
            school_id,
            student_id,
            badge["code"],
            source_type="manual",
            source_id=f"{badge_id}:{student_id}",
            membership_id=member["id"],
        )
    return Msg(detail="Insignia otorgada")


@router.post("/{school_id}/powerups/{powerup_id}/buy", response_model=Msg)
async def buy_powerup(
    school_id: str, powerup_id: str, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, ["student"])
    student = _own_student_profile(supabase, school_id, member["id"])
    if not student:
        raise HTTPException(status_code=403, detail="Sin perfil de alumno")
    student_id = str(student["id"])
    powerup = _first(
        supabase.table("reward_powerups")
        .select("id, cost_points, name")
        .eq("id", powerup_id)
        .eq("school_id", school_id)
        .limit(1)
        .execute()
        .data
    )
    if not powerup:
        raise HTTPException(status_code=404, detail="Poder no encontrado")
    from src.infrastructure.rewards import award_points, grant_powerup, points_balance

    cost = int(powerup.get("cost_points") or 0)
    balance = points_balance(supabase, student_id)
    if balance < cost:
        raise HTTPException(status_code=400, detail="Puntos insuficientes")
    award_points(
        supabase,
        school_id,
        student_id,
        -cost,
        f"compra_poder:{powerup.get('name')}",
        source_type="purchase",
        source_id=f"{powerup_id}:{uuid.uuid4().hex}",
    )
    grant_powerup(supabase, school_id, student_id, powerup_id, 1, "purchase")
    return Msg(detail="Poder adquirido")


# ---------------------------------------------------------------- reportes


def _section_report(supabase: Any, school_id: str, section_id: str) -> dict:
    section = (
        _first(
            supabase.table("sections")
            .select("id, display_name, grade, level")
            .eq("id", section_id)
            .limit(1)
            .execute()
            .data
        )
        or {}
    )
    students = (
        supabase.table("student_profiles")
        .select("id, full_name, email, section_id")
        .eq("school_id", school_id)
        .eq("section_id", section_id)
        .execute()
        .data
        or []
    )
    student_ids = [s["id"] for s in students]
    attendance = (
        supabase.table("attendance_records")
        .select("student_profile_id, status")
        .in_("student_profile_id", student_ids)
        .execute()
        .data
        if student_ids
        else []
    ) or []
    grades = (
        supabase.table("student_grades")
        .select("student_profile_id, score, status, grade_items(max_score, subject_id)")
        .in_("student_profile_id", student_ids)
        .execute()
        .data
        if student_ids
        else []
    ) or []
    submissions = (
        supabase.table("assignment_submissions")
        .select("student_profile_id, is_graded, score")
        .in_("student_profile_id", student_ids)
        .execute()
        .data
        if student_ids
        else []
    ) or []
    rewards = (
        supabase.table("student_badges")
        .select("student_profile_id")
        .in_("student_profile_id", student_ids)
        .execute()
        .data
        if student_ids
        else []
    ) or []

    per_student: dict[str, dict] = {
        s["id"]: {
            "id": s["id"],
            "full_name": s.get("full_name"),
            "attendance_total": 0,
            "attendance_ok": 0,
            "grades": [],
            "tasks_done": 0,
            "badges": 0,
        }
        for s in students
    }
    for row in attendance:
        bucket = per_student.get(str(row.get("student_profile_id")))
        if not bucket:
            continue
        bucket["attendance_total"] += 1
        if row.get("status") in {"present", "late"}:
            bucket["attendance_ok"] += 1
    for row in grades:
        bucket = per_student.get(str(row.get("student_profile_id")))
        if not bucket:
            continue
        score = row.get("score")
        item = row.get("grade_items") or {}
        max_score = float(item.get("max_score") or 0)
        if score is not None and max_score > 0:
            bucket["grades"].append((float(score) / max_score) * 100)
    for row in submissions:
        bucket = per_student.get(str(row.get("student_profile_id")))
        if bucket:
            bucket["tasks_done"] += 1
    for row in rewards:
        bucket = per_student.get(str(row.get("student_profile_id")))
        if bucket:
            bucket["badges"] += 1

    result_students = []
    for bucket in per_student.values():
        total = bucket["attendance_total"]
        avg_list = bucket["grades"]
        result_students.append(
            {
                "id": bucket["id"],
                "full_name": bucket["full_name"],
                "attendance_rate": (
                    round((bucket["attendance_ok"] / total) * 100, 1) if total else None
                ),
                "grade_average": (
                    round(sum(avg_list) / len(avg_list), 1) if avg_list else None
                ),
                "tasks_done": bucket["tasks_done"],
                "badges": bucket["badges"],
            }
        )
    return {
        "section": section,
        "students": result_students,
        "count": len(result_students),
    }


@router.get("/{school_id}/reports/class/{section_id}")
async def report_class(
    school_id: str,
    section_id: str,
    uid: Annotated[str, Depends(_current_uid)],
    export: bool = False,
):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, STAFF_ROLES)
    data = _section_report(supabase, school_id, section_id)
    rows = [
        [
            s.get("full_name"),
            s.get("attendance_rate"),
            s.get("grade_average"),
            s.get("tasks_done"),
            s.get("badges"),
        ]
        for s in data["students"]
    ]
    return _export_or_json(
        export,
        "battlegraf-clase.csv",
        ["Alumno", "Asistencia%", "Promedio%", "Tareas", "Insignias"],
        rows,
        data,
    )


@router.get("/{school_id}/reports/staff")
async def report_staff(
    school_id: str,
    uid: Annotated[str, Depends(_current_uid)],
    export: bool = False,
):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, LEAD_ROLES)
    staff = (
        supabase.table("staff_profiles")
        .select("id, full_name, email, role, scope_label, membership_id")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    subject_teachers = (
        supabase.table("subject_teachers")
        .select("staff_id, subject_id, subjects(name)")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    classes = (
        supabase.table("classes")
        .select("id, name, section_id, subject_id, teacher_membership_id")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    grade_items = (
        supabase.table("grade_items")
        .select("id, created_by_membership_id, section_id")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    assignments = (
        supabase.table("assignments")
        .select("id")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )

    by_staff: list[dict] = []
    for person in staff:
        membership_id = person.get("membership_id")
        subjects = [
            (row.get("subjects") or {}).get("name")
            for row in subject_teachers
            if str(row.get("staff_id")) == str(person["id"])
        ]
        their_classes = [
            c
            for c in classes
            if membership_id
            and str(c.get("teacher_membership_id")) == str(membership_id)
        ]
        items_created = [
            g
            for g in grade_items
            if membership_id
            and str(g.get("created_by_membership_id")) == str(membership_id)
        ]
        by_staff.append(
            {
                "id": person["id"],
                "full_name": person.get("full_name"),
                "role": person.get("role"),
                "scope_label": person.get("scope_label"),
                "subjects": [s for s in subjects if s],
                "classes": len(their_classes),
                "grade_items": len(items_created),
                "students": len(
                    {
                        str(c.get("section_id"))
                        for c in their_classes
                        if c.get("section_id")
                    }
                ),
            }
        )
    rows = [
        [
            p["full_name"],
            p["role"],
            ", ".join(p["subjects"]),
            p["classes"],
            p["grade_items"],
            p["students"],
        ]
        for p in by_staff
    ]
    return _export_or_json(
        export,
        "battlegraf-docentes.csv",
        ["Docente", "Rol", "Cursos", "Clases", "Evaluaciones", "Secciones"],
        rows,
        {"staff": by_staff, "count": len(by_staff), "assignments": len(assignments)},
    )


# ---------------------------------------------------------------- materiales IA


@router.post("/{school_id}/materials/upload", response_model=Msg)
async def upload_material(
    school_id: str,
    uid: Annotated[str, Depends(_current_uid)],
    subject_id: Annotated[str, Form()],
    file: Annotated[UploadFile, File()],
    title: Annotated[str, Form()] = "",
    grade: Annotated[str, Form()] = "",
):
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, STAFF_ROLES)
    raw = await file.read()
    filename = file.filename or "material.txt"
    suffix = ("." + filename.rsplit(".", 1)[-1].lower()) if "." in filename else ".txt"
    if len(raw) > 20 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Archivo mayor a 20 MB")

    text = ""
    try:
        tmp = io.BytesIO(raw)
        if suffix == ".pdf":
            from pypdf import PdfReader

            text = "\n".join(
                (page.extract_text() or "") for page in PdfReader(tmp).pages
            )
        elif suffix == ".docx":
            import docx

            text = "\n".join(p.text for p in docx.Document(tmp).paragraphs)
        elif suffix == ".pptx":
            from pptx import Presentation

            pptx = Presentation(tmp)
            chunks = []
            for slide in pptx.slides:
                for shape in slide.shapes:
                    if hasattr(shape, "text"):
                        chunks.append(shape.text)
            text = "\n".join(chunks)
        elif suffix in {".txt", ".png", ".jpg", ".jpeg", ".webp"}:
            text = raw.decode("utf-8", errors="ignore")
    except Exception:  # noqa: BLE001
        text = ""

    payload = {
        "school_id": school_id,
        "subject_id": subject_id,
        "title": title or filename,
        "file_name": filename,
        "file_type": suffix.lstrip("."),
        "processing_status": "extracted" if text else "received",
        "storage_path": None,
        "extracted_text": text[:200000],
        "char_count": len(text),
        "grade": grade or None,
        "uploaded_by_membership_id": member["id"],
        "is_demo": False,
    }
    result = supabase.table("learning_materials").insert(payload).execute().data or []
    return Msg(
        id=str(result[0].get("id")) if result else None,
        detail=f"Material recibido ({len(text)} caracteres extraidos)",
    )


@router.get("/{school_id}/materials")
async def list_materials(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, STAFF_ROLES)
    rows = (
        supabase.table("learning_materials")
        .select(
            "id, title, file_name, file_type, processing_status, subject_id, grade, "
            "char_count, created_at, subjects(name)"
        )
        .eq("school_id", school_id)
        .order("created_at", ascending=False)
        .execute()
        .data
        or []
    )
    return {"materials": rows, "count": len(rows)}


@router.post("/{school_id}/materials/{material_id}/generate", response_model=Msg)
async def generate_material_questions(
    school_id: str,
    material_id: str,
    uid: Annotated[str, Depends(_current_uid)],
    count: int = 10,
):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, STAFF_ROLES)
    material = _first(
        supabase.table("learning_materials")
        .select("id, subject_id, grade, extracted_text, title, subjects(name)")
        .eq("id", material_id)
        .eq("school_id", school_id)
        .limit(1)
        .execute()
        .data
    )
    if not material:
        raise HTTPException(status_code=404, detail="Material no encontrado")
    text = material.get("extracted_text") or ""
    if not text.strip():
        raise HTTPException(
            status_code=400, detail="El material no tiene texto extraido"
        )

    # Meta de estudio del grado/materia para orientar al agente.
    goal_query = (
        supabase.table("study_goals")
        .select("title, objectives, topics, competences")
        .eq("school_id", school_id)
        .eq("status", "active")
    )
    if material.get("grade"):
        goal_query = goal_query.eq("grade", material["grade"])
    if material.get("subject_id"):
        goal_query = goal_query.eq("subject_id", material["subject_id"])
    goal = _first(goal_query.limit(1).execute().data)
    goal_text = ""
    if goal:
        goal_text = (
            f"Meta: {goal.get('title')}. "
            f"Temas: {', '.join(goal.get('topics') or [])}. "
            f"Objetivos: {', '.join(goal.get('objectives') or [])}."
        )

    from src.domain.enums.subject import Subject

    subject_name = (material.get("subjects") or {}).get("name") or "General"
    try:
        subject_enum = Subject(subject_name)
    except Exception:  # noqa: BLE001
        subject_enum = next(iter(Subject))

    agent = build_question_agent()
    try:
        generated = await agent.generate_questions(
            f"{goal_text}\n\n{text}",
            subject_enum,
            count=max(1, min(count, 30)),
            context={"study_goal": goal, "prior_questions": []},
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"IA no disponible: {exc}") from exc

    letters = ["A", "B", "C", "D"]
    inserted = 0
    for item in generated or []:
        if not isinstance(item, dict):
            continue
        prompt = item.get("text") or item.get("question")
        options = [
            item.get("option_a"),
            item.get("option_b"),
            item.get("option_c"),
            item.get("option_d"),
        ]
        if not prompt or any(o is None for o in options):
            continue
        correct = str(item.get("correct_option") or "A").upper()
        correct_index = letters.index(correct) if correct in letters else 0
        supabase.table("question_bank").insert(
            {
                "school_id": school_id,
                "subject_id": material.get("subject_id"),
                "question": str(prompt)[:400],
                "options": [str(o)[:300] for o in options],
                "correct_index": correct_index,
                "status": "review",
                "source": "ai",
                "is_demo": False,
            }
        ).execute()
        inserted += 1
    supabase.table("learning_materials").update(
        {
            "processing_status": "review",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    ).eq("id", material_id).execute()
    return Msg(
        id=material_id,
        detail=f"{inserted} preguntas generadas para revision",
    )
