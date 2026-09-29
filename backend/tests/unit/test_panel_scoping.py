from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from src.presentation.api.routes import panel


def test_staff_policy_migration_drops_broad_read_without_removing_admin_or_own_reads():
    migrations = Path(__file__).resolve().parents[3] / "supabase" / "migrations"
    migration = (
        migrations / "20260924010000_academic_traceability_hardening.sql"
    ).read_text(encoding="utf-8")
    existing_staff_policies = (
        migrations / "20260802043000_command_center.sql"
    ).read_text(encoding="utf-8")

    assert (
        'drop policy if exists "members read staff" on public.staff_profiles;'
        in migration
    )
    assert 'create policy "member read own staff profile"' in migration
    assert 'create policy "admins manage staff"' in existing_staff_policies


class FakeSupabase:
    def __init__(self, responses=None):
        self.responses = responses or {}
        self.queries = []

    def table(self, name):
        query = FakeQuery(self, name)
        self.queries.append(query)
        return query


class FakeQuery:
    def __init__(self, supabase, table):
        self.supabase = supabase
        self.table = table
        self.filters = {}
        self.operation = "select"
        self.payload = None

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, field, value):
        self.filters[field] = value
        return self

    def in_(self, field, values):
        self.filters[field] = values
        return self

    def limit(self, *_args):
        return self

    def order(self, *_args, **_kwargs):
        return self

    def delete(self):
        self.operation = "delete"
        return self

    def insert(self, payload):
        self.operation = "insert"
        self.payload = payload
        return self

    def update(self, payload):
        self.operation = "update"
        self.payload = payload
        return self

    def execute(self):
        response = self.supabase.responses.get(self.table, [])
        if callable(response):
            response = response(self)
        return SimpleNamespace(data=response)


def test_own_student_profile_prefers_the_rostered_profile_with_a_section():
    supabase = FakeSupabase(
        {
            "student_profiles": [
                {
                    "id": "duplicate-profile",
                    "membership_id": "membership-1",
                    "section_id": None,
                },
                {
                    "id": "roster-profile",
                    "membership_id": "membership-1",
                    "section_id": "section-1",
                },
            ]
        }
    )

    profile = panel._own_student_profile(supabase, "school-1", "membership-1")

    assert profile["id"] == "roster-profile"


def test_preferred_student_profiles_preserves_ambiguous_section_assignments():
    profiles = [
        {"id": "profile-1", "membership_id": "membership-1", "section_id": "section-1"},
        {"id": "profile-2", "membership_id": "membership-1", "section_id": "section-2"},
    ]

    assert panel._preferred_student_profiles(profiles) == profiles


@pytest.mark.asyncio
async def test_require_member_rejects_non_active_memberships():
    supabase = FakeSupabase()

    with pytest.raises(HTTPException) as error:
        await panel._require_member(supabase, "user-1", "school-1", ["teacher"])

    assert error.value.status_code == 403
    assert supabase.queries[0].filters["status"] == "active"


def test_teacher_academic_scope_requires_staff_and_exact_section_course_pair(
    monkeypatch,
):
    member = {"id": "membership-1", "role": "teacher"}
    monkeypatch.setattr(
        panel,
        "_staff_for_member",
        lambda *_args: {"id": "staff-1"},
    )
    supabase = FakeSupabase(
        {
            "subject_teachers": [{"id": "subject-assignment-1"}],
            "section_subjects": [],
        }
    )

    with pytest.raises(HTTPException) as error:
        panel._require_academic_scope(
            supabase,
            "school-1",
            member,
            "user-1",
            subject_id="subject-1",
            section_id="section-1",
        )

    assert error.value.status_code == 403
    assert supabase.queries[0].filters == {
        "school_id": "school-1",
        "staff_id": "staff-1",
        "subject_id": "subject-1",
    }
    assert supabase.queries[1].filters == {
        "section_id": "section-1",
        "subject_id": "subject-1",
        "is_enabled": True,
    }


def test_teacher_academic_scope_fails_closed_without_staff(monkeypatch):
    monkeypatch.setattr(panel, "_staff_for_member", lambda *_args: None)
    supabase = FakeSupabase()

    with pytest.raises(HTTPException) as error:
        panel._require_academic_scope(
            supabase,
            "school-1",
            {"id": "membership-1", "role": "teacher"},
            "user-1",
            subject_id="subject-1",
            section_id="section-1",
        )

    assert error.value.status_code == 403
    assert not supabase.queries


