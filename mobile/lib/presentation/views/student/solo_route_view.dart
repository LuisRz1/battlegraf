import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/solo_campaign.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/solo_journey_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/player_avatar.dart';
import '../battle/bot_battle_demo_controller.dart';
import '../battle/bot_battle_demo_view.dart';

class SoloRouteView extends ConsumerWidget {
  const SoloRouteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(soloJourneyProvider);
    final campaign = ref.watch(soloCampaignProvider);
    final nodes = campaign.nodes;
    const mapHeight = 750.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PanelBox(
          span: 'CAMPAÑA PERSONAL',
          title: 'RUTA AL CASTILLO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${campaign.grade} · ${campaign.subject}',
                style: const TextStyle(color: AppColors.crema300, fontSize: 13),
              ),
              const SizedBox(height: 7),
              const Text(
                'Elige un camino, resuelve sus retos y conquista la fortaleza. Tu avance se guarda aunque pierdas conexión.',
                style: TextStyle(
                  color: AppColors.crema500,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              if (journey.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  journey.error!,
                  style: const TextStyle(color: AppColors.oro300, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        PanelBox(
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final centers = {
                for (final node in nodes)
                  node.id: Offset(
                    width *
                        (node.lane == 0
                            ? .23
                            : node.lane == 2
                            ? .77
                            : .5),
                    44 + node.row * 112,
                  ),
              };
              return SizedBox(
                height: mapHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/panel_map_bg.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const ColoredBox(color: AppColors.piedra950),
                      ),
                    ),
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xAA0D0C14)),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SoloRoutePainter(
                          centers: centers,
                          selectedRoute: journey.selectedRoute,
                          completed: journey.completed.keys.toSet(),
                        ),
                      ),
                    ),
                    for (final node in nodes)
                      Positioned(
                        left: centers[node.id]!.dx - 45,
                        top: centers[node.id]!.dy - 40,
                        width: 90,
                        height: 104,
                        child: _RouteNodeButton(
                          node: node,
                          unlocked: journey.isUnlocked(node),
                          completed: journey.isComplete(node.id),
                          onTap: () => _openNode(context, ref, node, campaign),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        PanelBox(
          span: 'ESTADO DE RUTA',
          title: '${journey.completedCount} NODOS · ${journey.experience} XP',
          child: Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: AppColors.legion),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  journey.isLoading
                      ? 'Sincronizando el progreso…'
                      : 'Avance sincronizado cuando hay internet; disponible offline.',
                  style: const TextStyle(
                    color: AppColors.crema500,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sincronizar',
                onPressed: () async {
                  await ref.read(authProvider.notifier).refreshProfile();
                  await ref
                      .read(soloJourneyProvider.notifier)
                      .load(forceCloud: true);
                  ref.invalidate(playerProfileProvider);
                },
                icon: const Icon(Icons.sync, color: AppColors.oro300),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openNode(
    BuildContext context,
    WidgetRef ref,
    SoloCampaignNode node,
    SoloCampaignDefinition campaign,
  ) async {
    final notifier = ref.read(soloJourneyProvider.notifier);
    final state = ref.read(soloJourneyProvider);
    if (!state.isUnlocked(node) || state.isComplete(node.id)) return;

    if (node.kind == SoloNodeKind.choice) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.piedra900,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PanelBox(
                  span: 'GUARDIANA DEL MAPA',
                  child: Row(
                    children: [
                      const PlayerAvatar(size: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dos pistas salen del cruce. Elige qué desafío quieres resolver primero.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const PanelHeader(
                  padded: false,
                  span: 'DECISIÓN DE CAMINO',
                  title: '¿POR DÓNDE VAMOS?',
                  description: 'Cada sendero tendrá sus propios retos.',
                ),
                const SizedBox(height: 12),
                for (final option in node.choices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PanelBox(
                      child: PanelRow(
                        leading: Icon(
                          option.id == 'forest'
                              ? Icons.park_outlined
                              : Icons.account_balance_outlined,
                          color: option.id == 'forest'
                              ? AppColors.legion
                              : AppColors.oro300,
                        ),
                        title: option.title,
                        subtitle: option.description,
                        trailing: const Icon(
                          Icons.arrow_forward,
                          color: AppColors.oro300,
                        ),
                        onTap: () => Navigator.pop(context, option.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (choice == null) return;
      final selected = await notifier.chooseRoute(choice);
      if (selected) ref.invalidate(playerProfileProvider);
      return;
    }

    if (node.kind == SoloNodeKind.boss) {
      final pool = [
        for (var index = 0; index < campaign.questions.length; index++)
          DemoQuestion(
            id: 'solo-${campaign.id}-$index',
            nodeId: 'solo-$index',
            subject: campaign.subject,
            prompt: campaign.questions[index].prompt,
            options: campaign.questions[index].options,
            correctOption: campaign.questions[index].correctOption,
          ),
      ];
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => BotBattleDemoView(
            pool: pool,
            layers: 4,
            nodesPerLayer: 3,
            onFinished: (winner, playerScore, _) {
              if (winner == DemoBattleSide.red) {
                unawaited(
                  notifier
                      .completeNode(
                        node.id,
                        score: playerScore * 20,
                        stars: playerScore >= 5
                            ? 3
                            : playerScore >= 3
                            ? 2
                            : 1,
                      )
                      .then((completed) {
                        if (completed) ref.invalidate(playerProfileProvider);
                      }),
                );
              }
            },
          ),
        ),
      );
      return;
    }

    if (node.kind == SoloNodeKind.treasure) {
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.piedra900,
          title: const Text('COFRE DESCUBIERTO'),
          content: Text('${node.subtitle}\n\n¿Abrimos el cofre?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('MÁS TARDE'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ABRIR'),
            ),
          ],
        ),
      );
      if (open != true) return;
      final completed = await notifier.completeNode(
        node.id,
        score: 100,
        stars: 3,
      );
      if (completed) ref.invalidate(playerProfileProvider);
      return;
    }

    final question =
        campaign.questions[node.questionIndex % campaign.questions.length];
    var selectedOption = '';
    final answer = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.piedra900,
          title: Text(node.title.toUpperCase()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.prompt),
              const SizedBox(height: 12),
              for (final option in question.options.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () =>
                        setDialogState(() => selectedOption = option.key),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selectedOption == option.key
                            ? AppColors.imperio.withValues(alpha: .16)
                            : AppColors.piedra950,
                        border: Border.all(
                          color: selectedOption == option.key
                              ? AppColors.oro300
                              : AppColors.bordeOro,
                        ),
                      ),
                      child: Text('${option.key}. ${option.value}'),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CERRAR'),
            ),
            FilledButton(
              onPressed: selectedOption.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, selectedOption),
              child: const Text('RESPONDER'),
            ),
          ],
        ),
      ),
    );
    if (answer == null) return;
    if (answer != question.correctOption) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revisa las pistas e intenta de nuevo.'),
          ),
        );
      }
      return;
    }
    final completed = await notifier.completeNode(
      node.id,
      score: 100,
      stars: 3,
    );
    if (completed) ref.invalidate(playerProfileProvider);
  }
}

