"""Panel API: CRUD completo del panel administrativo (expuesto en Swagger).

Autenticación: Bearer token = JWT de Supabase (el que usa la landing).
El usuario se resuelve por auth.uid() y sus memberships determinan permisos.
Operaciones contra Supabase (servidor -> service role, sin RLS).
"""

from datetime import date
from typing import Annotated, Any, Literal

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
    is_enabled: bool | None = None


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
    status: str | None = None


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
    subject_id: str | None = None
    grade: str | None = None
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


# ---------- modelos de ACTUALIZACION (PATCH parcial: solo los campos enviados) ----------


class SectionUpdate(BaseModel):
    level: str | None = None
    grade: str | None = Field(default=None, min_length=1, max_length=12)
    section_label: str | None = Field(default=None, min_length=1, max_length=8)
    tutor_name: str | None = None


class SubjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=80)
    icon_code: str | None = Field(default=None, min_length=1, max_length=3)
    color: str | None = None
    is_enabled: bool | None = None


class StaffUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=3, max_length=140)
    email: str | None = None
    role: str | None = None
    scope_label: str | None = None
    status: str | None = None


class StudentUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=3, max_length=140)
    email: str | None = None
    section_id: str | None = None


class QuestionUpdate(BaseModel):
    subject_id: str | None = None
    question: str | None = Field(default=None, min_length=8, max_length=400)
    options: list[str] | None = Field(default=None, min_length=4, max_length=4)
    correct_index: int | None = Field(default=None, ge=0, le=3)
    status: str | None = None


class AssignmentUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=140)
    section_id: str | None = None
    subject_id: str | None = None
    delivery_type: str | None = None
    due_at: str | None = None
    xp_reward: int | None = None
    status: str | None = None


class BattleUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=140)
    battle_type: str | None = None
    subject_id: str | None = None
    grade: str | None = None
    opponent_a: str | None = None
    opponent_b: str | None = None
    scheduled_at: str | None = None
    graph_layers: int | None = None
    nodes_per_layer: int | None = None
    status: str | None = None


class TeacherAssignIn(BaseModel):
    staff_id: str = Field(min_length=8, max_length=64)


class StudentTrackIn(BaseModel):
    pass


class AttendanceRecordIn(BaseModel):
    student_profile_id: str = Field(min_length=8, max_length=64)
    attendance_date: date
    status: Literal["present", "late", "absent", "excused"]
    minutes_late: int = Field(default=0, ge=0, le=600)
    note: str | None = Field(default=None, max_length=500)


class AttendanceBatchIn(BaseModel):
    records: list[AttendanceRecordIn] = Field(min_length=1, max_length=120)


class GradeItemIn(BaseModel):
    title: str = Field(min_length=3, max_length=160)
    subject_id: str = Field(min_length=8, max_length=64)
    section_id: str | None = None
    academic_period_id: str | None = None
    assignment_id: str | None = None
    category: Literal["assessment", "task", "battle", "participation", "project"] = (
        "assessment"
    )
    max_score: float = Field(default=20, gt=0, le=1000)
    weight: float = Field(default=1, gt=0, le=100)
    due_on: date | None = None
    status: Literal["draft", "published", "closed"] = "published"


class StudentGradeIn(BaseModel):
    score: float | None = Field(default=None, ge=0, le=1000)
    status: Literal["pending", "graded", "missing", "excused"] = "graded"
    feedback: str | None = Field(default=None, max_length=1200)


class StudentObservationIn(BaseModel):
    category: Literal[
        "academic", "attendance", "achievement", "behavior", "wellbeing", "support"
    ] = "academic"
    note: str = Field(min_length=3, max_length=2000)
    visibility: Literal["academic_team", "student"] = "academic_team"
    follow_up_on: date | None = None
    status: Literal["open", "resolved", "archived"] = "open"


class SchoolUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    ugel: str | None = None
    region: str | None = None
    city: str | None = None
    address: str | None = None
    battle_rules: dict | None = None
    battle_grades: list[str] | None = None


# ---------- utilidades ----------