@pytest.mark.asyncio
async def test_remove_teacher_validates_school_and_scopes_delete(monkeypatch):
    async def allow_member(*_args, **_kwargs):
        return {"id": "membership-1"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", allow_member)
    supabase = FakeSupabase({"subjects": [{"id": "subject-1"}], "staff_profiles": []})

    with pytest.raises(HTTPException) as error:
        await panel.remove_teacher_from_subject(
            "school-1", "subject-1", "staff-1", "user-1"
        )

    assert error.value.status_code == 404
    assert supabase.queries[0].filters == {"id": "subject-1", "school_id": "school-1"}
    assert supabase.queries[1].filters == {"id": "staff-1", "school_id": "school-1"}
    assert not any(query.operation == "delete" for query in supabase.queries)

    supabase.responses["staff_profiles"] = [{"id": "staff-1"}]
    await panel.remove_teacher_from_subject(
        "school-1", "subject-1", "staff-1", "user-1"
    )
    deletion = next(query for query in supabase.queries if query.operation == "delete")
    assert deletion.filters == {
        "school_id": "school-1",
        "subject_id": "subject-1",
        "staff_id": "staff-1",
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("student_school", "student_section"),
    [("school-1", "section-2"), ("school-2", "section-1")],
)
async def test_grade_write_rejects_student_outside_item_school_or_section(
    monkeypatch, student_school, student_section
):
    supabase = FakeSupabase(
        {
            "grade_items": [
                {
                    "id": "item-1",
                    "school_id": "school-1",
                    "max_score": 20,
                    "subject_id": "subject-1",
                    "section_id": "section-1",
                }
            ]
        }
    )

    async def allow_student(*_args, **_kwargs):
        return (
            {"id": "membership-1", "role": "director"},
            {
                "id": "student-1",
                "school_id": student_school,
                "section_id": student_section,
            },
        )

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_student_access", allow_student)

    with pytest.raises(HTTPException) as error:
        await panel.grade_student(
            "item-1", "student-1", panel.StudentGradeIn(score=15), "user-1"
        )

    assert error.value.status_code == 403
    assert not any(query.table == "student_grades" for query in supabase.queries)


@pytest.mark.asyncio
async def test_grade_item_rejects_subject_outside_school(monkeypatch):
    supabase = FakeSupabase()

    async def director_member(*_args, **_kwargs):
        return {"id": "membership-1", "role": "director"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", director_member)

    with pytest.raises(HTTPException) as error:
        await panel.create_grade_item(
            "school-1",
            panel.GradeItemIn(title="Evaluacion 1", subject_id="subject-foreign"),
            "user-1",
        )

    assert error.value.status_code == 404
    assert supabase.queries[0].filters == {
        "id": "subject-foreign",
        "school_id": "school-1",
    }
    assert not any(query.operation == "insert" for query in supabase.queries)


@pytest.mark.asyncio
async def test_assignment_create_enforces_teacher_section_course_pair(monkeypatch):
    supabase = FakeSupabase(
        {
            "subjects": [{"id": "subject-1"}],
            "sections": [{"id": "section-1"}],
            "section_subjects": [{"section_id": "section-1"}],
            "staff_profiles": [{"id": "staff-1"}],
            "subject_teachers": [{"id": "assignment-1"}],
            "assignments": [{"id": "assignment-1"}],
        }
    )

    async def teacher_member(*_args, **_kwargs):
        return {"id": "membership-1", "role": "teacher"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", teacher_member)
    monkeypatch.setattr(panel, "_staff_for_member", lambda *_args: {"id": "staff-1"})

    result = await panel.create_assignment(
        "school-1",
        panel.AssignmentIn(
            title="Practica 1", section_id="section-1", subject_id="subject-1"
        ),
        "user-1",
    )

    assert result.id == "assignment-1"
    insert = next(query for query in supabase.queries if query.operation == "insert")
    assert insert.table == "assignments"
    assert insert.payload["school_id"] == "school-1"


@pytest.mark.asyncio
async def test_assignment_create_rejects_tutor_outside_assigned_section(monkeypatch):
    supabase = FakeSupabase(
        {
            "subjects": [{"id": "subject-1"}],
            "sections": [{"id": "section-2"}],
            "section_subjects": [{"section_id": "section-2"}],
        }
    )

    async def tutor_member(*_args, **_kwargs):
        return {"id": "membership-1", "role": "tutor"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", tutor_member)
    monkeypatch.setattr(
        panel, "_accessible_students", lambda *_args: [{"section_id": "section-1"}]
    )

    with pytest.raises(HTTPException) as error:
        await panel.create_assignment(
            "school-1",
            panel.AssignmentIn(
                title="Practica 1", section_id="section-2", subject_id="subject-1"
            ),
            "user-1",
        )

    assert error.value.status_code == 403
    assert not any(query.operation == "insert" for query in supabase.queries)


def test_assignment_scope_accepts_active_class_enrollment_without_profile_section():
    supabase = FakeSupabase(
        {
            "classes": [
                {"id": "class-1", "section_id": "section-1", "subject_id": "subject-1"}
            ],
            "class_enrollments": lambda query: (
                [{"class_id": "class-1", "status": "active", "is_active": True}]
                if query.filters.get("student_id") == "user-1"
                else []
            ),
            "subjects": [{"id": "subject-1"}],
            "sections": [{"id": "section-1"}],
            "section_subjects": [{"section_id": "section-1"}],
        }
    )

    panel._require_assignment_student_scope(
        supabase,
        "school-1",
        {"id": "student-1", "section_id": None},
        "user-1",
        {"section_id": "section-1", "subject_id": "subject-1"},
    )

    assert any(
        query.table == "class_enrollments"
        and query.filters.get("student_id") == "user-1"
        for query in supabase.queries
    )


@pytest.mark.asyncio
async def test_assignment_submission_rejects_closed_assignment(monkeypatch):
    supabase = FakeSupabase(
        {
            "assignments": [
                {
                    "id": "assignment-1",
                    "school_id": "school-1",
                    "status": "closed",
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                }
            ]
        }
    )

    async def student_member(*_args, **_kwargs):
        return {"id": "membership-1", "role": "student"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", student_member)
    monkeypatch.setattr(
        panel,
        "_own_student_profile",
        lambda *_args: {
            "id": "student-1",
            "school_id": "school-1",
            "section_id": "section-1",
        },
    )

    with pytest.raises(HTTPException) as error:
        await panel.submit_assignment(
            "school-1",
            "assignment-1",
            panel.AssignmentSubmissionIn(answer="Answer"),
            "user-1",
        )

    assert error.value.status_code == 409
    assert not any(
        query.table == "assignment_submissions" for query in supabase.queries
    )


@pytest.mark.asyncio
async def test_assignment_submission_rejects_student_from_another_section(monkeypatch):
    supabase = FakeSupabase(
        {
            "assignments": [
                {
                    "id": "assignment-1",
                    "school_id": "school-1",
                    "status": "published",
                    "section_id": "section-1",
                    "subject_id": None,
                }
            ]
        }
    )

    async def student_member(*_args, **_kwargs):
        return {"id": "membership-1", "role": "student"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", student_member)
    monkeypatch.setattr(
        panel,
        "_own_student_profile",
        lambda *_args: {
            "id": "student-1",
            "school_id": "school-1",
            "section_id": "section-2",
        },
    )

    with pytest.raises(HTTPException) as error:
        await panel.submit_assignment(
            "school-1",
            "assignment-1",
            panel.AssignmentSubmissionIn(answer="Answer"),
            "user-1",
        )

    assert error.value.status_code == 403
    assert not any(
        query.table == "assignment_submissions" for query in supabase.queries
    )


@pytest.mark.asyncio
async def test_tracking_uses_user_id_for_legacy_submissions_and_fails_closed_courses(
    monkeypatch,
):
    supabase = FakeSupabase(
        {
            "subjects": [{"id": "subject-1", "name": "Matematica"}],
            "memberships": [{"user_id": "user-1"}],
            "task_submissions": [
                {
                    "task_id": "task-1",
                    "score": 9,
                    "is_graded": True,
                    "xp_awarded": 2,
                    "submitted_at": "2026-09-01T10:00:00Z",
                    "tasks": {"title": "Tarea"},
                }
            ],
            "assignments": [
                {
                    "id": "assignment-1",
                    "title": "Curso no resuelto",
                    "subject_id": "subject-1",
                    "section_id": "section-1",
                    "status": "published",
                }
            ],
        }
    )

    async def student_access(*_args, **_kwargs):
        return (
            {"id": "teacher-membership", "role": "director"},
            {
                "id": "student-1",
                "membership_id": "student-membership",
                "section_id": "section-1",
                "full_name": "Student",
            },
        )

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_student_access", student_access)
    monkeypatch.setattr(panel, "points_balance", lambda *_args: 0)

    result = await panel.student_tracking("school-1", "student-1", "user-1")

    submission_query = next(
        q for q in supabase.queries if q.table == "task_submissions"
    )
    assert submission_query.filters == {"student_id": "user-1"}
    membership_query = next(q for q in supabase.queries if q.table == "memberships")
    assert membership_query.filters == {
        "id": "student-membership",
        "school_id": "school-1",
        "role": "student",
        "status": "active",
    }
    assert result["tasks_done"][0]["task_id"] == "task-1"
    assert result["courses"] == []
    assert result["assignments"] == []


@pytest.mark.asyncio
async def test_tracking_resolves_legacy_class_enrollment_by_user_id(monkeypatch):
    supabase = FakeSupabase(
        {
            "subjects": [{"id": "subject-1", "name": "Matematica"}],
            "memberships": [{"user_id": "user-1"}],
            "classes": [
                {
                    "id": "class-1",
                    "name": "Clase A",
                    "code": "CL-0001",
                    "is_active": True,
                    "subject_id": "subject-1",
                    "subjects": {"name": "Matematica"},
                }
            ],
            "class_enrollments": lambda query: (
                [{"class_id": "class-1", "status": "active", "is_active": True}]
                if query.filters.get("student_id") == "user-1"
                else []
            ),
        }
    )

    async def student_access(*_args, **_kwargs):
        return (
            {"id": "director-membership", "role": "director"},
            {
                "id": "student-1",
                "membership_id": "student-membership",
                "section_id": "section-1",
                "full_name": "Student",
            },
        )

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_student_access", student_access)
    monkeypatch.setattr(panel, "points_balance", lambda *_args: 0)

    result = await panel.student_tracking("school-1", "student-1", "user-1")

    assert result["courses"][0]["id"] == "subject-1"
    assert result["enrolled_classes"][0]["id"] == "class-1"
    assert any(
        query.table == "class_enrollments"
        and query.filters.get("student_id") == "user-1"
        for query in supabase.queries
    )
