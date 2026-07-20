"""Entidades de dominio para batallas y grafos."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
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

    def get_start_node(self, player_index: int) -> Optional[GraphNode]:
        """Retorna el nodo inicial de un jugador (capa 0 o capa N-1)."""
        layer = 0 if player_index == 0 else self.num_layers - 1
        for node in self.nodes:
            if node.layer == layer:
                return node
        return None

    def get_accessible_nodes(self, from_node_id: UUID, conquered_node_ids: set[UUID]) -> list[GraphNode]:
        """Nodos accesibles desde una posicion actual + nodos conquistados."""
        reachable = set(conquered_node_ids) | {from_node_id}
        accessible = []
        for node in self.nodes:
            if node.id in reachable:
                continue
            # El nodo debe estar conectado a algun nodo conquistado en la capa anterior
            if any(conn_id in reachable for conn_id in node.connected_to):
                accessible.append(node)
        return accessible


@dataclass
class BattleNodeState:
    """Estado de un nodo durante una batalla."""

    node_id: UUID = field(default_factory=uuid4)
    owner: Optional[int] = None  # 0 = player 1, 1 = player 2, None = libre
    attempt_count: int = 0
    best_time_ms: Optional[int] = None  # Tiempo mas rapido (para robo)


@dataclass
class Battle:
    """Batalla entre dos jugadores."""

    id: UUID = field(default_factory=uuid4)
    player_1_id: UUID = field(default_factory=uuid4)
    player_2_id: UUID = field(default_factory=uuid4)
    graph_id: UUID = field(default_factory=uuid4)
    status: BattleStatus = BattleStatus.PENDING
    current_turn: int = 0
    winner_id: Optional[UUID] = None
    node_states: dict[UUID, BattleNodeState] = field(default_factory=dict)
    player_positions: dict[int, UUID] = field(default_factory=dict)
    turn_timeout_seconds: int = 30
    moves: list[BattleMove] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)
    finished_at: Optional[datetime] = None


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
    steal_successful: Optional[bool] = None
    created_at: datetime = field(default_factory=datetime.utcnow)
