"""Panel API: CRUD completo del panel administrativo (expuesto en Swagger).

Autenticación: Bearer token = JWT de Supabase (el que usa la landing).
El usuario se resuelve por auth.uid() y sus memberships determinan permisos.
Operaciones contra Supabase (servidor -> service role, sin RLS).
"""

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field

from src.infrastructure.config import get_settings
from src.infrastructure.database.supabase_admin import supabase_admin

router = APIRouter(prefix="/panel", tags=["Panel"])


# ---------- modelos ----------

class Msg(BaseModel):
    ok: bool = True
    detail: str | None = None
    id: str | None = None


class SectionIn(BaseModel):
    level: str = "Primaria"
    grade: str = Field(min_length=1, max_length=12)
    section_label: str = Field(min_length=1, max_length=8)
    tutor_name: str | None = None


class SubjectIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    icon_code: str = Field(min_length=1, max_length=3)
    color: str = "#e6b84d"


class StaffIn(BaseModel):
    full_name: str = Field(min_length=3, max_length=140)
    email: str | None = None
    role: str = "teacher"
    scope_label: str | None = None
    status: str = "invited"


class StudentIn(BaseModel):
    full_name: str = Field(min_length=3, max_length=140)
    email: str | None = None
    section_id: str | None = None


class QuestionIn(BaseModel):
    subject_id: str | None = None
    question: str = Field(min_length=8, max_length=400)
    options: list[str] = Field(min_length=4, max_length=4)
    correct_index: int = Field(ge=0, le=3)


class AssignmentIn(BaseModel):
    title: str = Field(min_length=3, max_length=140)
    section_id: str | None = None
    subject_id: str | None = None
    delivery_type: str = "quiz"
    due_at: str | None = None
    xp_reward: int = 80
    status: str = "scheduled"


class BattleIn(BaseModel):
    title: str = Field(min_length=3, max_length=140)
    battle_type: str = "student_vs_bot"
    opponent_a: str = ""
    opponent_b: str = ""
    scheduled_at: str | None = None
    graph_layers: int = 4
    nodes_per_layer: int = 4
    status: str = "scheduled"


class RankIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    min_xp: int = 0
    position: int = 0


class ClassIn(BaseModel):
    name: str = Field(min_length=3, max_length=140)
    subject_id: str | None = None
    section_id: str | None = None


class ClassCodeIn(BaseModel):
    class_code: str = Field(min_length=4, max_length=10)


# ---------- utilidades ----------

