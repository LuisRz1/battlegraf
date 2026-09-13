import 'package:flutter_test/flutter_test.dart';

import 'package:battlegraf_mobile/presentation/views/battle/bot_battle_demo_controller.dart';

List<DemoQuestion> _pool() => const [
  DemoQuestion(
    id: 'q1',
    nodeId: 'x',
    subject: 'math',
    prompt: '2+2?',
    options: {'A': '4', 'B': '5', 'C': '6', 'D': '7'},
    correctOption: 'A',
  ),
  DemoQuestion(
    id: 'q2',
    nodeId: 'x',
    subject: 'language',
    prompt: 'Sinónimo de rápido?',
    options: {'A': 'lento', 'B': 'veloz', 'C': 'alto', 'D': 'bajo'},
    correctOption: 'B',
  ),
  DemoQuestion(
    id: 'q3',
    nodeId: 'x',
    subject: 'science',
    prompt: 'Órgano que bombea sangre?',
    options: {'A': 'hígado', 'B': 'pulmón', 'C': 'corazón', 'D': 'riñón'},
    correctOption: 'C',
  ),
];

bool _connected(Map<String, List<String>> adj, String from, String to) {
  final seen = <String>{from};
  final queue = <String>[from];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    for (final next in adj[current] ?? const <String>[]) {
      if (seen.add(next)) queue.add(next);
    }
  }
  return seen.contains(to);
}

void main() {
  test('genera un mapa conectado de base a base con nodos intermedios', () {
    final controller = BotBattleDemoController(pool: _pool());
    final graph = controller.graph;
    expect(graph.nodes.length, greaterThan(4));
    expect(
      graph.nodes.where((node) => node.layer > 0).length,
      greaterThan(1),
    );

    final adjacency = <String, List<String>>{
      for (final node in graph.nodes) node.id: <String>[],
    };
    for (final edge in graph.edges) {
      adjacency[edge.source]?.add(edge.target);
      adjacency[edge.target]?.add(edge.source);
    }
    expect(
      _connected(adjacency, BotBattleDemoController.redBaseId,
          BotBattleDemoController.purpleBaseId),
      isTrue,
      reason: 'debe existir un camino de la base aliada a la rival',
    );
  });

  test('los mapas varían entre partidas', () {
    final signatures = <String>{};
    for (var i = 0; i < 12; i++) {
      final controller = BotBattleDemoController(pool: _pool());
      signatures.add(
        controller.graph.nodes
            .map((node) => '${node.layer}:${node.position}:${node.id}')
            .join('|'),
      );
    }
    expect(signatures.length, greaterThan(1));
  });

  test('respeta el tamaño de mapa configurado', () {
    final controller = BotBattleDemoController(
      pool: _pool(),
      layers: 6,
      nodesPerLayer: 4,
    );
    expect(controller.graph.layerCount, 6);
    expect(
      controller.graph.nodes.where((node) => node.layer == 1).length,
      4,
    );
  });

  test('usa los poderes equipados como tokens de ayuda', () {
    final controller = BotBattleDemoController(
      pool: _pool(),
      initialAbilities: {'half': 1, 'double': 1},
    );
    expect(controller.helpTokens, 2);
  });
}
