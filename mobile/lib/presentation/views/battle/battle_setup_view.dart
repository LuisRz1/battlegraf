import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/question_pool_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_ui.dart';

/// El alumno elige con que materia jugar. Solo se ofrecen temas que
/// realmente tienen preguntas aprobadas en el colegio.
class BattleSetupView extends ConsumerStatefulWidget {
  const BattleSetupView({super.key});

  @override
  ConsumerState<BattleSetupView> createState() => _BattleSetupViewState();
}

class _BattleSetupViewState extends ConsumerState<BattleSetupView> {
  String? _topic;

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(questionPoolProvider);
    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelHeader(
                span: 'BATALLA',
                title: 'ELEGIR MATERIA',
                description:
                    'Juega contra el BOT con las preguntas aprobadas por tus docentes.',
                action: PanelButton(
                  label: 'VOLVER',
                  ghost: true,
                  onTap: () => context.go('/lobby'),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  children: [
                    PanelBox(
                      span: 'CONTENIDO',
                      title: '${pool.questions.length} PREGUNTAS DISPONIBLES',
                      child: pool.isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(
                                color: AppColors.oro500,
                                backgroundColor: AppColors.piedra900,
                              ),
                            )
                          : pool.hasQuestions
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SectionChip(
                                  label: 'TODAS',
                                  color: _topic == null
                                      ? AppColors.oro500
                                      : AppColors.oro300,
                                  onTap: () => setState(() => _topic = null),
                                ),
                                for (final topic in pool.topics)
                                  SectionChip(
                                    label: topic.toUpperCase(),
                                    color: _topic == topic
                                        ? AppColors.oro500
                                        : AppColors.oro300,
                                    onTap: () => setState(() => _topic = topic),
                                  ),
                              ],
                            )
                          : Text(
                              pool.error ??
                                  'El colegio aun no tiene preguntas aprobadas.',
                              style: const TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                color: AppColors.crema500,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    if (pool.hasQuestions)
                      PanelButton(
                        label: 'COMENZAR BATALLA',
                        onTap: () {
                          final topic = _topic;
                          final uri = Uri(
                            path: '/battle/play',
                            queryParameters: topic == null
                                ? const {}
                                : {'topic': topic},
                          );
                          context.push(uri.toString());
                        },
                      ),
                    const SizedBox(height: 8),
                    PanelButton(
                      label: 'RECARGAR PREGUNTAS',
                      ghost: true,
                      onTap: () => ref.read(questionPoolProvider.notifier).load(),
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
