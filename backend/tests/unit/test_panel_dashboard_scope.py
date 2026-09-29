from types import SimpleNamespace

import pytest

from src.presentation.api.routes import panel


class FakeSupabase:
    def __init__(self, tables):
        self.tables = tables
        self.queries = []

    def table(self, name):
        query = FakeQuery(self.tables.get(name, []))
        query.table_name = name
        self.queries.append(query)
        return query


class FakeQuery:
    def __init__(self, rows):
        self.rows = rows
        self.filters = []

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, key, value):
        self.filters.append((key, value, False))
        return self

    def in_(self, key, values):
        self.filters.append((key, values, True))
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, *_args):
        return self

    def execute(self):
        rows = self.rows
        for key, value, is_many in self.filters:
            rows = [
                row
                for row in rows
                if (row.get(key) in value if is_many else row.get(key) == value)
            ]
        return SimpleNamespace(data=rows)


@pytest.mark.asyncio
async def test_teacher_dashboard_only_contains_assigned_courses_and_students(
    monkeypatch,
):
    staff_teacher = {
        "id": "staff-1",
        "school_id": "school-1",
        "membership_id": "teacher-membership",
        "full_name": "Docente 1",
        "role": "teacher",
        "status": "active",
    }
    staff_other = {
        "id": "staff-2",
        "school_id": "school-1",
        "membership_id": "other-membership",
        "full_name": "Docente 2",
        "role": "teacher",
        "status": "active",
    }
    supabase = FakeSupabase(
        {
            "schools": [{"id": "school-1", "name": "Colegio"}],
            "subscriptions": [{"school_id": "school-1", "plan_slug": "aula"}],
            "student_profiles": [
                {
                    "id": "student-1",
                    "school_id": "school-1",
                    "membership_id": "student-membership-1",
                    "section_id": "section-1",
                    "full_name": "Alumno 1",
                },
            ],
            "sections": [
                {"id": "section-1", "school_id": "school-1", "display_name": "1A"},
                {"id": "section-2", "school_id": "school-1", "display_name": "2A"},
            ],
            "subjects": [
                {
                    "id": "subject-1",
                    "school_id": "school-1",
                    "name": "Matematica",
                    "is_enabled": True,
                },
                {
                    "id": "subject-2",
                    "school_id": "school-1",
                    "name": "Ciencia",
                    "is_enabled": True,
                },
            ],
            "subject_teachers": [
                {
                    "id": "link-1",
                    "school_id": "school-1",
                    "subject_id": "subject-1",
                    "staff_id": "staff-1",
                    "staff_profiles": staff_teacher,
                },
                {
                    "id": "link-2",
                    "school_id": "school-1",
                    "subject_id": "subject-2",
                    "staff_id": "staff-1",
                    "staff_profiles": staff_teacher,
                },
            ],
            "staff_profiles": [staff_teacher, staff_other],
            "classes": [
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "name": "Matematica 1A",
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                    "is_active": True,
                },
                {
                    "id": "class-2",
                    "school_id": "school-1",
                    "name": "Ciencia 1A",
                    "section_id": "section-1",
                    "subject_id": "subject-2",
                    "is_active": True,
                },
                {
                    "id": "class-3",
                    "school_id": "school-1",
                    "name": "Ciencia 2A",
                    "section_id": "section-2",
                    "subject_id": "subject-2",
                    "is_active": True,
                },
            ],
            "class_enrollments": [
                {
                    "id": "enrollment-1",
                    "class_id": "class-1",
                    "student_profile_id": "student-1",
                    "status": "active",
                },
                {
                    "id": "enrollment-2",
                    "class_id": "class-2",
                    "student_profile_id": "student-1",
                    "status": "active",
                },
            ],
            "section_subjects": [
                {
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                    "is_enabled": True,
                },
                {
                    "section_id": "section-1",
                    "subject_id": "subject-2",
                    "is_enabled": False,
                },
                {
                    "section_id": "section-2",
                    "subject_id": "subject-2",
                    "is_enabled": False,
                },
            ],
            "assignments": [
                {
                    "id": "assignment-1",
                    "school_id": "school-1",
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                },
                {
                    "id": "assignment-2",
                    "school_id": "school-1",
                    "section_id": "section-1",
                    "subject_id": "subject-2",
                },
                {
                    "id": "assignment-global",
                    "school_id": "school-1",
                    "section_id": None,
                    "subject_id": None,
                },
            ],
            "learning_materials": [
                {
                    "id": "material-1",
                    "school_id": "school-1",
                    "subject_id": "subject-1",
                },
                {
                    "id": "material-2",
                    "school_id": "school-1",
                    "subject_id": "subject-2",
                },
            ],
            "question_bank": [
                {
                    "id": "question-1",
                    "school_id": "school-1",
                    "subject_id": "subject-1",
                },
                {
                    "id": "question-2",
                    "school_id": "school-1",
                    "subject_id": "subject-2",
                },
            ],
            "battle_events": [
                {"id": "battle-1", "school_id": "school-1", "subject_id": "subject-1"},
                {"id": "battle-2", "school_id": "school-1", "subject_id": "subject-2"},
            ],
        }
    )

    async def teacher_member(*_args, **_kwargs):
        return {"id": "teacher-membership", "role": "teacher"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", teacher_member)

    result = await panel.panel_dashboard("school-1", "user-1")

    assert [row["id"] for row in result["students"]] == ["student-1"]
    assert [row["id"] for row in result["subjects"]] == ["subject-1"]
    assert [row["subject_id"] for row in result["subject_teachers"]] == ["subject-1"]
    assert [row["id"] for row in result["classes"]] == ["class-1"]
    assert {row["id"] for row in result["assignments"]} == {
        "assignment-1",
        "assignment-global",
    }
    assert [row["id"] for row in result["materials"]] == ["material-1"]
    assert [row["id"] for row in result["questions"]] == ["question-1"]
    assert [row["id"] for row in result["battles"]] == ["battle-1"]
    assert [row["id"] for row in result["staff"]] == ["staff-1"]


async def _dashboard_result(monkeypatch, supabase, member, uid="user-1"):
    async def current_member(*_args, **_kwargs):
        return member

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", current_member)
    return await panel.panel_dashboard("school-1", uid)


def _scoped_dashboard_tables(
    *,
    student_profiles,
    sections,
    classes,
    enrollments,
    memberships=(),
    staff_profiles=()
):
    return {
        "student_profiles": student_profiles,
        "sections": sections,
        "classes": classes,
        "class_enrollments": enrollments,
        "memberships": memberships,
        "staff_profiles": staff_profiles,
    }


@pytest.mark.asyncio
async def test_student_dashboard_rejects_enrollment_outside_profile_section(
    monkeypatch,
):
    supabase = FakeSupabase(
        _scoped_dashboard_tables(
            student_profiles=[
                {
                    "id": "student-1",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": "section-1",
                    "full_name": "Alumno",
                }
            ],
            sections=[
                {
                    "id": "section-1",
                    "school_id": "school-1",
                    "display_name": "1A",
                },
                {
                    "id": "section-2",
                    "school_id": "school-1",
                    "display_name": "2A",
                },
            ],
            classes=[
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "section_id": "section-1",
                    "is_active": True,
                },
                {
                    "id": "class-2",
                    "school_id": "school-1",
                    "section_id": "section-2",
                    "is_active": True,
                },
            ],
            enrollments=[
                {
                    "id": "enrollment-1",
                    "class_id": "class-2",
                    "student_profile_id": "student-1",
                    "status": "active",
                    "is_active": True,
                }
            ],
        )
    )

    result = await _dashboard_result(
        monkeypatch,
        supabase,
        {"id": "membership-1", "role": "student", "user_id": "user-1"},
    )

    assert [row["id"] for row in result["classes"]] == ["class-1"]
    assert result["enrollments"] == []


