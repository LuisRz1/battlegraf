import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../../../presentation/widgets/retro_controls.dart';
import '../../../../presentation/widgets/retro_ui.dart';
import '../../domain/entities/institution_dashboard.dart';
import '../../domain/repositories/institution_repository.dart';
import '../providers/institution_provider.dart';

enum InstitutionArea {
  overview('centro', 'CENTRO', Icons.dashboard),
  profile('perfil', 'MI PERFIL', Icons.person),
  school('colegio', 'COLEGIO', Icons.account_balance),
  people('personas', 'PERSONAS', Icons.groups),
  sections('secciones', 'SECCIONES', Icons.meeting_room),
  subjects('cursos', 'CURSOS', Icons.menu_book),
  classes('clases', 'CLASES', Icons.school),
  content('contenidos', 'CONTENIDOS', Icons.auto_stories),
  tasks('tareas', 'TAREAS', Icons.assignment),
  battles('batallas', 'BATALLAS', Icons.sports_esports),
  progress('progreso', 'PROGRESO', Icons.military_tech),
  activity('actividad', 'ACTIVIDAD', Icons.history);

  const InstitutionArea(this.slug, this.label, this.icon);
  final String slug;
  final String label;
  final IconData icon;

  static InstitutionArea parse(String? slug) =>
      values.firstWhere((area) => area.slug == slug, orElse: () => overview);
}

List<InstitutionArea> institutionAreasForRole(String role) {
  if (role == 'student') {
    return const [
      InstitutionArea.overview,
      InstitutionArea.profile,
      InstitutionArea.classes,
      InstitutionArea.tasks,
      InstitutionArea.battles,
      InstitutionArea.progress,
    ];
  }
  if (role == 'teacher') {
    return const [
      InstitutionArea.overview,
      InstitutionArea.profile,
      InstitutionArea.people,
      InstitutionArea.subjects,
      InstitutionArea.classes,
      InstitutionArea.content,
      InstitutionArea.tasks,
      InstitutionArea.battles,
      InstitutionArea.progress,
    ];
  }
  if (role == 'tutor') {
    return const [
      InstitutionArea.overview,
      InstitutionArea.profile,
      InstitutionArea.people,
      InstitutionArea.sections,
      InstitutionArea.subjects,
      InstitutionArea.classes,
      InstitutionArea.content,
      InstitutionArea.tasks,
      InstitutionArea.battles,
      InstitutionArea.progress,
    ];
  }
  return InstitutionArea.values;
}

class InstitutionHubView extends ConsumerWidget {
  const InstitutionHubView({required this.area, super.key});

