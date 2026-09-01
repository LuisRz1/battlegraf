import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/battle.dart';
import '../../providers/battle_provider.dart';
import '../../widgets/retro_controls.dart';
import '../../widgets/retro_ui.dart';
import '../../widgets/panel_ui.dart';

/// List of active battles that the player can join or watch.
class BattleLobbyView extends ConsumerStatefulWidget {
  const BattleLobbyView({super.key});

  @override
  ConsumerState<BattleLobbyView> createState() => _BattleLobbyViewState();
}

class _BattleLobbyViewState extends ConsumerState<BattleLobbyView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(battleProvider.notifier).loadActiveBattles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final battleState = ref.watch(battleProvider);
    final battles = battleState.activeBattles;

    return Scaffold(
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: PanelHeader(
                                span: 'CONTENDIAS',
                                title: 'BATALLAS',
                                action: PanelButton(
                                  label: 'NUEVA',
                                  ghost: true,
                                  onTap: () => _showCreateBattleDialog(context),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
              Expanded(
                child: battleState.isLoading
                    ? const Center(
                        child: PixelLoader(label: 'BUSCANDO BATALLAS'),
                      )
                    : battles.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        color: AppColors.gold,
                        backgroundColor: AppColors.royalPurple,
                        onRefresh: () async {
                          await ref
                              .read(battleProvider.notifier)
                              .loadActiveBattles();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: battles.length,
                          itemBuilder: (context, index) {
                            final battle = battles[index];
                            final isActive =
                                battle.status.toLowerCase() == 'active' ||
                                battle.status.toLowerCase() == 'in_progress';
                            final isPending =
                                battle.status.toLowerCase() == 'pending';
                            return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: InkWell(
                                    onTap: () => _enterBattle(battle),
                                    child: PixelPanel(
                                      accent: isActive
                                          ? AppColors.brightRed
                                          : AppColors.shadowPurple,
                                      glow: isActive,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  battle.title,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.headlineMedium,
                                                ),
                                              ),
                                              _StatusChip(
                                                status: battle.status,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SchoolTower(
                                                color: AppColors.brightRed,
                                                size: 48,
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                    ),
                                                child: Column(
                                                  children: [
                                                    const HudLabel(
                                                      'POR TURNOS',
                                                      color: AppColors.gold,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      battle.currentTurn == 1
                                                          ? 'MORADO'
                                                          : 'ROJO',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .displayMedium
                                                          ?.copyWith(
                                                            fontSize: 18,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SchoolTower(
                                                color: AppColors.neonPurple,
                                                size: 48,
                                                flagRight: false,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${battle.players.length} jugadores',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: AppColors.gold,
                                                      ),
                                                ),
                                              ),
                                              RetroActionButton(
                                                compact: true,
                                                accent: isPending
                                                    ? AppColors.gold
                                                    : AppColors.brightRed,
                                                onPressed: () =>
                                                    _enterBattle(battle),
                                                label: isPending
                                                    ? 'INICIAR'
                                                    : isActive
                                                    ? 'UNIRSE'
                                                    : 'RESULTADO',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(
                                  duration: 400.ms,
                                  delay: (index * 80).ms,
                                )
                                .slideX(begin: 0.2);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enterBattle(Battle battle) async {
    if (battle.status.toLowerCase() == 'pending') {
      final started = await ref
          .read(battleProvider.notifier)
          .startBattle(battle.id);
      if (!started || !mounted) return;
    }
    if (mounted) context.go('/battle/${battle.id}');
  }

  void _showCreateBattleDialog(BuildContext context) {
    final player1Controller = TextEditingController();
    final player2Controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return RetroDialog(
          title: 'Nueva batalla',
          accent: AppColors.brightRed,
          actions: [
            RetroActionButton(
              label: 'CANCELAR',
              compact: true,
              accent: AppColors.shadowPurple,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            RetroActionButton(
              label: 'CREAR',
              compact: true,
              accent: AppColors.brightRed,
              onPressed: () async {
                final notifier = ref.read(battleProvider.notifier);
                final battle = await notifier.createBattle(
                  player1Controller.text.trim(),
                  player2Controller.text.trim(),
                );
                if (battle != null && dialogContext.mounted) {
                  final started = await notifier.startBattle(battle.id);
                  if (!started || !mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  this.context.go('/battle/${battle.id}');
                }
              },
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: player1Controller,
                decoration: const InputDecoration(labelText: 'ID jugador 1'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: player2Controller,
                decoration: const InputDecoration(labelText: 'ID jugador 2'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      player1Controller.dispose();
      player2Controller.dispose();
    });
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive =
        status.toLowerCase() == 'active' ||
        status.toLowerCase() == 'in_progress';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.gold.withAlpha(60) : AppColors.darkCard,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isActive ? AppColors.gold : AppColors.shadowPurple,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isActive ? AppColors.gold : AppColors.offWhite,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SchoolTower(
            color: AppColors.neonPurple,
            size: 104,
          ).animate().scale(duration: 600.ms),
          const SizedBox(height: 16),
          Text(
            'No hay batallas activas',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Crea una desde la seccion de maestro',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}
