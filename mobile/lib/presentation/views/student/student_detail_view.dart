import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/academic_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_ui.dart';

/// Ficha de un alumno especifico para el equipo docente:
/// cursos con sus docentes, notas, asistencia, tareas, batallas y observaciones.
class StudentDetailView extends ConsumerStatefulWidget {
  const StudentDetailView({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<StudentDetailView> createState() => _StudentDetailViewState();
}

class _StudentDetailViewState extends ConsumerState<StudentDetailView> {
  Map<String, dynamic>? _tracking;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(academicProvider.notifier)
          .loadStudent(widget.studentId);
      if (!mounted) return;
      setState(() {
        _tracking = Map<String, dynamic>.from(result);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _tracking?['student'] as Map?;
    final section = _tracking?['section'] as Map?;
    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelHeader(
                span: 'EXPEDIENTE DEL ALUMNO',
                title: '${student?['full_name'] ?? 'Alumno'}',
                description: section == null
                    ? 'Ficha academica'
                    : '${section['display_name'] ?? ''} · Grado ${section['grade'] ?? ''}',
                action: PanelButton(
                  label: 'VOLVER',
                  ghost: true,
                  onTap: () => context.pop(),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.oro500),
      );
    }
    final tracking = _tracking;
    if (tracking == null) {
      return PanelEmpty(
        icon: Icons.person_off,
        title: 'SIN ACCESO',
        message: _error ?? 'No se pudo cargar la ficha del alumno.',
      );
    }
    final attendance = tracking['attendance_summary'] as Map? ?? const {};
    final rank = tracking['rank'] as Map?;
    final position = tracking['rank_position'];
    final size = tracking['section_rank_size'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        PanelBox(
          span: 'RESUMEN',
          title: 'INDICADORES',
          child: StatStrip(
            stats: [
              StatPair(value: '${tracking['xp_total'] ?? 0}', label: 'XP'),
              StatPair(
                value: rank == null ? 'Sin rango' : '${rank['name']}',
                label: 'RANGO',
                valueColor: AppColors.oro300,
              ),
              StatPair(
                value: position == null || size == null
                    ? '—'
                    : '$position/$size',
                label: 'POSICION',
              ),
              StatPair(
                value: attendance['rate'] == null
                    ? '—'
                    : '${attendance['rate']}%',
                label: 'ASISTENCIA',
              ),
              StatPair(
                value: tracking['grade_average'] == null
                    ? '—'
                    : '${tracking['grade_average']}%',
                label: 'PROMEDIO',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _listBox(
          span: 'CURSOS',
          title: 'CURSOS Y DOCENTES',
          items: _asList(tracking['courses']),
          empty: 'Sin cursos registrados.',
          icon: Icons.menu_book,
          titleOf: (c) => '${c['name'] ?? 'Curso'}',
          subtitleOf: (c) => _teachers(c),
        ),
        const SizedBox(height: 12),
        _listBox(
          span: 'EVALUACIONES',
          title: 'NOTAS',
          items: _asList(tracking['grades']),
          empty: 'Sin notas registradas.',
          icon: Icons.grading,
          titleOf: (g) =>
              '${g['title'] ?? 'Actividad'} · ${g['subject'] ?? 'General'}',
          subtitleOf: (g) =>
              '${g['score'] ?? '-'}/${g['max_score'] ?? '-'}'
              '${(g['feedback'] ?? '').toString().trim().isEmpty ? '' : ' · ${g['feedback']}'}',
        ),
        const SizedBox(height: 12),
        _listBox(
          span: 'TAREAS',
          title: 'ENTREGAS',
          items: _asList(tracking['assignments']),
          empty: 'Sin tareas programadas.',
          icon: Icons.assignment,
          titleOf: (a) => '${a['title'] ?? 'Tarea'}',
          subtitleOf: (a) =>
              '${a['subject'] ?? 'General'} · ${a['submitted'] == true ? 'Entregada' : 'Pendiente'}',
        ),
        const SizedBox(height: 12),
        _listBox(
          span: 'BATALLAS',
          title: 'HISTORIAL',
          items: _asList(tracking['battle_results']),
          empty: 'Sin batallas registradas.',
          icon: Icons.sports_esports,
          titleOf: (b) => '${b['subject'] ?? 'Batalla'}',
          subtitleOf: (b) =>
              'Yo ${b['score'] ?? 0} · Rival ${b['opponent_score'] ?? 0}',
        ),
        const SizedBox(height: 12),
        _listBox(
          span: 'ASISTENCIA',
          title: 'REGISTRO',
          items: _asList(tracking['attendance']),
          empty: 'Sin registros de asistencia.',
          icon: Icons.event_available,
          titleOf: (a) =>
              '${a['attendance_date'] ?? ''} · ${a['status'] ?? ''}',
          subtitleOf: (a) => '${a['note'] ?? ''}',
        ),
        const SizedBox(height: 12),
        _listBox(
          span: 'ACOMPANAMIENTO',
          title: 'OBSERVACIONES',
          items: _asList(tracking['observations']),
          empty: 'Sin observaciones.',
          icon: Icons.chat_bubble_outline,
          titleOf: (o) => '${o['note'] ?? ''}',
          subtitleOf: (o) =>
              '${o['category'] ?? ''} · ${o['status'] ?? ''} · ${o['visibility'] ?? ''}',
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _teachers(Map<String, dynamic> course) {
    final teachers = course['teachers'];
    if (teachers is! List || teachers.isEmpty) return 'Sin docente asignado';
    final names = teachers
        .whereType<Map>()
        .map((t) => '${t['full_name'] ?? ''}')
        .where((n) => n.trim().isNotEmpty)
        .toList();
    return names.isEmpty ? 'Sin docente asignado' : names.join(' · ');
  }

  Widget _listBox({
    required String span,
    required String title,
    required List<Map<String, dynamic>> items,
    required String empty,
    required IconData icon,
    required String Function(Map<String, dynamic>) titleOf,
    required String Function(Map<String, dynamic>) subtitleOf,
  }) {
    return PanelBox(
      span: span,
      title: '$title (${items.length})',
      child: items.isEmpty
          ? Text(
              empty,
              style: const TextStyle(
                fontFamily: AppTheme.bodyFont,
                color: AppColors.crema500,
                fontSize: 12.5,
              ),
            )
          : Column(
              children: [
                for (final item in items)
                  PanelRow(
                    leading: Icon(icon, color: AppColors.oro300, size: 20),
                    title: titleOf(item),
                    subtitle: subtitleOf(item).trim().isEmpty
                        ? null
                        : subtitleOf(item),
                  ),
              ],
            ),
    );
  }
}