class _RouteNodeButton extends StatelessWidget {
  const _RouteNodeButton({
    required this.node,
    required this.unlocked,
    required this.completed,
    required this.onTap,
  });

  final SoloCampaignNode node;
  final bool unlocked;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = !unlocked
        ? AppColors.piedra600
        : completed
        ? AppColors.legion
        : node.kind == SoloNodeKind.boss || node.kind == SoloNodeKind.castle
        ? AppColors.imperio
        : AppColors.oro500;
    final icon = switch (node.kind) {
      SoloNodeKind.lesson => Icons.menu_book_outlined,
      SoloNodeKind.choice => Icons.alt_route,
      SoloNodeKind.treasure => Icons.inventory_2_outlined,
      SoloNodeKind.castle => Icons.castle_outlined,
      SoloNodeKind.boss => Icons.shield_outlined,
    };

    return Tooltip(
      message: node.subtitle,
      child: InkWell(
        onTap: unlocked && !completed ? onTap : null,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.piedra950,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2.5),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: .3),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: completed
                  ? const Icon(Icons.check, color: AppColors.legion, size: 27)
                  : !unlocked
                  ? const Icon(
                      Icons.lock_outline,
                      color: AppColors.crema500,
                      size: 23,
                    )
                  : switch (node.kind) {
                      SoloNodeKind.treasure => Image.asset(
                        'assets/images/panel_icon_chest.webp',
                        width: 37,
                        height: 37,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(icon, color: accent),
                      ),
                      SoloNodeKind.castle => Image.asset(
                        'assets/images/panel_base_team.webp',
                        width: 43,
                        height: 43,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(icon, color: accent),
                      ),
                      SoloNodeKind.boss => Image.asset(
                        'assets/images/panel_node_dispute.webp',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(icon, color: accent),
                      ),
                      _ => Icon(icon, color: accent, size: 26),
                    },
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 86,
              child: Text(
                node.title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  color: unlocked ? AppColors.crema100 : AppColors.crema500,
                  fontSize: 7.5,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoloRoutePainter extends CustomPainter {
  const _SoloRoutePainter({
    required this.centers,
    required this.selectedRoute,
    required this.completed,
  });

  final Map<String, Offset> centers;
  final String? selectedRoute;
  final Set<String> completed;

  static const _edges = <(String, String)>[
    ('first_step', 'path_choice'),
    ('path_choice', 'forest_lesson'),
    ('path_choice', 'ruins_lesson'),
    ('forest_lesson', 'forest_treasure'),
    ('ruins_lesson', 'ruins_treasure'),
    ('forest_treasure', 'castle_gate'),
    ('ruins_treasure', 'castle_gate'),
    ('castle_gate', 'castle_boss'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in _edges) {
      final from = centers[edge.$1];
      final to = centers[edge.$2];
      if (from == null || to == null) continue;
      final route = edge.$1.contains('forest') || edge.$2.contains('forest')
          ? 'forest'
          : edge.$1.contains('ruins') || edge.$2.contains('ruins')
          ? 'ruins'
          : null;
      final isChosen =
          route == null || selectedRoute == null || route == selectedRoute;
      final isComplete = completed.contains(edge.$2);
      final paint = Paint()
        ..color = isComplete
            ? AppColors.legion.withValues(alpha: .9)
            : isChosen
            ? AppColors.oro700.withValues(alpha: .85)
            : AppColors.piedra600.withValues(alpha: .5)
        ..strokeWidth = isComplete ? 3 : 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          from.dx,
          from.dy + (to.dy - from.dy) * .42,
          to.dx,
          from.dy + (to.dy - from.dy) * .58,
          to.dx,
          to.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoloRoutePainter oldDelegate) =>
      oldDelegate.selectedRoute != selectedRoute ||
      oldDelegate.completed != completed ||
      oldDelegate.centers != centers;
}
