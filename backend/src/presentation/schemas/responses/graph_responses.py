"""Response schemas for graph endpoints."""

from datetime import datetime

from pydantic import BaseModel


class GraphNodeResponse(BaseModel):
    id: str
    layer: int
    position: int
    subject: str
    color: str
    question_ids: list[str]
    connected_to: list[str]


class GraphResponse(BaseModel):
    id: str
    num_layers: int
    min_nodes_per_layer: int
    max_nodes_per_layer: int
    subjects: list[str]
    nodes: list[GraphNodeResponse]
    created_at: datetime
