import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:battlegraf_mobile/main.dart';
import 'package:battlegraf_mobile/domain/models/node.dart';
import 'package:battlegraf_mobile/domain/models/graph.dart';
import 'package:battlegraf_mobile/domain/models/battle.dart';
import 'package:battlegraf_mobile/domain/models/progression.dart';
import 'package:battlegraf_mobile/domain/models/school_task.dart';
import 'package:battlegraf_mobile/presentation/widgets/graph_board.dart';

void main() {
  testWidgets('BattleGraph app renders splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BattleGraphApp()));
    expect(find.text('BATTLE'), findsOneWidget);
    expect(find.text('GRAF'), findsOneWidget);
  });

  group('Battle models', () {
    test('Node serializes and parses owners', () {
      const node = Node(
        id: '1',
        label: 'M1',
        subject: 'math',
        layer: 0,
        position: 0,
        owner: NodeOwner.player,
      );
      final json = node.toJson();
      final parsed = Node.fromJson(json);
      expect(parsed.id, '1');
      expect(parsed.owner, NodeOwner.player);
    });

    test('Graph parses nodes and edges', () {
      final graph = Graph.fromJson({
        'nodes': [
          {
            'id': '1',
            'label': 'M1',
            'subject': 'math',
            'layer': 0,
            'position': 0,
          },
          {
            'id': '2',
            'label': 'L1',
            'subject': 'language',
            'layer': 1,
            'position': 0,
          },
        ],
        'edges': [
          {'source': '1', 'target': '2'},
        ],
        'layer_count': 2,
      });
      expect(graph.nodes.length, 2);
      expect(graph.edges.length, 1);
      expect(graph.layerCount, 2);
    });

    test('Battle parses nested graph', () {
      final battle = Battle.fromJson({
        'id': '1',
        'title': 'Demo',
        'status': 'active',
        'current_turn': 1,
        'turn_timeout_seconds': 30,
        'time_remaining': 25,
        'graph': {
          'nodes': [
            {
              'id': '1',
              'label': 'M1',
              'subject': 'math',
              'layer': 0,
              'position': 0,
            },
          ],
          'edges': [],
          'layer_count': 1,
        },
        'players': [
          {'id': '1', 'name': 'Alumno'},
        ],
      });
      expect(battle.id, '1');
      expect(battle.graph?.nodes.length, 1);
      expect(battle.players.length, 1);
    });

    test('Battle parses the real backend graph and numeric owners', () {
      final battle = Battle.fromJson({
        'id': 'battle-1',
        'status': 'in_progress',
        'player_1_id': 'student-1',
        'player_2_id': 'student-2',
        'current_turn': 0,
        'turn_number': 3,
        'current_player_id': 'student-1',
        'server_time': '2026-07-28T17:00:00Z',
        'turn_deadline_at': '2026-07-28T17:00:25Z',
        'player_positions': {'0': 'node-1', '1': 'node-2'},
        'graph': {
          'id': 'graph-1',
          'num_layers': 4,
          'nodes': [
            {
              'id': 'node-1',
              'subject': 'mathematics',
              'layer': 0,
              'position': 0,
              'connected_to': <String>[],
              'question_ids': ['question-1'],
            },
          ],
        },
        'node_states': [
          {'node_id': 'node-1', 'owner': 0},
        ],
      });

      expect(battle.graph?.layerCount, 4);
      expect(battle.graph?.nodes.single.owner, NodeOwner.player);
      expect(battle.players.length, 2);
      expect(battle.currentPlayerId, 'student-1');
      expect(battle.turnNumber, 3);
      expect(battle.playerPositions[0], 'node-1');
      expect(
        battle.turnDeadlineAt?.difference(battle.serverTime!).inSeconds,
        25,
      );
    });
  });

  testWidgets('Graph board only accepts nodes connected to red territory', (
    WidgetTester tester,
  ) async {
    const graph = Graph(
      layerCount: 3,
      nodes: [
        Node(
          id: 'red-base',
          label: 'ROJO',
          subject: 'base',
          layer: 0,
          position: 0,
        ),
        Node(id: 'math', label: 'M1', subject: 'math', layer: 1, position: 0),
        Node(
          id: 'purple-base',
          label: 'MORADO',
          subject: 'base',
          layer: 2,
          position: 0,
        ),
      ],
      edges: [
        GraphEdge(source: 'red-base', target: 'math'),
        GraphEdge(source: 'math', target: 'purple-base'),
      ],
    );
    final tapped = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 600,
            height: 360,
            child: GraphBoard(
              graph: graph,
              currentTurnIndex: 0,
              onNodeTap: (node) => tapped.add(node.id),
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(GraphBoard));

    await tester.tapAt(origin + const Offset(552, 180));
    expect(tapped, isEmpty);

    await tester.tapAt(origin + const Offset(300, 180));
    expect(tapped, ['math']);
  });

  group('Phase 5 models', () {
    test('Task hides or exposes answer according to API payload', () {
      final task = SchoolTask.fromJson({
        'id': 'task-1',
        'section_id': 'section-1',
        'subject': 'mathematics',
        'title': 'Suma',
        'description': 'Resuelve',
        'task_type': 'multiple_choice',
        'xp_reward': 20,
        'status': 'published',
        'options': {'A': '4', 'B': '3', 'C': '5', 'D': '6'},
        'correct_option': null,
      });

      expect(task.options.length, 4);
      expect(task.correctOption, isNull);
    });

    test('Progression profile parses rank and clan', () {
      final profile = ProgressionProfile.fromJson({
        'xp': 320,
        'rank': {'name': 'Explorador'},
        'clan': {'name': 'Estrategas'},
      });

      expect(profile.xp, 320);
      expect(profile.rankName, 'Explorador');
      expect(profile.clanName, 'Estrategas');
    });
  });
}
