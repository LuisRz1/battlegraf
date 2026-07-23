import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:battlegraf_mobile/main.dart';
import 'package:battlegraf_mobile/domain/models/node.dart';
import 'package:battlegraf_mobile/domain/models/graph.dart';
import 'package:battlegraf_mobile/domain/models/battle.dart';

void main() {
  testWidgets('BattleGraf app renders splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BattleGrafApp()));
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
  });
}