def _fail(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


async def _current_uid(authorization: Annotated[str | None, Header()] = None) -> str:
    """Valida el JWT de Supabase y devuelve el uid del usuario."""
    if not authorization or " " not in authorization:
        raise HTTPException(status_code=401, detail="Token requerido")
    token = authorization.split(" ", 1)[1]
    try:
        from jose import jwt  # PyJWT-compatible: python-jose
        settings = get_settings()
        secret = settings.supabase_jwt_secret
        payload = jwt.decode(
            token, secret, algorithms=["HS256"],
            options={"verify_aud": False},
        )
        if "sub" not in payload:
            raise ValueError("sin sub")
        return payload["sub"]
    except Exception:
        raise HTTPException(status_code=401, detail="Token invalido o expirado")


async def _require_member(supabase: Any, uid: str, school_id: str, roles: list[str]) -> dict:
    """Verifica que el usuario sea miembro del colegio con uno de los roles."""
    resp = (
        supabase.table("memberships")
        .select("id, role, user_id, school_id")
        .eq("user_id", uid)
        .eq("school_id", school_id)
        .in_("role", roles)
        .limit(1)
        .execute()
    )
    rows = resp.data or []
    if not rows:
        raise HTTPException(status_code=403, detail="Sin permisos en este colegio")
    return rows[0]


# ---------- secciones ----------

@router.post("/{school_id}/sections", response_model=Msg)
async def create_section(school_id: str, body: SectionIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    label = body.section_label.upper()
    display = f"{body.grade}. {body.level} {label}"
    code = f"{body.grade}-{body.level[:3].upper()}{label}"
    year = supabase.table("academic_years").select("id").eq("school_id", school_id).eq("is_active", True).limit(1).execute()
    resp = supabase.table("sections").insert({
        "school_id": school_id, "level": body.level, "grade": body.grade,
        "section_label": label, "code": code, "display_name": display,
        "tutor_name": body.tutor_name, "academic_year_id": (year.data or [{}])[0].get("id"),
    }).execute()
    return Msg(id=resp and resp.data and resp.data[0].get("id"), detail="Seccion creada")


@router.patch("/sections/{section_id}", response_model=Msg)
async def update_section(section_id: str, body: SectionIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("sections").select("school_id").eq("id", section_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    label = body.section_label.upper()
    supabase.table("sections").update({
        "level": body.level, "grade": body.grade, "section_label": label,
        "tutor_name": body.tutor_name, "display_name": f"{body.grade}. {body.level} {label}",
    }).eq("id", section_id).execute()
    return Msg(detail="Seccion actualizada")


@router.delete("/sections/{section_id}", response_model=Msg)
async def delete_section(section_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("sections").select("school_id").eq("id", section_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator"])
    supabase.table("sections").delete().eq("id", section_id).execute()
    return Msg(detail="Seccion eliminada")


@router.get("/{school_id}/sections")
async def list_sections(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    rows = supabase.table("sections").select("*").eq("school_id", school_id).order("display_name").execute()
    return rows.data or []


# ---------- materias ----------

@router.post("/{school_id}/subjects", response_model=Msg)
async def create_subject(school_id: str, body: SubjectIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    slug = "".join(ch for ch in body.name.lower() if ch.isalnum())[:50]
    resp = supabase.table("subjects").insert({
        "school_id": school_id, "name": body.name, "slug": slug,
        "icon_code": body.icon_code.upper(), "color": body.color, "is_enabled": True,
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Materia creada")


@router.patch("/subjects/{subject_id}", response_model=Msg)
async def update_subject(subject_id: str, body: SubjectIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("subjects").select("school_id").eq("id", subject_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("subjects").update({
        "name": body.name, "icon_code": body.icon_code.upper(), "color": body.color,
    }).eq("id", subject_id).execute()
    return Msg(detail="Materia actualizada")


@router.delete("/subjects/{subject_id}", response_model=Msg)
async def delete_subject(subject_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("subjects").select("school_id").eq("id", subject_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("subjects").delete().eq("id", subject_id).execute()
    return Msg(detail="Materia eliminada")


# ---------- personas ----------

@router.post("/{school_id}/staff", response_model=Msg)
async def create_staff(school_id: str, body: StaffIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector"])
    resp = supabase.table("staff_profiles").insert({
        "school_id": school_id, "full_name": body.full_name, "email": body.email,
        "role": body.role, "scope_label": body.scope_label, "status": body.status, "is_demo": False,
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Perfil creado")


@router.patch("/staff/{staff_id}", response_model=Msg)
async def update_staff(staff_id: str, body: StaffIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("staff_profiles").select("school_id").eq("id", staff_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector"])
    supabase.table("staff_profiles").update(body.model_dump()).eq("id", staff_id).execute()
    return Msg(detail="Perfil actualizado")


@router.delete("/staff/{staff_id}", response_model=Msg)
async def delete_staff(staff_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("staff_profiles").select("school_id").eq("id", staff_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector"])
    supabase.table("staff_profiles").delete().eq("id", staff_id).execute()
    return Msg(detail="Perfil eliminado")


@router.post("/{school_id}/students", response_model=Msg)
async def create_student(school_id: str, body: StudentIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    resp = supabase.table("student_profiles").insert({
        "school_id": school_id, "full_name": body.full_name, "email": body.email,
        "section_id": body.section_id, "status": "active", "is_demo": False,
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Alumno creado")


@router.patch("/students/{student_id}", response_model=Msg)
async def update_student(student_id: str, body: StudentIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("student_profiles").select("school_id").eq("id", student_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    patch: dict[str, Any] = {"full_name": body.full_name}
    if body.email is not None:
        patch["email"] = body.email
    if body.section_id is not None:
        patch["section_id"] = body.section_id
    supabase.table("student_profiles").update(patch).eq("id", student_id).execute()
    return Msg(detail="Alumno actualizado")


@router.delete("/students/{student_id}", response_model=Msg)
async def delete_student(student_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("student_profiles").select("school_id").eq("id", student_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator"])
    supabase.table("student_profiles").delete().eq("id", student_id).execute()
    return Msg(detail="Alumno eliminado")


# ---------- preguntas ----------

@router.post("/{school_id}/questions", response_model=Msg)
async def create_question(school_id: str, body: QuestionIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    resp = supabase.table("question_bank").insert({
        "school_id": school_id, "subject_id": body.subject_id, "question": body.question,
        "options": body.options, "correct_index": body.correct_index, "status": "review", "source": "manual",
        "is_demo": False,
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Pregunta creada")


@router.patch("/questions/{question_id}", response_model=Msg)
async def update_question(question_id: str, body: QuestionIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("question_bank").select("school_id").eq("id", question_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("question_bank").update(body.model_dump()).eq("id", question_id).execute()
    return Msg(detail="Pregunta actualizada")


@router.delete("/questions/{question_id}", response_model=Msg)
async def delete_question(question_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("question_bank").select("school_id").eq("id", question_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("question_bank").delete().eq("id", question_id).execute()
    return Msg(detail="Pregunta eliminada")


@router.post("/questions/{question_id}/approve", response_model=Msg)
async def approve_question(question_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("question_bank").select("school_id").eq("id", question_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("question_bank").update({"status": "approved"}).eq("id", question_id).execute()
    return Msg(detail="Pregunta aprobada")


# ---------- tareas y batallas ----------

@router.post("/{school_id}/assignments", response_model=Msg)
async def create_assignment(school_id: str, body: AssignmentIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    resp = supabase.table("assignments").insert({
        "school_id": school_id, "section_id": body.section_id, "subject_id": body.subject_id,
        "title": body.title, "delivery_type": body.delivery_type, "due_at": body.due_at,
        "xp_reward": body.xp_reward, "status": body.status, "is_demo": False,
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Tarea creada")


@router.patch("/assignments/{assignment_id}", response_model=Msg)
async def update_assignment(assignment_id: str, body: AssignmentIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("assignments").select("school_id").eq("id", assignment_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("assignments").update(body.model_dump()).eq("id", assignment_id).execute()
    return Msg(detail="Tarea actualizada")


@router.delete("/assignments/{assignment_id}", response_model=Msg)
async def delete_assignment(assignment_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("assignments").select("school_id").eq("id", assignment_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("assignments").delete().eq("id", assignment_id).execute()
    return Msg(detail="Tarea eliminada")


@router.post("/{school_id}/battles", response_model=Msg)
async def create_battle(school_id: str, body: BattleIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    resp = supabase.table("battle_events").insert({
        "school_id": school_id, "title": body.title, "battle_type": body.battle_type,
        "opponent_a": body.opponent_a, "opponent_b": body.opponent_b, "scheduled_at": body.scheduled_at,
        "graph_layers": body.graph_layers, "nodes_per_layer": body.nodes_per_layer,
        "status": body.status, "is_demo": False,
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Batalla programada")


@router.patch("/battles/{battle_id}", response_model=Msg)
async def update_battle(battle_id: str, body: BattleIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("battle_events").select("school_id").eq("id", battle_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("battle_events").update(body.model_dump()).eq("id", battle_id).execute()
    return Msg(detail="Batalla actualizada")


@router.delete("/battles/{battle_id}", response_model=Msg)
async def delete_battle(battle_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("battle_events").select("school_id").eq("id", battle_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    supabase.table("battle_events").delete().eq("id", battle_id).execute()
    return Msg(detail="Batalla eliminada")


# ---------- rangos y clases ----------

@router.post("/{school_id}/ranks", response_model=Msg)
async def create_rank(school_id: str, body: RankIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator"])
    resp = supabase.table("rank_definitions").insert({
        "school_id": school_id, "name": body.name, "min_xp": body.min_xp,
        "position": body.position, "is_demo": False,
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Rango creado")


@router.delete("/ranks/{rank_id}", response_model=Msg)
async def delete_rank(rank_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (supabase.table("rank_definitions").select("school_id").eq("id", rank_id).execute().data or [{}])[0]
    await _require_member(supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector", "coordinator"])
    supabase.table("rank_definitions").delete().eq("id", rank_id).execute()
    return Msg(detail="Rango eliminado")


@router.post("/{school_id}/classes", response_model=Msg)
async def create_class(school_id: str, body: ClassIn, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    member = await _require_member(supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"])
    year = supabase.table("academic_years").select("id").eq("school_id", school_id).eq("is_active", True).limit(1).execute()
    subj = None
    if body.subject_id:
        subj = (supabase.table("subjects").select("name").eq("id", body.subject_id).execute().data or [{}])[0].get("name")
    # codigo unico CL-XXXX
    import random as rnd
    code = ""
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    for _ in range(12):
        cand = "CL-" + "".join(rnd.choice(alphabet) for _ in range(4))
        exists = supabase.table("classes").select("id").eq("code", cand).execute()
        if not exists.data:
            code = cand
            break
    resp = supabase.table("classes").insert({
        "school_id": school_id, "name": body.name, "subject": subj, "code": code,
        "is_active": True, "academic_year_id": (year.data or [{}])[0].get("id"),
        "section_id": body.section_id, "subject_id": body.subject_id,
        "teacher_membership_id": member["id"],
    }).execute()
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Clase creada con codigo " + code)


@router.post("/classes/join", response_model=Msg)
async def join_class(body: ClassCodeIn, uid: Annotated[str, Depends(_current_uid)]):
    """El alumno se inscribe a una clase vigente mediante su codigo."""
    supabase = supabase_admin()
    try:
        result = supabase.rpc("enroll_student_by_code", {"p_join_code": body.class_code}).execute()
        return Msg(id=result.data, detail="Inscrito a la clase")
    except Exception as exc:  # noqa: BLE001
        raise _fail(str(exc))