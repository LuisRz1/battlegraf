"""Unit tests for graph generation invariants."""

import pytest

from src.domain.enums import Subject
from src.domain.services.graph_builder import GraphBuilder, GraphConfig


def test_graph_has_exactly_two_single_node_base_layers() -> None:
    builder = GraphBuilder(
        GraphConfig(
            num_layers=6,
            min_nodes_per_layer=3,
            max_nodes_per_layer=4,
            subjects=[Subject.MATH, Subject.LANGUAGE],
            seed=7,
        )
    )

    graph = builder.build()

    assert builder.validate(graph)
    assert len([node for node in graph.nodes if node.layer == 0]) == 1
    assert len([node for node in graph.nodes if node.layer == 5]) == 1
    for layer in range(1, 5):
        assert 3 <= len([node for node in graph.nodes if node.layer == layer]) <= 4


def test_seed_is_deterministic_without_mutating_global_random_state() -> None:
    config = GraphConfig(num_layers=4, seed=21)

    first = GraphBuilder(config).build()
    second = GraphBuilder(config).build()

    first_shape = [
        (node.layer, node.position, node.subject, len(node.connected_to))
        for node in first.nodes
    ]
    second_shape = [
        (node.layer, node.position, node.subject, len(node.connected_to))
        for node in second.nodes
    ]
    assert first_shape == second_shape


@pytest.mark.parametrize(
    "config",
    [
        GraphConfig(num_layers=3),
        GraphConfig(min_nodes_per_layer=0),
        GraphConfig(min_nodes_per_layer=5, max_nodes_per_layer=4),
        GraphConfig(subjects=[Subject.MATH, Subject.MATH]),
    ],
)
def test_invalid_graph_configuration_is_rejected(config: GraphConfig) -> None:
    with pytest.raises(ValueError):
        GraphBuilder(config)
