import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/school_task.dart';
import '../../providers/task_provider.dart';
import '../../widgets/retro_controls.dart';
import '../../widgets/retro_ui.dart';

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
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: RetroScreenHeader(
                  title: 'TAREAS',
                  onBack: () => context.go('/lobby'),
                  actionLabel: 'ACTUALIZAR',
                  onAction: () => ref.read(taskProvider.notifier).loadTasks(),
                  accent: AppColors.cyan,
                ),
              ),
              const SizedBox(height: 10),
              if (state.error != null || state.feedback != null)
                _StatusBanner(
                  message: state.error ?? state.feedback!,
                  isError: state.error != null,
                ),
              Expanded(
                child: state.isLoading && state.tasks.isEmpty
                    ? const PixelLoader(
                        label: 'CARGANDO TAREAS',
                        color: AppColors.cyan,
                      )
                    : state.tasks.isEmpty
                    ? const _EmptyTasks()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.tasks.length,
                        itemBuilder: (context, index) {
                          final task = state.tasks[index];
                          return _TaskCard(
                                task: task,
                                onTap: () => _openTask(task),
                              )
                              .animate()
                              .fadeIn(delay: (index * 70).ms)
                              .slideX(begin: 0.15);
                        },
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
        'La entrega de archivos se habilitará en el siguiente paso.',
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
              accent: AppColors.cyan,
              actions: [
                RetroActionButton(
                  label: 'CANCELAR',
                  compact: true,
                  accent: AppColors.shadowPurple,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                RetroActionButton(
                  label: 'ENTREGAR',
                  compact: true,
                  accent: AppColors.cyan,
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
                        accent: AppColors.cyan,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: PixelPanel(
          accent: AppColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SchoolTower(color: AppColors.cyan, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Text(
                    '${task.xpReward} XP',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.gold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(task.description),
              const SizedBox(height: 12),
              Text(
                '$dueLabel · ${task.subject.toUpperCase()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final accent = isError ? AppColors.brightRed : AppColors.cyan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: PixelPanel(
        accent: accent,
        padding: const EdgeInsets.all(10),
        child: HudLabel(message, color: accent),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: PixelPanel(
          accent: AppColors.cyan,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SchoolTower(color: AppColors.cyan, size: 74),
              SizedBox(height: 12),
              HudLabel('NO HAY TAREAS DISPONIBLES', color: AppColors.cyan),
            ],
          ),
        ),
      ),
    );
  }
}
