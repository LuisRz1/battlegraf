import 'package:battlegraf_mobile/core/theme/app_theme.dart';
import 'package:battlegraf_mobile/presentation/views/battle/bot_battle_demo_view.dart';
import 'package:battlegraf_mobile/presentation/widgets/graph_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plays one complete red and purple turn on a phone viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const BotBattleDemoView()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TU TURNO'), findsOneWidget);
    expect(find.byKey(const Key('demo-graph-board')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final board = tester.widget<GraphBoardWithEffects>(
      find.byKey(const Key('demo-graph-board')),
    );
    board.onNodeTap(
      board.graph.nodes.firstWhere((node) => node.id == 'math-1'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('demo-question-panel')), findsOneWidget);
    expect(find.text('¿Cuál es el resultado de 3/4 + 1/4?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-option-B')));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.tap(find.byKey(const Key('demo-submit-answer')));
    await tester.pump();

    expect(find.text('TURNO BOT'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('TU TURNO'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeps the question controls visible on a compact phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const BotBattleDemoView()),
    );
    await tester.pump();

    final board = tester.widget<GraphBoardWithEffects>(
      find.byKey(const Key('demo-graph-board')),
    );
    board.onNodeTap(
      board.graph.nodes.firstWhere((node) => node.id == 'math-1'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('demo-question-panel')), findsOneWidget);
    expect(find.byKey(const Key('demo-submit-answer')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
