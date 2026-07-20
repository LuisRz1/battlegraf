"""ORM models for battles, graphs, and battle moves."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, UUIDMixin


class GraphModel(Base, UUIDMixin):
    """A generated battle graph."""

    __tablename__ = "graphs"

    num_layers: Mapped[int] = mapped_column(Integer, nullable=False)
    min_nodes_per_layer: Mapped[int] = mapped_column(Integer, nullable=False)
    max_nodes_per_layer: Mapped[int] = mapped_column(Integer, nullable=False)
    subjects: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)

    nodes: Mapped[list["GraphNodeModel"]] = relationship("GraphNodeModel", back_populates="graph", lazy="selectin", cascade="all, delete-orphan")


class GraphNodeModel(Base, UUIDMixin):
    """A node in a battle graph."""

    __tablename__ = "graph_nodes"

    graph_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("graphs.id"), nullable=False)
    layer: Mapped[int] = mapped_column(Integer, nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    subject: Mapped[str] = mapped_column(String(50), nullable=False)
    color: Mapped[str] = mapped_column(String(7), nullable=False)
    question_ids: Mapped[list[uuid.UUID]] = mapped_column(JSON, default=list, nullable=False)
    connected_to: Mapped[list[uuid.UUID]] = mapped_column(JSON, default=list, nullable=False)

    graph: Mapped[GraphModel] = relationship("GraphModel", back_populates="nodes")


class BattleModel(Base, UUIDMixin):
    """A battle between two players or sections."""

    __tablename__ = "battles"

    player_1_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    player_2_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    graph_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("graphs.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False)
    current_turn: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    winner_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    turn_timeout_seconds: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_section_battle: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    node_states: Mapped[list["BattleNodeStateModel"]] = relationship("BattleNodeStateModel", back_populates="battle", lazy="selectin", cascade="all, delete-orphan")


class BattleNodeStateModel(Base):
    """State of a node during a battle."""

    __tablename__ = "battle_node_states"

    battle_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("battles.id"), primary_key=True)
    node_id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    owner: Mapped[int | None] = mapped_column(Integer, nullable=True)
    attempt_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    best_time_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)

    battle: Mapped[BattleModel] = relationship("BattleModel", back_populates="node_states")


class BattleMoveModel(Base, UUIDMixin):
    """A single move/action inside a battle."""

    __tablename__ = "battle_moves"

    battle_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("battles.id"), nullable=False)
    player_index: Mapped[int] = mapped_column(Integer, nullable=False)
    node_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("graph_nodes.id"), nullable=False)
    question_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("questions.id"), nullable=False)
    chosen_answer: Mapped[str] = mapped_column(String(1), nullable=False)
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    response_time_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    is_steal_attempt: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    steal_successful: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
