"""Request schemas for battle endpoints."""

from pydantic import BaseModel, Field

from src.domain.enums import Subject


class CreateBattleRequest(BaseModel):
    player_1_id: str
    player_2_id: str
    graph_id: str | None = None
    num_layers: int = Field(default=4, ge=4, le=10)
    min_nodes_per_layer: int = Field(default=3, ge=1, le=6)
    max_nodes_per_layer: int = Field(default=4, ge=1, le=8)
    subjects: list[Subject] = Field(default_factory=lambda: [Subject.MATH])


class StartBattleRequest(BaseModel):
    pass


class SubmitAnswerRequest(BaseModel):
    node_id: str
    question_id: str
    chosen_answer: str = Field(min_length=1, max_length=1)
    # Kept temporarily for backward compatibility with existing mobile clients.
    # The server deliberately ignores this untrusted value.
    response_time_ms: int | None = Field(default=None, ge=0)


class SelectNodeRequest(BaseModel):
    node_id: str
