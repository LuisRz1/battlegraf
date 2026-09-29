import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/solo_campaign.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/solo_journey_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/player_avatar.dart';

class StudentHomeTab extends ConsumerWidget {
  const StudentHomeTab({
    required this.displayName,
    required this.schoolName,
    required this.isPersonal,
    required this.onContinue,
    required this.onLinkSchool,
    super.key,
  });

  final String displayName;
  final String? schoolName;
  final bool isPersonal;
  final VoidCallback onContinue;
  final VoidCallback onLinkSchool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProfileProvider);
    final journey = ref.watch(soloJourneyProvider);
    final campaign = ref.watch(soloCampaignProvider);
    final school = isPersonal ? null : ref.watch(studentDashboardProvider);
    SoloCampaignNode? nextNode;
    for (final node in campaign.nodes) {
      if (!journey.isComplete(node.id) && journey.isUnlocked(node)) {
        nextNode = node;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PanelBox(
          span: isPersonal ? 'PERFIL PERSONAL' : 'ESPACIO ESCOLAR',
          title: 'BIENVENIDO, ${displayName.toUpperCase()}',
          child: Row(
            children: [
              PlayerAvatar(config: player.avatarConfig, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPersonal ? 'CUENTA DE ALUMNO' : schoolName ?? 'COLEGIO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.displayFont,
                        color: AppColors.oro300,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${player.grade} · ${player.subject}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.crema500,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PanelBox(
          span: isPersonal ? 'AVANCE DE CAMPAÑA' : 'AVANCE ESCOLAR',
          title: isPersonal
              ? '${journey.experience} XP · ${journey.completedCount} NODOS'
              : '${school?.xpTotal ?? 0} XP · ${school?.courses.length ?? 0} CURSOS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _HomeMetric(
                      label: isPersonal ? 'RACHA' : 'ASISTENCIA',
                      value: isPersonal
                          ? _streakFrom(journey.recentActivity).toString()
                          : school?.attendanceRate == null
                          ? '—'
                          : '${school!.attendanceRate!.toStringAsFixed(0)}%',
                      icon: isPersonal
                          ? Icons.local_fire_department_outlined
                          : Icons.event_available_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HomeMetric(
                      label: isPersonal ? 'LOGROS' : 'PROMEDIO',
                      value: isPersonal
                          ? player.ownedItems.length.toString()
                          : school?.gradeAverage == null
                          ? '—'
                          : '${school!.gradeAverage!.toStringAsFixed(0)}%',
                      icon: isPersonal
                          ? Icons.workspace_premium_outlined
                          : Icons.grade_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HomeMetric(
                      label: isPersonal ? 'RUTA' : 'TAREAS',
                      value: isPersonal
                          ? 'SOLO'
                          : '${school?.pendingAssignments.length ?? 0}',
                      icon: isPersonal
                          ? Icons.route
                          : Icons.assignment_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.piedra900,
                  border: Border.all(color: AppColors.bordeOro),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: AppColors.imperio),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPersonal
                                ? 'SIGUIENTE DESAFÍO'
                                : 'SIGUIENTE TAREA',
                            style: const TextStyle(
                              fontFamily: AppTheme.displayFont,
                              color: AppColors.imperio,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPersonal
                                ? nextNode?.title ?? 'Ruta completada'
                                : school
                                          ?.pendingAssignments
                                          .firstOrNull?['title']
                                          ?.toString() ??
                                      'Todo al día',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.crema100,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PanelButton(
                  label: isPersonal
                      ? nextNode == null
                            ? 'REVISAR MI RUTA'
                            : 'CONTINUAR RUTA'
                      : 'ABRIR ESPACIO ESCOLAR',
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  onTap: onContinue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isPersonal)
          PanelBox(
            span: 'ACTIVIDAD RECIENTE',
            title: 'ÚLTIMOS LOGROS',
            child: journey.recentActivity.isEmpty
                ? const Text(
                    'Completa un nodo para registrar tu primera actividad.',
                    style: TextStyle(color: AppColors.crema500, height: 1.4),
                  )
                : Column(
                    children: [
                      for (final entry in journey.recentActivity.take(3))
                        PanelRow(
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.legion,
                            size: 19,
                          ),
                          title: campaign.node(entry.nodeId).title,
                          subtitle:
                              '+${20 + entry.score ~/ 10} XP · ${_timeAgo(entry.completedAt)}',
                          tag: '${entry.stars}★',
                          tagColor: AppColors.oro300,
                        ),
                    ],
                  ),
          )
        else
          PanelBox(
            span: 'ACTIVIDAD ESCOLAR',
            title: 'TUS PRÓXIMOS PASOS',
            child: school?.pendingAssignments.isNotEmpty == true
                ? Column(
                    children: [
                      for (final task in school!.pendingAssignments.take(3))
                        PanelRow(
                          leading: const Icon(
                            Icons.assignment_outlined,
                            color: AppColors.imperio,
                          ),
                          title: '${task['title'] ?? 'Tarea'}',
                          subtitle: '${task['subject'] ?? 'Curso'}',
                          tag: 'PENDIENTE',
                          tagColor: AppColors.oro300,
                        ),
                    ],
                  )
                : const Text(
                    'No hay tareas pendientes. Puedes practicar con tus cursos.',
                    style: TextStyle(color: AppColors.crema500, height: 1.4),
                  ),
          ),
        if (isPersonal && !ref.watch(authProvider).hasSchoolMembership) ...[
          const SizedBox(height: 12),
          PanelBox(
            span: 'CUENTA GRATUITA',
            title: '¿TU COLEGIO YA ESTÁ EN BATTLEGRAPH?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vincula un código escolar para ver tus clases, tareas, notas y recursos. Tu ruta personal no se pierde.',
                  style: TextStyle(color: AppColors.crema500, height: 1.4),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PanelButton(
                    label: 'VINCULAR COLEGIO',
                    ghost: true,
                    onTap: onLinkSchool,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  int _streakFrom(List<SoloProgressEntry> entries) {
    if (entries.isEmpty) return 0;
    final days = entries.map((entry) {
      final date = entry.completedAt.toLocal();
      return DateTime(date.year, date.month, date.day);
    }).toSet();
    var streak = 0;
    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _timeAgo(DateTime date) {
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.inMinutes < 1) return 'Ahora';
    if (elapsed.inHours < 1) return 'Hace ${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return 'Hace ${elapsed.inHours} h';
    return 'Hace ${elapsed.inDays} días';
  }
}

class _HomeMetric extends StatelessWidget {
  const _HomeMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.piedra900,
        border: Border.all(color: AppColors.bordeOro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.oro300, size: 17),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              color: AppColors.crema100,
              fontSize: 10,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              color: AppColors.crema500,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
}
