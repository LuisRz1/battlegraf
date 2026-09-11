import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_ui.dart';

/// Dashboard del alumno: XP, rango, asistencia, notas, tareas,
/// batallas y observaciones visibles.
class StudentDashboardView extends ConsumerStatefulWidget {
  const StudentDashboardView({super.key});

  @override
  ConsumerState<StudentDashboardView> createState() =>
      _StudentDashboardViewState();
}

class _StudentDashboardViewState extends ConsumerState<StudentDashboardView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(studentDashboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(studentDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelHeader(
                span: 'MI AVANCE',
                title: 'DASHBOARD DEL ALUMNO',
                description:
                    '${state.fullName ?? auth.user?['full_name'] ?? 'Alumno'} · '
                    '${auth.user?['school_name'] ?? ''}',
                action: PanelButton(
                  label: 'VOLVER',
                  ghost: true,
                  onTap: () => context.go('/lobby'),
                ),
              ),
              Expanded(child: _buildBody(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(StudentDashboardState state) {
    if (state.isLoading && state.tracking == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.oro500),
      );
    }
    if (state.tracking == null) {
      return PanelEmpty(
        icon: Icons.insights,
        title: 'SIN DATOS',
        message: state.error ?? 'No se pudo cargar tu avance.',
      );
    }
    final rank = state.rankPosition != null && state.sectionRankSize != null
        ? '${state.rankPosition}/${state.sectionRankSize}'
        : '—';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        PanelBox(
          span: 'RESUMEN',
          title: 'MIS ESTADISTICAS',
          child: StatStrip(
            stats: [
              StatPair(value: '${state.xpTotal}', label: 'XP'),
              StatPair(
                value: state.rankName,
                label: 'RANGO',
                valueColor: AppColors.oro300,
              ),
              StatPair(value: rank, label: 'POSICION'),
              StatPair(
                value: state.attendanceRate == null
                    ? '—'
                    : '${state.attendanceRate!.toStringAsFixed(0)}%',
                label: 'ASISTENCIA',
              ),
              StatPair(
                value: state.gradeAverage == null
                    ? '—'
                    : '${state.gradeAverage!.toStringAsFixed(0)}%',
                label: 'PROMEDIO',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PanelButton(
                label: 'JUGAR BATALLA',
                onTap: () => context.push('/battle/setup'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PanelButton(
                label: 'ACTUALIZAR',
                ghost: true,
                onTap: () => ref.read(studentDashboardProvider.notifier).load(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _courses(state),
        const SizedBox(height: 12),
        _assignments(state),
        const SizedBox(height: 12),
        _battles(state),
        const SizedBox(height: 12),
        _observations(state),
      ],
    );
  }

  Widget _courses(StudentDashboardState state) {
    final averages = {
      for (final g in state.gradesBySubject)
        '${g['subject']}': g['average'],
    };
    return PanelBox(
      span: 'CURSOS Y NOTAS',
      title: 'MIS CURSOS',
      child: state.courses.isEmpty
          ? const _EmptyText('Aun no tienes cursos asignados.')
          : Column(
              children: [
                for (final course in state.courses)
                  PanelRow(
                    leading: const Icon(
                      Icons.menu_book,
                      color: AppColors.oro300,
                      size: 20,
                    ),
                    title: '${course['name'] ?? 'Curso'}',
                    subtitle: _teacherNames(course),
                    tag: averages['${course['name']}'] == null
                        ? null
                        : '${averages['${course['name']}']}%',
                    tagColor: _gradeColor(averages['${course['name']}']),
                  ),
              ],
            ),
    );
  }

  String _teacherNames(Map<String, dynamic> course) {
    final teachers = course['teachers'];
    if (teachers is! List || teachers.isEmpty) return 'Sin docente asignado';
    final names = teachers
        .whereType<Map>()
        .map((t) => '${t['full_name'] ?? ''}')
        .where((n) => n.trim().isNotEmpty)
        .toList();
    return names.isEmpty ? 'Sin docente asignado' : names.join(' · ');
  }

  Color _gradeColor(Object? value) {
    final n = value is num ? value.toDouble() : null;
    if (n == null) return AppColors.oro300;
    if (n < 55) return AppColors.imperio;
    if (n < 65) return AppColors.legion;
    return AppColors.aliados;
  }

  Widget _assignments(StudentDashboardState state) {
    final pending = state.pendingAssignments;
    return PanelBox(
      span: 'TAREAS',
      title: '${pending.length} PENDIENTES',
      child: state.assignments.isEmpty
          ? const _EmptyText('No hay tareas programadas por ahora.')
          : Column(
              children: [
                for (final a in state.assignments)
                  PanelRow(
                    leading: Icon(
                      a['submitted'] == true
                          ? Icons.check_circle
                          : Icons.assignment,
                      color: a['submitted'] == true
                          ? AppColors.aliados
                          : AppColors.oro300,
                      size: 20,
                    ),
                    title: '${a['title'] ?? 'Tarea'}',
                    subtitle:
                        '${a['subject'] ?? 'General'} · vence ${_fmtDate(a['due_at'])}',
                    tag: a['submitted'] == true ? 'ENTREGADA' : 'PENDIENTE',
                    tagColor: a['submitted'] == true
                        ? AppColors.aliados
                        : AppColors.oro300,
                  ),
              ],
            ),
    );
  }

  Widget _battles(StudentDashboardState state) {
    return PanelBox(
      span: 'BATALLAS',
      title: 'MI HISTORIAL',
      child: state.battleResults.isEmpty
          ? const _EmptyText('Aun no registras batallas jugadas.')
          : Column(
              children: [
                for (final b in state.battleResults)
                  PanelRow(
                    leading: const Icon(
                      Icons.sports_esports,
                      color: AppColors.oro300,
                      size: 20,
                    ),
                    title: '${b['subject'] ?? 'Batalla'}',
                    subtitle:
                        'Yo ${b['score'] ?? 0} · Rival ${b['opponent_score'] ?? 0} · ${_fmtDate(b['played_at'])}',
                    tag: '${b['result'] ?? 'jugada'}'.toUpperCase(),
                    tagColor: AppColors.aliados,
                  ),
              ],
            ),
    );
  }

  Widget _observations(StudentDashboardState state) {
    return PanelBox(
      span: 'ACOMPANAMIENTO',
      title: 'OBSERVACIONES',
      child: state.observations.isEmpty
          ? const _EmptyText('No tienes observaciones visibles.')
          : Column(
              children: [
                for (final o in state.observations)
                  PanelRow(
                    leading: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.oro300,
                      size: 20,
                    ),
                    title: '${o['note'] ?? ''}',
                    subtitle:
                        '${o['category'] ?? 'academico'} · ${_fmtDate(o['created_at'])}',
                  ),
              ],
            ),
    );
  }

  String _fmtDate(Object? value) {
    final text = '${value ?? ''}';
    if (text.isEmpty || text == 'null') return '—';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        fontFamily: AppTheme.bodyFont,
        color: AppColors.crema500,
        fontSize: 12.5,
        height: 1.4,
      ),
    );
  }
}
