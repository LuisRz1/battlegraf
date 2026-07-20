"""Request schemas for battle endpoints."""

from pydantic import BaseModel


class CreateBattleRequest(BaseModel):
    player_1_id: str
    player_2_id: str
    graph_id: str | None = None


class StartBattleRequest(BaseModel):
    pass


class SubmitAnswerRequest(BaseModel):
    node_id: str
    question_id: str
    chosen_answer: str
    response_time_ms: int


class SelectNodeRequest(BaseModel):
    node_id: str
