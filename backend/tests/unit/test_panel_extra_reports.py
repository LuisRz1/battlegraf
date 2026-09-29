from types import SimpleNamespace

import pytest

from src.presentation.api.routes import panel_extra


class FakeSupabase:
    def __init__(self, tables):
        self.tables = tables

    def table(self, name):
        return FakeQuery(self.tables.get(name, []))


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
async def test_staff_report_counts_active_enrolled_students_not_sections(monkeypatch):
    supabase = FakeSupabase(
        {
            "staff_profiles": [
                {
                    "id": "staff-1",
                    "school_id": "school-1",
                    "membership_id": "teacher-membership",
                    "full_name": "Docente",
                    "role": "teacher",
                }
            ],
            "subject_teachers": [
                {
                    "staff_id": "staff-1",
                    "school_id": "school-1",
                    "subject_id": "subject-1",
                    "subjects": {"name": "Matematica"},
                }
            ],
            "classes": [
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
                    "subject_id": "subject-1",
                    "is_active": True,
                },
                {
                    "id": "class-archived",
                    "school_id": "school-1",
                    "section_id": "section-3",
                    "subject_id": "subject-1",
                    "is_active": False,
                },
            ],
            "sections": [
                {"id": "section-1", "school_id": "school-1"},
                {"id": "section-2", "school_id": "school-1"},
                {"id": "section-3", "school_id": "school-1"},
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
                    "is_enabled": True,
                },
                {
                    "section_id": "section-3",
                    "subject_id": "subject-1",
                    "is_enabled": True,
                },
            ],
            "class_enrollments": [
                {
                    "class_id": "class-1",
                    "student_profile_id": "student-profile-1",
                    "student_id": "user-1",
                    "status": "active",
                    "is_active": True,
                },
                {
                    "class_id": "class-2",
                    "student_profile_id": "student-profile-1",
                    "student_id": "user-1",
                    "status": "active",
                    "is_active": True,
                },
                {
                    "class_id": "class-2",
                    "student_id": "user-1",
                    "status": "active",
                    "is_active": True,
                },
                {
                    "class_id": "class-2",
                    "student_id": "user-2",
                    "status": "active",
                    "is_active": True,
                },
                {
                    "class_id": "class-2",
                    "student_id": "user-3",
                    "status": "dropped",
                    "is_active": True,
                },
            ],
            "student_profiles": [
                {
                    "id": "student-profile-1",
                    "school_id": "school-1",
                    "membership_id": "student-membership",
                }
            ],
            "memberships": [
                {
                    "id": "student-membership",
                    "school_id": "school-1",
                    "user_id": "user-1",
                    "status": "active",
                }
            ],
            "grade_items": [
                {
                    "id": "grade-1",
                    "school_id": "school-1",
                    "created_by_membership_id": "teacher-membership",
                }
            ],
            "assignments": [{"id": "assignment-1"}],
        }
    )

    async def allow_lead(*_args, **_kwargs):
        return {"id": "director-membership", "role": "director"}

    monkeypatch.setattr(panel_extra, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel_extra, "_require_member", allow_lead)

    result = await panel_extra.report_staff("school-1", "user-director")

    assert result["staff"][0]["classes"] == 2
    assert result["staff"][0]["students"] == 2
    assert result["staff"][0]["grade_items"] == 1


@pytest.mark.asyncio
async def test_staff_report_keeps_legacy_membership_assigned_classes(monkeypatch):
    supabase = FakeSupabase(
        {
            "staff_profiles": [
                {
                    "id": "staff-1",
                    "school_id": "school-1",
                    "membership_id": "teacher-membership",
                    "full_name": "Docente",
                    "role": "teacher",
                }
            ],
            "subject_teachers": [],
            "classes": [
                {
                    "id": "legacy-class",
                    "school_id": "school-1",
                    "section_id": "section-1",
                    "subject_id": None,
                    "teacher_membership_id": "teacher-membership",
                    "is_active": True,
                }
            ],
            "sections": [{"id": "section-1", "school_id": "school-1"}],
            "section_subjects": [],
            "class_enrollments": [
                {
                    "class_id": "legacy-class",
                    "student_profile_id": "student-profile-1",
                    "status": "active",
                    "is_active": True,
                }
            ],
            "student_profiles": [
                {
                    "id": "student-profile-1",
                    "school_id": "school-1",
                    "membership_id": "student-membership",
                }
            ],
            "memberships": [
                {
                    "id": "student-membership",
                    "school_id": "school-1",
                    "user_id": "student-user",
                    "status": "active",
                }
            ],
            "grade_items": [],
            "assignments": [],
        }
    )

    async def allow_lead(*_args, **_kwargs):
        return {"id": "director-membership", "role": "director"}

    monkeypatch.setattr(panel_extra, "supabase_admin", lambda: supabase)
    monkeypatch.setattr(panel_extra, "_require_member", allow_lead)

    result = await panel_extra.report_staff("school-1", "user-director")

    assert result["staff"][0]["classes"] == 1
    assert result["staff"][0]["students"] == 1
