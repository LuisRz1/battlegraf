import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/academic_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/retro_controls.dart';
import '../../widgets/retro_ui.dart';

class AcademicOverviewView extends ConsumerWidget {
  const AcademicOverviewView({super.key});

  bool _canManage(String role) => [
    'owner',
    'director',
    'subdirector',
    'coordinator',
    'tutor',
    'teacher',
  ].contains(role);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(academicProvider);
    final auth = ref.watch(authProvider);
    final canManage = _canManage(auth.role);

    return Scaffold(
      body: BattleBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: ref.read(academicProvider.notifier).load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RetroScreenHeader(
                  title: auth.role == 'student' ? 'MI AVANCE' : 'SEGUIMIENTO',
                  accent: AppColors.cyan,
                  actionLabel: canManage ? 'ACCIONES' : 'ACTUALIZAR',
                  onAction: canManage
                      ? () => _showActions(context, ref, state)
                      : () => ref.read(academicProvider.notifier).load(),
                ),
                const SizedBox(height: 14),
                if (state.isLoading && state.overview == null)
                  const SizedBox(
                    height: 360,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.error != null && state.overview == null)
                  _ErrorPanel(
                    message: state.error!,
                    onRetry: ref.read(academicProvider.notifier).load,
                  )
                else ...[
                  _Metrics(metrics: state.metrics),
                  const SizedBox(height: 14),
                  _SubjectPerformance(
                    rows: List<Map<String, dynamic>>.from(
                      state.overview?['subject_performance'] as List? ??
                          const [],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PixelPanel(
                    accent: AppColors.neonPurple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HudLabel(
                          'FICHAS DE ESTUDIANTES',
                          color: AppColors.offWhite,
                        ),
                        const SizedBox(height: 10),
                        if (state.students.isEmpty)
                          const Text(
                            'Aún no hay alumnos o registros visibles para este rol.',
                          )
                        else
                          ...state.students.map(
                            (student) => _StudentTile(
                              student: student,
                              onTap: () => _showStudent(context, ref, student),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, AcademicState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.deepPurple,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HudLabel('GESTIÓN ACADÉMICA', color: AppColors.gold),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.how_to_reg,
                title: 'ASISTENCIA DE HOY',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _attendanceDialog(context, ref, state.students);
                },
              ),
              _ActionTile(
                icon: Icons.assignment_add,
                title: 'CREAR EVALUACIÓN',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _gradeItemDialog(context, ref, state.overview ?? const {});
                },
              ),
              _ActionTile(
                icon: Icons.grade,
                title: 'REGISTRAR NOTA',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _gradeDialog(context, ref, state);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _attendanceDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> students,
  ) async {
    final statuses = {
      for (final student in students) '${student['id']}': 'present',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: const Text('Asistencia de hoy'),
          content: SizedBox(
            width: 560,
            child: students.isEmpty
                ? const Text('No hay estudiantes visibles.')
                : ListView(
                    shrinkWrap: true,
                    children: students
                        .map(
                          (student) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${student['full_name']}'),
                            subtitle: Text(
                              '${(student['section'] as Map?)?['display_name'] ?? 'Sin sección'}',
                            ),
                            trailing: DropdownButton<String>(
                              value: statuses['${student['id']}'],
                              dropdownColor: AppColors.darkCard,
                              items: const [
                                DropdownMenuItem(
                                  value: 'present',
                                  child: Text('Presente'),
                                ),
                                DropdownMenuItem(
                                  value: 'late',
                                  child: Text('Tardanza'),
                                ),
                                DropdownMenuItem(
                                  value: 'absent',
                                  child: Text('Falta'),
                                ),
                                DropdownMenuItem(
                                  value: 'excused',
                                  child: Text('Justificada'),
                                ),
                              ],
                              onChanged: (value) => setLocalState(
                                () => statuses['${student['id']}'] =
                                    value ?? 'present',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: students.isEmpty
                  ? null
                  : () async {
                      final ok = await ref
                          .read(academicProvider.notifier)
                          .saveAttendance(DateTime.now(), statuses);
                      if (!dialogContext.mounted) return;
                      if (ok) {
                        Navigator.pop(dialogContext);
                      } else {
                        _showAcademicError(dialogContext, ref);
                      }
                    },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _gradeItemDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> overview,
  ) async {
    final subjects = List<Map<String, dynamic>>.from(
      overview['subjects'] as List? ?? const [],
    );
    final sections = List<Map<String, dynamic>>.from(
      overview['sections'] as List? ?? const [],
    );
    final title = TextEditingController();
    final maximum = TextEditingController(text: '20');
    String? subjectId = subjects.isEmpty ? null : '${subjects.first['id']}';
    String? sectionId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: const Text('Nueva evaluación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(labelText: 'Curso'),
                  items: subjects
                      .map(
                        (subject) => DropdownMenuItem(
                          value: '${subject['id']}',
                          child: Text('${subject['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocalState(() => subjectId = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: sectionId,
                  decoration: const InputDecoration(labelText: 'Sección'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    ...sections.map(
                      (section) => DropdownMenuItem(
                        value: '${section['id']}',
                        child: Text('${section['display_name']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocalState(() => sectionId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maximum,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puntaje máximo',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: subjectId == null
                  ? null
                  : () async {
                      final normalizedTitle = title.text.trim();
                      if (normalizedTitle.length < 3) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Escribe un título de al menos 3 caracteres.',
                            ),
                          ),
                        );
                        return;
                      }
                      final ok = await ref
                          .read(academicProvider.notifier)
                          .createGradeItem(
                            title: normalizedTitle,
                            subjectId: subjectId!,
                            sectionId: sectionId,
                            maxScore: double.tryParse(maximum.text) ?? 20,
                          );
                      if (!dialogContext.mounted) return;
                      if (ok) {
                        Navigator.pop(dialogContext);
                      } else {
                        _showAcademicError(dialogContext, ref);
                      }
                    },
              child: const Text('CREAR'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    maximum.dispose();
  }

  Future<void> _gradeDialog(
    BuildContext context,
    WidgetRef ref,
    AcademicState state,
  ) async {
    if (state.gradeItems.isEmpty || state.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea una evaluación y verifica los alumnos.'),
        ),
      );
      return;
    }
    String itemId = '${state.gradeItems.first['id']}';
    String studentId = '${state.students.first['id']}';
    final score = TextEditingController();
    final feedback = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: const Text('Registrar nota'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: itemId,
                  decoration: const InputDecoration(labelText: 'Actividad'),
                  items: state.gradeItems
                      .map(
                        (item) => DropdownMenuItem(
                          value: '${item['id']}',
                          child: Text('${item['title']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setLocalState(() => itemId = value ?? itemId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: studentId,
                  decoration: const InputDecoration(labelText: 'Alumno'),
                  items: state.students
                      .map(
                        (student) => DropdownMenuItem(
                          value: '${student['id']}',
                          child: Text('${student['full_name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setLocalState(() => studentId = value ?? studentId),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: score,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: feedback,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Retroalimentación',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = double.tryParse(score.text);
                if (value == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Ingresa una nota válida.')),
                  );
                  return;
                }
                final ok = await ref
                    .read(academicProvider.notifier)
                    .saveGrade(
                      gradeItemId: itemId,
                      studentId: studentId,
                      score: value,
                      feedback: feedback.text.trim(),
                    );
                if (!dialogContext.mounted) return;
                if (ok) {
                  Navigator.pop(dialogContext);
                } else {
                  _showAcademicError(dialogContext, ref);
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    score.dispose();
    feedback.dispose();
  }

  Future<void> _showStudent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> student,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepPurple,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        builder: (context, controller) => FutureBuilder<Map<String, dynamic>>(
          future: ref
              .read(academicProvider.notifier)
              .loadStudent('${student['id']}'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tracking = snapshot.data!;
            return _StudentDetail(
              controller: controller,
              tracking: tracking,
              canManage: _canManage(ref.read(authProvider).role),
              onObservation: () => _observationDialog(context, ref, student),
            );
          },
        ),
      ),
    );
  }

  Future<void> _observationDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> student,
  ) async {
    final note = TextEditingController();
    String category = 'academic';
    bool visible = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: Text('Observación · ${student['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(value: 'academic', child: Text('Académica')),
                  DropdownMenuItem(
                    value: 'attendance',
                    child: Text('Asistencia'),
                  ),
                  DropdownMenuItem(value: 'achievement', child: Text('Logro')),
                  DropdownMenuItem(
                    value: 'behavior',
                    child: Text('Convivencia'),
                  ),
                  DropdownMenuItem(
                    value: 'wellbeing',
                    child: Text('Bienestar'),
                  ),
                  DropdownMenuItem(value: 'support', child: Text('Apoyo')),
                ],
                onChanged: (value) =>
                    setLocalState(() => category = value ?? category),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Observación'),
              ),
              SwitchListTile(
                value: visible,
                title: const Text('Visible para el estudiante'),
                onChanged: (value) => setLocalState(() => visible = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (note.text.trim().length < 3) return;
                final ok = await ref
                    .read(academicProvider.notifier)
                    .addObservation(
                      studentId: '${student['id']}',
                      category: category,
                      note: note.text.trim(),
                      visibleToStudent: visible,
                    );
                if (!dialogContext.mounted) return;
                if (ok) {
                  Navigator.pop(dialogContext);
                } else {
                  _showAcademicError(dialogContext, ref);
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
  }

  void _showAcademicError(BuildContext context, WidgetRef ref) {
    final message =
        ref.read(academicProvider).error ??
        'No se pudo guardar el cambio académico.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics});
  final Map<String, dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('ALUMNOS', '${metrics['students'] ?? 0}', AppColors.cyan),
      (
        'ASISTENCIA',
        metrics['attendance_rate'] == null
            ? '—'
            : '${metrics['attendance_rate']}%',
        AppColors.gold,
      ),
      (
        'PROMEDIO',
        metrics['grade_average'] == null ? '—' : '${metrics['grade_average']}%',
        AppColors.neonPurple,
      ),
      (
        'ALERTAS',
        '${(metrics['critical'] ?? 0) + (metrics['attention'] ?? 0)}',
        AppColors.brightRed,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: rows
          .map(
            (row) => PixelPanel(
              accent: row.$3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    row.$2,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: row.$3),
                  ),
                  const SizedBox(height: 5),
                  HudLabel(row.$1, color: row.$3),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SubjectPerformance extends StatelessWidget {
  const _SubjectPerformance({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => PixelPanel(
    accent: AppColors.gold,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HudLabel('PROMEDIO POR CURSO', color: AppColors.offWhite),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Text('Aún no hay notas para calcular promedios.')
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text('${row['name']}')),
                  Text(
                    '${row['average']}%',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onTap});
  final Map<String, dynamic> student;
  final VoidCallback onTap;

  Color get color => switch (student['risk']) {
    'critical' => AppColors.brightRed,
    'attention' => AppColors.gold,
    _ => AppColors.cyan,
  };

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: color,
      child: Text(
        '${student['full_name'] ?? 'A'}'.substring(0, 1).toUpperCase(),
      ),
    ),
    title: Text('${student['full_name']}'),
    subtitle: Text(
      '${(student['section'] as Map?)?['display_name'] ?? 'Sin sección'} · asistencia ${student['attendance_rate'] ?? '—'}% · promedio ${student['grade_average'] ?? '—'}%',
    ),
    trailing: const Icon(Icons.chevron_right),
  );
}

class _StudentDetail extends StatelessWidget {
  const _StudentDetail({
    required this.controller,
    required this.tracking,
    required this.canManage,
    required this.onObservation,
  });
  final ScrollController controller;
  final Map<String, dynamic> tracking;
  final bool canManage;
  final VoidCallback onObservation;

  @override
  Widget build(BuildContext context) {
    final student = Map<String, dynamic>.from(
      tracking['student'] as Map? ?? const {},
    );
    final attendance = Map<String, dynamic>.from(
      tracking['attendance_summary'] as Map? ?? const {},
    );
    final grades = List<Map<String, dynamic>>.from(
      tracking['grades'] as List? ?? const [],
    );
    final observations = List<Map<String, dynamic>>.from(
      tracking['observations'] as List? ?? const [],
    );
    final courses = List<Map<String, dynamic>>.from(
      tracking['courses'] as List? ?? const [],
    );
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(18),
      children: [
        const Center(child: SizedBox(width: 48, child: Divider(thickness: 4))),
        Text(
          '${student['full_name'] ?? 'Alumno'}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${(tracking['section'] as Map?)?['display_name'] ?? 'Sin sección'} · ${tracking['xp_total'] ?? 0} XP',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                'ASISTENCIA',
                attendance['rate'] == null ? '—' : '${attendance['rate']}%',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                'PROMEDIO',
                tracking['grade_average'] == null
                    ? '—'
                    : '${tracking['grade_average']}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (canManage)
          OutlinedButton.icon(
            onPressed: onObservation,
            icon: const Icon(Icons.note_add),
            label: const Text('NUEVA OBSERVACIÓN'),
          ),
        const _SectionLabel('CURSOS'),
        ...courses.map(
          (course) => ListTile(
            title: Text('${course['name']}'),
            subtitle: Text(
              List<Map<String, dynamic>>.from(
                        course['teachers'] as List? ?? const [],
                      )
                      .map((teacher) => '${teacher['full_name']}')
                      .join(', ')
                      .isEmpty
                  ? 'Sin profesor asignado'
                  : List<Map<String, dynamic>>.from(
                      course['teachers'] as List,
                    ).map((teacher) => '${teacher['full_name']}').join(', '),
            ),
          ),
        ),
        const _SectionLabel('NOTAS'),
        if (grades.isEmpty)
          const Text('Sin notas registradas.')
        else
          ...grades.map(
            (grade) => ListTile(
              title: Text('${grade['title']}'),
              subtitle: Text(
                '${grade['subject']} · ${grade['feedback'] ?? 'Sin retroalimentación'}',
              ),
              trailing: Text(
                grade['score'] == null
                    ? '—'
                    : '${grade['score']}/${grade['max_score']}',
                style: const TextStyle(color: AppColors.gold),
              ),
            ),
          ),
        const _SectionLabel('OBSERVACIONES'),
        if (observations.isEmpty)
          const Text('Sin observaciones.')
        else
          ...observations.map(
            (observation) => ListTile(
              title: Text('${observation['category']}'),
              subtitle: Text('${observation['note']}'),
              trailing: Text('${observation['status']}'),
            ),
          ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => PixelPanel(
    accent: AppColors.gold,
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: 4),
        HudLabel(label, color: AppColors.gold),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: HudLabel(label, color: AppColors.cyan),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.gold),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => PixelPanel(
    accent: AppColors.brightRed,
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('REINTENTAR')),
      ],
    ),
  );
}
