import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/battle.dart';
import '../../../domain/models/node.dart';
import '../../providers/battle_provider.dart';
import '../../widgets/graph_board.dart';
import '../../widgets/retro_ui.dart';

/// Main red-versus-purple battle screen.
class BattleView extends ConsumerStatefulWidget {
  final String battleId;

  const BattleView({super.key, required this.battleId});

  @override
  ConsumerState<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends ConsumerState<BattleView> {
  String _answer = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(battleProvider.notifier).loadBattle(widget.battleId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(battleProvider);
    final battle = state.battle;

    return Scaffold(
      appBar: AppBar(
        title: Text(battle?.title.toUpperCase() ?? 'BATALLA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/battle-lobby'),
        ),
      ),
      body: BattleBackdrop(
        intense: true,
        child: SafeArea(
          child: state.isLoading && battle == null
              ? const Center(
                  child: LinearProgressIndicator(
                    color: AppColors.brightRed,
                    backgroundColor: AppColors.shadowPurple,
                  ),
                )
              : battle == null
              ? const _ErrorMessage()
              : Stack(
                  children: [
                    Column(
                      children: [
                        _TurnHeader(
                          redPlayer: battle.players.isNotEmpty
                              ? battle.players.first.name
                              : 'Jugador rojo',
                          purplePlayer: battle.players.length > 1
                              ? battle.players[1].name
                              : 'Jugador morado',
                          timeRemaining: state.timeRemaining,
                          currentTurnIndex: battle.currentTurn ?? 0,
                          isMyTurn: _isMyTurn(battle, state.currentUserId),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: PixelPanel(
                              padding: EdgeInsets.zero,
                              accent: (battle.currentTurn ?? 0) == 0
                                  ? AppColors.brightRed
                                  : AppColors.neonPurple,
                              glow: true,
                              child: battle.graph == null
                                  ? const Center(
                                      child: Text('Grafo no disponible'),
                                    )
                                  : Stack(
                                      children: [
                                        GraphBoardWithEffects(
                                          graph: battle.graph!,
                                          activeNodeId: state.activeNodeId,
                                          currentTurnIndex:
                                              battle.currentTurn ?? 0,
                                          playerPositions:
                                              battle.playerPositions,
                                          onNodeTap: _onNodeTap,
                                          animateConquest:
                                              state.feedbackSuccess,
                                        ),
                                        const Positioned(
                                          top: 10,
                                          left: 12,
                                          child: HudLabel(
                                            'TORRE MORADA / OBJETIVO',
                                            color: AppColors.neonPurple,
                                          ),
                                        ),
                                        const Positioned(
                                          right: 12,
                                          bottom: 10,
                                          child: HudLabel(
                                            'TORRE ROJA / RUTA CONECTADA',
                                            color: AppColors.brightRed,
                                          ),
                                        ),
                                        if (state.feedback != null &&
                                            state.activeQuestion == null)
                                          Positioned(
                                            right: 12,
                                            bottom: 32,
                                            left: 12,
                                            child: _BattleFeedback(
                                              message: state.feedback!,
                                              success: state.feedbackSuccess,
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        _QuestionPanel(
                          question: state.activeQuestion,
                          answer: _answer,
                          turnColor: (battle.currentTurn ?? 0) == 0
                              ? AppColors.brightRed
                              : AppColors.neonPurple,
                          onAnswerChanged: (value) =>
                              setState(() => _answer = value),
                          onSubmit: _submitAnswer,
                          feedback: state.feedback,
                          success: state.feedbackSuccess,
                        ),
                      ],
                    ),
                    if (battle.status.toLowerCase() == 'finished' ||
                        battle.winnerId != null)
                      Positioned.fill(
                        child: _VictoryOverlay(
                          winnerIsRed:
                              battle.players.isNotEmpty &&
                              battle.winnerId == battle.players.first.id,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  bool _isMyTurn(Battle battle, String? userId) {
    if (userId == null || battle.currentTurn == null) return false;
    final me = battle.players.firstWhere(
      (player) => player.id == userId,
      orElse: () => const Player(id: '', name: ''),
    );
    if (me.id.isEmpty) return userId == battle.currentPlayerId;
    return battle.players.indexWhere((player) => player.id == me.id) ==
        battle.currentTurn;
  }

  Future<void> _onNodeTap(Node node) async {
    if (node.locked) return;
    final state = ref.read(battleProvider);
    final battle = state.battle;
    if (battle == null ||
        state.timeRemaining <= 0 ||
        !_isMyTurn(battle, state.currentUserId)) {
      return;
    }
    setState(() => _answer = '');
    await ref.read(battleProvider.notifier).selectNode(node.id);
  }

  void _submitAnswer() {
    final notifier = ref.read(battleProvider.notifier);
    final state = ref.read(battleProvider);
    if (state.activeNodeId == null ||
        state.activeQuestion == null ||
        _answer.isEmpty ||
        state.timeRemaining <= 0) {
      return;
    }
    notifier.answerNode(state.activeNodeId!, _answer);
    setState(() => _answer = '');
  }
}

class _TurnHeader extends StatelessWidget {
  final String redPlayer;
  final String purplePlayer;
  final int timeRemaining;
  final int currentTurnIndex;
  final bool isMyTurn;

  const _TurnHeader({
    required this.redPlayer,
    required this.purplePlayer,
    required this.timeRemaining,
    required this.currentTurnIndex,
    required this.isMyTurn,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = timeRemaining <= 5;
    final activeColor = currentTurnIndex == 0
        ? AppColors.brightRed
        : AppColors.neonPurple;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        accent: activeColor,
        glow: true,
        child: Row(
          children: [
            _PlayerSide(
              name: redPlayer,
              label: 'ROJO',
              color: AppColors.brightRed,
              active: currentTurnIndex == 0,
            ),
            Expanded(
              child: Column(
                children: [
                  HudLabel(
                    isMyTurn ? 'TU TURNO' : 'TURNO RIVAL',
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentTurnIndex == 0 ? 'JUEGA ROJO' : 'JUEGA MORADO',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: activeColor,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeRemaining.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: isLow ? AppColors.brightRed : AppColors.offWhite,
                      fontSize: 23,
                    ),
                  ).animate(target: isLow ? 1 : 0).shakeX(duration: 300.ms),
                ],
              ),
            ),
            _PlayerSide(
              name: purplePlayer,
              label: 'MORADO',
              color: AppColors.neonPurple,
              active: currentTurnIndex == 1,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 420.ms).slideY(begin: -0.15);
  }
}

class _PlayerSide extends StatelessWidget {
  final String name;
  final String label;
  final Color color;
  final bool active;

  const _PlayerSide({
    required this.name,
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active ? 1 : .4,
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            SchoolTower(
              color: color,
              size: active ? 48 : 42,
              flagRight: label == 'ROJO',
            ),
            HudLabel(label, color: color),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  final BattleQuestion? question;
  final String answer;
  final Color turnColor;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onSubmit;
  final String? feedback;
  final bool success;

  const _QuestionPanel({
    required this.question,
    required this.answer,
    required this.turnColor,
    required this.onAnswerChanged,
    required this.onSubmit,
    this.feedback,
    required this.success,
  });

  @override
  Widget build(BuildContext context) {
    if (question == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(10),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .43,
        ),
        child: PixelPanel(
          accent: success ? AppColors.cyan : turnColor,
          glow: success,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HudLabel('RETO DEL HEXÁGONO', color: turnColor),
                const SizedBox(height: 8),
                Text(
                  question!.text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.offWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (question!.options.isNotEmpty)
                  ...question!.options.entries.map((option) {
                    final selected = answer == option.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: InkWell(
                        onTap: () => onAnswerChanged(option.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected
                                ? turnColor.withAlpha(205)
                                : AppColors.voidBlack.withAlpha(190),
                            border: Border.all(
                              color: selected
                                  ? AppColors.offWhite
                                  : AppColors.shadowPurple,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '${option.key}. ${option.value}',
                            style: TextStyle(
                              color: selected
                                  ? AppColors.offWhite
                                  : AppColors.mutedInk,
                              fontFamily: AppTheme.bodyFont,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                else
                  TextField(
                    onChanged: onAnswerChanged,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu respuesta...',
                    ),
                  ),
                if (feedback != null) ...[
                  const SizedBox(height: 8),
                  HudLabel(
                    feedback!,
                    color: success ? AppColors.cyan : AppColors.brightRed,
                  ).animate().shakeX(duration: 300.ms),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: answer.isEmpty ? null : onSubmit,
                    child: const Text('CONQUISTAR NODO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: .15);
  }
}

class _BattleFeedback extends StatelessWidget {
  final String message;
  final bool success;

  const _BattleFeedback({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      padding: const EdgeInsets.all(10),
      accent: success ? AppColors.cyan : AppColors.brightRed,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  final bool winnerIsRed;

  const _VictoryOverlay({required this.winnerIsRed});

  @override
  Widget build(BuildContext context) {
    final color = winnerIsRed ? AppColors.brightRed : AppColors.neonPurple;
    final label = winnerIsRed ? 'ROJO' : 'MORADO';
    return ColoredBox(
      color: AppColors.voidBlack.withAlpha(234),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PixelPanel(
            accent: color,
            glow: true,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SchoolTower(color: color, size: 112),
                const SizedBox(height: 16),
                const HudLabel('BATALLA FINALIZADA'),
                const SizedBox(height: 10),
                Text(
                  'VICTORIA $label',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () => context.go('/battle-lobby'),
                  child: const Text('VOLVER A BATALLAS'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PixelPanel(
        accent: AppColors.brightRed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SchoolTower(color: AppColors.brightRed, size: 72),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar la batalla',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
