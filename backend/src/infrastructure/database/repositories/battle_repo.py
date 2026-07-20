"""SQLAlchemy implementations for battle, graph, and move repositories."""

import uuid
from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import Battle, BattleMove, BattleNodeState, Graph, GraphNode
from src.domain.enums import BattleStatus, Subject
from src.domain.interfaces.repositories import BattleMoveRepository, BattleRepository, GraphRepository
from src.infrastructure.database.models import (
    BattleModel,
    BattleMoveModel,
    BattleNodeStateModel,
    GraphModel,
    GraphNodeModel,
)


class SQLAlchemyGraphRepository(GraphRepository):
    """Repository for Graph entities."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: GraphModel) -> Graph:
        return Graph(
            id=model.id,
            num_layers=model.num_layers,
            min_nodes_per_layer=model.min_nodes_per_layer,
            max_nodes_per_layer=model.max_nodes_per_layer,
            subjects=[Subject(s) for s in model.subjects],
            nodes=[self._node_to_entity(n) for n in model.nodes],
            created_at=model.created_at,
        )

    def _node_to_entity(self, model: GraphNodeModel) -> GraphNode:
        return GraphNode(
            id=model.id,
            graph_id=model.graph_id,
            layer=model.layer,
            position=model.position,
            subject=Subject(model.subject),
            color=model.color,
            question_ids=[uuid.UUID(q) for q in model.question_ids],
            connected_to=[uuid.UUID(q) for q in model.connected_to],
        )

    async def create(self, graph: Graph) -> Graph:
        model = GraphModel(
            id=graph.id,
            num_layers=graph.num_layers,
            min_nodes_per_layer=graph.min_nodes_per_layer,
            max_nodes_per_layer=graph.max_nodes_per_layer,
            subjects=[s.value for s in graph.subjects],
        )
        self._session.add(model)
        await self._session.flush()

        for node in graph.nodes:
            node_model = GraphNodeModel(
                id=node.id,
                graph_id=model.id,
                layer=node.layer,
                position=node.position,
                subject=node.subject.value,
                color=node.color,
                question_ids=[str(q) for q in node.question_ids],
                connected_to=[str(q) for q in node.connected_to],
            )
            self._session.add(node_model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, graph_id: uuid.UUID) -> Graph | None:
        result = await self._session.execute(
            select(GraphModel).where(GraphModel.id == graph_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_all(self) -> Sequence[Graph]:
        result = await self._session.execute(select(GraphModel))
        return [self._to_entity(m) for m in result.scalars().all()]


class SQLAlchemyBattleRepository(BattleRepository):
    """Repository for Battle entities."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: BattleModel) -> Battle:
        return Battle(
            id=model.id,
            player_1_id=model.player_1_id,
            player_2_id=model.player_2_id,
            graph_id=model.graph_id,
            status=BattleStatus(model.status),
            current_turn=model.current_turn,
            winner_id=model.winner_id,
            node_states={s.node_id: self._node_state_to_entity(s) for s in model.node_states},
            turn_timeout_seconds=model.turn_timeout_seconds,
            created_at=model.created_at,
            finished_at=model.finished_at,
        )

    def _node_state_to_entity(self, model: BattleNodeStateModel) -> BattleNodeState:
        return BattleNodeState(
            node_id=model.node_id,
            owner=model.owner,
            attempt_count=model.attempt_count,
            best_time_ms=model.best_time_ms,
        )

    async def create(self, battle: Battle) -> Battle:
        model = BattleModel(
            id=battle.id,
            player_1_id=battle.player_1_id,
            player_2_id=battle.player_2_id,
            graph_id=battle.graph_id,
            status=battle.status.value,
            current_turn=battle.current_turn,
            winner_id=battle.winner_id,
            turn_timeout_seconds=battle.turn_timeout_seconds,
            created_at=battle.created_at,
            finished_at=battle.finished_at,
        )
        self._session.add(model)
        await self._session.flush()

        for node_state in battle.node_states.values():
            state_model = BattleNodeStateModel(
                battle_id=model.id,
                node_id=node_state.node_id,
                owner=node_state.owner,
                attempt_count=node_state.attempt_count,
                best_time_ms=node_state.best_time_ms,
            )
            self._session.add(state_model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, battle_id: uuid.UUID) -> Battle | None:
        result = await self._session.execute(
            select(BattleModel).where(BattleModel.id == battle_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def update(self, battle: Battle) -> Battle:
        result = await self._session.execute(
            select(BattleModel).where(BattleModel.id == battle.id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("Battle not found")
        model.status = battle.status.value
        model.current_turn = battle.current_turn
        model.winner_id = battle.winner_id
        model.finished_at = battle.finished_at
        await self._session.flush()

        for node_state in battle.node_states.values():
            existing = await self._session.get(BattleNodeStateModel, (model.id, node_state.node_id))
            if existing:
                existing.owner = node_state.owner
                existing.attempt_count = node_state.attempt_count
                existing.best_time_ms = node_state.best_time_ms
            else:
                new_state = BattleNodeStateModel(
                    battle_id=model.id,
                    node_id=node_state.node_id,
                    owner=node_state.owner,
                    attempt_count=node_state.attempt_count,
                    best_time_ms=node_state.best_time_ms,
                )
                self._session.add(new_state)
        await self._session.flush()
        return self._to_entity(model)

    async def list_by_player(self, player_id: uuid.UUID) -> Sequence[Battle]:
        result = await self._session.execute(
            select(BattleModel)
            .where(
                (BattleModel.player_1_id == player_id)
                | (BattleModel.player_2_id == player_id)
            )
            .order_by(BattleModel.created_at.desc())
        )
        return [self._to_entity(m) for m in result.scalars().all()]


class SQLAlchemyBattleMoveRepository(BattleMoveRepository):
    """Repository for BattleMove entities."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: BattleMoveModel) -> BattleMove:
        return BattleMove(
            id=model.id,
            battle_id=model.battle_id,
            player_index=model.player_index,
            node_id=model.node_id,
            question_id=model.question_id,
            chosen_answer=model.chosen_answer,
            is_correct=model.is_correct,
            response_time_ms=model.response_time_ms,
            is_steal_attempt=model.is_steal_attempt,
            steal_successful=model.steal_successful,
            created_at=model.created_at,
        )

    async def create(self, move: BattleMove) -> BattleMove:
        model = BattleMoveModel(
            id=move.id,
            battle_id=move.battle_id,
            player_index=move.player_index,
            node_id=move.node_id,
            question_id=move.question_id,
            chosen_answer=move.chosen_answer,
            is_correct=move.is_correct,
            response_time_ms=move.response_time_ms,
            is_steal_attempt=move.is_steal_attempt,
            steal_successful=move.steal_successful,
            created_at=move.created_at,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def list_by_battle(self, battle_id: uuid.UUID) -> Sequence[BattleMove]:
        result = await self._session.execute(
            select(BattleMoveModel).where(BattleMoveModel.battle_id == battle_id)
        )
        return [self._to_entity(m) for m in result.scalars().all()]