  final InstitutionArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(institutionProvider);
    final auth = ref.watch(authProvider);
    final allowed = institutionAreasForRole(auth.role);
    final effectiveArea = allowed.contains(area)
        ? area
        : InstitutionArea.overview;
    final canCreate = _canCreate(auth.role, effectiveArea);

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              key: const ValueKey('institution-create-action'),
              onPressed: state.dashboard == null
                  ? null
                  : () => _showCreate(
                      context,
                      ref,
                      effectiveArea,
                      state.dashboard!,
                      auth.role,
                    ),
              backgroundColor: AppColors.neonPurple,
              foregroundColor: AppColors.offWhite,
              icon: Icon(
                effectiveArea == InstitutionArea.school
                    ? Icons.edit_outlined
                    : Icons.add,
              ),
              label: Text(
                effectiveArea == InstitutionArea.school ? 'EDITAR' : 'NUEVO',
              ),
            )
          : null,
      body: BattleBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: ref.read(institutionProvider.notifier).load,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: RetroScreenHeader(
                      title: effectiveArea.label,
                      accent: _accent(effectiveArea),
                      onBack: () => context.go('/lobby'),
                      actionLabel: 'MÓDULOS',
                      onAction: () => _showModules(context, auth.role),
                    ),
                  ),
                ),
                if (state.loading && state.dashboard == null)
                  const SliverFillRemaining(
                    child: PixelLoader(label: 'CARGANDO CENTRO DE MANDO'),
                  )
                else if (state.error != null && state.dashboard == null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: PixelPanel(
                          accent: AppColors.brightRed,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: ref
                                    .read(institutionProvider.notifier)
                                    .load,
                                child: const Text('REINTENTAR'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                    sliver: SliverList.list(
                      children: [
                        if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PixelPanel(
                              accent: AppColors.brightRed,
                              child: Text(state.error!),
                            ),
                          ),
                        ..._content(
                          context,
                          ref,
                          effectiveArea,
                          state.dashboard!,
                          auth,
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

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    InstitutionArea area,
    InstitutionDashboard dashboard,
    AuthState auth,
  ) {
    final canAdmin = const {
      'owner',
      'director',
      'subdirector',
      'coordinator',
    }.contains(auth.role);
    return switch (area) {
      InstitutionArea.overview => _overview(context, dashboard, auth),
      InstitutionArea.profile => _profile(context, dashboard, auth),
      InstitutionArea.school => _school(context, dashboard, auth),
      InstitutionArea.people => _people(
        context,
        ref,
        dashboard,
        canAdmin,
        auth.role,
      ),
      InstitutionArea.sections => _rows(
        context,
        'SECCIONES Y TUTORES',
        dashboard.sections,
        (row) => '${row['display_name'] ?? row['code'] ?? 'Sección'}',
        (row) =>
            '${row['tutor_name'] ?? 'Tutor por asignar'} · ${row['status'] ?? 'active'}',
        actions: canAdmin
            ? (row) => [
                _editAction(
                  context,
                  ref,
                  'SECCIÓN',
                  [
                    _FieldSpec(
                      'grade',
                      'Grado',
                      initial: '${row['grade'] ?? ''}',
                    ),
                    _FieldSpec(
                      'section_label',
                      'Sección',
                      initial: '${row['section_label'] ?? ''}',
                    ),
                    _FieldSpec(
                      'tutor_name',
                      'Tutor',
                      initial: '${row['tutor_name'] ?? ''}',
                    ),
                  ],
                  (repository, values) =>
                      repository.updateSection('${row['id']}', values),
                ),
                _deleteAction(context, ref, 'la sección', (repository) {
                  return repository.deleteSection('${row['id']}');
                }),
              ]
            : null,
      ),
      InstitutionArea.subjects => _subjects(context, ref, dashboard, canAdmin),
      InstitutionArea.classes => _classes(context, ref, dashboard, auth),
      InstitutionArea.content => _contentRows(
        context,
        ref,
        dashboard,
        canAdmin,
      ),
      InstitutionArea.tasks => _rows(
        context,
        'TAREAS PROGRAMADAS',
        dashboard.assignments,
        (row) => '${row['title'] ?? 'Tarea'}',
        (row) =>
            '${_relation(row['subjects']) ?? 'General'} · ${row['status'] ?? 'draft'} · ${row['xp_reward'] ?? 0} XP',
        actions: canAdmin
            ? (row) => [
                _editAction(
                  context,
                  ref,
                  'TAREA',
                  [
                    _FieldSpec(
                      'title',
                      'Título',
                      initial: '${row['title'] ?? ''}',
                    ),
                    _FieldSpec(
                      'subject_id',
                      'Curso',
                      initial: '${row['subject_id'] ?? ''}',
                      options: _options(dashboard.subjects, 'name'),
                    ),
                    _FieldSpec(
                      'section_id',
                      'Sección',
                      initial: '${row['section_id'] ?? ''}',
                      options: _options(dashboard.sections, 'display_name'),
                    ),
                    _FieldSpec(
                      'xp_reward',
                      'XP',
                      initial: '${row['xp_reward'] ?? 80}',
                      numeric: true,
                    ),
                    _FieldSpec(
                      'status',
                      'Estado',
                      initial: '${row['status'] ?? 'scheduled'}',
                      options: const {
                        'draft': 'Borrador',
                        'scheduled': 'Programada',
                        'published': 'Publicada',
                        'closed': 'Cerrada',
                      },
                    ),
                  ],
                  (repository, values) =>
                      repository.updateAssignment('${row['id']}', {
                        ...values,
                        'xp_reward':
                            int.tryParse('${values['xp_reward']}') ?? 80,
                      }),
                ),
                _deleteAction(context, ref, 'la tarea', (repository) {
                  return repository.deleteAssignment('${row['id']}');
                }),
              ]
            : null,
      ),
      InstitutionArea.battles => _battles(context, ref, dashboard, canAdmin),
      InstitutionArea.progress => _progress(context, ref, dashboard, canAdmin),
      InstitutionArea.activity => _rows(
        context,
        'AUDITORÍA RECIENTE',
        dashboard.audits,
        (row) => '${row['action'] ?? 'Actividad'}',
        (row) =>
            '${row['actor_name'] ?? 'Sistema'} · ${row['target_label'] ?? ''}',
      ),
    };
  }

  List<Widget> _overview(
    BuildContext context,
    InstitutionDashboard dashboard,
    AuthState auth,
  ) {
    final schoolName =
        '${dashboard.school['name'] ?? auth.user?['school_name'] ?? 'Institución BattleGraph'}';
    return [
      PixelPanel(
        accent: AppColors.brightRed,
        glow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HudLabel('INSTITUCIÓN ACTIVA', color: AppColors.gold),
            const SizedBox(height: 8),
            Text(schoolName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'ROL ${roleLabel(auth.role)} · ${dashboard.school['code'] ?? auth.user?['school_code'] ?? ''}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _MetricGrid(
        values: [
          ('ALUMNOS', dashboard.students.length, AppColors.brightRed),
          ('SECCIONES', dashboard.sections.length, AppColors.neonPurple),
          ('CURSOS', dashboard.subjects.length, AppColors.cyan),
          ('CLASES', dashboard.classes.length, AppColors.gold),
          ('TAREAS', dashboard.assignments.length, AppColors.cyan),
          ('BATALLAS', dashboard.battles.length, AppColors.brightRed),
        ],
      ),
      const SizedBox(height: 14),
      PixelPanel(
        accent: AppColors.cyan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HudLabel('ACCESOS RÁPIDOS', color: AppColors.offWhite),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: institutionAreasForRole(auth.role)
                  .where((item) => item != InstitutionArea.overview)
                  .map(
                    (item) => ActionChip(
                      avatar: Icon(item.icon, size: 17),
                      label: Text(item.label),
                      onPressed: () => context.go('/institution/${item.slug}'),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _school(
    BuildContext context,
    InstitutionDashboard dashboard,
    AuthState auth,
  ) {
    final school = dashboard.school;
    return [
      PixelPanel(
        accent: AppColors.gold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HudLabel('DATOS MAESTROS', color: AppColors.offWhite),
            const SizedBox(height: 12),
            _InfoRow(
              'Nombre',
              '${school['name'] ?? auth.user?['school_name'] ?? '—'}',
            ),
            _InfoRow(
              'Código',
              '${school['code'] ?? auth.user?['school_code'] ?? '—'}',
            ),
            _InfoRow('Región', '${school['region'] ?? '—'}'),
            _InfoRow('Ciudad', '${school['city'] ?? '—'}'),
            _InfoRow('UGEL', '${school['ugel'] ?? '—'}'),
            _InfoRow('Dirección', '${school['address'] ?? '—'}'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      PixelPanel(
        accent: AppColors.neonPurple,
        child: _InfoRow(
          'Plan',
          '${dashboard.subscription['plan_slug'] ?? 'explorador'} · ${dashboard.subscription['status'] ?? 'active'}',
        ),
      ),
    ];
  }

  List<Widget> _profile(
    BuildContext context,
    InstitutionDashboard dashboard,
    AuthState auth,
  ) => [
    PixelPanel(
      accent: AppColors.cyan,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HudLabel('IDENTIDAD INSTITUCIONAL', color: AppColors.offWhite),
          const SizedBox(height: 12),
          _InfoRow('Nombre', '${auth.user?['full_name'] ?? 'Usuario'}'),
          _InfoRow('Correo', '${auth.user?['email'] ?? '—'}'),
          _InfoRow('Rol', roleLabel(auth.role)),
          _InfoRow('Colegio', '${dashboard.school['name'] ?? '—'}'),
          _InfoRow('Código', '${dashboard.school['code'] ?? '—'}'),
        ],
      ),
    ),
    const SizedBox(height: 14),
    PixelPanel(
      accent: AppColors.neonPurple,
      child: _InfoRow(
        'Plan activo',
        '${dashboard.subscription['plan_slug'] ?? 'explorador'} · ${dashboard.subscription['status'] ?? 'active'}',
      ),
    ),
  ];

  List<Widget> _people(
    BuildContext context,
    WidgetRef ref,
    InstitutionDashboard dashboard,
    bool canAdmin,
    String role,
  ) => [
    ..._rows(
      context,
      'ALUMNOS (${dashboard.students.length})',
      dashboard.students,
      (row) => '${row['full_name'] ?? 'Alumno'}',
      (row) => '${row['email'] ?? 'Sin correo'} · ${row['status'] ?? 'active'}',
      actions: canAdmin
          ? (row) => [
              _editAction(
                context,
                ref,
                'ALUMNO',
                [
                  _FieldSpec(
                    'full_name',
                    'Nombre completo',
                    initial: '${row['full_name'] ?? ''}',
                  ),
                  _FieldSpec(
                    'email',
                    'Correo',
                    initial: '${row['email'] ?? ''}',
                  ),
                  _FieldSpec(
                    'section_id',
                    'Sección',
                    initial: '${row['section_id'] ?? ''}',
                    options: _options(dashboard.sections, 'display_name'),
                  ),
                ],
                (repository, values) =>
                    repository.updateStudent('${row['id']}', values),
              ),
              _deleteAction(context, ref, 'el alumno', (repository) {
                return repository.deleteStudent('${row['id']}');
              }),
            ]
          : null,
    ),
    const SizedBox(height: 16),
    ..._rows(
      context,
      'EQUIPO (${dashboard.staff.length})',
      dashboard.staff,
      (row) => '${row['full_name'] ?? 'Personal'}',
      (row) =>
          '${roleLabel('${row['role'] ?? ''}')} · ${row['scope_label'] ?? 'Sin alcance'}',
      actions: const {'owner', 'director', 'subdirector'}.contains(role)
          ? (row) => [
              _editAction(
                context,
                ref,
                'PERSONAL',
                [
                  _FieldSpec(
                    'full_name',
                    'Nombre completo',
                    initial: '${row['full_name'] ?? ''}',
                  ),
                  _FieldSpec(
                    'email',
                    'Correo',
                    initial: '${row['email'] ?? ''}',
                  ),
                  _FieldSpec(
                    'role',
                    'Rol',
                    initial: '${row['role'] ?? 'teacher'}',
                    options: const {
                      'teacher': 'Profesor',
                      'tutor': 'Tutor',
                      'coordinator': 'Coordinador',
                      'subdirector': 'Subdirector',
                    },
                  ),
                  _FieldSpec(
                    'scope_label',
                    'Alcance',
                    initial: '${row['scope_label'] ?? ''}',
                  ),
                  _FieldSpec(
                    'status',
                    'Estado',
                    initial: '${row['status'] ?? 'active'}',
                    options: const {
                      'active': 'Activo',
                      'invited': 'Invitado',
                      'suspended': 'Suspendido',
                    },
                  ),
                ],
                (repository, values) =>
                    repository.updateStaff('${row['id']}', values),
              ),
              _deleteAction(context, ref, 'el perfil', (repository) {
                return repository.deleteStaff('${row['id']}');
              }),
            ]
          : null,
    ),
  ];

  List<Widget> _subjects(
    BuildContext context,
    WidgetRef ref,
    InstitutionDashboard dashboard,
    bool canAdmin,
  ) {
    String teachers(JsonMap subject) {
      final names = dashboard.subjectTeachers
          .where((link) => '${link['subject_id']}' == '${subject['id']}')
          .map((link) {
            final staff = link['staff_profiles'];
            if (staff is List && staff.isNotEmpty) {
              return '${staff.first['full_name']}';
            }
            if (staff is Map) return '${staff['full_name']}';
            return '';
          })
          .where((name) => name.isNotEmpty)
          .toList();
      return names.isEmpty ? 'Sin docente asignado' : names.join(', ');
    }

    return _rows(
      context,
      'CURSOS Y DOCENTES',
      dashboard.subjects,
      (row) => '${row['name'] ?? 'Curso'}',
      teachers,
      actions: canAdmin
          ? (row) => [
              _editAction(
                context,
                ref,
                'CURSO',
                [
                  _FieldSpec('name', 'Nombre', initial: '${row['name'] ?? ''}'),
                  _FieldSpec(
                    'icon_code',
                    'Código',
                    initial: '${row['icon_code'] ?? ''}',
                  ),
                  _FieldSpec(
                    'color',
                    'Color hexadecimal',
                    initial: '${row['color'] ?? '#28c9d7'}',
                  ),
                ],
                (repository, values) =>
                    repository.updateSubject('${row['id']}', values),
              ),
              _deleteAction(context, ref, 'el curso', (repository) {
                return repository.deleteSubject('${row['id']}');
              }),
            ]
          : null,
    );
  }

  List<Widget> _classes(
    BuildContext context,
    WidgetRef ref,
    InstitutionDashboard dashboard,
    AuthState auth,
  ) => [
    if (auth.role == 'student') ...[
      PixelPanel(
        accent: AppColors.cyan,
        child: Column(
          children: [
            const HudLabel('CÓDIGO DE CLASE', color: AppColors.offWhite),
            const SizedBox(height: 8),
            const Text('Ingresa el código entregado por tu docente.'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _joinClassDialog(context, ref),
                child: const Text('UNIRME A UNA CLASE'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ],
    ..._rows(
      context,
      'CLASES ACTIVAS',
      dashboard.classes,
      (row) => '${row['name'] ?? row['subject'] ?? 'Clase'}',
      (row) =>
          '${row['code'] ?? 'Sin código'} · ${_relation(row['sections']) ?? 'Sin sección'}',
    ),
  ];

  Future<void> _joinClassDialog(BuildContext context, WidgetRef ref) async {
    final values = await _EntityDialog.show(context, 'CLASE', const [
      _FieldSpec('code', 'Código de clase'),
    ]);
    final code = '${values?['code'] ?? ''}'.trim().toUpperCase();
    if (code.isEmpty) return;
    final ok = await ref.read(institutionProvider.notifier).mutate((repo, _) {
      return repo.joinClass(code);
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Clase vinculada.' : 'Código no válido.')),
    );
  }

  List<Widget> _contentRows(
    BuildContext context,
    WidgetRef ref,
    InstitutionDashboard dashboard,
    bool canAdmin,
  ) => [
    ..._rows(
      context,
      'MATERIALES (${dashboard.materials.length})',
      dashboard.materials,
      (row) => '${row['title'] ?? 'Material'}',
      (row) =>
          '${row['file_type'] ?? 'manual'} · ${row['processing_status'] ?? 'ready'}',
      actions: canAdmin
          ? (row) => [
              _deleteAction(context, ref, 'el material', (repository) {
                return repository.deleteMaterial('${row['id']}');
              }),
            ]
          : null,
    ),
    const SizedBox(height: 16),
    ..._rows(
      context,
      'BANCO DE PREGUNTAS (${dashboard.questions.length})',
      dashboard.questions,
      (row) => '${row['question'] ?? 'Pregunta'}',
      (row) => '${row['status'] ?? 'draft'} · ${row['source'] ?? 'manual'}',
      actions: canAdmin
          ? (row) => [
              _editAction(
                context,
                ref,
                'PREGUNTA',
                [
                  _FieldSpec(
                    'question',
                    'Pregunta',
                    initial: '${row['question'] ?? ''}',
                  ),
                  for (var index = 0; index < 4; index++)
                    _FieldSpec(
                      'option_${index + 1}',
                      'Opción ${index + 1}',
                      initial: _listValue(row['options'], index),
                    ),
                  _FieldSpec(
                    'correct_index',
                    'Respuesta correcta',
                    initial: '${row['correct_index'] ?? 0}',
                    options: const {
                      '0': 'Opción 1',
                      '1': 'Opción 2',
                      '2': 'Opción 3',
                      '3': 'Opción 4',
                    },
                  ),
                  _FieldSpec(
                    'subject_id',
                    'Curso',
                    initial: '${row['subject_id'] ?? ''}',
                    options: _options(dashboard.subjects, 'name'),
                  ),
                  _FieldSpec(
                    'status',
                    'Estado',
                    initial: '${row['status'] ?? 'review'}',
                    options: const {
                      'draft': 'Borrador',
                      'review': 'En revisión',
                      'approved': 'Aprobada',
                    },
                  ),
                ],
                (repository, values) =>
                    repository.updateQuestion('${row['id']}', {
                      'question': values['question'],
                      'subject_id': values['subject_id'],
                      'status': values['status'],
                      'correct_index':
                          int.tryParse('${values['correct_index']}') ?? 0,
                      'options': [
                        values['option_1'],
                        values['option_2'],
                        values['option_3'],
                        values['option_4'],
                      ],
                    }),
              ),
              if ('${row['status']}' != 'approved')
                _RowAction(
                  icon: Icons.verified,
                  label: 'APROBAR',
                  onPressed: () => _runMutation(context, ref, (repository) {
                    return repository.approveQuestion('${row['id']}');
                  }),
                ),
              _deleteAction(context, ref, 'la pregunta', (repository) {
                return repository.deleteQuestion('${row['id']}');
              }),
            ]
          : null,
    ),
  ];

  List<Widget> _battles(
    BuildContext context,
    WidgetRef ref,
    InstitutionDashboard dashboard,
    bool canAdmin,
  ) => [
    PixelPanel(
      accent: AppColors.brightRed,
      glow: true,
      child: Column(
        children: [
          const AcademicHexBadge(
            label: 'VS',
            color: AppColors.brightRed,
            size: 58,
          ),
          const SizedBox(height: 10),
          const HudLabel('MODO JUGABLE OFFLINE', color: AppColors.gold),
          const SizedBox(height: 8),
          const Text(
            'Prueba el tablero por turnos mientras las batallas escolares esperan rival.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/battle/demo-bot'),
              child: const Text('JUGAR VS BOT'),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    ..._rows(
      context,
      'EVENTOS PROGRAMADOS',
      dashboard.battles,
      (row) => '${row['title'] ?? 'Batalla'}',
      (row) =>
          '${row['battle_type'] ?? 'versus'} · ${row['status'] ?? 'scheduled'}',
      actions: canAdmin
          ? (row) => [
              _editAction(
                context,
                ref,
                'BATALLA',
                [
                  _FieldSpec(
                    'title',
                    'Título',
                    initial: '${row['title'] ?? ''}',
                  ),
                  _FieldSpec(
                    'battle_type',
                    'Tipo',
                    initial: '${row['battle_type'] ?? 'versus'}',
                    options: const {
                      'versus': 'Versus',
                      'conquest': 'Conquista',
                      'reconquista': 'Reconquista',
                      'tournament': 'Torneo',
                      'student_vs_bot': 'Alumno vs BOT',
                    },
                  ),
                  _FieldSpec(
                    'subject_id',
                    'Curso',
                    initial: '${row['subject_id'] ?? ''}',
                    options: _options(dashboard.subjects, 'name'),
                  ),
                  _FieldSpec(
                    'grade',
                    'Grado',
                    initial: '${row['grade'] ?? ''}',
                  ),
                  _FieldSpec(
                    'opponent_a',
                    'Contrincante A',
                    initial: '${row['opponent_a'] ?? ''}',
                  ),
                  _FieldSpec(
                    'opponent_b',
                    'Contrincante B',
                    initial: '${row['opponent_b'] ?? ''}',
                  ),
                  _FieldSpec(
                    'status',
                    'Estado',
                    initial: '${row['status'] ?? 'scheduled'}',
                    options: const {
                      'scheduled': 'Programada',
                      'live': 'En vivo',
                      'finished': 'Finalizada',
                    },
                  ),
                ],
                (repository, values) =>
                    repository.updateBattle('${row['id']}', values),
              ),
              _deleteAction(context, ref, 'la batalla', (repository) {
                return repository.deleteBattle('${row['id']}');
              }),
            ]
          : null,
    ),
  ];

  List<Widget> _progress(
    BuildContext context,
    WidgetRef ref,
    InstitutionDashboard dashboard,
    bool canAdmin,
  ) => [
    ..._rows(
      context,
      'RANGOS',
      dashboard.ranks,
      (row) => '${row['name'] ?? 'Rango'}',
      (row) => 'Desde ${row['min_xp'] ?? 0} XP',
      actions: canAdmin
          ? (row) => [
              _deleteAction(context, ref, 'el rango', (repository) {
                return repository.deleteRank('${row['id']}');
              }),
            ]
          : null,
    ),
    const SizedBox(height: 16),
    ..._rows(
      context,
      'CLANES',
      dashboard.clans,
      (row) => '${row['name'] ?? 'Clan'}',
      (row) => '${row['rank_name'] ?? 'Aprendiz'}',
    ),
  ];

  List<Widget> _rows(
    BuildContext context,
    String title,
    List<JsonMap> rows,
    String Function(JsonMap) primary,
    String Function(JsonMap) secondary, {
    List<_RowAction> Function(JsonMap)? actions,
  }) => [
    PixelPanel(
      accent: _accent(area),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudLabel(title, color: AppColors.offWhite),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Aún no hay información visible para este rol.'),
            )
          else
            ...rows.map(
              (row) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkCard.withValues(alpha: .82),
                  border: Border.all(color: AppColors.shadowPurple),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary(row),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      secondary(row),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (actions != null && actions(row).isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: actions(row)
                            .map(
                              (action) => TextButton.icon(
                                onPressed: action.onPressed,
                                icon: Icon(action.icon, size: 16),
                                label: Text(action.label),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  ];

  _RowAction _deleteAction(
    BuildContext context,
    WidgetRef ref,
    String label,
    Future<void> Function(InstitutionRepository repository) action,
  ) => _RowAction(
    icon: Icons.delete_outline,
    label: 'ELIMINAR',
    onPressed: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('CONFIRMAR ELIMINACIÓN'),
          content: Text('¿Seguro que deseas eliminar $label?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ELIMINAR'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await _runMutation(context, ref, action);
    },
  );

  _RowAction _editAction(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<_FieldSpec> fields,
    Future<void> Function(InstitutionRepository repository, JsonMap values)
    action,
  ) => _RowAction(
    icon: Icons.edit_outlined,
    label: 'EDITAR',
    onPressed: () async {
      final values = await _EntityDialog.show(
        context,
        title,
        fields,
        verb: 'EDITAR',
      );
      if (values == null || !context.mounted) return;
      await _runMutation(context, ref, (repository) {
        return action(repository, values);
      });
    },
  );

  Future<void> _runMutation(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(InstitutionRepository repository) action,
  ) async {
    final ok = await ref.read(institutionProvider.notifier).mutate((repo, _) {
      return action(repo);
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Cambio guardado.' : 'No se pudo guardar el cambio.',
        ),
      ),
    );
  }

  Future<void> _showModules(BuildContext context, String role) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.deepPurple,
      builder: (sheetContext) => SafeArea(
        child: GridView.count(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: institutionAreasForRole(role)
              .map(
                (item) => InkWell(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/institution/${item.slug}');
                  },
                  child: PixelPanel(
                    accent: _accent(item),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, color: _accent(item)),
                        const SizedBox(height: 6),
                        FittedBox(
                          child: HudLabel(item.label, color: _accent(item)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  bool _canCreate(String role, InstitutionArea area) {
    if (role == 'student' ||
        area == InstitutionArea.overview ||
        area == InstitutionArea.profile ||
        area == InstitutionArea.activity) {
      return false;
    }
    const leadership = {'owner', 'director', 'subdirector'};
    if (area == InstitutionArea.school) return leadership.contains(role);
    if (area == InstitutionArea.progress) {
      return leadership.contains(role) || role == 'coordinator';
    }
    return true;
  }

  Future<void> _showCreate(
    BuildContext context,
    WidgetRef ref,
    InstitutionArea area,
    InstitutionDashboard dashboard,
    String role,
  ) async {
    final notifier = ref.read(institutionProvider.notifier);
    final fields = <_FieldSpec>[];
    switch (area) {
      case InstitutionArea.school:
        fields.addAll([
          _FieldSpec(
            'name',
            'Nombre del colegio',
            initial: '${dashboard.school['name'] ?? ''}',
          ),
          _FieldSpec(
            'region',
            'Región',
            initial: '${dashboard.school['region'] ?? ''}',
          ),
          _FieldSpec(
            'city',
            'Ciudad',
            initial: '${dashboard.school['city'] ?? ''}',
          ),
          _FieldSpec(
            'ugel',
            'UGEL',
            initial: '${dashboard.school['ugel'] ?? ''}',
          ),
          _FieldSpec(
            'address',
            'Dirección',
            initial: '${dashboard.school['address'] ?? ''}',
          ),
        ]);
      case InstitutionArea.sections:
        fields.addAll(const [
          _FieldSpec('grade', 'Grado', initial: '5'),
          _FieldSpec('section_label', 'Sección', initial: 'A'),
          _FieldSpec('tutor_name', 'Tutor'),
        ]);
      case InstitutionArea.subjects:
        fields.addAll(const [
          _FieldSpec('name', 'Nombre del curso'),
          _FieldSpec('icon_code', 'Código (3 letras)', initial: 'CUR'),
          _FieldSpec('color', 'Color hexadecimal', initial: '#28c9d7'),
        ]);
      case InstitutionArea.people:
        final canCreateStaff = const {
          'owner',
          'director',
          'subdirector',
        }.contains(role);
        fields.addAll([
          _FieldSpec(
            'kind',
            'Tipo',
            options: {
              'student': 'Alumno',
              if (canCreateStaff) 'staff': 'Personal',
            },
          ),
          const _FieldSpec('full_name', 'Nombre completo'),
          const _FieldSpec('email', 'Correo'),
          _FieldSpec(
            'section_id',
            'Sección',
            options: _options(dashboard.sections, 'display_name'),
          ),
          const _FieldSpec(
            'role',
            'Rol del personal',
            options: {
              'teacher': 'Profesor',
              'tutor': 'Tutor',
              'coordinator': 'Coordinador',
              'subdirector': 'Subdirector',
            },
          ),
        ]);
      case InstitutionArea.classes:
        fields.addAll([
          const _FieldSpec('name', 'Nombre de la clase'),
          _FieldSpec(
            'subject_id',
            'Curso',
            options: _options(dashboard.subjects, 'name'),
          ),
          _FieldSpec(
            'section_id',
            'Sección',
            options: _options(dashboard.sections, 'display_name'),
          ),
        ]);
      case InstitutionArea.content:
        fields.addAll([
          const _FieldSpec(
            'kind',
            'Tipo',
            options: {'material': 'Material', 'question': 'Pregunta'},
          ),
          const _FieldSpec('title', 'Título del material'),
          const _FieldSpec('file_name', 'Nombre del archivo'),
          const _FieldSpec('question', 'Pregunta'),
          const _FieldSpec('option_1', 'Opción correcta'),
          const _FieldSpec('option_2', 'Opción 2'),
          const _FieldSpec('option_3', 'Opción 3'),
          const _FieldSpec('option_4', 'Opción 4'),
          _FieldSpec(
            'subject_id',
            'Curso',
            options: _options(dashboard.subjects, 'name'),
          ),
        ]);
      case InstitutionArea.tasks:
        fields.addAll([
          const _FieldSpec('title', 'Título de la tarea'),
          _FieldSpec(
            'subject_id',
            'Curso',
            options: _options(dashboard.subjects, 'name'),
          ),
          _FieldSpec(
            'section_id',
            'Sección',
            options: _options(dashboard.sections, 'display_name'),
          ),
          const _FieldSpec('xp_reward', 'XP', initial: '80', numeric: true),
        ]);
      case InstitutionArea.battles:
        fields.addAll([
          const _FieldSpec('title', 'Título de la batalla'),
          _FieldSpec(
            'subject_id',
            'Curso',
            options: _options(dashboard.subjects, 'name'),
          ),
          const _FieldSpec('grade', 'Grado', initial: '5'),
        ]);
      case InstitutionArea.progress:
        fields.addAll(const [
          _FieldSpec('name', 'Nombre del rango'),
          _FieldSpec('min_xp', 'XP mínimo', initial: '0', numeric: true),
        ]);
      case InstitutionArea.overview ||
          InstitutionArea.profile ||
          InstitutionArea.activity:
        return;
    }
    final values = await _EntityDialog.show(
      context,
      area.label,
      fields,
      verb: area == InstitutionArea.school ? 'EDITAR' : 'NUEVO',
    );
    if (values == null) return;
    final ok = await notifier.mutate((repository, schoolId) async {
      switch (area) {
        case InstitutionArea.school:
          await repository.updateSchool(schoolId, values);
        case InstitutionArea.sections:
          await repository.createSection(schoolId, {
            'level': 'Primaria',
            ...values,
          });
        case InstitutionArea.subjects:
          await repository.createSubject(schoolId, values);
        case InstitutionArea.people:
          final payload = JsonMap.from(values)..remove('kind');
          if (values['kind'] == 'student') {
            payload.remove('role');
            await repository.createStudent(schoolId, payload);
          } else {
            payload.remove('section_id');
            payload['status'] = 'invited';
            await repository.createStaff(schoolId, payload);
          }
        case InstitutionArea.classes:
          await repository.createClass(schoolId, values);
        case InstitutionArea.content:
          if (values['kind'] == 'material') {
            await repository.createMaterial(schoolId, {
              'title': values['title'],
              'file_name': values['file_name'],
              'subject_id': values['subject_id'],
            });
          } else {
            await repository.createQuestion(schoolId, {
              'question': values['question'],
              'subject_id': values['subject_id'],
              'options': [
                values['option_1'],
                values['option_2'],
                values['option_3'],
                values['option_4'],
              ],
              'correct_index': 0,
              'status': 'review',
            });
          }
        case InstitutionArea.tasks:
          await repository.createAssignment(schoolId, {
            ...values,
            'xp_reward': int.tryParse('${values['xp_reward']}') ?? 80,
            'delivery_type': 'quiz',
            'status': 'scheduled',
          });
        case InstitutionArea.battles:
          await repository.createBattle(schoolId, {
            ...values,
            'battle_type': 'student_vs_bot',
            'opponent_a': 'Alumno',
            'opponent_b': 'BOT',
            'graph_layers': 4,
            'nodes_per_layer': 4,
            'status': 'scheduled',
          });
        case InstitutionArea.progress:
          await repository.createRank(schoolId, {
            ...values,
            'min_xp': int.tryParse('${values['min_xp']}') ?? 0,
            'position': dashboard.ranks.length + 1,
          });
        case InstitutionArea.overview ||
            InstitutionArea.profile ||
            InstitutionArea.activity:
          return;
      }
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Cambio guardado.' : 'No se pudo guardar el cambio.',
        ),
      ),
    );
  }

  static Map<String, String> _options(List<JsonMap> rows, String label) => {
    for (final row in rows) '${row['id']}': '${row[label] ?? 'Sin nombre'}',
  };

  static String? _relation(dynamic value) {
    if (value is List && value.isNotEmpty) {
      final row = value.first;
      if (row is Map) return '${row['name'] ?? row['display_name'] ?? ''}';
    }
    if (value is Map) return '${value['name'] ?? value['display_name'] ?? ''}';
    return null;
  }

  static String _listValue(dynamic value, int index) {
    if (value is List && index >= 0 && index < value.length) {
      return '${value[index]}';
    }
    return '';
  }

  static Color _accent(InstitutionArea area) => switch (area) {
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
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});
  final List<(String, int, Color)> values;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
    ),
    itemCount: values.length,
    itemBuilder: (context, index) {
      final (label, value, color) = values[index];
      return PixelPanel(
        accent: color,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            FittedBox(child: HudLabel(label, color: color)),
          ],
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label, {
    this.initial = '',
    this.options,
    this.numeric = false,
  });
  final String key;
  final String label;
  final String initial;
  final Map<String, String>? options;
  final bool numeric;
}

class _RowAction {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _EntityDialog {
  static Future<JsonMap?> show(
    BuildContext context,
    String title,
    List<_FieldSpec> fields, {
    String verb = 'NUEVO',
  }) async {
    final controllers = {
      for (final field in fields.where((item) => item.options == null))
        field.key: TextEditingController(text: field.initial),
    };
    final values = {
      for (final field in fields)
        field.key: field.options == null
            ? field.initial
            : field.options!.containsKey(field.initial)
            ? field.initial
            : field.options!.keys.firstOrNull ?? '',
    };
    final result = await showDialog<JsonMap>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: Text('$verb · $title'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fields.map((field) {
                  if (field.options case final options?) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue: values[field.key]?.isEmpty ?? true
                            ? null
                            : '${values[field.key]}',
                        decoration: InputDecoration(labelText: field.label),
                        items: options.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => values[field.key] = value ?? ''),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[field.key],
                      keyboardType: field.numeric
                          ? TextInputType.number
                          : TextInputType.text,
                      maxLines:
                          field.key == 'question' || field.key == 'address'
                          ? 3
                          : 1,
                      decoration: InputDecoration(labelText: field.label),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                for (final entry in controllers.entries) {
                  values[entry.key] = entry.value.text.trim();
                }
                Navigator.pop(dialogContext, JsonMap.from(values));
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }
}
