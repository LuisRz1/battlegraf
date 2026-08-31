import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progression_provider.dart';
import '../../widgets/retro_controls.dart';
import '../../widgets/retro_ui.dart';

class ProgressionView extends ConsumerStatefulWidget {
  const ProgressionView({super.key});

  @override
  ConsumerState<ProgressionView> createState() => _ProgressionViewState();
}

class _ProgressionViewState extends ConsumerState<ProgressionView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(progressionProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(progressionProvider);
    final userId = ref.watch(authProvider).user?['id']?.toString();
    return Scaffold(
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: RetroScreenHeader(
                  title: 'PROGRESIÓN',
                  onBack: () => context.go('/lobby'),
                  actionLabel: 'ACTUALIZAR',
                  onAction: () => ref.read(progressionProvider.notifier).load(),
                  accent: AppColors.gold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: state.isLoading && state.profile == null
                    ? const PixelLoader(
                        label: 'CARGANDO RANGO',
                        color: AppColors.gold,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (state.error != null)
                            PixelPanel(
                              accent: AppColors.brightRed,
                              padding: const EdgeInsets.all(10),
                              child: HudLabel(
                                state.error!,
                                color: AppColors.brightRed,
                              ),
                            ),
                          _ProfileCard(
                            xp: state.profile?.xp ?? 0,
                            rank: state.profile?.rankName ?? 'Sin rango',
                            clan: state.profile?.clanName ?? 'Sin clan',
                          ).animate().fadeIn().slideY(begin: -0.15),
                          const SizedBox(height: 20),
                          Text(
                            'RANKING DE SECCIÓN',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          ...state.leaderboard.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: PixelPanel(
                                accent: entry.userId == userId
                                    ? AppColors.brightRed
                                    : AppColors.shadowPurple,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    AcademicHexBadge(
                                      label: '${entry.position}',
                                      color: entry.userId == userId
                                          ? AppColors.brightRed
                                          : AppColors.gold,
                                      size: 42,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        entry.displayName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    ),
                                    HudLabel(
                                      '${entry.xp} XP',
                                      color: AppColors.gold,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (state.leaderboard.isEmpty)
                            const PixelPanel(
                              accent: AppColors.gold,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AcademicHexBadge(
                                    label: 'XP',
                                    color: AppColors.gold,
                                    size: 54,
                                  ),
                                  SizedBox(height: 12),
                                  HudLabel(
                                    'AÚN NO HAY DATOS DE CLASIFICACIÓN',
                                    color: AppColors.gold,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final int xp;
  final String rank;
  final String clan;

  const _ProfileCard({
    required this.xp,
    required this.rank,
    required this.clan,
  });

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      accent: AppColors.gold,
      glow: true,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const SchoolTower(color: AppColors.gold, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rank, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('$xp XP · $clan'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
