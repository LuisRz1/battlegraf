import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/node.dart';
import '../../providers/battle_provider.dart';
import '../../widgets/graph_board.dart';

/// Main battle screen with header, graph and question panel.
class BattleView extends ConsumerStatefulWidget {
  final int battleId;

  const BattleView({super.key, required this.battleId});

  @override
  ConsumerState<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends ConsumerState<BattleView> {
  String _answer = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(battleProvider.notifier).loadBattle(widget.battleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final battleState = ref.watch(battleProvider);
    final battle = battleState.battle;

    return Scaffold(
      appBar: AppBar(
        title: Text(battle?.title.toUpperCase() ?? 'BATALLA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/battle-lobby'),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.deepPurple, AppColors.royalPurple],
          ),
        ),
        child: SafeArea(
          child: battleState.isLoading && battle == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : battle == null
                  ? const _ErrorMessage()
                  : Column(
                      children: [
                        _TurnHeader(
                          currentPlayer: battle.currentPlayer ?? 'Turno',
                          timeRemaining: battleState.timeRemaining,
                          turnNumber: battle.currentTurn ?? 1,
                        ),
                        Expanded(
                          child: battle.graph == null
                              ? const Center(
                                  child: Text('Grafo no disponible'),
                                )
                              : GraphBoardWithEffects(
                                  graph: battle.graph!,
                                  activeNodeId: battleState.activeNodeId,
                                  onNodeTap: (node) => _onNodeTap(node),
                                  animateConquest: battleState.feedbackSuccess,
                                ),
                        ),
                        _QuestionPanel(
                          node: _activeNode(battleState),
                          answer: _answer,
                          onAnswerChanged: (value) => setState(() => _answer = value),
                          onSubmit: _submitAnswer,
                          feedback: battleState.feedback,
                          success: battleState.feedbackSuccess,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Node? _activeNode(BattleState state) {
    final battle = state.battle;
    if (battle?.graph == null) return null;
    final activeId = state.activeNodeId;
    if (activeId == null) return null;
    return battle!.graph!.nodes.where((n) => n.id == activeId).firstOrNull;
  }

  void _onNodeTap(Node node) {
    if (node.locked) return;
    ref.read(battleProvider.notifier).selectNode(node.id);
    setState(() => _answer = '');
  }

  void _submitAnswer() {
    final activeNodeId = ref.read(battleProvider).activeNodeId;
    if (activeNodeId == null || _answer.isEmpty) return;
    ref.read(battleProvider.notifier).answerNode(activeNodeId, _answer);
    setState(() => _answer = '');
  }
}

class _TurnHeader extends StatelessWidget {
  final String currentPlayer;
  final int timeRemaining;
  final int turnNumber;

  const _TurnHeader({
    required this.currentPlayer,
    required this.timeRemaining,
    required this.turnNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = timeRemaining <= 5;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turno $turnNumber',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentPlayer,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'TIEMPO',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeRemaining}s',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: isLow ? AppColors.brightRed : AppColors.gold,
                          fontSize: 24,
                        ),
                  ).animate(target: isLow ? 1 : 0).shakeX(duration: 300.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2);
  }
}

class _QuestionPanel extends StatelessWidget {
  final Node? node;
  final String answer;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onSubmit;
  final String? feedback;
  final bool success;

  const _QuestionPanel({
    required this.node,
    required this.answer,
    required this.onAnswerChanged,
    required this.onSubmit,
    this.feedback,
    required this.success,
  });

  @override
  Widget build(BuildContext context) {
    if (node == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node!.question ?? 'Responde para conquistar ${node!.label}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              if (node!.options.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: node!.options.map((option) {
                    final isSelected = answer == option;
                    return ChoiceChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (_) => onAnswerChanged(option),
                      selectedColor: AppColors.crimsonRed,
                      backgroundColor: AppColors.darkCard,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.offWhite : AppColors.gold,
                        fontFamily: AppTheme.bodyFont,
                      ),
                    );
                  }).toList(),
                )
              else
                TextField(
                  onChanged: onAnswerChanged,
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu respuesta...',
                  ),
                  style: const TextStyle(fontFamily: AppTheme.bodyFont),
                ),
              if (feedback != null) ...[
                const SizedBox(height: 12),
                Text(
                  feedback!,
                  style: TextStyle(
                    color: success ? AppColors.gold : AppColors.brightRed,
                    fontFamily: AppTheme.bodyFont,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().shakeX(duration: 300.ms),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: answer.isEmpty ? null : onSubmit,
                  child: const Text('CONQUISTAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: AppColors.brightRed, size: 48),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar la batalla',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
