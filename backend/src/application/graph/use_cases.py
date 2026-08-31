"""Use cases for graph generation."""

from src.domain.entities import Graph
from src.domain.enums import Subject
from src.domain.interfaces.repositories import GraphRepository
from src.domain.services.graph_builder import GraphBuilder, GraphConfig


class GenerateGraph:
    """Generate and persist a battle graph."""

    def __init__(self, graph_repo: GraphRepository) -> None:
        self.graph_repo = graph_repo

    async def execute(
        self,
        num_layers: int = 4,
        min_nodes_per_layer: int = 3,
        max_nodes_per_layer: int = 4,
        subjects: list[Subject] | None = None,
    ) -> Graph:
        config = GraphConfig(
            num_layers=num_layers,
            min_nodes_per_layer=min_nodes_per_layer,
            max_nodes_per_layer=max_nodes_per_layer,
            subjects=subjects or [Subject.MATH],
        )
        builder = GraphBuilder(config)
        graph = builder.build()
        if not builder.validate(graph):
            raise RuntimeError("Generated graph failed validation")
        return await self.graph_repo.create(graph)
