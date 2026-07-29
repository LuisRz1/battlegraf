"""Unit tests for turn, route, steal, and victory rules."""

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest

from src.domain.entities import (
    Battle,
    BattleMove,
    BattleNodeState,
    Graph,
    GraphNode,
    Question,
)
from src.domain.enums import BattleStatus, Subject
from src.domain.services.battle_engine import BattleEngine

TURN_START = datetime(2026, 7, 28, 12, 0, tzinfo=UTC)


def _question(question_id: UUID) -> Question:
    return Question(
        id=question_id,
        subject=Subject.MATH,
        text="2 + 2",
        option_a="4",
        option_b="3",
        option_c="5",
        option_d="6",
        correct_option="A",
        is_approved=True,
    )


def _linear_battle() -> tuple[Battle, Graph, dict[UUID, Question]]:
    question_ids = [uuid4() for _ in range(4)]
    nodes = [
        GraphNode(
            id=uuid4(),
            layer=0,
            position=0,
            subject=Subject.MATH,
            question_ids=[question_ids[0]],
        ),
        GraphNode(
            id=uuid4(),
            layer=1,
            position=0,
            subject=Subject.MATH,
            question_ids=[question_ids[1]],
        ),
        GraphNode(
            id=uuid4(),
            layer=2,
            position=0,
            subject=Subject.MATH,
            question_ids=[question_ids[2]],
        ),
        GraphNode(
            id=uuid4(),
            layer=3,
            position=0,
            subject=Subject.MATH,
            question_ids=[question_ids[3]],
        ),
    ]
    nodes[1].connected_to = [nodes[0].id]
    nodes[2].connected_to = [nodes[1].id]
    nodes[3].connected_to = [nodes[2].id]
    graph = Graph(
        num_layers=4,
        nodes=nodes,
        subjects=[Subject.MATH],
    )
    battle = Battle(
        player_1_id=uuid4(),
        player_2_id=uuid4(),
        graph_id=graph.id,
        status=BattleStatus.IN_PROGRESS,
        node_states={node.id: BattleNodeState(node_id=node.id) for node in nodes},
    )
    questions = {question_id: _question(question_id) for question_id in question_ids}
    return battle, graph, questions


def test_players_can_only_advance_from_their_own_base_direction() -> None:
    battle, graph, questions = _linear_battle()
    engine = BattleEngine(battle, graph, questions)

    assert engine.select_node(0, graph.nodes[1].id) == graph.nodes[1]
    with pytest.raises(ValueError, match="not accessible"):
        engine.select_node(0, graph.nodes[2].id)

    battle.current_turn = 1
    assert engine.select_node(1, graph.nodes[2].id) == graph.nodes[2]


def test_answer_must_use_an_assigned_unused_question() -> None:
    battle, graph, questions = _linear_battle()
    target = graph.nodes[1]
    question_id = target.question_ids[0]
    battle.moves.append(
        BattleMove(
            battle_id=battle.id,
            player_index=1,
            node_id=target.id,
            question_id=question_id,
            chosen_answer="A",
            is_correct=True,
            response_time_ms=1000,
        )
    )
    engine = BattleEngine(battle, graph, questions)

    with pytest.raises(ValueError, match="already used"):
        engine.start_question(0, target.id, question_id, TURN_START)

    with pytest.raises(ValueError, match="not assigned"):
        engine.start_question(
            0,
            target.id,
            graph.nodes[2].question_ids[0],
            TURN_START,
        )


def test_exact_steal_tie_favors_defender() -> None:
    battle, graph, questions = _linear_battle()
    target = graph.nodes[1]
    battle.node_states[target.id].owner = 1
    battle.node_states[target.id].best_time_ms = 1000
    engine = BattleEngine(battle, graph, questions)
    engine.start_question(0, target.id, target.question_ids[0], TURN_START)

    result = engine.answer_question(
        0,
        target.id,
        target.question_ids[0],
        "a",
        TURN_START + timedelta(milliseconds=1000),
    )

    assert result.is_correct
    assert not result.node_stolen
    assert battle.node_states[target.id].owner == 1
    assert battle.node_states[target.id].best_time_ms == 1000
    assert battle.moves[-1].is_steal_attempt
    assert battle.moves[-1].steal_successful is False