def _fail(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


async def _current_uid(authorization: str | None = Header(default=None)) -> str:
    """Valida el JWT de Supabase y devuelve el uid del usuario.

    El proyecto usa ES256 (clave EC publicada en SUPABASE_JWKS_URL). Se valida
    con la JWKS publica (sin necesidad del JWT_SECRET, que en Vercel llega
    encriptado). Fallback HS256 con supabase_jwt_secret para proyectos legacy.
    """
    if not authorization or " " not in authorization:
        raise HTTPException(status_code=401, detail="Token requerido")
    token = authorization.split(" ", 1)[1]
    try:
        settings = get_settings()
        # 1) Validar con la JWKS publica (proyectos modernos ES256/RS256)
        #    Se prefiere PyJWT (jwt.PyJWKClient) porque python-jose no lo trae.
        if settings.supabase_jwks_url:
            try:
                import jwt as pyjwt  # PyJWT con PyJWKClient

                jwks_client = pyjwt.PyJWKClient(settings.supabase_jwks_url)
                signing_key = jwks_client.get_signing_key_from_jwt(token)
                payload = pyjwt.decode(
                    token,
                    signing_key.key,
                    algorithms=["ES256", "RS256"],
                    options={"verify_aud": False},
                )
                if "sub" in payload:
                    return payload["sub"]
            except Exception:
                pass  # si PyJWT falla (token HS256), seguimos con jose
        # 2) Fallback: python-jose con HS256 (proyectos legacy)
        from jose import jwt  # python-jose

        secret = settings.supabase_jwt_secret
        if secret:
            payload = jwt.decode(
                token,
                secret,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
            if "sub" in payload:
                return payload["sub"]
        raise ValueError("sin sub valido")
    except Exception as exc:
        raise HTTPException(
            status_code=401, detail="Token invalido o expirado"
        ) from exc


async def _require_member(
    supabase: Any, uid: str, school_id: str, roles: list[str]
) -> dict:
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


def _first(rows: list[dict] | None) -> dict | None:
    return rows[0] if rows else None


def _student_risk(
    attendance_rate: float | None, grade_average: float | None, open_follow_ups: int
) -> str:
    """Clasifica alertas sin sustituir el criterio profesional del colegio."""
    if (attendance_rate is not None and attendance_rate < 80) or (
        grade_average is not None and grade_average < 55
    ):
        return "critical"
    if (
        (attendance_rate is not None and attendance_rate < 90)
        or (grade_average is not None and grade_average < 65)
        or open_follow_ups > 0
    ):
        return "attention"
    return "ok"


def _staff_for_member(
    supabase: Any, school_id: str, member: dict, uid: str
) -> dict | None:
    """Resuelve el perfil de personal aun si proviene de datos antiguos sin membership_id."""
    linked = (
        supabase.table("staff_profiles")
        .select("id, school_id, membership_id, full_name, email, role, scope_label")
        .eq("school_id", school_id)
        .eq("membership_id", member["id"])
        .limit(1)
        .execute()
        .data
    )
    if linked:
        return linked[0]
    profile = (
        supabase.table("profiles").select("email").eq("id", uid).limit(1).execute().data
    )
    email = (_first(profile) or {}).get("email")
    if not email:
        return None
    candidates = (
        supabase.table("staff_profiles")
        .select("id, school_id, membership_id, full_name, email, role, scope_label")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    return next(
        (
            row
            for row in candidates
            if (row.get("email") or "").lower() == email.lower()
        ),
        None,
    )


def _accessible_students(
    supabase: Any, school_id: str, member: dict, uid: str
) -> list[dict]:
    students = (
        supabase.table("student_profiles")
        .select("id, school_id, membership_id, full_name, email, section_id, status")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    role = member.get("role")
    if role in {"owner", "director", "subdirector", "coordinator"}:
        return students
    if role == "student":
        return [
            row
            for row in students
            if str(row.get("membership_id")) == str(member.get("id"))
        ]

    staff = _staff_for_member(supabase, school_id, member, uid)
    if not staff:
        return []
    if role == "tutor":
        sections = (
            supabase.table("sections")
            .select("id, tutor_staff_id, tutor_name, display_name")
            .eq("school_id", school_id)
            .execute()
            .data
            or []
        )
        section_ids = {
            str(row["id"])
            for row in sections
            if str(row.get("tutor_staff_id")) == str(staff.get("id"))
            or (row.get("tutor_name") or "").strip().lower()
            == (staff.get("full_name") or "").strip().lower()
            or (
                staff.get("scope_label")
                and (
                    staff["scope_label"].lower()
                    in (row.get("display_name") or "").lower()
                    or (row.get("display_name") or "").lower()
                    in staff["scope_label"].lower()
                )
            )
        }
        return [row for row in students if str(row.get("section_id")) in section_ids]
    if role == "teacher":
        subject_links = (
            supabase.table("subject_teachers")
            .select("subject_id")
            .eq("school_id", school_id)
            .eq("staff_id", staff["id"])
            .execute()
            .data
            or []
        )
        subject_ids = {str(row["subject_id"]) for row in subject_links}
        classes = (
            supabase.table("classes")
            .select("section_id, subject_id, is_active")
            .eq("school_id", school_id)
            .execute()
            .data
            or []
        )
        section_ids = {
            str(row["section_id"])
            for row in classes
            if row.get("is_active")
            and row.get("section_id")
            and str(row.get("subject_id")) in subject_ids
        }
        return [row for row in students if str(row.get("section_id")) in section_ids]
    return []


def _require_academic_scope(
    supabase: Any,
    school_id: str,
    member: dict,
    uid: str,
    *,
    subject_id: str | None = None,
    section_id: str | None = None,
) -> None:
    """Impide que tutores/profesores escriban fuera de su aula o curso."""
    role = member.get("role")
    if role in {"owner", "director", "subdirector", "coordinator"}:
        return
    allowed_students = _accessible_students(supabase, school_id, member, uid)
    allowed_section_ids = {
        str(row["section_id"]) for row in allowed_students if row.get("section_id")
    }
    if section_id and str(section_id) not in allowed_section_ids:
        raise HTTPException(status_code=403, detail="Seccion fuera de tu alcance")
    if role != "teacher" or not subject_id:
        return
    staff = _staff_for_member(supabase, school_id, member, uid)
    links = (
        supabase.table("subject_teachers")
        .select("subject_id")
        .eq("school_id", school_id)
        .eq("staff_id", (staff or {}).get("id", ""))
        .execute()
        .data
        or []
    )
    if str(subject_id) not in {str(row["subject_id"]) for row in links}:
        raise HTTPException(status_code=403, detail="Curso fuera de tu alcance")


async def _require_student_access(
    supabase: Any, uid: str, school_id: str, student_id: str, *, write: bool = False
) -> tuple[dict, dict]:
    member = await _require_member(
        supabase,
        uid,
        school_id,
        [
            "owner",
            "director",
            "subdirector",
            "coordinator",
            "tutor",
            "teacher",
            "student",
        ],
    )
    allowed = _accessible_students(supabase, school_id, member, uid)
    student = next(
        (row for row in allowed if str(row.get("id")) == str(student_id)), None
    )
    if not student or (write and member.get("role") == "student"):
        raise HTTPException(status_code=403, detail="Sin acceso a este alumno")
    return member, student


# ---------- dashboard (todas las lecturas del panel en una llamada) ----------


@router.get("/{school_id}/dashboard")
async def panel_dashboard(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    """Devuelve todos los datos que necesita el panel (lecturas) en una sola respuesta."""
    supabase = supabase_admin()
    member = await _require_member(
        supabase,
        uid,
        school_id,
        [
            "owner",
            "director",
            "subdirector",
            "coordinator",
            "tutor",
            "teacher",
            "student",
        ],
    )
    t = supabase.table
    out: dict[str, Any] = {"school_id": school_id}

    def rows(resp):
        return resp.data or []

    try:
        out["school"] = (
            t("schools")
            .select("id, name, code, region, city, ugel, address, onboarding_complete")
            .eq("id", school_id)
            .limit(1)
            .execute()
            .data
            or [{}]
        )[0]
        out["subscription"] = (
            t("subscriptions")
            .select("*")
            .eq("school_id", school_id)
            .limit(1)
            .execute()
            .data
            or [{}]
        )[0]
        out["students"] = rows(
            t("student_profiles")
            .select(
                "id, school_id, full_name, email, section_id, membership_id, status, is_demo, created_at"
            )
            .eq("school_id", school_id)
            .execute()
        )
        out["sections"] = rows(
            t("sections").select("*").eq("school_id", school_id).execute()
        )
        out["subjects"] = rows(
            t("subjects")
            .select(
                "id, school_id, slug, name, color, icon_code, is_enabled, is_demo, created_at"
            )
            .eq("school_id", school_id)
            .eq("is_enabled", True)
            .execute()
        )
        out["subject_teachers"] = rows(
            t("subject_teachers")
            .select("id, subject_id, staff_id, staff_profiles(full_name, role)")
            .eq("school_id", school_id)
            .execute()
        )
        out["clans"] = rows(
            t("clans")
            .select("id, name, color, rank_name, section_id, is_demo, created_at")
            .eq("school_id", school_id)
            .execute()
        )
        out["materials"] = rows(
            t("learning_materials")
            .select(
                "id, school_id, title, file_name, file_type, processing_status, subject_id, created_at"
            )
            .eq("school_id", school_id)
            .order("created_at", True)
            .execute()
        )
        out["questions"] = rows(
            t("question_bank")
            .select(
                "id, school_id, question, options, correct_index, status, subject_id, source, is_demo, created_at"
            )
            .eq("school_id", school_id)
            .order("created_at", True)
            .execute()
        )
        out["staff"] = rows(
            t("staff_profiles")
            .select(
                "id, school_id, full_name, email, role, scope_label, status, is_demo, created_at"
            )
            .eq("school_id", school_id)
            .execute()
        )
        out["assignments"] = rows(
            t("assignments")
            .select(
                "id, school_id, title, section_id, subject_id, delivery_type, due_at, xp_reward, status"
            )
            .eq("school_id", school_id)
            .execute()
        )
        out["battles"] = rows(
            t("battle_events")
            .select(
                "id, school_id, title, battle_type, subject_id, grade, "
                "opponent_a, opponent_b, scheduled_at, graph_layers, "
                "nodes_per_layer, status"
            )
            .eq("school_id", school_id)
            .execute()
        )
        out["ranks"] = rows(
            t("rank_definitions")
            .select("id, school_id, name, min_xp, position, is_demo")
            .eq("school_id", school_id)
            .execute()
        )
        out["audits"] = rows(
            t("audit_logs")
            .select("id, actor_name, action, target_label, category, created_at")
            .eq("school_id", school_id)
            .order("created_at", True)
            .limit(30)
            .execute()
        )
        out["settings"] = (
            t("school_settings")
            .select(
                "battle_rules, rank_rules, ai_preferences, accessibility, battle_grades"
            )
            .eq("school_id", school_id)
            .limit(1)
            .execute()
            .data
            or [{}]
        )[0]
        out["classes"] = rows(
            t("classes")
            .select(
                "id, school_id, name, subject, code, is_active, created_at, "
                "academic_year_id, section_id, subject_id, teacher_membership_id"
            )
            .eq("school_id", school_id)
            .order("created_at", True)
            .execute()
        )
        class_ids = [str(c["id"]) for c in out["classes"]]
        out["enrollments"] = (
            rows(
                t("class_enrollments")
                .select(
                    "id, class_id, student_profile_id, academic_year_id, status, enrolled_at"
                )
                .in_("class_id", class_ids)
                .execute()
            )
            if class_ids
            else []
        )

        # El cliente administrativo de Supabase omite RLS. Por eso el alcance
        # del rol se aplica de nuevo antes de construir y devolver la respuesta.
        role = member.get("role")
        if role not in {"owner", "director", "subdirector", "coordinator"}:
            allowed_students = _accessible_students(supabase, school_id, member, uid)
            allowed_student_ids = {str(row["id"]) for row in allowed_students}
            allowed_section_ids = {
                str(row["section_id"])
                for row in allowed_students
                if row.get("section_id")
            }
            allowed_enrollments = [
                row
                for row in out["enrollments"]
                if str(row.get("student_profile_id")) in allowed_student_ids
            ]
            allowed_class_ids = {
                str(row["class_id"])
                for row in allowed_enrollments
                if row.get("class_id")
            }

            out["students"] = allowed_students
            out["sections"] = [
                row
                for row in out["sections"]
                if str(row.get("id")) in allowed_section_ids
            ]
            out["clans"] = [
                row
                for row in out["clans"]
                if str(row.get("section_id")) in allowed_section_ids
            ]
            out["assignments"] = [
                row
                for row in out["assignments"]
                if str(row.get("section_id")) in allowed_section_ids
            ]
            out["enrollments"] = allowed_enrollments
            out["classes"] = [
                row
                for row in out["classes"]
                if str(row.get("id")) in allowed_class_ids
                or str(row.get("section_id")) in allowed_section_ids
            ]
            out["audits"] = []
            out["settings"] = {
                "accessibility": (out.get("settings") or {}).get("accessibility", {})
            }
            # Los correos del personal y el banco de respuestas no forman parte
            # de la vista del alumno. Tutores y profesores reciben un directorio
            # sin correo, suficiente para identificar responsables académicos.
            out["staff"] = (
                []
                if role == "student"
                else [
                    {key: value for key, value in row.items() if key != "email"}
                    for row in out["staff"]
                ]
            )
            if role == "student":
                out["questions"] = []

        out["viewer_role"] = member.get("role")

        # relaciones para compatibilidad con el front
        subj_by_id = {str(s["id"]): s["name"] for s in out["subjects"]}
        sec_by_id = {str(s["id"]): s["display_name"] for s in out["sections"]}
        stud_by_id = {str(st["id"]): st["full_name"] for st in out["students"]}
        stud_email_by_id = {str(st["id"]): st.get("email") for st in out["students"]}
        for m in out["materials"]:
            m["subjects"] = (
                [{"name": subj_by_id.get(str(m.get("subject_id")), "Sin materia")}]
                if m.get("subject_id")
                else []
            )
        for q in out["questions"]:
            q["subjects"] = (
                [{"name": subj_by_id.get(str(q.get("subject_id")), "General")}]
                if q.get("subject_id")
                else []
            )
        for a in out["assignments"]:
            a["subjects"] = (
                [{"name": subj_by_id.get(str(a.get("subject_id")), "General")}]
                if a.get("subject_id")
                else []
            )
            a["sections"] = (
                [
                    {
                        "id": str(a.get("section_id")),
                        "display_name": sec_by_id.get(str(a.get("section_id")), ""),
                    }
                ]
                if a.get("section_id")
                else []
            )
        for c in out["classes"]:
            c["academic_years"] = [{"label": "2026", "is_active": True}]
            c["sections"] = (
                [
                    {
                        "id": str(c.get("section_id")),
                        "display_name": sec_by_id.get(str(c.get("section_id")), ""),
                        "level": "",
                        "grade": "",
                        "section_label": "",
                    }
                ]
                if c.get("section_id")
                else []
            )
        for e in out["enrollments"]:
            e["student_profiles"] = [
                {
                    "id": e.get("student_profile_id"),
                    "full_name": stud_by_id.get(
                        str(e.get("student_profile_id")), "Alumno"
                    ),
                    "email": stud_email_by_id.get(str(e.get("student_profile_id"))),
                }
            ]
    except Exception as exc:  # noqa: BLE001
        raise _fail(f"Error cargando el dashboard: {exc}") from exc
    return out


# ---------- secciones ----------


@router.post("/{school_id}/sections", response_model=Msg)
async def create_section(
    school_id: str, body: SectionIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    label = body.section_label.upper()
    display = f"{body.grade}. {body.level} {label}"
    code = f"{body.grade}-{body.level[:3].upper()}{label}"
    year = (
        supabase.table("academic_years")
        .select("id")
        .eq("school_id", school_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    resp = (
        supabase.table("sections")
        .insert(
            {
                "school_id": school_id,
                "level": body.level,
                "grade": body.grade,
                "section_label": label,
                "code": code,
                "display_name": display,
                "tutor_name": body.tutor_name,
                "academic_year_id": (year.data or [{}])[0].get("id"),
            }
        )
        .execute()
    )
    sec_id = resp.data[0].get("id") if resp.data else None
    try:  # noqa: SIM105
        subs = (
            supabase.table("subjects").select("id").eq("school_id", school_id).execute()
        )
        if subs.data:
            supabase.table("section_subjects").insert(
                [{"section_id": sec_id, "subject_id": s["id"]} for s in subs.data]
            ).execute()
        supabase.table("clans").insert(
            [
                {
                    "school_id": school_id,
                    "section_id": sec_id,
                    "name": f"{label} Rojos",
                    "color": "#ef3340",
                    "is_demo": False,
                },
                {
                    "school_id": school_id,
                    "section_id": sec_id,
                    "name": f"{label} Morados",
                    "color": "#9d55f5",
                    "is_demo": False,
                },
            ]
        ).execute()
    except Exception:  # noqa: BLE001
        pass
    return Msg(id=sec_id, detail="Seccion creada")


@router.patch("/sections/{section_id}", response_model=Msg)
async def update_section(
    section_id: str, body: SectionUpdate, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("sections")
        .select("school_id, level, grade, section_label")
        .eq("id", section_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    patch: dict[str, Any] = {}
    if body.section_label is not None:
        patch["section_label"] = body.section_label.upper()
    if body.level is not None:
        patch["level"] = body.level
    if body.grade is not None:
        patch["grade"] = body.grade
    if body.tutor_name is not None:
        patch["tutor_name"] = body.tutor_name
    if "grade" in patch or "level" in patch or "section_label" in patch:
        grade = patch.get("grade", row.get("grade", ""))
        level = patch.get("level", row.get("level", "Primaria"))
        label = patch.get("section_label", row.get("section_label", "")).upper()
        patch["display_name"] = f"{grade}. {level} {label}"
    supabase.table("sections").update(patch).eq("id", section_id).execute()
    return Msg(detail="Seccion actualizada")


@router.delete("/sections/{section_id}", response_model=Msg)
async def delete_section(section_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("sections")
        .select("school_id")
        .eq("id", section_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator"],
    )
    supabase.table("sections").delete().eq("id", section_id).execute()
    return Msg(detail="Seccion eliminada")


@router.get("/{school_id}/sections")
async def list_sections(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    rows = (
        supabase.table("sections")
        .select("*")
        .eq("school_id", school_id)
        .order("display_name")
        .execute()
    )
    return rows.data or []


# ---------- materias ----------


@router.post("/{school_id}/subjects", response_model=Msg)
async def create_subject(
    school_id: str, body: SubjectIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    slug = "".join(ch for ch in body.name.lower() if ch.isalnum())[:50]
    resp = (
        supabase.table("subjects")
        .insert(
            {
                "school_id": school_id,
                "name": body.name,
                "slug": slug,
                "icon_code": body.icon_code.upper(),
                "color": body.color,
                "is_enabled": True,
            }
        )
        .execute()
    )
    subj_id = resp.data[0].get("id") if resp.data else None
    try:
        secs = (
            supabase.table("sections").select("id").eq("school_id", school_id).execute()
        )
        if secs.data:
            supabase.table("section_subjects").insert(
                [{"section_id": sec["id"], "subject_id": subj_id} for sec in secs.data]
            ).execute()
    except Exception:  # noqa: BLE001
        pass
    return Msg(id=subj_id, detail="Materia creada")


@router.patch("/subjects/{subject_id}", response_model=Msg)
async def update_subject(
    subject_id: str, body: SubjectUpdate, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("subjects")
        .select("school_id")
        .eq("id", subject_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    patch_data: dict[str, Any] = {}
    if body.name is not None:
        patch_data["name"] = body.name
    if body.icon_code is not None:
        patch_data["icon_code"] = body.icon_code.upper()
    if body.color is not None:
        patch_data["color"] = body.color
    if body.is_enabled is not None:
        patch_data["is_enabled"] = body.is_enabled
    supabase.table("subjects").update(patch_data).eq("id", subject_id).execute()
    return Msg(detail="Materia actualizada")


@router.delete("/subjects/{subject_id}", response_model=Msg)
async def delete_subject(subject_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("subjects")
        .select("school_id")
        .eq("id", subject_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    supabase.table("subjects").delete().eq("id", subject_id).execute()
    # limpiar asignaciones de profesores del curso
    supabase.table("subject_teachers").delete().eq("subject_id", subject_id).execute()
    return Msg(detail="Materia eliminada")


# ---------- trazabilidad: profesores por curso (materia) ----------


@router.post("/{school_id}/subjects/{subject_id}/teachers", response_model=Msg)
async def assign_teacher_to_subject(
    school_id: str,
    subject_id: str,
    body: TeacherAssignIn,
    uid: Annotated[str, Depends(_current_uid)],
):
    """Asigna un profesor (staff) a un curso. Un curso puede tener varios profesores."""
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor"],
    )
    # profesor debe pertenecer al colegio
    staff = (
        supabase.table("staff_profiles")
        .select("id, school_id")
        .eq("id", body.staff_id)
        .execute()
        .data
    )
    if not staff or staff[0].get("school_id") != school_id:
        raise HTTPException(
            status_code=404, detail="Profesor no encontrado en este colegio"
        )
    # el curso debe pertenecer al colegio
    subj = (
        supabase.table("subjects")
        .select("id, school_id")
        .eq("id", subject_id)
        .execute()
        .data
    )
    if not subj or subj[0].get("school_id") != school_id:
        raise HTTPException(
            status_code=404, detail="Curso no encontrado en este colegio"
        )
    # evitar duplicados
    dupe = (
        supabase.table("subject_teachers")
        .select("id")
        .eq("subject_id", subject_id)
        .eq("staff_id", body.staff_id)
        .execute()
        .data
    )
    if not dupe:
        supabase.table("subject_teachers").insert(
            {
                "school_id": school_id,
                "subject_id": subject_id,
                "staff_id": body.staff_id,
            }
        ).execute()
    return Msg(detail="Profesor asignado al curso")


@router.delete(
    "/{school_id}/subjects/{subject_id}/teachers/{staff_id}", response_model=Msg
)
async def remove_teacher_from_subject(
    school_id: str,
    subject_id: str,
    staff_id: str,
    uid: Annotated[str, Depends(_current_uid)],
):
    """Quita un profesor del curso."""
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor"],
    )
    supabase.table("subject_teachers").delete().eq("subject_id", subject_id).eq(
        "staff_id", staff_id
    ).execute()
    return Msg(detail="Profesor removido del curso")


# ---------- trazabilidad: progreso completo de un alumno ----------


@router.get("/{school_id}/students/{student_id}/tracking")
async def student_tracking(
    school_id: str, student_id: str, uid: Annotated[str, Depends(_current_uid)]
):
    """Todo el recorrido de un alumno: perfil, seccion, cursos con profesores,
    notas, asistencia, observaciones, rango, tareas y batallas."""
    supabase = supabase_admin()
    _, st = await _require_student_access(supabase, uid, school_id, student_id)

    # seccion del alumno
    section = None
    if st.get("section_id"):
        sec = (
            supabase.table("sections")
            .select("id, display_name, grade, level")
            .eq("id", st["section_id"])
            .execute()
            .data
        )
        if sec:
            section = sec[0]

    # cursos (materias) del colegio con sus profesores
    subjects = (
        supabase.table("subjects")
        .select("id, name, color, icon_code, is_enabled")
        .eq("school_id", school_id)
        .order("name", ascending=True)
        .execute()
        .data
    )
    subj_by_id = {str(subject["id"]): subject["name"] for subject in (subjects or [])}
    teachers_by_subject = {}
    st_rows = (
        supabase.table("subject_teachers")
        .select("subject_id, staff_profiles(id, full_name, role)")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    for row in st_rows:
        tid = row.get("subject_id")
        rel = row.get("staff_profiles") or {}
        teachers_by_subject.setdefault(tid, []).append(
            {
                "id": rel.get("id"),
                "full_name": rel.get("full_name"),
                "role": rel.get("role"),
            }
        )
    courses = []
    for sbj in subjects:
        courses.append(
            {
                "id": sbj["id"],
                "name": sbj["name"],
                "color": sbj.get("color"),
                "icon_code": sbj.get("icon_code"),
                "is_enabled": sbj.get("is_enabled", True),
                "teachers": teachers_by_subject.get(sbj["id"], []),
            }
        )

    # xp total del alumno (xp_transactions.user_id = membership.user_id del alumno)
    xp_total = 0
    membership_id = st.get("membership_id")
    if membership_id:
        mem = (
            supabase.table("memberships")
            .select("user_id")
            .eq("id", membership_id)
            .execute()
            .data
        )
        if mem:
            xq = (
                supabase.table("xp_transactions")
                .select("amount")
                .eq("user_id", mem[0]["user_id"])
                .execute()
                .data
                or []
            )
            xp_total = sum(int(r.get("amount") or 0) for r in xq)

    # rango segun xp (rank_definitions del colegio)
    rank = None
    ranks = (
        supabase.table("rank_definitions")
        .select("id, name, min_xp, position")
        .eq("school_id", school_id)
        .order("min_xp", ascending=True)
        .execute()
        .data
        or []
    )
    for r in ranks:
        if xp_total >= int(r.get("min_xp") or 0):
            rank = {"id": r["id"], "name": r["name"], "position": r.get("position")}

    # tareas entregadas por el alumno (task_submissions.student_id = student_profiles.id)
    submissions = (
        supabase.table("task_submissions")
        .select(
            "task_id, score, is_graded, xp_awarded, submitted_at, tasks(title, subject, due_date, status)"
        )
        .eq("student_id", student_id)
        .execute()
        .data
        or []
    )
    tasks_done = []
    for sub in submissions:
        t = sub.get("tasks") or {}
        tasks_done.append(
            {
                "task_id": sub.get("task_id"),
                "title": t.get("title") or "Sin titulo",
                "subject": t.get("subject"),
                "due_date": t.get("due_date"),
                "score": sub.get("score"),
                "is_graded": sub.get("is_graded"),
                "xp_awarded": sub.get("xp_awarded"),
                "submitted_at": sub.get("submitted_at"),
            }
        )

    # batallas en las que el alumno participo (battle_moves no tiene student_id:
    # se infieren desde el juego por player_index; las batallas del colegio se listan
    # con su materia y estado para trazabilidad del contexto)
    battles = (
        supabase.table("battle_events")
        .select(
            "id, title, battle_type, status, scheduled_at, subject_id, grade, subjects(name)"
        )
        .eq("school_id", school_id)
        .order("scheduled_at", ascending=False)
        .limit(20)
        .execute()
        .data
        or []
    )
    battle_list = []
    for b in battles:
        battle_list.append(
            {
                "id": b["id"],
                "title": b.get("title"),
                "battle_type": b.get("battle_type"),
                "status": b.get("status"),
                "scheduled_at": b.get("scheduled_at"),
                "subject": (b.get("subjects") or {}).get("name"),
                "grade": b.get("grade"),
            }
        )

    # clases donde participa (class_enrollments no tiene school_id; se filtran por
    # las clases del colegio)
    cls_rows = (
        supabase.table("classes")
        .select("id, name, code, is_active, subject_id, subjects(name)")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    enroll = (
        supabase.table("class_enrollments")
        .select("class_id, status")
        .eq("student_profile_id", student_id)
        .execute()
        .data
        or []
    )
    enrolled_ids = {e["class_id"] for e in enroll}
    enrolled_classes = []
    for c in cls_rows:
        if c["id"] in enrolled_ids:
            enrolled_classes.append(
                {
                    "id": c["id"],
                    "name": c.get("name"),
                    "code": c.get("code"),
                    "is_active": c.get("is_active"),
                    "subject": (c.get("subjects") or {}).get("name"),
                }
            )

    # Seguimiento academico. El bloque es tolerante mientras se aplica la
    # migracion: el resto de la ficha continua disponible sin ocultar el error.
    academic_periods: list[dict] = []
    attendance: list[dict] = []
    grades: list[dict] = []
    observations: list[dict] = []
    academic_ready = True
    try:
        academic_periods = (
            supabase.table("academic_periods")
            .select("id, name, starts_on, ends_on, is_active")
            .eq("school_id", school_id)
            .order("starts_on", ascending=False)
            .execute()
            .data
            or []
        )
        attendance = (
            supabase.table("attendance_records")
            .select("id, attendance_date, status, minutes_late, note")
            .eq("student_profile_id", student_id)
            .order("attendance_date", ascending=False)
            .execute()
            .data
            or []
        )
        grade_rows = (
            supabase.table("student_grades")
            .select("id, grade_item_id, score, status, feedback, graded_at")
            .eq("student_profile_id", student_id)
            .order("graded_at", ascending=False)
            .execute()
            .data
            or []
        )
        item_ids = [
            str(row["grade_item_id"]) for row in grade_rows if row.get("grade_item_id")
        ]
        items = (
            supabase.table("grade_items")
            .select(
                "id, title, category, max_score, weight, due_on, subject_id, academic_period_id"
            )
            .in_("id", item_ids)
            .execute()
            .data
            if item_ids
            else []
        )
        items_by_id = {str(item["id"]): item for item in (items or [])}
        for row in grade_rows:
            item = items_by_id.get(str(row.get("grade_item_id")), {})
            max_score = float(item.get("max_score") or 20)
            score = float(row["score"]) if row.get("score") is not None else None
            grades.append(
                {
                    **row,
                    "title": item.get("title", "Actividad"),
                    "category": item.get("category"),
                    "max_score": max_score,
                    "percentage": (
                        round((score / max_score) * 100, 1)
                        if score is not None and max_score
                        else None
                    ),
                    "subject_id": item.get("subject_id"),
                    "subject": subj_by_id.get(str(item.get("subject_id")), "General"),
                    "academic_period_id": item.get("academic_period_id"),
                }
            )
        observations = (
            supabase.table("student_observations")
            .select("id, category, note, visibility, follow_up_on, status, created_at")
            .eq("student_profile_id", student_id)
            .order("created_at", ascending=False)
            .limit(30)
            .execute()
            .data
            or []
        )
    except Exception:  # noqa: BLE001
        academic_ready = False

    attendance_count = len(attendance)
    attended_count = sum(
        1 for row in attendance if row.get("status") in {"present", "late"}
    )
    graded = [
        row
        for row in grades
        if row.get("percentage") is not None and row.get("status") == "graded"
    ]
    attendance_rate = (
        round((attended_count / attendance_count) * 100, 1)
        if attendance_count
        else None
    )
    grade_average = (
        round(sum(float(row["percentage"]) for row in graded) / len(graded), 1)
        if graded
        else None
    )

    return {
        "student": {
            "id": st["id"],
            "full_name": st["full_name"],
            "email": st.get("email"),
            "status": st.get("status"),
        },
        "section": section,
        "xp_total": xp_total,
        "rank": rank,
        "courses": courses,
        "tasks_done": tasks_done,
        "battles": battle_list,
        "enrolled_classes": enrolled_classes,
        "academic_ready": academic_ready,
        "academic_periods": academic_periods,
        "attendance": attendance,
        "attendance_summary": {
            "records": attendance_count,
            "present": sum(1 for row in attendance if row.get("status") == "present"),
            "late": sum(1 for row in attendance if row.get("status") == "late"),
            "absent": sum(1 for row in attendance if row.get("status") == "absent"),
            "excused": sum(1 for row in attendance if row.get("status") == "excused"),
            "rate": attendance_rate,
        },
        "grades": grades,
        "grade_average": grade_average,
        "observations": observations,
    }


# ---------- gestion academica: asistencia, notas y acompanamiento ----------


@router.get("/{school_id}/academics/overview")
async def academic_overview(school_id: str, uid: Annotated[str, Depends(_current_uid)]):
    """Resumen institucional filtrado por el alcance real del rol."""
    supabase = supabase_admin()
    member = await _require_member(
        supabase,
        uid,
        school_id,
        [
            "owner",
            "director",
            "subdirector",
            "coordinator",
            "tutor",
            "teacher",
            "student",
        ],
    )
    students = _accessible_students(supabase, school_id, member, uid)
    student_ids = [str(row["id"]) for row in students]
    sections = (
        supabase.table("sections")
        .select("id, display_name, grade, level, section_label")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    subjects = (
        supabase.table("subjects")
        .select("id, name, color, icon_code")
        .eq("school_id", school_id)
        .execute()
        .data
        or []
    )
    periods = (
        supabase.table("academic_periods")
        .select("id, name, starts_on, ends_on, is_active")
        .eq("school_id", school_id)
        .order("starts_on", ascending=False)
        .execute()
        .data
        or []
    )
    attendance = (
        supabase.table("attendance_records")
        .select("student_profile_id, attendance_date, status, minutes_late")
        .in_("student_profile_id", student_ids)
        .execute()
        .data
        if student_ids
        else []
    )
    grade_rows = (
        supabase.table("student_grades")
        .select("student_profile_id, grade_item_id, score, status, graded_at")
        .in_("student_profile_id", student_ids)
        .execute()
        .data
        if student_ids
        else []
    )
    items = (
        supabase.table("grade_items")
        .select(
            "id, title, subject_id, section_id, academic_period_id, max_score, weight, category"
        )
        .eq("school_id", school_id)
        .order("created_at", ascending=False)
        .execute()
        .data
        or []
    )
    observations = (
        supabase.table("student_observations")
        .select("student_profile_id, category, status, follow_up_on, created_at")
        .in_("student_profile_id", student_ids)
        .execute()
        .data
        if student_ids
        else []
    )

    section_by_id = {str(row["id"]): row for row in sections}
    subject_by_id = {str(row["id"]): row for row in subjects}
    item_by_id = {str(row["id"]): row for row in (items or [])}
    attendance_by_student: dict[str, list[dict]] = {}
    grades_by_student: dict[str, list[dict]] = {}
    observations_by_student: dict[str, list[dict]] = {}
    subject_scores: dict[str, list[float]] = {}
    for row in attendance or []:
        attendance_by_student.setdefault(str(row["student_profile_id"]), []).append(row)
    for row in grade_rows or []:
        item = item_by_id.get(str(row.get("grade_item_id")), {})
        if row.get("score") is not None and row.get("status") == "graded":
            maximum = float(item.get("max_score") or 20)
            percentage = (
                round((float(row["score"]) / maximum) * 100, 1) if maximum else 0
            )
            enriched = {**row, "percentage": percentage, "item": item}
            grades_by_student.setdefault(str(row["student_profile_id"]), []).append(
                enriched
            )
            if item.get("subject_id"):
                subject_scores.setdefault(str(item["subject_id"]), []).append(
                    percentage
                )
    for row in observations or []:
        observations_by_student.setdefault(str(row["student_profile_id"]), []).append(
            row
        )

    summaries = []
    for student in students:
        student_id = str(student["id"])
        student_attendance = attendance_by_student.get(student_id, [])
        attended = sum(
            1 for row in student_attendance if row.get("status") in {"present", "late"}
        )
        attendance_rate = (
            round((attended / len(student_attendance)) * 100, 1)
            if student_attendance
            else None
        )
        student_grades = grades_by_student.get(student_id, [])
        grade_average = (
            round(
                sum(float(row["percentage"]) for row in student_grades)
                / len(student_grades),
                1,
            )
            if student_grades
            else None
        )
        open_follow_ups = sum(
            1
            for row in observations_by_student.get(student_id, [])
            if row.get("status") == "open"
        )
        risk = _student_risk(attendance_rate, grade_average, open_follow_ups)
        summaries.append(
            {
                "id": student_id,
                "full_name": student.get("full_name"),
                "email": student.get("email"),
                "section": section_by_id.get(str(student.get("section_id"))),
                "attendance_rate": attendance_rate,
                "absences": sum(
                    1 for row in student_attendance if row.get("status") == "absent"
                ),
                "late_arrivals": sum(
                    1 for row in student_attendance if row.get("status") == "late"
                ),
                "grade_average": grade_average,
                "graded_items": len(student_grades),
                "open_follow_ups": open_follow_ups,
                "risk": risk,
            }
        )

    summaries.sort(
        key=lambda row: (
            {"critical": 0, "attention": 1, "ok": 2}[row["risk"]],
            row["full_name"] or "",
        )
    )
    subject_performance = []
    for subject_id, scores in subject_scores.items():
        subject = subject_by_id.get(subject_id, {})
        subject_performance.append(
            {
                "id": subject_id,
                "name": subject.get("name", "Curso"),
                "color": subject.get("color"),
                "average": round(sum(scores) / len(scores), 1),
                "records": len(scores),
            }
        )
    subject_performance.sort(key=lambda row: row["name"])

    attendance_rates = [
        float(row["attendance_rate"])
        for row in summaries
        if row["attendance_rate"] is not None
    ]
    grade_averages = [
        float(row["grade_average"])
        for row in summaries
        if row["grade_average"] is not None
    ]
    return {
        "school_id": school_id,
        "role": member.get("role"),
        "periods": periods,
        "sections": sections,
        "subjects": subjects,
        "grade_items": items,
        "students": summaries,
        "subject_performance": subject_performance,
        "metrics": {
            "students": len(summaries),
            "attendance_rate": (
                round(sum(attendance_rates) / len(attendance_rates), 1)
                if attendance_rates
                else None
            ),
            "grade_average": (
                round(sum(grade_averages) / len(grade_averages), 1)
                if grade_averages
                else None
            ),
            "critical": sum(1 for row in summaries if row["risk"] == "critical"),
            "attention": sum(1 for row in summaries if row["risk"] == "attention"),
            "open_follow_ups": sum(int(row["open_follow_ups"]) for row in summaries),
        },
    }


@router.post("/{school_id}/attendance/batch", response_model=Msg)
async def record_attendance(
    school_id: str, body: AttendanceBatchIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    member = await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    for record in body.records:
        _, student = await _require_student_access(
            supabase, uid, school_id, record.student_profile_id, write=True
        )
        payload = {
            "school_id": school_id,
            "student_profile_id": record.student_profile_id,
            "section_id": student.get("section_id"),
            "attendance_date": record.attendance_date.isoformat(),
            "status": record.status,
            "minutes_late": record.minutes_late if record.status == "late" else 0,
            "note": record.note,
            "recorded_by_membership_id": member["id"],
            "is_demo": False,
        }
        existing = (
            supabase.table("attendance_records")
            .select("id")
            .eq("student_profile_id", record.student_profile_id)
            .eq("attendance_date", record.attendance_date.isoformat())
            .limit(1)
            .execute()
            .data
        )
        if existing:
            supabase.table("attendance_records").update(payload).eq(
                "id", existing[0]["id"]
            ).execute()
        else:
            supabase.table("attendance_records").insert(payload).execute()
    return Msg(detail=f"Asistencia guardada para {len(body.records)} alumnos")


@router.post("/{school_id}/grade-items", response_model=Msg)
async def create_grade_item(
    school_id: str, body: GradeItemIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    member = await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    _require_academic_scope(
        supabase,
        school_id,
        member,
        uid,
        subject_id=body.subject_id,
        section_id=body.section_id,
    )
    payload = body.model_dump(mode="json")
    payload.update(
        {
            "school_id": school_id,
            "created_by_membership_id": member["id"],
            "is_demo": False,
        }
    )
    result = supabase.table("grade_items").insert(payload).execute().data or []
    return Msg(
        id=str(result[0].get("id")) if result else None,
        detail="Actividad evaluable creada",
    )


@router.put("/grade-items/{item_id}/students/{student_id}", response_model=Msg)
async def grade_student(
    item_id: str,
    student_id: str,
    body: StudentGradeIn,
    uid: Annotated[str, Depends(_current_uid)],
):
    supabase = supabase_admin()
    item_rows = (
        supabase.table("grade_items")
        .select("id, school_id, max_score, subject_id, section_id")
        .eq("id", item_id)
        .limit(1)
        .execute()
        .data
    )
    if not item_rows:
        raise HTTPException(status_code=404, detail="Actividad no encontrada")
    item = item_rows[0]
    member, _ = await _require_student_access(
        supabase, uid, str(item["school_id"]), student_id, write=True
    )
    _require_academic_scope(
        supabase,
        str(item["school_id"]),
        member,
        uid,
        subject_id=item.get("subject_id"),
        section_id=item.get("section_id"),
    )
    if body.score is not None and body.score > float(item.get("max_score") or 0):
        raise _fail("La nota no puede superar el puntaje maximo")
    payload = {
        "school_id": item["school_id"],
        "grade_item_id": item_id,
        "student_profile_id": student_id,
        "score": body.score,
        "status": body.status,
        "feedback": body.feedback,
        "graded_by_membership_id": member["id"],
        "graded_at": date.today().isoformat(),
        "is_demo": False,
    }
    existing = (
        supabase.table("student_grades")
        .select("id")
        .eq("grade_item_id", item_id)
        .eq("student_profile_id", student_id)
        .limit(1)
        .execute()
        .data
    )
    if existing:
        supabase.table("student_grades").update(payload).eq(
            "id", existing[0]["id"]
        ).execute()
        grade_id = str(existing[0]["id"])
    else:
        result = supabase.table("student_grades").insert(payload).execute().data or []
        grade_id = str(result[0].get("id")) if result else None
    return Msg(id=grade_id, detail="Nota guardada")


@router.post("/{school_id}/students/{student_id}/observations", response_model=Msg)
async def create_student_observation(
    school_id: str,
    student_id: str,
    body: StudentObservationIn,
    uid: Annotated[str, Depends(_current_uid)],
):
    supabase = supabase_admin()
    member, _ = await _require_student_access(
        supabase, uid, school_id, student_id, write=True
    )
    payload = body.model_dump(mode="json")
    payload.update(
        {
            "school_id": school_id,
            "student_profile_id": student_id,
            "author_membership_id": member["id"],
            "is_demo": False,
        }
    )
    result = supabase.table("student_observations").insert(payload).execute().data or []
    return Msg(
        id=str(result[0].get("id")) if result else None, detail="Observacion registrada"
    )


@router.post("/{school_id}/academics/seed-demo", response_model=Msg)
async def seed_academic_demo(
    school_id: str, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator"]
    )
    supabase.rpc("seed_academic_pilot", {"p_school_id": school_id}).execute()
    return Msg(detail="Datos academicos de prueba creados")


# ---------- personas ----------


@router.post("/{school_id}/staff", response_model=Msg)
async def create_staff(
    school_id: str, body: StaffIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase, uid, school_id, ["owner", "director", "subdirector"]
    )
    resp = (
        supabase.table("staff_profiles")
        .insert(
            {
                "school_id": school_id,
                "full_name": body.full_name,
                "email": body.email,
                "role": body.role,
                "scope_label": body.scope_label,
                "status": body.status,
                "is_demo": False,
            }
        )
        .execute()
    )
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Perfil creado")


@router.patch("/staff/{staff_id}", response_model=Msg)
async def update_staff(
    staff_id: str, body: StaffUpdate, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("staff_profiles")
        .select("school_id")
        .eq("id", staff_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector"]
    )
    payload = body.model_dump(exclude_none=True)
    supabase.table("staff_profiles").update(payload).eq("id", staff_id).execute()
    return Msg(detail="Perfil actualizado")


@router.delete("/staff/{staff_id}", response_model=Msg)
async def delete_staff(staff_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("staff_profiles")
        .select("school_id")
        .eq("id", staff_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase, uid, row.get("school_id", ""), ["owner", "director", "subdirector"]
    )
    supabase.table("staff_profiles").delete().eq("id", staff_id).execute()
    return Msg(detail="Perfil eliminado")


@router.post("/{school_id}/students", response_model=Msg)
async def create_student(
    school_id: str, body: StudentIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    resp = (
        supabase.table("student_profiles")
        .insert(
            {
                "school_id": school_id,
                "full_name": body.full_name,
                "email": body.email,
                "section_id": body.section_id,
                "status": "active",
                "is_demo": False,
            }
        )
        .execute()
    )
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Alumno creado")


@router.patch("/students/{student_id}", response_model=Msg)
async def update_student(
    student_id: str, body: StudentUpdate, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("student_profiles")
        .select("school_id")
        .eq("id", student_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    patch: dict[str, Any] = {}
    if body.full_name is not None:
        patch["full_name"] = body.full_name
    if body.email is not None:
        patch["email"] = body.email
    if body.section_id is not None:
        patch["section_id"] = body.section_id
    supabase.table("student_profiles").update(patch).eq("id", student_id).execute()
    return Msg(detail="Alumno actualizado")


@router.delete("/students/{student_id}", response_model=Msg)
async def delete_student(student_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("student_profiles")
        .select("school_id")
        .eq("id", student_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator"],
    )
    supabase.table("student_profiles").delete().eq("id", student_id).execute()
    return Msg(detail="Alumno eliminado")


# ---------- preguntas ----------


@router.post("/{school_id}/questions", response_model=Msg)
async def create_question(
    school_id: str, body: QuestionIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    resp = (
        supabase.table("question_bank")
        .insert(
            {
                "school_id": school_id,
                "subject_id": body.subject_id,
                "question": body.question,
                "options": body.options,
                "correct_index": body.correct_index,
                "status": "review",
                "source": "manual",
                "is_demo": False,
            }
        )
        .execute()
    )
    return Msg(
        id=resp.data[0].get("id") if resp.data else None, detail="Pregunta creada"
    )


@router.patch("/questions/{question_id}", response_model=Msg)
async def update_question(
    question_id: str, body: QuestionUpdate, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("question_bank")
        .select("school_id")
        .eq("id", question_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    payload = body.model_dump(exclude_none=True)
    supabase.table("question_bank").update(payload).eq("id", question_id).execute()
    return Msg(detail="Pregunta actualizada")


@router.delete("/questions/{question_id}", response_model=Msg)
async def delete_question(question_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("question_bank")
        .select("school_id")
        .eq("id", question_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    supabase.table("question_bank").delete().eq("id", question_id).execute()
    return Msg(detail="Pregunta eliminada")


@router.post("/questions/{question_id}/approve", response_model=Msg)
async def approve_question(
    question_id: str, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("question_bank")
        .select("school_id")
        .eq("id", question_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    supabase.table("question_bank").update({"status": "approved"}).eq(
        "id", question_id
    ).execute()
    return Msg(detail="Pregunta aprobada")


# ---------- tareas y batallas ----------


@router.post("/{school_id}/assignments", response_model=Msg)
async def create_assignment(
    school_id: str, body: AssignmentIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    resp = (
        supabase.table("assignments")
        .insert(
            {
                "school_id": school_id,
                "section_id": body.section_id,
                "subject_id": body.subject_id,
                "title": body.title,
                "delivery_type": body.delivery_type,
                "due_at": body.due_at,
                "xp_reward": body.xp_reward,
                "status": body.status,
                "is_demo": False,
            }
        )
        .execute()
    )
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Tarea creada")


@router.patch("/assignments/{assignment_id}", response_model=Msg)
async def update_assignment(
    assignment_id: str,
    body: AssignmentUpdate,
    uid: Annotated[str, Depends(_current_uid)],
):
    supabase = supabase_admin()
    row = (
        supabase.table("assignments")
        .select("school_id")
        .eq("id", assignment_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    payload = body.model_dump(exclude_none=True)
    supabase.table("assignments").update(payload).eq("id", assignment_id).execute()
    return Msg(detail="Tarea actualizada")


@router.delete("/assignments/{assignment_id}", response_model=Msg)
async def delete_assignment(
    assignment_id: str, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("assignments")
        .select("school_id")
        .eq("id", assignment_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    supabase.table("assignments").delete().eq("id", assignment_id).execute()
    return Msg(detail="Tarea eliminada")


@router.post("/{school_id}/battles", response_model=Msg)
async def create_battle(
    school_id: str, body: BattleIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    resp = (
        supabase.table("battle_events")
        .insert(
            {
                "school_id": school_id,
                "title": body.title,
                "battle_type": body.battle_type,
                "subject_id": body.subject_id,
                "grade": body.grade,
                "opponent_a": body.opponent_a,
                "opponent_b": body.opponent_b,
                "scheduled_at": body.scheduled_at,
                "graph_layers": body.graph_layers,
                "nodes_per_layer": body.nodes_per_layer,
                "status": body.status,
                "is_demo": False,
            }
        )
        .execute()
    )
    return Msg(
        id=resp.data[0].get("id") if resp.data else None, detail="Batalla programada"
    )


@router.patch("/battles/{battle_id}", response_model=Msg)
async def update_battle(
    battle_id: str, body: BattleUpdate, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    row = (
        supabase.table("battle_events")
        .select("school_id")
        .eq("id", battle_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    payload = body.model_dump(exclude_none=True)
    supabase.table("battle_events").update(payload).eq("id", battle_id).execute()
    return Msg(detail="Batalla actualizada")


@router.delete("/battles/{battle_id}", response_model=Msg)
async def delete_battle(battle_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("battle_events")
        .select("school_id")
        .eq("id", battle_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    supabase.table("battle_events").delete().eq("id", battle_id).execute()
    return Msg(detail="Batalla eliminada")


# ---------- materiales ----------


class MaterialIn(BaseModel):
    title: str = Field(min_length=3, max_length=120)
    subject_id: str
    file_name: str | None = None
    file_type: str | None = None


@router.post("/{school_id}/materials", response_model=Msg)
async def create_material(
    school_id: str, body: MaterialIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    subj = (
        supabase.table("subjects")
        .select("id")
        .eq("id", body.subject_id)
        .eq("school_id", school_id)
        .limit(1)
        .execute()
        .data
        or [{}]
    )[0]
    if not subj.get("id"):
        raise _fail("Materia invalida")
    ftype = body.file_type or (
        body.file_name.split(".")[-1].lower() if body.file_name else "manual"
    )
    resp = (
        supabase.table("learning_materials")
        .insert(
            {
                "school_id": school_id,
                "subject_id": body.subject_id,
                "title": body.title,
                "file_name": body.file_name,
                "file_type": ftype,
                "processing_status": "ready",
                "is_demo": False,
            }
        )
        .execute()
    )
    mid = resp.data[0].get("id") if resp.data else None
    # preguntas de prototipo vinculadas al material (como hacia el front)
    try:  # noqa: SIM105
        supabase.table("question_bank").insert(
            [
                {
                    "school_id": school_id,
                    "subject_id": body.subject_id,
                    "question": f"Cuál es la idea principal de «{body.title}»?",
                    "options": [
                        "El concepto central",
                        "Un detalle secundario",
                        "Un tema distinto",
                        "Ninguna",
                    ],
                    "correct_index": 0,
                    "status": "review",
                    "source": "prototype-ai",
                    "is_demo": False,
                },
                {
                    "school_id": school_id,
                    "subject_id": body.subject_id,
                    "question": f"Qué estrategia ayuda a comprender «{body.title}»?",
                    "options": [
                        "Relacionar sus ideas",
                        "Ignorar ejemplos",
                        "Memorizar sin leer",
                        "Cambiar de tema",
                    ],
                    "correct_index": 0,
                    "status": "review",
                    "source": "prototype-ai",
                    "is_demo": False,
                },
            ]
        ).execute()
    except Exception:  # noqa: BLE001
        pass
    return Msg(id=mid, detail="Material creado")


@router.delete("/materials/{material_id}", response_model=Msg)
async def delete_material(material_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("learning_materials")
        .select("school_id")
        .eq("id", material_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    supabase.table("learning_materials").delete().eq("id", material_id).execute()
    return Msg(detail="Material eliminado")


# ---------- colegio (datos maestros y reglas) ----------


class SchoolIn(BaseModel):
    name: str = Field(min_length=3, max_length=120)
    code: str | None = None
    ugel: str | None = None
    region: str | None = None
    city: str | None = None
    address: str | None = None
    battle_rules: dict[str, Any] | None = None
    battle_grades: list[str] | None = None


@router.patch("/{school_id}", response_model=Msg)
async def update_school(
    school_id: str, body: SchoolUpdate, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase, uid, school_id, ["owner", "director", "subdirector"]
    )
    patch_data: dict[str, Any] = {}
    if body.name is not None:
        patch_data["name"] = body.name
    if body.code is not None:
        patch_data["code"] = body.code.upper()
    for k in ("ugel", "region", "city", "address"):
        v = getattr(body, k)
        if v is not None:
            patch_data[k] = v
    supabase.table("schools").update(patch_data).eq("id", school_id).execute()
    if body.battle_rules is not None or body.battle_grades is not None:
        existing = (
            supabase.table("school_settings")
            .select("battle_rules, battle_grades")
            .eq("school_id", school_id)
            .limit(1)
            .execute()
            .data
            or [{}]
        )[0]
        settings_patch: dict[str, Any] = {}
        if body.battle_rules is not None:
            settings_patch["battle_rules"] = (
                existing.get("battle_rules") or {}
            ) | body.battle_rules
        if body.battle_grades is not None:
            settings_patch["battle_grades"] = body.battle_grades
        try:
            supabase.table("school_settings").update(settings_patch).eq(
                "school_id", school_id
            ).execute()
        except Exception:  # noqa: BLE001
            supabase.table("school_settings").insert(
                {"school_id": school_id, **settings_patch}
            ).execute()
    return Msg(detail="Colegio actualizado")


# ---------- rangos y clases ----------


@router.post("/{school_id}/ranks", response_model=Msg)
async def create_rank(
    school_id: str, body: RankIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    await _require_member(
        supabase, uid, school_id, ["owner", "director", "subdirector", "coordinator"]
    )
    resp = (
        supabase.table("rank_definitions")
        .insert(
            {
                "school_id": school_id,
                "name": body.name,
                "min_xp": body.min_xp,
                "position": body.position,
                "is_demo": False,
            }
        )
        .execute()
    )
    return Msg(id=resp.data[0].get("id") if resp.data else None, detail="Rango creado")


@router.delete("/ranks/{rank_id}", response_model=Msg)
async def delete_rank(rank_id: str, uid: Annotated[str, Depends(_current_uid)]):
    supabase = supabase_admin()
    row = (
        supabase.table("rank_definitions")
        .select("school_id")
        .eq("id", rank_id)
        .execute()
        .data
        or [{}]
    )[0]
    await _require_member(
        supabase,
        uid,
        row.get("school_id", ""),
        ["owner", "director", "subdirector", "coordinator"],
    )
    supabase.table("rank_definitions").delete().eq("id", rank_id).execute()
    return Msg(detail="Rango eliminado")


@router.post("/{school_id}/classes", response_model=Msg)
async def create_class(
    school_id: str, body: ClassIn, uid: Annotated[str, Depends(_current_uid)]
):
    supabase = supabase_admin()
    member = await _require_member(
        supabase,
        uid,
        school_id,
        ["owner", "director", "subdirector", "coordinator", "tutor", "teacher"],
    )
    year = (
        supabase.table("academic_years")
        .select("id")
        .eq("school_id", school_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    subj = None
    if body.subject_id:
        subj = (
            supabase.table("subjects")
            .select("name")
            .eq("id", body.subject_id)
            .execute()
            .data
            or [{}]
        )[0].get("name")
    # codigo unico CL-XXXX
    import random as rnd
    import uuid as _uuid

    code = ""
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    for _ in range(12):
        cand = "CL-" + "".join(rnd.choice(alphabet) for _ in range(4))
        exists = supabase.table("classes").select("id").eq("code", cand).execute()
        if not exists.data:
            code = cand
            break
    resp = (
        supabase.table("classes")
        .insert(
            {
                "id": str(_uuid.uuid4()),
                "school_id": school_id,
                "name": body.name,
                "subject": subj,
                "code": code,
                "is_active": True,
                "academic_year_id": (year.data or [{}])[0].get("id"),
                "section_id": body.section_id,
                "subject_id": body.subject_id,
                "teacher_membership_id": member["id"],
                "created_at": "now()",
                "updated_at": "now()",
            }
        )
        .execute()
    )
    return Msg(
        id=resp.data[0].get("id") if resp.data else None,
        detail="Clase creada con codigo " + code,
    )


@router.post("/classes/join", response_model=Msg)
async def join_class(body: ClassCodeIn, uid: Annotated[str, Depends(_current_uid)]):
    """El alumno se inscribe a una clase vigente mediante su codigo."""
    supabase = supabase_admin()
    code = body.class_code.strip().upper()
    classroom = _first(
        (
            supabase.table("classes")
            .select("id, school_id, academic_year_id, is_active")
            .eq("code", code)
            .eq("is_active", True)
            .limit(1)
            .execute()
            .data
            or []
        )
    )
    if not classroom:
        raise _fail("Clase no encontrada o inactiva.")

    year_id = classroom.get("academic_year_id")
    if year_id:
        active_year = _first(
            (
                supabase.table("academic_years")
                .select("id")
                .eq("id", year_id)
                .eq("is_active", True)
                .limit(1)
                .execute()
                .data
                or []
            )
        )
        if not active_year:
            raise _fail("La clase no pertenece al año lectivo activo.")

    membership = _first(
        (
            supabase.table("memberships")
            .select("id")
            .eq("user_id", uid)
            .eq("school_id", classroom["school_id"])
            .eq("role", "student")
            .eq("status", "active")
            .limit(1)
            .execute()
            .data
            or []
        )
    )
    if not membership:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo un alumno activo de esta institución puede unirse.",
        )

    profile = _first(
        (
            supabase.table("student_profiles")
            .select("id")
            .eq("membership_id", membership["id"])
            .eq("school_id", classroom["school_id"])
            .limit(1)
            .execute()
            .data
            or []
        )
    )
    if not profile:
        raise _fail("El alumno no tiene un perfil institucional activo.")

    existing = _first(
        (
            supabase.table("class_enrollments")
            .select("id")
            .eq("class_id", classroom["id"])
            .eq("student_profile_id", profile["id"])
            .limit(1)
            .execute()
            .data
            or []
        )
    )
    if existing:
        return Msg(id=str(existing["id"]), detail="Ya estás inscrito en la clase")

    import uuid as _uuid

    enrollment_id = str(_uuid.uuid4())
    supabase.table("class_enrollments").insert(
        {
            "id": enrollment_id,
            "class_id": classroom["id"],
            "student_id": None,
            "student_profile_id": profile["id"],
            "academic_year_id": year_id,
            "status": "active",
            "is_active": True,
            "enrolled_at": "now()",
            "created_at": "now()",
            "updated_at": "now()",
        }
    ).execute()
    return Msg(id=enrollment_id, detail="Inscrito a la clase")