@pytest.mark.asyncio
async def test_dashboard_resolves_legacy_enrollments_through_active_same_school_memberships(
    monkeypatch,
):
    staff = {
        "id": "staff-1",
        "school_id": "school-1",
        "membership_id": "tutor-membership",
        "full_name": "Tutor",
        "role": "tutor",
        "status": "active",
    }
    supabase = FakeSupabase(
        _scoped_dashboard_tables(
            student_profiles=[
                {
                    "id": "student-active",
                    "school_id": "school-1",
                    "membership_id": "active-membership",
                    "section_id": "section-1",
                    "full_name": "Activo",
                },
                {
                    "id": "student-active-duplicate",
                    "school_id": "school-1",
                    "membership_id": "active-membership",
                    "section_id": None,
                    "full_name": "Activo",
                },
                {
                    "id": "student-inactive",
                    "school_id": "school-1",
                    "membership_id": "inactive-membership",
                    "section_id": "section-1",
                    "full_name": "Invitado",
                },
                {
                    "id": "student-other-school",
                    "school_id": "school-1",
                    "membership_id": "other-school-membership",
                    "section_id": "section-1",
                    "full_name": "Otro colegio",
                },
            ],
            sections=[
                {
                    "id": "section-1",
                    "school_id": "school-1",
                    "display_name": "1A",
                    "tutor_staff_id": "staff-1",
                }
            ],
            classes=[
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "section_id": "section-1",
                    "is_active": True,
                }
            ],
            enrollments=[
                {
                    "id": "enrollment-active",
                    "class_id": "class-1",
                    "student_profile_id": None,
                    "student_id": "student-user-1",
                    "status": "active",
                    "is_active": True,
                },
                {
                    "id": "enrollment-inactive",
                    "class_id": "class-1",
                    "student_profile_id": None,
                    "student_id": "student-user-2",
                    "status": "active",
                    "is_active": True,
                },
                {
                    "id": "enrollment-other-school",
                    "class_id": "class-1",
                    "student_profile_id": None,
                    "student_id": "student-user-3",
                    "status": "active",
                    "is_active": True,
                },
            ],
            memberships=[
                {
                    "id": "active-membership",
                    "user_id": "student-user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                },
                {
                    "id": "inactive-membership",
                    "user_id": "student-user-2",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "invited",
                },
                {
                    "id": "other-school-membership",
                    "user_id": "student-user-3",
                    "school_id": "school-2",
                    "role": "student",
                    "status": "active",
                },
            ],
            staff_profiles=[staff],
        )
    )

    result = await _dashboard_result(
        monkeypatch, supabase, {"id": "tutor-membership", "role": "tutor"}
    )

    assert [row["id"] for row in result["enrollments"]] == ["enrollment-active"]
    assert result["enrollments"][0]["student_profile_id"] == "student-active"
    membership_query = next(
        query for query in supabase.queries if query.table_name == "memberships"
    )
    assert ("school_id", "school-1", False) in membership_query.filters
    assert ("role", "student", False) in membership_query.filters
    assert ("status", "active", False) in membership_query.filters


