import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:battlegraf_mobile/main.dart';

void main() {
  testWidgets('BattleGraf app renders splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BattleGrafApp()));
    expect(find.text('BATTLE'), findsOneWidget);
    expect(find.text('GRAF'), findsOneWidget);
  });
}
