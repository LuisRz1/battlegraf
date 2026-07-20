"""Response schemas for battle endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from src.presentation.schemas.responses.graph_responses import GraphNodeResponse, GraphResponse


class BattleNodeStateResponse(BaseModel):
    node_id: str
    owner: int | None
    attempt_count: int
    best_time_ms: int | None


class BattleMoveResponse(BaseModel):
    id: str
    player_index: int
    node_id: str
    question_id: str
    chosen_answer: str
    is_correct: bool
    response_time_ms: int
    is_steal_attempt: bool
    steal_successful: bool | None


class BattleResponse(BaseModel):
    id: str
    player_1_id: str
    player_2_id: str
    graph_id: str
    status: str
    current_turn: int
    winner_id: str | None
    turn_timeout_seconds: int
    node_states: list[BattleNodeStateResponse]
    moves: list[BattleMoveResponse]
    created_at: datetime
    finished_at: datetime | None


class AnswerResultResponse(BaseModel):
    is_correct: bool
    node_conquered: bool
    node_stolen: bool
    battle_finished: bool
    winner_id: str | None
    current_turn: int
    message: str
