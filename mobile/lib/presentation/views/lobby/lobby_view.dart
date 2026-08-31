import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/institution/presentation/views/institution_hub_view.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/retro_controls.dart';
import '../../widgets/retro_ui.dart';

class LobbyView extends ConsumerWidget {
  const LobbyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = authState.role;
    final menuItems = <_LobbyItem>[
      _LobbyItem(
        sigil: role == 'student' ? 'MIS' : 'ACA',
        title: role == 'student' ? 'MI AVANCE' : 'ACADEMIA',
        accent: AppColors.neonPurple,
        route: '/academics',
      ),
      ...institutionAreasForRole(role).map(
        (area) => _LobbyItem(
          sigil: _sigil(area),
          title: area.label,
          accent: _areaColor(area),
          route: '/institution/${area.slug}',
        ),
      ),
    ];

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
                              roleLabel(user?['role']?.toString() ?? role),
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
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: .95,
                        ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return _MenuCard(
                        sigil: item.sigil,
                        title: item.title,
                        accent: item.accent,
                        onTap: () => context.go(item.route),
                      );
                    },
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

class _LobbyItem {
  const _LobbyItem({
    required this.sigil,
    required this.title,
    required this.accent,
    required this.route,
  });

  final String sigil;
  final String title;
  final Color accent;
  final String route;
}

String _sigil(InstitutionArea area) => switch (area) {
  InstitutionArea.overview => 'CMD',
  InstitutionArea.profile => 'YO',
  InstitutionArea.school => 'IE',
  InstitutionArea.people => 'USR',
  InstitutionArea.sections => 'SEC',
  InstitutionArea.subjects => 'CUR',
  InstitutionArea.classes => 'CLS',
  InstitutionArea.content => 'IA',
  InstitutionArea.tasks => 'TXT',
  InstitutionArea.battles => 'VS',
  InstitutionArea.progress => 'XP',
  InstitutionArea.activity => 'LOG',
};

Color _areaColor(InstitutionArea area) => switch (area) {
  InstitutionArea.overview || InstitutionArea.battles => AppColors.brightRed,
  InstitutionArea.profile => AppColors.cyan,
  InstitutionArea.people ||
  InstitutionArea.subjects ||
  InstitutionArea.content => AppColors.cyan,
  InstitutionArea.sections ||
  InstitutionArea.classes ||
  InstitutionArea.progress => AppColors.gold,
  InstitutionArea.school ||
  InstitutionArea.tasks ||
  InstitutionArea.activity => AppColors.neonPurple,
};

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
