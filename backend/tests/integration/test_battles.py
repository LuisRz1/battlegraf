"""End-to-end API contract tests for a two-player battle."""

from datetime import UTC, datetime, timedelta

import pytest

import src.domain.services.battle_engine as battle_engine_module
from src.domain.entities import Question, QuestionBank
from src.domain.enums import Subject
from src.infrastructure.auth.jwt_handler import create_access_token
from src.infrastructure.database.repositories import (
    SQLAlchemyQuestionBankRepository,
    SQLAlchemyQuestionRepository,
)


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def approved_math_questions(db_session, sample_school, professor):
    bank_repo = SQLAlchemyQuestionBankRepository(db_session)
    question_repo = SQLAlchemyQuestionRepository(db_session)
    bank = await bank_repo.create(
        QuestionBank(
            school_id=sample_school.id,
            subject=Subject.MATH,
        )
    )
    questions = [
        Question(
            school_id=sample_school.id,
            bank_id=bank.id,
            creator_id=professor.id,
            subject=Subject.MATH,
            text=f"Pregunta {index}",
            option_a="Correcta",
            option_b="Incorrecta B",
            option_c="Incorrecta C",
            option_d="Incorrecta D",
            correct_option="A",
            is_approved=True,
        )
        for index in range(10)
    ]
    created = await question_repo.create_many(questions)
    await db_session.commit()
    return created


def test_mobile_battle_contract_and_bidirectional_turns(
    test_client,
    student,
    student_2,
    student_token,
    approved_math_questions,
    monkeypatch,
):
    class ServerClock(datetime):
        value = datetime.now(UTC)

        @classmethod
        def now(cls, tz=None):
            return cls.value if tz is not None else cls.value.replace(tzinfo=None)

    monkeypatch.setattr(battle_engine_module, "datetime", ServerClock)

    created = test_client.post(
        "/api/v1/battles",
        json={
            "player_1_id": str(student.id),
            "player_2_id": str(student_2.id),
            "num_layers": 4,
            "min_nodes_per_layer": 3,
            "max_nodes_per_layer": 3,
            "subjects": ["mathematics"],
        },
        headers=_headers(student_token),
    )
    assert created.status_code == 201
    battle = created.json()
    assert battle["graph"] is not None
    assert battle["graph"]["num_layers"] == 4
    nodes = battle["graph"]["nodes"]
    assert len([node for node in nodes if node["layer"] == 0]) == 1
    assert len([node for node in nodes if node["layer"] == 3]) == 1
    assert all(len(node["question_ids"]) == 5 for node in nodes)

    started = test_client.post(
        f"/api/v1/battles/{battle['id']}/start",
        json={},
        headers=_headers(student_token),
    )
    assert started.status_code == 200
    started_battle = started.json()
    assert started_battle["current_player_id"] == str(student.id)
    assert started_battle["turn_number"] == 1
    assert started_battle["turn_deadline_at"] is not None
    assert 1 <= started_battle["time_remaining"] <= 30
    assert started_battle["player_positions"] == {
        "0": next(node["id"] for node in nodes if node["layer"] == 0),
        "1": next(node["id"] for node in nodes if node["layer"] == 3),
    }
    owner_by_node = {
        node_state["node_id"]: node_state["owner"]
        for node_state in started_battle["node_states"]
    }
    assert owner_by_node[started_battle["player_positions"]["0"]] == 0
    assert owner_by_node[started_battle["player_positions"]["1"]] == 1

    player_one_target = next(node for node in nodes if node["layer"] == 1)
    selected = test_client.post(
        f"/api/v1/battles/{battle['id']}/select-node",
        json={"node_id": player_one_target["id"]},
        headers=_headers(student_token),
    )
    assert selected.status_code == 200
    challenge = selected.json()
    assert set(challenge["options"]) == {"A", "B", "C", "D"}
    assert "correct_option" not in challenge

    answered = test_client.post(
        f"/api/v1/battles/{battle['id']}/answer",
        json={
            "node_id": player_one_target["id"],
            "question_id": challenge["question_id"],
            "chosen_answer": "A",
            "response_time_ms": 999_999_999,
        },
        headers=_headers(student_token),
    )
    assert answered.status_code == 200
    assert answered.json()["node_conquered"]
    assert answered.json()["current_turn"] == 1
    assert answered.json()["turn_number"] == 2
    assert answered.json()["response_time_ms"] < 999_999_999

    player_two_token = create_access_token(
        student_2.id,
        student_2.role,
        student_2.school_id,
        student_2.section_id,
    )
    player_two_target = next(node for node in nodes if node["layer"] == 2)
    reverse_selected = test_client.post(
        f"/api/v1/battles/{battle['id']}/select-node",
        json={"node_id": player_two_target["id"]},
        headers=_headers(player_two_token),
    )
    assert reverse_selected.status_code == 200
    reverse_challenge = reverse_selected.json()

    reverse_answered = test_client.post(
        f"/api/v1/battles/{battle['id']}/answer",
        json={
            "node_id": player_two_target["id"],
            "question_id": reverse_challenge["question_id"],
            "chosen_answer": "A",
            "response_time_ms": 999_999_999,
        },
        headers=_headers(player_two_token),
    )
    assert reverse_answered.status_code == 200
    assert reverse_answered.json()["node_conquered"]
    assert reverse_answered.json()["current_turn"] == 0
    assert reverse_answered.json()["turn_number"] == 3

    red_next_target = next(
        node
        for node in nodes
        if node["layer"] == 2 and player_one_target["id"] in node["connected_to"]
    )
    pending_red_question = test_client.post(
        f"/api/v1/battles/{battle['id']}/select-node",
        json={"node_id": red_next_target["id"]},
        headers=_headers(student_token),
    )
    assert pending_red_question.status_code == 200

    ServerClock.value += timedelta(seconds=31)
    after_timeout = test_client.get(
        f"/api/v1/battles/{battle['id']}",
        headers=_headers(student_token),
    )
    assert after_timeout.status_code == 200
    assert after_timeout.json()["current_turn"] == 1
    assert after_timeout.json()["turn_number"] == 4
    assert after_timeout.json()["active_node_id"] is None
    assert after_timeout.json()["player_positions"] == {
        "0": player_one_target["id"],
        "1": player_two_target["id"],
    }
