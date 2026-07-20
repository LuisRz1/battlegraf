"""Request schemas for graph endpoints."""

from pydantic import BaseModel, Field

from src.domain.enums import Subject


class GenerateGraphRequest(BaseModel):
    num_layers: int = Field(default=4, ge=3, le=10)
    min_nodes_per_layer: int = Field(default=3, ge=1, le=6)
    max_nodes_per_layer: int = Field(default=4, ge=1, le=8)
    subjects: list[Subject] = [Subject.MATH]
