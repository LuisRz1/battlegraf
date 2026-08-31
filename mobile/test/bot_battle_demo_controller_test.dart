import 'package:battlegraf_mobile/domain/models/node.dart';
import 'package:battlegraf_mobile/presentation/views/battle/bot_battle_demo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BotBattleDemoController', () {
    test('builds two bases and a connected five-layer board', () {
      final battle = BotBattleDemoController();
      addTearDown(battle.dispose);

      expect(battle.graph.layerCount, greaterThanOrEqualTo(4));
      expect(
        battle.graph.nodes
            .firstWhere((node) => node.id == BotBattleDemoController.redBaseId)
            .owner,
        NodeOwner.player,
      );
      expect(
        battle.graph.nodes
            .firstWhere(
              (node) => node.id == BotBattleDemoController.purpleBaseId,
            )
            .owner,
        NodeOwner.opponent,
      );
      expect(battle.legalNodeIds, {'math-1', 'language-1', 'science-1'});
    });

    test('cannot jump back to another branch after advancing', () {
      final battle = BotBattleDemoController();
      addTearDown(battle.dispose);

      expect(battle.selectNode('math-1'), isTrue);
      final firstQuestion = battle.activeQuestion!;
      battle.submitPlayerAnswer(firstQuestion.correctOption);
      battle.resolveBotTurn();

      expect(battle.currentSide, DemoBattleSide.red);
      expect(battle.legalNodeIds, {'history-2', 'math-2'});
      expect(battle.legalNodeIds, isNot(contains('language-1')));
      expect(battle.legalNodeIds, isNot(contains('science-1')));
      expect(battle.selectNode('language-1'), isFalse);
    });

    test('an incorrect answer preserves the node and passes the turn', () {
      final battle = BotBattleDemoController();
      addTearDown(battle.dispose);

      battle.selectNode('science-1');
      final question = battle.activeQuestion!;
      final wrongOption = question.options.keys.firstWhere(
        (option) => option != question.correctOption,
      );

      expect(battle.submitPlayerAnswer(wrongOption), isFalse);
      expect(battle.currentSide, DemoBattleSide.purple);
      expect(battle.phase, DemoBattlePhase.botThinking);
      expect(
        battle.graph.nodes.firstWhere((node) => node.id == 'science-1').owner,
        NodeOwner.neutral,
      );

      battle.resolveBotTurn();
      expect(battle.currentSide, DemoBattleSide.red);
      expect(battle.legalNodeIds, contains('science-1'));
    });

    test('a slower rival answer cannot steal a conquered node', () {
      final battle = BotBattleDemoController();
      addTearDown(battle.dispose);

      battle.selectNode('math-1');
      battle.submitPlayerAnswer(
        battle.activeQuestion!.correctOption,
        elapsedMilliseconds: 2400,
      );
      battle.resolveBotTurn();

      battle.selectNode('math-2');
      battle.submitPlayerAnswer(
        battle.activeQuestion!.correctOption,
        elapsedMilliseconds: 2000,
      );
      battle.resolveBotTurn();

      expect(
        battle.graph.nodes.firstWhere((node) => node.id == 'math-2').owner,
        NodeOwner.player,
      );
      expect(battle.statusMessage, contains('récord rival'));
      expect(battle.currentSide, DemoBattleSide.red);
    });

    test('a correct route can conquer the purple tower', () {
      final battle = BotBattleDemoController();
      addTearDown(battle.dispose);

      for (var move = 0; move < 30 && !battle.isFinished; move++) {
        if (battle.currentSide == DemoBattleSide.purple) {
          battle.resolveBotTurn();
          continue;
        }

        final targets = battle.legalNodeIds.toList()
          ..sort((a, b) {
            final aLayer = battle.graph.nodes
                .firstWhere((node) => node.id == a)
                .layer;
            final bLayer = battle.graph.nodes
                .firstWhere((node) => node.id == b)
                .layer;
            return bLayer.compareTo(aLayer);
          });
        expect(targets, isNotEmpty);
        battle.selectNode(targets.first);
        battle.submitPlayerAnswer(battle.activeQuestion!.correctOption);
      }

      expect(battle.isFinished, isTrue);
      expect(battle.winner, DemoBattleSide.red);
    });

    test('repeated player errors let the BOT conquer the red tower', () {
      final battle = BotBattleDemoController();
      addTearDown(battle.dispose);

      for (var move = 0; move < 40 && !battle.isFinished; move++) {
        if (battle.currentSide == DemoBattleSide.purple) {
          battle.resolveBotTurn();
          continue;
        }

        final target = battle.legalNodeIds.first;
        battle.selectNode(target);
        final question = battle.activeQuestion!;
        final wrongOption = question.options.keys.firstWhere(
          (option) => option != question.correctOption,
        );
        battle.submitPlayerAnswer(wrongOption);
      }

      expect(battle.isFinished, isTrue);
      expect(battle.winner, DemoBattleSide.purple);

      battle.reset();
      expect(battle.isFinished, isFalse);
      expect(battle.currentSide, DemoBattleSide.red);
      expect(battle.turnNumber, 1);
    });
  });
}
