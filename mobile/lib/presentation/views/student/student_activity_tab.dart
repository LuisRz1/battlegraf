import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../providers/solo_journey_provider.dart';
import '../../widgets/panel_ui.dart';

class StudentActivityTab extends ConsumerWidget {
  const StudentActivityTab({required this.isPersonal, super.key});

  final bool isPersonal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solo = ref.watch(soloJourneyProvider);
    final campaign = ref.watch(soloCampaignProvider);
    final school = isPersonal
        ? const StudentDashboardState()
        : ref.watch(studentDashboardProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PanelBox(
          span: isPersonal ? 'MI CAMPAÑA' : 'MI ESPACIO ESCOLAR',
          title: 'ACTIVIDAD RECIENTE',
          child: Text(
            isPersonal
                ? 'Retos y recompensas de tu ruta personal. Tu colegio no ve este avance.'
                : 'Información académica vinculada a tu perfil escolar.',
            style: const TextStyle(
              color: AppColors.crema500,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isPersonal) ...[
          PanelBox(
            span: 'HISTORIAL DE NODOS',
            title: '${solo.completedCount} DESAFÍOS COMPLETADOS',
            child: solo.recentActivity.isEmpty
                ? const _ActivityEmpty(
                    'Completa el primer reto para comenzar tu historial.',
                  )
                : Column(
                    children: [
                      for (final entry in solo.recentActivity)
                        PanelRow(
                          leading: Icon(
                            campaign.node(entry.nodeId).kind.name == 'boss'
                                ? Icons.castle_outlined
                                : Icons.check_circle_outline,
                            color: AppColors.legion,
                            size: 20,
                          ),
                          title: campaign.node(entry.nodeId).title,
                          subtitle:
                              '${campaign.subject} · ${_date(entry.completedAt)}',
                          tag: '+${20 + entry.score ~/ 10} XP',
                          tagColor: AppColors.oro300,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          PanelBox(
            span: 'SIGUIENTE PASO',
            title: 'MANTÉN TU RITMO',
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_outlined,
                  color: AppColors.imperio,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    solo.error ??
                        'Cada nodo completado acerca tu avatar a una nueva recompensa.',
                    style: const TextStyle(
                      color: AppColors.crema500,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          PanelBox(
            span: 'TAREAS',
            title: '${school.pendingAssignments.length} PENDIENTES',
            child: school.pendingAssignments.isEmpty
                ? const _ActivityEmpty('No tienes tareas pendientes.')
                : Column(
                    children: [
                      for (final assignment in school.pendingAssignments.take(
                        8,
                      ))
                        PanelRow(
                          leading: const Icon(
                            Icons.assignment_outlined,
                            color: AppColors.oro300,
                            size: 20,
                          ),
                          title: '${assignment['title'] ?? 'Tarea'}',
                          subtitle:
                              '${assignment['subject'] ?? 'Curso'} · vence ${assignment['due_at'] ?? 'sin fecha'}',
                          tag: 'PENDIENTE',
                          tagColor: AppColors.imperio,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          PanelBox(
            span: 'BATALLAS',
            title: 'ÚLTIMOS RESULTADOS',
            child: school.battleResults.isEmpty
                ? const _ActivityEmpty('Tus resultados aparecerán aquí.')
                : Column(
                    children: [
                      for (final result in school.battleResults.take(8))
                        PanelRow(
                          leading: const Icon(
                            Icons.sports_esports_outlined,
                            color: AppColors.aliados,
                            size: 20,
                          ),
                          title: '${result['subject'] ?? 'Batalla'}',
                          subtitle:
                              'Tú ${result['score'] ?? 0} · rival ${result['opponent_score'] ?? 0}',
                          tag: '${result['result'] ?? 'JUGADA'}'.toUpperCase(),
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: AppColors.crema500, fontSize: 12),
      ),
    ),
  );
}
