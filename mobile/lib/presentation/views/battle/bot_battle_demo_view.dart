import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/node.dart';
import '../../widgets/graph_board.dart';
import '../../widgets/retro_ui.dart';
import 'bot_battle_demo_controller.dart';

/// Public, backend-free prototype of a complete turn-based BattleGraph match.
class BotBattleDemoView extends StatefulWidget {
  const BotBattleDemoView({super.key});

  @override
  State<BotBattleDemoView> createState() => _BotBattleDemoViewState();
}

class _BotBattleDemoViewState extends State<BotBattleDemoView> {
  static const _secondsPerTurn = 25;

  late final BotBattleDemoController _battle;
  Timer? _clock;
  Timer? _botDelay;
  int _secondsRemaining = _secondsPerTurn;
  int _observedTurn = 1;
  String? _selectedOption;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _battle = BotBattleDemoController()..addListener(_onBattleChanged);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _botDelay?.cancel();
    _battle
      ..removeListener(_onBattleChanged)
      ..dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted ||
        _battle.isFinished ||
        _battle.currentSide != DemoBattleSide.red) {
      return;
    }
    if (_secondsRemaining <= 1) {
      _secondsRemaining = 0;
      _battle.handlePlayerTimeout();
    } else {
      setState(() => _secondsRemaining -= 1);
    }
  }

  void _onBattleChanged() {
    if (!mounted) return;

    if (_observedTurn != _battle.turnNumber) {
      _observedTurn = _battle.turnNumber;
      _secondsRemaining = _secondsPerTurn;
      _selectedOption = null;
    }

    if (_battle.phase == DemoBattlePhase.botThinking && _botDelay == null) {
      _botDelay = Timer(Duration(milliseconds: _reduceMotion ? 250 : 1050), () {
        _botDelay = null;
        if (mounted) _battle.resolveBotTurn();
      });
    } else if (_battle.phase != DemoBattlePhase.botThinking) {
      _botDelay?.cancel();
      _botDelay = null;
    }

    setState(() {});
  }

  void _leaveDemo() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  void _selectNode(Node node) {
    _battle.selectNode(node.id);
  }

  void _submitAnswer() {
    final option = _selectedOption;
    if (option == null) return;
    final elapsedMilliseconds = ((_secondsPerTurn - _secondsRemaining) * 1000)
        .clamp(600, 25000);
    _battle.submitPlayerAnswer(
      option,
      elapsedMilliseconds: elapsedMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final turnColor = _battle.currentSide == DemoBattleSide.red
        ? AppColors.brightRed
        : AppColors.neonPurple;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Salir del prototipo',
          onPressed: _leaveDemo,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('BATALLA DE AULA'),
        actions: [
          IconButton(
            tooltip: 'Reiniciar batalla',
            onPressed: _battle.reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: BattleBackdrop(
        intense: true,
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _DemoBattleHud(
                    currentSide: _battle.currentSide,
                    turnNumber: _battle.turnNumber,
                    secondsRemaining: _secondsRemaining,
                    redOwned: _battle.ownedNodes(DemoBattleSide.red),
                    purpleOwned: _battle.ownedNodes(DemoBattleSide.purple),
                    redAccuracy: _accuracy(
                      _battle.redCorrect,
                      _battle.redAttempts,
                    ),
                    purpleAccuracy: _accuracy(
                      _battle.purpleCorrect,
                      _battle.purpleAttempts,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: PixelPanel(
                        padding: EdgeInsets.zero,
                        accent: turnColor,
                        glow: true,
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              child: GraphBoardWithEffects(
                                key: const Key('demo-graph-board'),
                                graph: _battle.graph,
                                activeNodeId:
                                    _battle.selectedNodeId ??
                                    _battle.lastMoveNodeId,
                                currentTurnIndex:
                                    _battle.currentSide == DemoBattleSide.red
                                    ? 0
                                    : 1,
                                playerPositions: _battle.playerPositions,
                                legalNodeIds: _battle.legalNodeIds,
                                enableMotion: !_reduceMotion,
                                animateConquest:
                                    _battle.lastMoveWasCorrect == true,
                                onNodeTap: _selectNode,
                              ),
                            ),
                            const Positioned(
                              top: 10,
                              left: 12,
                              child: HudLabel(
                                'TORRE MORADA / META',
                                color: AppColors.neonPurple,
                              ),
                            ),
                            const Positioned(
                              right: 12,
                              bottom: 10,
                              child: HudLabel(
                                'INICIO / TORRE ROJA',
                                color: AppColors.brightRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _StatusStrip(
                    message: _battle.statusMessage,
                    color: turnColor,
                    success: _battle.lastMoveWasCorrect,
                  ),
                  AnimatedSwitcher(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                    child: _bottomPanel(turnColor),
                  ),
                ],
              ),
              if (_battle.isFinished)
                Positioned.fill(
                  child: _DemoResultOverlay(
                    winner: _battle.winner!,
                    redScore: '${_battle.redCorrect}/${_battle.redAttempts}',
                    purpleScore:
                        '${_battle.purpleCorrect}/${_battle.purpleAttempts}',
                    onReset: _battle.reset,
                    onExit: _leaveDemo,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel(Color turnColor) {
    if (_battle.phase == DemoBattlePhase.answerQuestion) {
      final question = _battle.activeQuestion!;
      return _DemoQuestionPanel(
        key: const ValueKey('question'),
        question: question,
        selectedOption: _selectedOption,
        onSelect: (value) => setState(() => _selectedOption = value),
        onSubmit: _selectedOption == null ? null : _submitAnswer,
      );
    }
    if (_battle.phase == DemoBattlePhase.botThinking) {
      return const _BotTurnPanel(key: ValueKey('bot-turn'));
    }
    if (_battle.phase == DemoBattlePhase.finished) {
      return const SizedBox(key: ValueKey('finished'), height: 8);
    }
    return _ChooseRoutePanel(
      key: const ValueKey('choose-route'),
      legalCount: _battle.legalNodeIds.length,
      color: turnColor,
    );
  }

  static String _accuracy(int correct, int attempts) {
    if (attempts == 0) return '--';
    return '${(correct * 100 / attempts).round()}%';
  }
}

class _DemoBattleHud extends StatelessWidget {
  const _DemoBattleHud({
    required this.currentSide,
    required this.turnNumber,
    required this.secondsRemaining,
    required this.redOwned,
    required this.purpleOwned,
    required this.redAccuracy,
    required this.purpleAccuracy,
  });

  final DemoBattleSide currentSide;
  final int turnNumber;
  final int secondsRemaining;
  final int redOwned;
  final int purpleOwned;
  final String redAccuracy;
  final String purpleAccuracy;

  @override
  Widget build(BuildContext context) {
    final redTurn = currentSide == DemoBattleSide.red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        accent: redTurn ? AppColors.brightRed : AppColors.neonPurple,
        glow: true,
        child: Row(
          children: [
            _HudSide(
              label: 'TÚ',
              color: AppColors.brightRed,
              nodes: redOwned,
              accuracy: redAccuracy,
              active: redTurn,
              towerRight: true,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HudLabel(
                    redTurn ? 'TU TURNO' : 'TURNO BOT',
                    color: redTurn ? AppColors.brightRed : AppColors.neonPurple,
                  ),
                  const SizedBox(height: 4),
                  AcademicHexBadge(
                    label: redTurn ? '$secondsRemaining' : 'BOT',
                    color: redTurn ? AppColors.brightRed : AppColors.neonPurple,
                    size: 46,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'RONDA $turnNumber',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontFamily: AppTheme.displayFont,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),
            _HudSide(
              label: 'BOT',
              color: AppColors.neonPurple,
              nodes: purpleOwned,
              accuracy: purpleAccuracy,
              active: !redTurn,
              towerRight: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _HudSide extends StatelessWidget {
  const _HudSide({
    required this.label,
    required this.color,
    required this.nodes,
    required this.accuracy,
    required this.active,
    required this.towerRight,
  });

  final String label;
  final Color color;
  final int nodes;
  final String accuracy;
  final bool active;
  final bool towerRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Row(
        mainAxisAlignment: towerRight
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (towerRight) SchoolTower(color: color, size: 43, flagRight: true),
          if (towerRight) const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: towerRight
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: AppTheme.displayFont,
                    fontSize: 9,
                    shadows: active
                        ? [Shadow(color: color, blurRadius: 10)]
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$nodes NODOS',
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 8,
                  ),
                ),
                Text(
                  'PREC. $accuracy',
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
          if (!towerRight) const SizedBox(width: 6),
          if (!towerRight)
            SchoolTower(color: color, size: 43, flagRight: false),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.message,
    required this.color,
    required this.success,
  });

  final String message;
  final Color color;
  final bool? success;

  @override
  Widget build(BuildContext context) {
    final indicator = success == null
        ? color
        : success!
        ? AppColors.cyan
        : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 3),
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        accent: indicator,
        child: Row(
          children: [
            Container(width: 7, height: 7, color: indicator),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.offWhite,
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChooseRoutePanel extends StatelessWidget {
  const _ChooseRoutePanel({
    super.key,
    required this.legalCount,
    required this.color,
  });

  final int legalCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        accent: color,
        child: Row(
          children: [
            AcademicHexBadge(label: '$legalCount', color: color, size: 38),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  HudLabel('RUTAS DISPONIBLES', color: AppColors.cyan),
                  SizedBox(height: 3),
                  Text(
                    'Toca un hexágono iluminado. Solo puedes avanzar desde tu posición actual.',
                    style: TextStyle(
                      color: AppColors.mutedInk,
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 9,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotTurnPanel extends StatelessWidget {
  const _BotTurnPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: PixelPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        accent: AppColors.neonPurple,
        glow: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HudLabel(
              'EL BOT ESTÁ RESOLVIENDO UN RETO',
              color: AppColors.neonPurple,
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              minHeight: 4,
              color: AppColors.neonPurple,
              backgroundColor: AppColors.royalPurple.withAlpha(190),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoQuestionPanel extends StatelessWidget {
  const _DemoQuestionPanel({
    super.key,
    required this.question,
    required this.selectedOption,
    required this.onSelect,
    required this.onSubmit,
  });

  final DemoQuestion question;
  final String? selectedOption;
  final ValueChanged<String> onSelect;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('demo-question-panel'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: PixelPanel(
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
        accent: AppColors.brightRed,
        glow: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AcademicHexBadge(
                  label: '?',
                  color: AppColors.brightRed,
                  size: 35,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HudLabel(question.subject, color: AppColors.gold),
                      const SizedBox(height: 3),
                      Text(
                        question.prompt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.offWhite,
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          height: 1.22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.55,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final option in question.options.entries)
                  _AnswerOption(
                    optionId: option.key,
                    text: option.value,
                    selected: selectedOption == option.key,
                    onTap: () => onSelect(option.key),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                key: const Key('demo-submit-answer'),
                onPressed: onSubmit,
                child: const Text('CONFIRMAR RESPUESTA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.optionId,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String optionId;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('demo-option-$optionId'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.crimsonRed.withAlpha(145)
                : AppColors.voidBlack.withAlpha(220),
            border: Border.all(
              color: selected ? AppColors.offWhite : AppColors.shadowPurple,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                optionId,
                style: TextStyle(
                  color: selected ? AppColors.gold : AppColors.brightRed,
                  fontFamily: AppTheme.displayFont,
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 8,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoResultOverlay extends StatelessWidget {
  const _DemoResultOverlay({
    required this.winner,
    required this.redScore,
    required this.purpleScore,
    required this.onReset,
    required this.onExit,
  });

  final DemoBattleSide winner;
  final String redScore;
  final String purpleScore;
  final VoidCallback onReset;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final redWon = winner == DemoBattleSide.red;
    final color = redWon ? AppColors.brightRed : AppColors.neonPurple;
    return ColoredBox(
      color: AppColors.voidBlack.withAlpha(225),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PixelPanel(
            padding: const EdgeInsets.all(20),
            accent: color,
            glow: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SchoolTower(color: color, size: 104, flagRight: redWon),
                  const SizedBox(height: 12),
                  Text(
                    redWon ? 'VICTORIA' : 'DERROTA',
                    style: TextStyle(
                      color: AppColors.offWhite,
                      fontFamily: AppTheme.displayFont,
                      fontSize: 22,
                      shadows: [Shadow(color: color, blurRadius: 16)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    redWon
                        ? 'Conquistaste la torre morada.'
                        : 'El BOT alcanzó tu torre roja.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ACIERTOS  TÚ $redScore  /  BOT $purpleScore',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontFamily: AppTheme.displayFont,
                      fontSize: 8,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('demo-reset-button'),
                      onPressed: onReset,
                      child: const Text('JUGAR DE NUEVO'),
                    ),
                  ),
                  TextButton(onPressed: onExit, child: const Text('VOLVER')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