def test_faster_correct_answer_steals_node() -> None:
    battle, graph, questions = _linear_battle()
    target = graph.nodes[1]
    battle.node_states[target.id].owner = 1
    battle.node_states[target.id].best_time_ms = 1000
    engine = BattleEngine(battle, graph, questions)
    engine.start_question(0, target.id, target.question_ids[0], TURN_START)

    result = engine.answer_question(
        0,
        target.id,
        target.question_ids[0],
        "A",
        TURN_START + timedelta(milliseconds=999),
    )

    assert result.node_stolen
    assert battle.node_states[target.id].owner == 0
    assert battle.node_states[target.id].best_time_ms == 999


def test_conquering_opponent_base_finishes_immediately() -> None:
    battle, graph, questions = _linear_battle()
    battle.node_states[graph.nodes[1].id].owner = 0
    battle.node_states[graph.nodes[2].id].owner = 0
    engine = BattleEngine(battle, graph, questions)
    target = graph.nodes[3]
    engine.start_question(0, target.id, target.question_ids[0], TURN_START)

    result = engine.answer_question(
        0,
        target.id,
        target.question_ids[0],
        "A",
        TURN_START + timedelta(milliseconds=750),
    )

    assert result.battle_finished
    assert result.winner_index == 0
    assert battle.status == BattleStatus.FINISHED
    assert battle.winner_id == battle.player_1_id


def test_start_assigns_bases_positions_and_authoritative_deadline() -> None:
    battle, graph, questions = _linear_battle()
    battle.status = BattleStatus.PENDING
    engine = BattleEngine(battle, graph, questions)

    engine.start_battle(TURN_START)

    assert battle.current_turn == 0
    assert battle.turn_number == 1
    assert battle.turn_started_at == TURN_START
    assert battle.turn_deadline_at == TURN_START + timedelta(seconds=30)
    assert battle.player_positions == {
        0: graph.nodes[0].id,
        1: graph.nodes[3].id,
    }
    assert battle.node_states[graph.nodes[0].id].owner == 0
    assert battle.node_states[graph.nodes[3].id].owner == 1


def test_answers_alternate_red_to_purple_to_red() -> None:
    battle, graph, questions = _linear_battle()
    engine = BattleEngine(battle, graph, questions)
    engine.ensure_turn_clock(TURN_START)

    red_target = graph.nodes[1]
    engine.start_question(0, red_target.id, red_target.question_ids[0], TURN_START)
    red_result = engine.answer_question(
        0,
        red_target.id,
        red_target.question_ids[0],
        "B",
        TURN_START + timedelta(milliseconds=600),
    )

    assert red_result.current_turn == 1
    assert red_result.turn_number == 2

    purple_started_at = TURN_START + timedelta(seconds=1)
    purple_target = graph.nodes[2]
    engine.start_question(
        1,
        purple_target.id,
        purple_target.question_ids[0],
        purple_started_at,
    )
    purple_result = engine.answer_question(
        1,
        purple_target.id,
        purple_target.question_ids[0],
        "A",
        purple_started_at + timedelta(milliseconds=450),
    )

    assert purple_result.current_turn == 0
    assert purple_result.turn_number == 3
    assert purple_result.response_time_ms == 450
    assert battle.player_positions[1] == purple_target.id


def test_expired_turn_clears_question_and_alternates_from_deadline() -> None:
    battle, graph, questions = _linear_battle()
    engine = BattleEngine(battle, graph, questions)
    engine.ensure_turn_clock(TURN_START)
    target = graph.nodes[1]
    engine.start_question(0, target.id, target.question_ids[0], TURN_START)

    expired_turns = engine.expire_turn_if_needed(
        TURN_START + timedelta(seconds=30)
    )

    assert expired_turns == 1
    assert battle.current_turn == 1
    assert battle.turn_number == 2
    assert battle.active_node_id is None
    assert battle.active_question_id is None
    assert battle.question_started_at is None
    assert battle.turn_started_at == TURN_START + timedelta(seconds=30)
    assert battle.turn_deadline_at == TURN_START + timedelta(seconds=60)
