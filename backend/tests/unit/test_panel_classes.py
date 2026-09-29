from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from src.presentation.api.routes import panel


class FakeSupabase:
    def __init__(self, tables):
        self.tables = tables
        self.queries = []

    def table(self, name):
        query = FakeQuery(self, name)
        self.queries.append(query)
        return query


class FakeQuery:
    def __init__(self, supabase, table):
        self.supabase = supabase
        self.table = table
        self.filters = []
        self.inserted = None
        self.updated = None

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, key, value):
        self.filters.append((key, value, False))
        return self

    def in_(self, key, values):
        self.filters.append((key, values, True))
        return self

    def limit(self, *_args):
        return self

    def insert(self, payload):
        self.inserted = payload
        return self

    def update(self, payload):
        self.updated = payload
        return self

    def execute(self):
        if self.inserted is not None:
            return SimpleNamespace(data=[{"id": self.inserted["id"]}])
        rows = self.supabase.tables.get(self.table, [])
        for key, value, is_many in self.filters:
            rows = [
                row
                for row in rows
                if (row.get(key) in value if is_many else row.get(key) == value)
            ]
        return SimpleNamespace(data=rows)


@pytest.mark.asyncio
async def test_create_class_uses_current_course_relations_not_legacy_teacher_column(
    monkeypatch,
):
    supabase = FakeSupabase(
        {
            "academic_years": [
                {"id": "year-1", "school_id": "school-1", "is_active": True}
            ],
            "subjects": [
                {"id": "subject-1", "school_id": "school-1", "name": "Matematica"}
            ],
            "sections": [{"id": "section-1", "school_id": "school-1"}],
            "section_subjects": [
                {
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                    "is_enabled": True,
                }
            ],
            "subject_teachers": [
                {
                    "id": "assignment-1",
                    "school_id": "school-1",
                    "staff_id": "staff-1",
                    "subject_id": "subject-1",
                }
            ],
            "classes": [],
        }
    )

    async def teacher_member(*_args, **_kwargs):
        return {"id": "membership-1", "role": "teacher"}

    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel, "_require_member", teacher_member)
    monkeypatch.setattr(panel, "_staff_for_member", lambda *_args: {"id": "staff-1"})

    result = await panel.create_class(
        "school-1",
        panel.ClassIn(
            name="Matematica 1", subject_id="subject-1", section_id="section-1"
        ),
        "user-1",
    )

    insert_query = next(
        query for query in supabase.queries if query.inserted is not None
    )
    assert result.id == insert_query.inserted["id"]
    assert insert_query.inserted["academic_year_id"] == "year-1"
    assert insert_query.inserted["subject_id"] == "subject-1"
    assert insert_query.inserted["section_id"] == "section-1"
    assert "teacher_membership_id" not in insert_query.inserted


def test_teacher_student_access_requires_enabled_course_in_same_school(monkeypatch):
    supabase = FakeSupabase(
        {
            "student_profiles": [
                {"id": "student-1", "school_id": "school-1", "section_id": "section-1"},
                {"id": "student-2", "school_id": "school-1", "section_id": "section-2"},
            ],
            "subject_teachers": [
                {
                    "school_id": "school-1",
                    "staff_id": "staff-1",
                    "subject_id": "subject-1",
                }
            ],
            "subjects": [{"id": "subject-1", "school_id": "school-1"}],
            "classes": [
                {
                    "school_id": "school-1",
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                    "is_active": True,
                },
                {
                    "school_id": "school-1",
                    "section_id": "section-2",
                    "subject_id": "subject-1",
                    "is_active": True,
                },
            ],
            "sections": [
                {"id": "section-1", "school_id": "school-1"},
                {"id": "section-2", "school_id": "school-1"},
            ],
            "section_subjects": [
                {
                    "section_id": "section-1",
                    "subject_id": "subject-1",
                    "is_enabled": True,
                },
                {
                    "section_id": "section-2",
                    "subject_id": "subject-1",
                    "is_enabled": False,
                },
            ],
        }
    )
    monkeypatch.setattr(panel, "_staff_for_member", lambda *_args: {"id": "staff-1"})

    accessible = panel._accessible_students(
        supabase, "school-1", {"id": "membership-1", "role": "teacher"}, "user-1"
    )

    assert [student["id"] for student in accessible] == ["student-1"]


@pytest.mark.asyncio
async def test_student_cannot_join_a_class_assigned_to_another_section(monkeypatch):
    supabase = FakeSupabase(
        {
            "classes": [
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "academic_year_id": "year-1",
                    "section_id": "section-2",
                    "is_active": True,
                    "code": "CL-1234",
                }
            ],
            "academic_years": [
                {"id": "year-1", "school_id": "school-1", "is_active": True}
            ],
            "memberships": [
                {
                    "id": "membership-1",
                    "user_id": "user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                }
            ],
            "student_profiles": [
                {
                    "id": "student-1",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": "section-1",
                }
            ],
        }
    )
    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)
    with pytest.raises(HTTPException) as error:
        await panel.join_class(panel.ClassCodeIn(class_code="CL-1234"), "user-1")

    assert error.value.status_code == 403
    assert not any(query.inserted is not None for query in supabase.queries)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "profiles",
    [
        [],
        [
            {"id": "student-1", "section_id": "section-1"},
            {"id": "student-2", "section_id": "section-1"},
        ],
    ],
)
async def test_student_join_requires_exactly_one_profile_for_membership(
    monkeypatch, profiles
):
    supabase = FakeSupabase(
        {
            "classes": [
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "academic_year_id": "year-1",
                    "section_id": "section-1",
                    "is_active": True,
                    "code": "CL-1234",
                }
            ],
            "academic_years": [
                {"id": "year-1", "school_id": "school-1", "is_active": True}
            ],
            "memberships": [
                {
                    "id": "membership-1",
                    "user_id": "user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                }
            ],
            "student_profiles": [
                {
                    **profile,
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                }
                for profile in profiles
            ],
        }
    )
    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)

    with pytest.raises(HTTPException) as error:
        await panel.join_class(panel.ClassCodeIn(class_code="CL-1234"), "user-1")

    assert error.value.status_code == 400
    assert "perfil institucional" in error.value.detail
    assert not any(query.inserted is not None for query in supabase.queries)


