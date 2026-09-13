import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/school_task.dart';
import '../../providers/task_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_controls.dart';
import '../../widgets/retro_ui.dart';

/// Tareas a entregar — estilo panel web (cajas con borde oro).
class TaskListView extends ConsumerStatefulWidget {
  const TaskListView({super.key});

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).loadTasks());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelHeader(
                span: 'MISIONES PENDIENTES',
                title: 'TAREAS',
                description: 'Lo que tu docente espera de ti',
                action: PanelButton(
                  label: 'ACTUALIZAR',
                  ghost: true,
                  onTap: () => ref.read(taskProvider.notifier).loadTasks(),
                ),
              ),
              if (state.error != null || state.feedback != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: PanelBox(
                    span: state.error != null ? 'ERROR' : 'EXITO',
                    borderColor: state.error != null ? AppColors.rojoAccion : AppColors.legion,
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      state.error ?? state.feedback!,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        color: state.error != null ? AppColors.imperio : AppColors.legion,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: state.isLoading && state.tasks.isEmpty
                    ? const Center(
                        child: HudLabel('CARGANDO TAREAS', color: AppColors.oro300),
                      )
                    : state.tasks.isEmpty
                    ? const PanelEmpty(
                        title: 'SIN TAREAS PENDIENTES',
                        message: 'Cuando tu docente publique misiones, apareceran aqui.',
                        icon: Icons.assignment_turned_in,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        children: [
                          for (var i = 0; i < state.tasks.length; i++)
                            _TaskCard(
                              task: state.tasks[i],
                              onTap: () => _openTask(state.tasks[i]),
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

  Future<void> _openTask(SchoolTask task) async {
    if (task.taskType == 'file_upload') {
      showRetroMessage(
        context,
        'La entrega de archivos se habilitara en el siguiente paso.',
      );
      return;
    }
    final answerController = TextEditingController();
    String selected = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return RetroDialog(
              title: task.title,
              accent: AppColors.oro500,
              actions: [
                RetroActionButton(
                  label: 'CANCELAR',
                  compact: true,
                  accent: AppColors.piedra600,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                RetroActionButton(
                  label: 'ENTREGAR',
                  compact: true,
                  accent: AppColors.oro500,
                  onPressed: () async {
                    final answer = task.options.isNotEmpty
                        ? selected
                        : answerController.text.trim();
                    if (answer.isEmpty) return;
                    final result = await ref
                        .read(taskProvider.notifier)
                        .submit(task, answer);
                    if (result != null && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.description),
                  const SizedBox(height: 16),
                  if (task.options.isNotEmpty)
                    ...task.options.entries.map(
                      (option) => HexOptionTile(
                        code: option.key,
                        text: option.value,
                        selected: selected == option.key,
                        accent: AppColors.oro500,
                        onTap: () {
                          setDialogState(() => selected = option.key);
                        },
                      ),
                    )
                  else
                    TextField(
                      controller: answerController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu respuesta',
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
    answerController.dispose();
  }
}

class _TaskCard extends StatelessWidget {
  final SchoolTask task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate;
    final dueLabel = dueDate == null
        ? 'Sin fecha limite'
        : '${dueDate.day.toString().padLeft(2, '0')}/'
              '${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PanelBox(
        span: task.subject.toUpperCase(),
        title: task.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.description,
              style: const TextStyle(
                fontFamily: AppTheme.bodyFont,
                color: AppColors.crema100,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatPair(value: '${task.xpReward}', label: 'XP'),
                const SizedBox(width: 18),
                StatPair(value: dueLabel, label: 'ENTREGA'),
                const Spacer(),
                PanelMiniButton(label: 'ENTREGAR', onTap: onTap),
              ],
            ),
          ],
        ),
      ),
    );
  }
}