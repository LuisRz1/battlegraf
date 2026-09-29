import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/panel_ui.dart';

class StudentSchoolTab extends ConsumerWidget {
  const StudentSchoolTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final student = ref.watch(studentDashboardProvider);
    final courses = student.courses;

    return RefreshIndicator(
      onRefresh: ref.read(studentDashboardProvider.notifier).load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          PanelBox(
            span: 'ESPACIO ESCOLAR',
            title: auth.user?['school_name']?.toString() ?? 'MI COLEGIO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aquí encuentras únicamente tus clases, cursos y avance personal del colegio.',
                  style: TextStyle(
                    color: AppColors.crema500,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PanelMiniButton(
                      label: 'MIS CLASES',
                      onTap: () => context.go('/institution/clases'),
                    ),
                    PanelMiniButton(
                      label: 'AVANCE COMPLETO',
                      onTap: () => context.go('/student'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PanelBox(
            span: 'CURSOS ASIGNADOS',
            title: '${courses.length} MATERIAS',
            child: courses.isEmpty
                ? const _SchoolEmpty('Todavía no tienes cursos asignados.')
                : Column(
                    children: [
                      for (final course in courses)
                        PanelRow(
                          leading: const Icon(
                            Icons.menu_book_outlined,
                            color: AppColors.oro300,
                          ),
                          title: '${course['name'] ?? 'Curso'}',
                          subtitle: _teachers(course),
                          tag: _courseAverage(student, course),
                          tagColor: AppColors.legion,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          PanelBox(
            span: 'TAREAS ESCOLARES',
            title: '${student.pendingAssignments.length} PENDIENTES',
            child: student.pendingAssignments.isEmpty
                ? const _SchoolEmpty('No tienes tareas pendientes.')
                : Column(
                    children: [
                      for (final assignment in student.pendingAssignments.take(
                        5,
                      ))
                        PanelRow(
                          leading: const Icon(
                            Icons.assignment_outlined,
                            color: AppColors.imperio,
                          ),
                          title: '${assignment['title'] ?? 'Tarea'}',
                          subtitle:
                              '${assignment['subject'] ?? 'Curso'} · ${assignment['due_at'] ?? 'sin fecha'}',
                          tag: 'PENDIENTE',
                          tagColor: AppColors.oro300,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          PanelBox(
            span: 'ACCESOS DEL ALUMNO',
            title: 'SIGUIENTE ACCIÓN',
            child: Column(
              children: [
                _SchoolAction(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Entregar una tarea',
                  subtitle: 'Revisa tus pendientes y comentarios.',
                  onTap: () => context.go('/institution/tareas'),
                ),
                _SchoolAction(
                  icon: Icons.sports_esports_outlined,
                  title: 'Practicar con preguntas del colegio',
                  subtitle: 'Usa los cursos vinculados a tu perfil.',
                  onTap: () => context.go('/battle/setup'),
                ),
                _SchoolAction(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Hablar con el asistente',
                  subtitle: 'Consulta contenidos del espacio escolar.',
                  onTap: () => context.go('/assistant'),
                ),
              ],
            ),
          ),
          if (student.error != null) ...[
            const SizedBox(height: 10),
            Text(
              student.error!,
              style: const TextStyle(color: AppColors.oro300, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _teachers(Map<String, dynamic> course) {
    final teachers = course['teachers'];
    if (teachers is! List || teachers.isEmpty) return 'Docente por asignar';
    final names = teachers
        .whereType<Map>()
        .map((teacher) => '${teacher['full_name'] ?? ''}')
        .where((name) => name.trim().isNotEmpty)
        .toList();
    return names.isEmpty ? 'Docente por asignar' : names.join(' · ');
  }

  String? _courseAverage(
    StudentDashboardState state,
    Map<String, dynamic> course,
  ) {
    for (final row in state.gradesBySubject) {
      if ('${row['subject_id']}' == '${course['id']}' &&
          row['average'] is num) {
        return '${(row['average'] as num).toStringAsFixed(0)}%';
      }
    }
    return null;
  }
}

class _SchoolAction extends StatelessWidget {
  const _SchoolAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PanelRow(
    leading: Icon(icon, color: AppColors.oro300),
    title: title,
    subtitle: subtitle,
    trailing: const Icon(Icons.chevron_right, color: AppColors.crema500),
    onTap: onTap,
  );
}

class _SchoolEmpty extends StatelessWidget {
  const _SchoolEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(color: AppColors.crema500)),
    ),
  );
}
