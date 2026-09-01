import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/institution/presentation/views/institution_hub_view.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_ui.dart';

/// Centro de mando del estudiante — mismo lenguaje visual del panel web.
class LobbyView extends ConsumerWidget {
  const LobbyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = authState.role;
    final isStudent = role == 'student';

    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelHeader(
                span: 'CENTRO DE MANDO',
                title: 'BATTLEGRAPH',
                description: '${user?['full_name'] ?? 'Guerrero'} · ${roleLabel(user?['role']?.toString() ?? role)}',
                action: PanelButton(
                  label: 'SALIR',
                  ghost: true,
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  children: [
                    // Perfil del estudiante
                    PanelBox(
                      span: 'IDENTIDAD',
                      title: 'MI PERFIL',
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.piedra900,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.bordeOro, width: 1.3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Image.asset(
                                'assets/images/battlegraph_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                    const Icon(Icons.games, color: AppColors.oro500, size: 30),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?['full_name'] ?? 'Guerrero',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.displayFont,
                                    color: AppColors.oro300,
                                    fontSize: 14,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  roleLabel(user?['role']?.toString() ?? role),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.bodyFont,
                                    color: AppColors.crema500,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Acciones principales del estudiante
                    PanelBox(
                      span: 'MISIONES',
                      title: '¿QUE QUIERES HACER?',
                      child: Column(
                        children: [
                          _LobbyTile(
                            icon: Icons.sports_esports,
                            title: 'JUGAR',
                            subtitle: 'Batalla por turnos · responde y conquista',
                            accent: AppColors.oro500,
                            onTap: () => context.go('/battle/demo-bot'),
                          ),
                          _LobbyTile(
                            icon: Icons.assignment,
                            title: 'TAREAS',
                            subtitle: 'Revisa lo que debes entregar',
                            accent: AppColors.aliados,
                            onTap: () => context.go('/institution/tasks'),
                          ),
                          _LobbyTile(
                            icon: Icons.school,
                            title: 'CLASES',
                            subtitle: 'Tus cursos y codigos de clase',
                            accent: AppColors.imperio,
                            onTap: () => context.go('/institution/classes'),
                          ),
                          _LobbyTile(
                            icon: Icons.insights,
                            title: 'MI AVANCE',
                            subtitle: 'XP, rango y progreso por curso',
                            accent: AppColors.legion,
                            onTap: () => context.go('/academics'),
                          ),
                          if (!isStudent)
                            ...institutionAreasForRole(role).map(
                              (area) => _LobbyTile(
                                icon: Icons.dashboard,
                                title: area.label,
                                subtitle: 'Panel de ${area.label.toLowerCase()}',
                                accent: AppColors.neonPurple,
                                onTap: () => context.go('/institution/${area.slug}'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const PanelBox(
                      span: 'HUD',
                      title: 'ESTADO',
                      child: Text(
                        'Conectado al centro de mando. Las batallas usan las preguntas '
                        'aprobadas por tus docentes y el avance se registra por curso.',
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          color: AppColors.crema500,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
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

class _LobbyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _LobbyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.bordeOro, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withAlpha(26),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: accent.withAlpha(160), width: 1.1),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      color: AppColors.crema100,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      color: AppColors.crema500,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.bordeOro, size: 20),
          ],
        ),
      ),
    );
  }
}