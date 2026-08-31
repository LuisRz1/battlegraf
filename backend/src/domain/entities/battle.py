"""Entidades de dominio para batallas y grafos."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID, uuid4

from ..enums import BattleStatus, Subject


@dataclass
class GraphNode:
    """Nodo del grafo de batalla. Pertenece a una capa y tiene una materia."""

    id: UUID = field(default_factory=uuid4)
    graph_id: UUID = field(default_factory=uuid4)
    layer: int = 0
    position: int = 0
    subject: Subject = Subject.MATH
    color: str = "#FF4444"
    question_ids: list[UUID] = field(default_factory=list)
    connected_to: list[UUID] = field(default_factory=list)


@dataclass
class Graph:
    """Grafo completo de batalla: capas + nodos + conexiones."""

    id: UUID = field(default_factory=uuid4)
    num_layers: int = 4
    min_nodes_per_layer: int = 3
    max_nodes_per_layer: int = 4
    nodes: list[GraphNode] = field(default_factory=list)
    subjects: list[Subject] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)

    def get_start_node(self, player_index: int) -> GraphNode | None:
        """Retorna el nodo inicial de un jugador (capa 0 o capa N-1)."""
        layer = 0 if player_index == 0 else self.num_layers - 1
        for node in self.nodes:
            if node.layer == layer:
                return node
        return None

    def get_neighbors(self, node_id: UUID) -> set[UUID]:
        """Return adjacent nodes regardless of the player's direction."""
        node = next((item for item in self.nodes if item.id == node_id), None)
        if node is None:
            return set()
        neighbors = set(node.connected_to)
        neighbors.update(item.id for item in self.nodes if node_id in item.connected_to)
        return neighbors


@dataclass
class BattleNodeState:
    """Estado de un nodo durante una batalla."""

    node_id: UUID = field(default_factory=uuid4)
    owner: int | None = None  # 0 = player 1, 1 = player 2, None = libre
    attempt_count: int = 0
    best_time_ms: int | None = None  # Tiempo del propietario actual


@dataclass
class BattleMove:
    """Un movimiento dentro de una batalla."""

    id: UUID = field(default_factory=uuid4)
    battle_id: UUID = field(default_factory=uuid4)
    player_index: int = 0
    node_id: UUID = field(default_factory=uuid4)
    question_id: UUID = field(default_factory=uuid4)
    chosen_answer: str = ""
    is_correct: bool = False
    response_time_ms: int = 0
    is_steal_attempt: bool = False
    steal_successful: bool | None = None
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class Battle:
    """Batalla entre dos jugadores."""

    id: UUID = field(default_factory=uuid4)
    player_1_id: UUID = field(default_factory=uuid4)
    player_2_id: UUID = field(default_factory=uuid4)
    graph_id: UUID = field(default_factory=uuid4)
    status: BattleStatus = BattleStatus.PENDING
    current_turn: int = 0
    turn_number: int = 1
    winner_id: UUID | None = None
    node_states: dict[UUID, BattleNodeState] = field(default_factory=dict)
    player_positions: dict[int, UUID] = field(default_factory=dict)
    turn_timeout_seconds: int = 30
    turn_started_at: datetime | None = None
    turn_deadline_at: datetime | None = None
    active_node_id: UUID | None = None
    active_question_id: UUID | None = None
    question_started_at: datetime | None = None
    moves: list[BattleMove] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)
    finished_at: datetime | None = None
