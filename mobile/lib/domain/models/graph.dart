import 'node.dart';

/// A graph board made of layered nodes.
class Graph {
  final List<Node> nodes;
  final List<GraphEdge> edges;
  final int layerCount;

  const Graph({
    required this.nodes,
    required this.edges,
    this.layerCount = 3,
  });

  factory Graph.fromJson(Map<String, dynamic> json) {
    return Graph(
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List<dynamic>?)
              ?.map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      layerCount: json['layer_count'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
      'layer_count': layerCount,
    };
  }

  Graph copyWith({
    List<Node>? nodes,
    List<GraphEdge>? edges,
    int? layerCount,
  }) {
    return Graph(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      layerCount: layerCount ?? this.layerCount,
    );
  }
}

/// A connection between two nodes.
class GraphEdge {
  final int source;
  final int target;

  const GraphEdge({required this.source, required this.target});

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      source: json['source'] as int,
      target: json['target'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'source': source, 'target': target};
  }
}
