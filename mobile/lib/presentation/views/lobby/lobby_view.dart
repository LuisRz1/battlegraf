import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/retro_controls.dart';
import '../../widgets/retro_ui.dart';

class LobbyView extends ConsumerWidget {
  const LobbyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      body: BattleBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RetroScreenHeader(
                  title: 'LOBBY',
                  accent: AppColors.brightRed,
                  actionLabel: 'SALIR',
                  onAction: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
                const SizedBox(height: 14),
                PixelPanel(
                  accent: AppColors.brightRed,
                  glow: true,
                  child: Row(
                    children: [
                      const SchoolTower(color: AppColors.brightRed, size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const HudLabel('CENTRO DE MANDO'),
                            const SizedBox(height: 4),
                            Text(
                              '${user?['full_name'] ?? 'Guerrero'}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?['role']?.toString().toUpperCase() ??
                                  'USUARIO',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.12),
                const SizedBox(height: 18),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _MenuCard(
                        sigil: 'VS',
                        title: 'BATALLA',
                        accent: AppColors.brightRed,
                        onTap: () => context.go('/battle-lobby'),
                      ),
                      _MenuCard(
                        sigil: 'SEC',
                        title: 'SECCIONES',
                        accent: AppColors.neonPurple,
                        onTap: () {},
                      ),
                      _MenuCard(
                        sigil: 'TXT',
                        title: 'TAREAS',
                        accent: AppColors.cyan,
                        onTap: () => context.go('/tasks'),
                      ),
                      _MenuCard(
                        sigil: 'XP',
                        title: 'RANKING',
                        accent: AppColors.gold,
                        onTap: () => context.go('/progression'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String sigil;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  const _MenuCard({
    required this.sigil,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
          onTap: onTap,
          child: PixelPanel(
            accent: accent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AcademicHexBadge(label: sigil, color: accent, size: 72),
                const SizedBox(height: 12),
                HudLabel(title, color: accent),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(.88, .88), curve: Curves.easeOutBack);
  }
}
