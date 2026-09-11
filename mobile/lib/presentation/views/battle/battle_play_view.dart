import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/question_pool_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/panel_ui.dart';
import 'bot_battle_demo_controller.dart';
import 'bot_battle_demo_view.dart';

/// Partida real del alumno: usa las preguntas del colegio y registra el
/// resultado para que aparezca en su historial.
class BattlePlayView extends ConsumerStatefulWidget {
  const BattlePlayView({super.key, this.topic});

  final String? topic;

  @override
  ConsumerState<BattlePlayView> createState() => _BattlePlayViewState();
}

class _BattlePlayViewState extends ConsumerState<BattlePlayView> {
  bool _recorded = false;

  Future<void> _onFinished(
    DemoBattleSide winner,
    int playerScore,
    int botScore,
  ) async {
    if (_recorded) return;
    _recorded = true;
    final ok = await ref
        .read(studentDashboardProvider.notifier)
        .recordBattleResult(
          subject: widget.topic ?? 'Todas',
          result: winner == DemoBattleSide.red ? 'victoria' : 'derrota',
          score: playerScore,
          opponentScore: botScore,
        );
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resultado guardado en tu historial.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(questionPoolProvider);
    final questions = pool.forTopic(widget.topic);
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.fondoGame,
        appBar: AppBar(
          backgroundColor: AppColors.piedra950,
          title: const Text('BATALLA'),
        ),
        body: PanelEmpty(
          icon: Icons.extension_off,
          title: 'SIN PREGUNTAS',
          message: pool.isLoading
              ? 'Cargando preguntas del colegio...'
              : 'No hay preguntas para esta materia.',
        ),
      );
    }
    return BotBattleDemoView(
      pool: questions,
      onFinished: _onFinished,
    );
  }
}
