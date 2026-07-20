"""Battle engine with turns, conquest, node stealing, and victory conditions."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from src.domain.entities import Battle, BattleMove, BattleNodeState, Graph, GraphNode, Question
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
    message: str


class BattleEngine:
    """Core rules for battle progression."""

    def __init__(self, battle: Battle, graph: Graph, questions: dict[UUID, Question]) -> None:
        self.battle = battle
        self.graph = graph
        self.questions = questions
        self._ensure_node_states()

    def _ensure_node_states(self) -> None:
        """Create initial node states for all graph nodes if missing."""
        for node in self.graph.nodes:
            if node.id not in self.battle.node_states:
                self.battle.node_states[node.id] = BattleNodeState(node_id=node.id)

    def start_battle(self) -> None:
        """Initialize battle state and set first turn."""
        if self.battle.status != BattleStatus.PENDING:
            raise ValueError("Battle is not pending")
        self.battle.status = BattleStatus.IN_PROGRESS
        self.battle.current_turn = 0
        self._set_initial_positions()

    def _set_initial_positions(self) -> None:
        """Place players at their starting nodes without conquering them."""
        for player_index in (0, 1):
            start = self.graph.get_start_node(player_index)
            if start:
                self.battle.player_positions[player_index] = start.id

    def select_node(self, player_index: int, node_id: UUID) -> GraphNode:
        """Validate and return a node the player can attack."""
        self._validate_turn(player_index)
        node = self._get_node(node_id)
        if not self._is_node_accessible(player_index, node):
            raise ValueError("Node is not accessible")
        return node

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
        """A node is accessible if connected to a conquered or starting node."""
        if node.layer == 0 and player_index == 0:
            return True
        last_layer = self.graph.num_layers - 1
        if node.layer == last_layer and player_index == 1:
            return True
        conquered = self._get_conquered_nodes(player_index)
        current_position = self.battle.player_positions.get(player_index)
        if current_position:
            conquered = conquered | {current_position}
        return any(conn_id in conquered for conn_id in node.connected_to)

    def answer_question(
        self,
        player_index: int,
        node_id: UUID,
        question_id: UUID,
        chosen_answer: str,
        response_time_ms: int,
    ) -> AnswerResult:
        """Process an answer and update battle state."""
        self._validate_turn(player_index)
        node = self._get_node(node_id)
        question = self.questions.get(question_id)
        if not question:
            raise ValueError("Question not found")

        is_correct = question.check_answer(chosen_answer)
        state = self.battle.node_states[node_id]
        state.attempt_count += 1
        if is_correct:
            if state.best_time_ms is None or response_time_ms < state.best_time_ms:
                state.best_time_ms = response_time_ms

        node_conquered = False
        node_stolen = False
        if is_correct:
            if state.owner is None:
                state.owner = player_index
                node_conquered = True
            elif state.owner != player_index:
                # Steal if new answer is faster than previous best time
                if state.best_time_ms is not None and response_time_ms <= state.best_time_ms:
                    state.owner = player_index
                    node_stolen = True
                else:
                    is_correct = False
            else:
                node_conquered = False

        self._record_move(
            player_index=player_index,
            node_id=node_id,
            question_id=question_id,
            chosen_answer=chosen_answer,
            is_correct=is_correct,
            response_time_ms=response_time_ms,
            is_steal_attempt=state.owner != player_index and not is_correct,
            steal_successful=node_stolen,
        )

        winner_index = self._check_victory()
        if winner_index is not None:
            self.battle.status = BattleStatus.FINISHED
            self.battle.finished_at = datetime.now(timezone.utc)
            self.battle.winner_id = self._player_id_by_index(winner_index)
        else:
            self._advance_turn()

        return AnswerResult(
            is_correct=is_correct,
            node_conquered=node_conquered,
            node_stolen=node_stolen,
            battle_finished=self.battle.status == BattleStatus.FINISHED,
            winner_index=winner_index,
            current_turn=self.battle.current_turn,
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
        steal_successful: bool,
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

    def _advance_turn(self) -> None:
        self.battle.current_turn = 1 - self.battle.current_turn

    def _check_victory(self) -> int | None:
        """Victory when a player conquers the opponent's starting node or majority of nodes."""
        total_nodes = len(self.graph.nodes)
        if total_nodes == 0:
            return None

        target_node = self.graph.get_start_node(1)
        if target_node and self.battle.node_states.get(target_node.id, BattleNodeState()).owner == 0:
            return 0
        target_node = self.graph.get_start_node(0)
        if target_node and self.battle.node_states.get(target_node.id, BattleNodeState()).owner == 1:
            return 1

        counts = [0, 0]
        for state in self.battle.node_states.values():
            if state.owner in (0, 1):
                counts[state.owner] += 1
        majority = (total_nodes // 2) + 1
        if counts[0] >= majority:
            return 0
        if counts[1] >= majority:
            return 1
        return None

    def _build_message(self, is_correct: bool, node_conquered: bool, node_stolen: bool) -> str:
        if not is_correct:
            return "Respuesta incorrecta"
        if node_stolen:
            return "Nodo robado con mejor tiempo"
        if node_conquered:
            return "Nodo conquistado"
        return "Respuesta correcta"