@pytest.mark.asyncio
async def test_student_dashboard_keeps_own_profileless_explicit_enrollment(monkeypatch):
    supabase = FakeSupabase(
        _scoped_dashboard_tables(
            student_profiles=[],
            sections=[
                {
                    "id": "section-2",
                    "school_id": "school-1",
                    "display_name": "2A",
                }
            ],
            classes=[
                {
                    "id": "class-explicit",
                    "school_id": "school-1",
                    "section_id": "section-2",
                    "is_active": True,
                }
            ],
            enrollments=[
                {
                    "id": "enrollment-explicit",
                    "class_id": "class-explicit",
                    "student_profile_id": None,
                    "student_id": "user-1",
                    "status": "active",
                    "is_active": True,
                }
            ],
            memberships=[
                {
                    "id": "membership-1",
                    "user_id": "user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                }
            ],
        )
    )

    result = await _dashboard_result(
        monkeypatch,
        supabase,
        {"id": "membership-1", "role": "student", "user_id": "user-1"},
    )

    assert [row["id"] for row in result["classes"]] == ["class-explicit"]
    assert [row["id"] for row in result["enrollments"]] == ["enrollment-explicit"]
    assert result["enrollments"][0]["student_profile_id"] is None


@pytest.mark.asyncio
async def test_tutor_dashboard_hides_enrolled_class_when_section_course_is_disabled(
    monkeypatch,
):
    staff = {
        "id": "staff-1",
        "school_id": "school-1",
        "membership_id": "tutor-membership",
        "role": "tutor",
        "status": "active",
    }
    tables = _scoped_dashboard_tables(
        student_profiles=[
            {
                "id": "student-1",
                "school_id": "school-1",
                "membership_id": "student-membership",
                "section_id": "section-1",
                "full_name": "Alumno",
            }
        ],
        sections=[
            {
                "id": "section-1",
                "school_id": "school-1",
                "tutor_staff_id": "staff-1",
                "display_name": "1A",
            }
        ],
        classes=[
            {
                "id": "disabled-class",
                "school_id": "school-1",
                "section_id": "section-1",
                "subject_id": "subject-1",
                "is_active": True,
            }
        ],
        enrollments=[
            {
                "id": "enrollment-1",
                "class_id": "disabled-class",
                "student_profile_id": "student-1",
                "status": "active",
                "is_active": True,
            }
        ],
        staff_profiles=[staff],
    )
    tables.update(
        {
            "schools": [{"id": "school-1", "name": "Colegio"}],
            "subjects": [
                {"id": "subject-1", "school_id": "school-1", "is_enabled": True}
            ],
            "section_subjects": [
                {
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                    "is_enabled": False,
                }
            ],
            "learning_materials": [
                {"id": "material-1", "school_id": "school-1", "subject_id": "subject-1"}
            ],
            "question_bank": [
                {
                    "id": "question-1",
                    "school_id": "school-1",
                    "subject_id": "subject-1",
                    "correct_index": 1,
                }
            ],
            "battle_events": [
                {"id": "battle-1", "school_id": "school-1", "subject_id": "subject-1"}
            ],
            "assignments": [
                {
                    "id": "assignment-1",
                    "school_id": "school-1",
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                }
            ],
        }
    )
    supabase = FakeSupabase(tables)

    result = await _dashboard_result(
        monkeypatch, supabase, {"id": "tutor-membership", "role": "tutor"}
    )

    assert result["classes"] == []
    assert result["assignments"] == []
    assert result["materials"] == []
    assert result["questions"] == []
    assert result["battles"] == []


@pytest.mark.asyncio
async def test_student_dashboard_limits_subject_resources_to_own_section(monkeypatch):
    tables = _scoped_dashboard_tables(
        student_profiles=[
            {
                "id": "student-1",
                "school_id": "school-1",
                "membership_id": "student-membership",
                "section_id": "section-1",
                "full_name": "Alumno",
            }
        ],
        sections=[
            {"id": "section-1", "school_id": "school-1", "display_name": "1A"},
            {"id": "section-2", "school_id": "school-1", "display_name": "2A"},
        ],
        classes=[
            {
                "id": "class-1",
                "school_id": "school-1",
                "section_id": "section-1",
                "subject_id": "subject-1",
                "is_active": True,
            },
            {
                "id": "class-2",
                "school_id": "school-1",
                "section_id": "section-2",
                "subject_id": "subject-2",
                "is_active": True,
            },
        ],
        enrollments=[],
    )
    tables.update(
        {
            "schools": [{"id": "school-1", "name": "Colegio"}],
            "subjects": [
                {
                    "id": "subject-1",
                    "school_id": "school-1",
                    "name": "Curso A",
                    "is_enabled": True,
                },
                {
                    "id": "subject-2",
                    "school_id": "school-1",
                    "name": "Curso B",
                    "is_enabled": True,
                },
            ],
            "section_subjects": [
                {
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                    "is_enabled": True,
                },
                {
                    "section_id": "section-2",
                    "subject_id": "subject-2",
                    "is_enabled": True,
                },
            ],
            "learning_materials": [
                {
                    "id": "material-1",
                    "school_id": "school-1",
                    "subject_id": "subject-1",
                },
                {
                    "id": "material-2",
                    "school_id": "school-1",
                    "subject_id": "subject-2",
                },
            ],
            "battle_events": [
                {"id": "battle-1", "school_id": "school-1", "subject_id": "subject-1"},
                {"id": "battle-2", "school_id": "school-1", "subject_id": "subject-2"},
            ],
        }
    )

    result = await _dashboard_result(
        monkeypatch,
        FakeSupabase(tables),
        {"id": "student-membership", "role": "student", "user_id": "user-1"},
    )

    assert [row["id"] for row in result["classes"]] == ["class-1"]
    assert [row["id"] for row in result["subjects"]] == ["subject-1"]
    assert [row["id"] for row in result["materials"]] == ["material-1"]
    assert [row["id"] for row in result["battles"]] == ["battle-1"]


@pytest.mark.asyncio
async def test_student_explicit_enrollment_only_adds_its_section_course(monkeypatch):
    tables = _scoped_dashboard_tables(
        student_profiles=[],
        sections=[{"id": "section-2", "school_id": "school-1", "display_name": "2A"}],
        classes=[
            {
                "id": "enrolled-class",
                "school_id": "school-1",
                "section_id": "section-2",
                "subject_id": "subject-1",
                "is_active": True,
            },
            {
                "id": "other-class",
                "school_id": "school-1",
                "section_id": "section-2",
                "subject_id": "subject-2",
                "is_active": True,
            },
        ],
        enrollments=[
            {
                "id": "enrollment-1",
                "class_id": "enrolled-class",
                "student_profile_id": None,
                "student_id": "user-1",
                "status": "active",
                "is_active": True,
            }
        ],
        memberships=[
            {
                "id": "student-membership",
                "user_id": "user-1",
                "school_id": "school-1",
                "role": "student",
                "status": "active",
            }
        ],
    )
    tables.update(
        {
            "schools": [{"id": "school-1", "name": "Colegio"}],
            "subjects": [
                {
                    "id": "subject-1",
                    "school_id": "school-1",
                    "name": "Curso A",
                    "is_enabled": True,
                },
                {
                    "id": "subject-2",
                    "school_id": "school-1",
                    "name": "Curso B",
                    "is_enabled": True,
                },
            ],
            "section_subjects": [
                {
                    "section_id": "section-2",
                    "subject_id": "subject-1",
                    "is_enabled": True,
                },
                {
                    "section_id": "section-2",
                    "subject_id": "subject-2",
                    "is_enabled": True,
                },
            ],
            "learning_materials": [
                {
                    "id": "material-1",
                    "school_id": "school-1",
                    "subject_id": "subject-1",
                },
                {
                    "id": "material-2",
                    "school_id": "school-1",
                    "subject_id": "subject-2",
                },
            ],
        }
    )

    result = await _dashboard_result(
        monkeypatch,
        FakeSupabase(tables),
        {"id": "student-membership", "role": "student", "user_id": "user-1"},
    )

    assert [row["id"] for row in result["classes"]] == ["enrolled-class"]
    assert [row["id"] for row in result["subjects"]] == ["subject-1"]
    assert [row["id"] for row in result["materials"]] == ["material-1"]
