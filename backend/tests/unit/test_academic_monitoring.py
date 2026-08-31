from src.presentation.api.routes.panel import (
    AttendanceBatchIn,
    AttendanceRecordIn,
    GradeItemIn,
    _student_risk,
)


def test_student_risk_prioritizes_attendance_and_grades():
    assert _student_risk(79.9, 100, 0) == "critical"
    assert _student_risk(100, 54.9, 0) == "critical"
    assert _student_risk(88, 80, 0) == "attention"
    assert _student_risk(100, 64, 0) == "attention"
    assert _student_risk(100, 100, 1) == "attention"
    assert _student_risk(95, 80, 0) == "ok"
    assert _student_risk(None, None, 0) == "ok"


def test_attendance_batch_accepts_pilot_statuses():
    body = AttendanceBatchIn(
        records=[
            AttendanceRecordIn(
                student_profile_id="student-0001",
                attendance_date="2026-08-29",
                status="late",
                minutes_late=8,
            )
        ]
    )
    assert body.records[0].status == "late"
    assert body.records[0].minutes_late == 8


def test_grade_item_defaults_match_peruvian_scale():
    item = GradeItemIn(title="Diagnóstico", subject_id="subject-0001")
    assert item.max_score == 20
    assert item.category == "assessment"
    assert item.status == "published"
