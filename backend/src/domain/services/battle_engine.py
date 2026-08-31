"""Battle engine with turns, conquest, node stealing, and victory conditions."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

from src.domain.entities import (
    Battle,
    BattleMove,
    BattleNodeState,
    Graph,
    GraphNode,
    Question,
)
from src.domain.enums import BattleStatus


@dataclass
class AnswerResult:
    """Result of a player answering a question."""

    is_correct: bool
    node_conquered: bool
    node_stolen: bool
    battle_finished: bool
    winner_index: int | None
    current_turn: int
    turn_number: int
    response_time_ms: int
    message: str


class BattleEngine:
    """Core rules for battle progression."""

    def __init__(
        self, battle: Battle, graph: Graph, questions: dict[UUID, Question]
    ) -> None:
        self.battle = battle
        self.graph = graph
        self.questions = questions
        self._ensure_node_states()
        if self.battle.status == BattleStatus.IN_PROGRESS:
            self._set_initial_positions()

    def _ensure_node_states(self) -> None:
        """Create initial node states for all graph nodes if missing."""
        for node in self.graph.nodes:
            if node.id not in self.battle.node_states:
                self.battle.node_states[node.id] = BattleNodeState(node_id=node.id)

    def start_battle(self, started_at: datetime | None = None) -> None:
        """Initialize battle state and set first turn."""
        if self.battle.status != BattleStatus.PENDING:
            raise ValueError("Battle is not pending")
        self.battle.status = BattleStatus.IN_PROGRESS
        self.battle.current_turn = 0
        self.battle.turn_number = 1
        self._set_initial_positions()
        self._start_turn_clock(started_at or datetime.now(UTC))

    def _set_initial_positions(self) -> None:
        """Place players at and assign ownership of their starting bases."""
        for player_index in (0, 1):
            start = self.graph.get_start_node(player_index)
            if start:
                self.battle.player_positions.setdefault(player_index, start.id)
                state = self.battle.node_states[start.id]
                if state.owner is None:
                    state.owner = player_index

    def _start_turn_clock(self, started_at: datetime) -> None:
        started_at = self._as_utc(started_at)
        timeout = max(1, self.battle.turn_timeout_seconds)
        self.battle.turn_started_at = started_at
        self.battle.turn_deadline_at = started_at + timedelta(seconds=timeout)
        self._clear_active_question()

    def ensure_turn_clock(self, started_at: datetime | None = None) -> bool:
        """Initialize the clock for a legacy in-progress battle if it is missing."""
        if (
            self.battle.status != BattleStatus.IN_PROGRESS
            or self.battle.turn_deadline_at is not None
        ):
            return False
        self._start_turn_clock(started_at or datetime.now(UTC))
        return True

    def _clear_active_question(self) -> None:
        self.battle.active_node_id = None
        self.battle.active_question_id = None
        self.battle.question_started_at = None

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)

    def expire_turn_if_needed(self, checked_at: datetime | None = None) -> int:
        """Advance every elapsed turn window and return the number expired."""
        if (
            self.battle.status != BattleStatus.IN_PROGRESS
            or self.battle.turn_deadline_at is None
        ):
            return 0

        now = self._as_utc(checked_at or datetime.now(UTC))
        deadline = self._as_utc(self.battle.turn_deadline_at)
        if now < deadline:
            return 0

        timeout = max(1, self.battle.turn_timeout_seconds)
        elapsed_seconds = max(0.0, (now - deadline).total_seconds())
        expired_turns = int(elapsed_seconds // timeout) + 1
        if expired_turns % 2:
            self.battle.current_turn = 1 - self.battle.current_turn
        self.battle.turn_number += expired_turns
        self.battle.turn_started_at = deadline + timedelta(
            seconds=timeout * (expired_turns - 1)
        )
        self.battle.turn_deadline_at = deadline + timedelta(
            seconds=timeout * expired_turns
        )
        self._clear_active_question()
        return expired_turns

    def select_node(self, player_index: int, node_id: UUID) -> GraphNode:
        """Validate and return a node the player can attack."""
        self._validate_turn(player_index)
        node = self._get_node(node_id)
        if not self._is_node_accessible(player_index, node):
            raise ValueError("Node is not accessible")
        return node

    def start_question(
        self,
        player_index: int,
        node_id: UUID,
        question_id: UUID,
        started_at: datetime | None = None,
    ) -> Question:
        """Persist the one server-timed question active for the current turn."""
        now = self._as_utc(started_at or datetime.now(UTC))
        if self.expire_turn_if_needed(now):
            raise ValueError("Turn expired before selecting a question")
        node = self.select_node(player_index, node_id)
        if question_id not in node.question_ids:
            raise ValueError("Question is not assigned to this node")
        if any(
            move.node_id == node_id and move.question_id == question_id
            for move in self.battle.moves
        ):
            raise ValueError("Question was already used on this node")
        question = self.questions.get(question_id)
        if question is None:
            raise ValueError("Question not found")

        if self.battle.active_question_id is not None:
            if (
                self.battle.active_node_id == node_id
                and self.battle.active_question_id == question_id
            ):
                return question
            raise ValueError("A question is already active for this turn")

        self.battle.active_node_id = node_id
        self.battle.active_question_id = question_id
        self.battle.question_started_at = now
        return question

    def _validate_turn(self, player_index: int) -> None:
        if self.battle.status != BattleStatus.IN_PROGRESS:
            raise ValueError("Battle is not in progress")
        if self.battle.current_turn != player_index:
            raise ValueError("Not your turn")

    def _get_node(self, node_id: UUID) -> GraphNode:
        for node in self.graph.nodes:
            if node.id == node_id:
                return node
        raise ValueError("Node not found")

    def _get_conquered_nodes(self, player_index: int) -> set[UUID]:
        return {
            node_id
            for node_id, state in self.battle.node_states.items()
            if state.owner == player_index
        }

    def _is_node_accessible(self, player_index: int, node: GraphNode) -> bool:
        """A target must extend a continuous route from the player's base."""
        state = self.battle.node_states[node.id]
        if state.owner == player_index:
            return False

        territory = self._get_connected_territory(player_index)
        if not territory:
            return False

        nodes_by_id = {item.id: item for item in self.graph.nodes}
        for neighbor_id in self.graph.get_neighbors(node.id) & territory:
            neighbor = nodes_by_id[neighbor_id]
            if player_index == 0 and neighbor.layer < node.layer:
                return True
            if player_index == 1 and neighbor.layer > node.layer:
                return True
        return False

    def _get_connected_territory(self, player_index: int) -> set[UUID]:
        """Owned territory that remains connected to the player's base."""
        base = self.graph.get_start_node(player_index)
        if base is None:
            return set()

        connected = {base.id}
        pending = [base.id]
        while pending:
            current = pending.pop()
            for neighbor_id in self.graph.get_neighbors(current):
                state = self.battle.node_states.get(neighbor_id)
                if (
                    neighbor_id not in connected
                    and state is not None
                    and state.owner == player_index
                ):
                    connected.add(neighbor_id)
                    pending.append(neighbor_id)
        return connected

    def answer_question(
        self,
        player_index: int,
        node_id: UUID,
        question_id: UUID,
        chosen_answer: str,
        answered_at: datetime | None = None,
    ) -> AnswerResult:
        """Process an answer and update battle state."""
        now = self._as_utc(answered_at or datetime.now(UTC))
        if self.expire_turn_if_needed(now):
            raise ValueError("Turn expired before the answer was received")
        self._validate_turn(player_index)
        if (
            self.battle.active_node_id != node_id
            or self.battle.active_question_id != question_id
            or self.battle.question_started_at is None
        ):
            raise ValueError("Question is not active for this turn")
        node = self._get_node(node_id)
        if not self._is_node_accessible(player_index, node):
            raise ValueError("Node is not accessible")
        if question_id not in node.question_ids:
            raise ValueError("Question is not assigned to this node")
        if any(
            move.node_id == node_id and move.question_id == question_id
            for move in self.battle.moves
        ):
            raise ValueError("Question was already used on this node")
        question = self.questions.get(question_id)
        if not question:
            raise ValueError("Question not found")
        normalized_answer = chosen_answer.strip().upper()
        if normalized_answer not in {"A", "B", "C", "D"}:
            raise ValueError("Answer must be A, B, C, or D")
        question_started_at = self._as_utc(self.battle.question_started_at)
        response_time_ms = max(
            0,
            int((now - question_started_at).total_seconds() * 1000),
        )

        is_correct = question.check_answer(normalized_answer)
        state = self.battle.node_states[node_id]
        original_owner = state.owner
        state.attempt_count += 1

        node_conquered = False
        node_stolen = False
        if is_correct:
            if original_owner is None:
                state.owner = player_index
                state.best_time_ms = response_time_ms
                node_conquered = True
            elif original_owner != player_index:
                # Exact ties favor the defender.
                if state.best_time_ms is None or response_time_ms < state.best_time_ms:
                    state.owner = player_index
                    state.best_time_ms = response_time_ms
                    node_stolen = True

        if node_conquered or node_stolen:
            self.battle.player_positions[player_index] = node_id

        self._record_move(
            player_index=player_index,
            node_id=node_id,
            question_id=question_id,
            chosen_answer=normalized_answer,
            is_correct=is_correct,
            response_time_ms=response_time_ms,
            is_steal_attempt=original_owner not in (None, player_index),
            steal_successful=(
                node_stolen if original_owner not in (None, player_index) else None
            ),
        )

        winner_index = self._check_victory()
        if winner_index is not None:
            self.battle.status = BattleStatus.FINISHED
            self.battle.finished_at = now
            self.battle.winner_id = self._player_id_by_index(winner_index)
            self.battle.turn_deadline_at = None
            self._clear_active_question()
        else:
            self._advance_turn(now)

        return AnswerResult(
            is_correct=is_correct,
            node_conquered=node_conquered,
            node_stolen=node_stolen,
            battle_finished=self.battle.status == BattleStatus.FINISHED,
            winner_index=winner_index,
            current_turn=self.battle.current_turn,
            turn_number=self.battle.turn_number,
            response_time_ms=response_time_ms,
            message=self._build_message(is_correct, node_conquered, node_stolen),
        )

    def _player_id_by_index(self, player_index: int) -> UUID:
        return self.battle.player_1_id if player_index == 0 else self.battle.player_2_id

    def _record_move(
        self,
        player_index: int,
        node_id: UUID,
        question_id: UUID,
        chosen_answer: str,
        is_correct: bool,
        response_time_ms: int,
        is_steal_attempt: bool,
        steal_successful: bool | None,
    ) -> None:
        move = BattleMove(
            battle_id=self.battle.id,
            player_index=player_index,
            node_id=node_id,
            question_id=question_id,
            chosen_answer=chosen_answer,
            is_correct=is_correct,
            response_time_ms=response_time_ms,
            is_steal_attempt=is_steal_attempt,
            steal_successful=steal_successful,
        )
        self.battle.moves.append(move)

    def _advance_turn(self, started_at: datetime | None = None) -> None:
        self.battle.current_turn = 1 - self.battle.current_turn
        self.battle.turn_number += 1
        self._start_turn_clock(started_at or datetime.now(UTC))

    def _check_victory(self) -> int | None:
        """Victory occurs immediately after conquering the opponent's base."""
        target_node = self.graph.get_start_node(1)
        if (
            target_node
            and self.battle.node_states.get(target_node.id, BattleNodeState()).owner
            == 0
        ):
            return 0
        target_node = self.graph.get_start_node(0)
        if (
            target_node
            and self.battle.node_states.get(target_node.id, BattleNodeState()).owner
            == 1
        ):
            return 1

        return None

    def _build_message(
        self, is_correct: bool, node_conquered: bool, node_stolen: bool
    ) -> str:
        if not is_correct:
            return "Respuesta incorrecta"
        if node_stolen:
            return "Nodo robado con mejor tiempo"
        if node_conquered:
            return "Nodo conquistado"
        return "Respuesta correcta; el defensor conserva el nodo"