@pytest.mark.asyncio
async def test_student_join_uses_sectioned_roster_profile_when_legacy_duplicate_exists(
    monkeypatch,
):
    supabase = FakeSupabase(
        {
            "classes": [
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "academic_year_id": "year-1",
                    "section_id": "section-1",
                    "is_active": True,
                    "code": "CL-1234",
                }
            ],
            "academic_years": [
                {"id": "year-1", "school_id": "school-1", "is_active": True}
            ],
            "memberships": [
                {
                    "id": "membership-1",
                    "user_id": "user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                }
            ],
            "student_profiles": [
                {
                    "id": "legacy-profile",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": None,
                },
                {
                    "id": "roster-profile",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": "section-1",
                },
            ],
            "class_enrollments": [],
        }
    )
    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)

    result = await panel.join_class(panel.ClassCodeIn(class_code="CL-1234"), "user-1")

    assert result.id
    enrollment = next(
        query
        for query in supabase.queries
        if query.table == "class_enrollments" and query.inserted is not None
    )
    assert enrollment.inserted["student_profile_id"] == "roster-profile"


@pytest.mark.asyncio
async def test_student_join_repoints_existing_duplicate_profile_enrollment(monkeypatch):
    supabase = FakeSupabase(
        {
            "classes": [
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "academic_year_id": "year-1",
                    "section_id": "section-1",
                    "is_active": True,
                    "code": "CL-1234",
                }
            ],
            "academic_years": [
                {"id": "year-1", "school_id": "school-1", "is_active": True}
            ],
            "memberships": [
                {
                    "id": "membership-1",
                    "user_id": "user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                }
            ],
            "student_profiles": [
                {
                    "id": "legacy-profile",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": None,
                },
                {
                    "id": "roster-profile",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": "section-1",
                },
            ],
            "class_enrollments": [
                {
                    "id": "legacy-enrollment",
                    "class_id": "class-1",
                    "student_profile_id": "legacy-profile",
                    "student_id": None,
                    "status": "active",
                    "is_active": True,
                }
            ],
        }
    )
    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)

    result = await panel.join_class(panel.ClassCodeIn(class_code="CL-1234"), "user-1")

    update = next(
        query
        for query in supabase.queries
        if query.table == "class_enrollments" and query.updated is not None
    )
    assert result.id == "legacy-enrollment"
    assert update.updated == {
        "student_profile_id": "roster-profile",
        "student_id": None,
    }


@pytest.mark.asyncio
async def test_student_join_rejects_enrollment_with_another_student_id(monkeypatch):
    supabase = FakeSupabase(
        {
            "classes": [
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "academic_year_id": "year-1",
                    "section_id": "section-1",
                    "is_active": True,
                    "code": "CL-1234",
                }
            ],
            "academic_years": [
                {"id": "year-1", "school_id": "school-1", "is_active": True}
            ],
            "memberships": [
                {
                    "id": "membership-1",
                    "user_id": "user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                }
            ],
            "student_profiles": [
                {
                    "id": "roster-profile",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": "section-1",
                }
            ],
            "class_enrollments": [
                {
                    "id": "conflicting-enrollment",
                    "class_id": "class-1",
                    "student_profile_id": "roster-profile",
                    "student_id": "other-user",
                    "status": "active",
                    "is_active": True,
                }
            ],
        }
    )
    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)

    with pytest.raises(HTTPException) as error:
        await panel.join_class(panel.ClassCodeIn(class_code="CL-1234"), "user-1")

    assert error.value.status_code == 409
    assert not any(query.updated is not None for query in supabase.queries)
    assert not any(query.inserted is not None for query in supabase.queries)


@pytest.mark.asyncio
async def test_student_without_section_cannot_join_a_section_class(monkeypatch):
    supabase = FakeSupabase(
        {
            "classes": [
                {
                    "id": "class-1",
                    "school_id": "school-1",
                    "academic_year_id": "year-1",
                    "section_id": "section-1",
                    "is_active": True,
                    "code": "CL-1234",
                }
            ],
            "academic_years": [
                {"id": "year-1", "school_id": "school-1", "is_active": True}
            ],
            "memberships": [
                {
                    "id": "membership-1",
                    "user_id": "user-1",
                    "school_id": "school-1",
                    "role": "student",
                    "status": "active",
                }
            ],
            "student_profiles": [
                {
                    "id": "student-1",
                    "school_id": "school-1",
                    "membership_id": "membership-1",
                    "section_id": None,
                }
            ],
        }
    )
    monkeypatch.setattr(panel, "supabase_admin", lambda: supabase)

    with pytest.raises(HTTPException) as error:
        await panel.join_class(panel.ClassCodeIn(class_code="CL-1234"), "user-1")

    assert error.value.status_code == 403
    assert not any(query.inserted is not None for query in supabase.queries)
