"""Graph builder with forced-path validation."""

from __future__ import annotations

import random
import uuid
from dataclasses import dataclass
from uuid import UUID

from src.domain.entities import Graph, GraphNode
from src.domain.enums import Subject


@dataclass
class GraphConfig:
    """Configuration for graph generation."""

    num_layers: int = 4
    min_nodes_per_layer: int = 3
    max_nodes_per_layer: int = 4
    subjects: list[Subject] | None = None
    seed: int | None = None


class GraphBuilder:
    """Builds a directed acyclic battle graph with forced paths."""

    def __init__(self, config: GraphConfig | None = None) -> None:
        self.config = config or GraphConfig()
        if self.config.seed is not None:
            random.seed(self.config.seed)

    def build(self) -> Graph:
        """Generate a graph with valid forward-only forced paths."""
        subjects = self.config.subjects or [Subject.MATH]
        nodes: list[GraphNode] = []
        layers: list[list[GraphNode]] = []

        for layer_idx in range(self.config.num_layers):
            layer_size = random.randint(
                self.config.min_nodes_per_layer, self.config.max_nodes_per_layer
            )
            layer_nodes: list[GraphNode] = []
            for pos in range(layer_size):
                subject = subjects[(layer_idx + pos) % len(subjects)]
                node = GraphNode(
                    id=uuid.uuid4(),
                    layer=layer_idx,
                    position=pos,
                    subject=subject,
                    color=subject.default_color,
                )
                layer_nodes.append(node)
                nodes.append(node)
            layers.append(layer_nodes)

        self._wire_layers(layers)
        self._ensure_forced_paths(layers)

        return Graph(
            num_layers=self.config.num_layers,
            min_nodes_per_layer=self.config.min_nodes_per_layer,
            max_nodes_per_layer=self.config.max_nodes_per_layer,
            subjects=subjects,
            nodes=nodes,
        )

    def _wire_layers(self, layers: list[list[GraphNode]]) -> None:
        """Connect each node to at least one node in the previous layer."""
        for layer_idx in range(1, len(layers)):
            previous_layer = layers[layer_idx - 1]
            current_layer = layers[layer_idx]
            for node in current_layer:
                # Each node connects to 1-2 random previous nodes
                connections = random.sample(
                    previous_layer, k=min(random.randint(1, 2), len(previous_layer))
                )
                node.connected_to = [n.id for n in connections]

    def _ensure_forced_paths(self, layers: list[list[GraphNode]]) -> None:
        """Guarantee at least one forced path from layer 0 to the last layer."""
        for layer_idx in range(1, len(layers)):
            previous_layer = layers[layer_idx - 1]
            current_layer = layers[layer_idx]
            # Ensure every previous node connects forward to at least one current node
            previous_ids = {n.id for n in previous_layer}
            for prev_node in previous_layer:
                targets = [n for n in current_layer if prev_node.id in n.connected_to]
                if not targets:
                    target = random.choice(current_layer)
                    target.connected_to.append(prev_node.id)
                    target.connected_to = list(set(target.connected_to))

            # Ensure every current node has a predecessor
            for node in current_layer:
                if not any(conn_id in previous_ids for conn_id in node.connected_to):
                    predecessor = random.choice(previous_layer)
                    node.connected_to.append(predecessor.id)
                    node.connected_to = list(set(node.connected_to))

    def validate(self, graph: Graph) -> bool:
        """Validate that all nodes are reachable via forced paths."""
        if not graph.nodes:
            return False

        layer_map: dict[int, list[GraphNode]] = {}
        for node in graph.nodes:
            layer_map.setdefault(node.layer, []).append(node)

        for layer_idx in range(1, graph.num_layers):
            previous_layer = layer_map.get(layer_idx - 1, [])
            current_layer = layer_map.get(layer_idx, [])
            previous_ids = {n.id for n in previous_layer}
            for node in current_layer:
                if not any(conn_id in previous_ids for conn_id in node.connected_to):
                    return False
            for prev_node in previous_layer:
                if not any(prev_node.id in n.connected_to for n in current_layer):
                    return False
        return True
