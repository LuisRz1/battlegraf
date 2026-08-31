"""Integration tests for the phase 5 task and progression flow."""

from datetime import UTC, datetime, timedelta


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _multiple_choice_task(sample_section, *, xp_reward: int = 20) -> dict:
    return {
        "section_id": str(sample_section.id),
        "subject": "mathematics",
        "title": "Suma básica",
        "description": "Resuelve la pregunta.",
        "task_type": "multiple_choice",
        "due_date": (datetime.now(UTC) + timedelta(days=2)).isoformat(),
        "xp_reward": xp_reward,
        "options": {"A": "4", "B": "3", "C": "5", "D": "6"},
        "correct_option": "A",
        "publish": True,
    }


def test_multiple_choice_task_awards_xp_once(
    test_client,
    sample_section,
    professor_token,
    student_token,
):
    created = test_client.post(
        "/api/v1/tasks",
        json=_multiple_choice_task(sample_section),
        headers=_headers(professor_token),
    )
    assert created.status_code == 201
    task = created.json()
    assert task["correct_option"] == "A"

    listed = test_client.get(
        "/api/v1/tasks",
        headers=_headers(student_token),
    )
    assert listed.status_code == 200
    assert listed.json()[0]["correct_option"] is None

    submission = test_client.post(
        f"/api/v1/tasks/{task['id']}/submissions",
        json={"answer": "A"},
        headers=_headers(student_token),
    )
    assert submission.status_code == 201
    assert submission.json()["score"] == 100
    assert submission.json()["xp_awarded"] == 20

    duplicate = test_client.post(
        f"/api/v1/tasks/{task['id']}/submissions",
        json={"answer": "A"},
        headers=_headers(student_token),
    )
    assert duplicate.status_code == 409

    profile = test_client.get(
        "/api/v1/progression/me",
        headers=_headers(student_token),
    )
    assert profile.status_code == 200
    assert profile.json()["xp"] == 20
    assert len(profile.json()["transactions"]) == 1


def test_open_answer_requires_manual_grade(
    test_client,
    sample_section,
    professor_token,
    student_token,
):
    task_response = test_client.post(
        "/api/v1/tasks",
        json={
            "section_id": str(sample_section.id),
            "subject": "language",
            "title": "Comentario de lectura",
            "description": "Explica la idea principal.",
            "task_type": "open_answer",
            "xp_reward": 30,
            "publish": True,
        },
        headers=_headers(professor_token),
    )
    assert task_response.status_code == 201
    task = task_response.json()

    submitted = test_client.post(
        f"/api/v1/tasks/{task['id']}/submissions",
        json={"answer": "La idea principal es aprender colaborando."},
        headers=_headers(student_token),
    )
    assert submitted.status_code == 201
    submission = submitted.json()
    assert not submission["is_graded"]
    assert submission["score"] is None

    graded = test_client.post(
        f"/api/v1/tasks/{task['id']}/submissions/{submission['id']}/grade",
        json={"score": 80, "feedback": "Buen análisis."},
        headers=_headers(professor_token),
    )
    assert graded.status_code == 200
    assert graded.json()["xp_awarded"] == 24

    regraded = test_client.post(
        f"/api/v1/tasks/{task['id']}/submissions/{submission['id']}/grade",
        json={"score": 100, "feedback": "Duplicado"},
        headers=_headers(professor_token),
    )
    assert regraded.status_code == 409


def test_default_ranks_and_clan_membership(
    test_client,
    sample_section,
    student,
    director_token,
):
    ranks = test_client.post(
        "/api/v1/progression/ranks/defaults",
        headers=_headers(director_token),
    )
    assert ranks.status_code == 200
    assert [rank["name"] for rank in ranks.json()][:2] == ["Novato", "Aprendiz"]

    clan_response = test_client.post(
        "/api/v1/progression/clans",
        json={"section_id": str(sample_section.id), "name": "Estrategas"},
        headers=_headers(director_token),
    )
    assert clan_response.status_code == 201
    clan = clan_response.json()

    member_response = test_client.post(
        f"/api/v1/progression/clans/{clan['id']}/members/{student.id}",
        headers=_headers(director_token),
    )
    assert member_response.status_code == 200
    assert member_response.json()["member_count"] == 1
