import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/question_pool_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_ui.dart';

/// El alumno elige con que materia jugar y que poderes equipar.
/// Solo se ofrecen temas con preguntas aprobadas en el colegio.
class BattleSetupView extends ConsumerStatefulWidget {
  const BattleSetupView({super.key});

  @override
  ConsumerState<BattleSetupView> createState() => _BattleSetupViewState();
}

class _BattleSetupViewState extends ConsumerState<BattleSetupView> {
  String? _topic;
  final Set<String> _selectedPowers = {};
  bool _starting = false;

  String _abilityFor(String effect) {
    switch (effect) {
      case 'half':
      case 'double':
        return 'half';
      case 'invuln':
      case 'alarm':
        return 'invuln';
      case 'fortify':
      case 'chest':
        return 'fortify';
      case 'retopic':
      case 'clock':
        return 'retopic';
      default:
        return 'half';
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final notifier = ref.read(studentDashboardProvider.notifier);
    final owned = {
      for (final p in ref.read(studentDashboardProvider).powerups)
        '${p['code']}': (p['quantity'] as num?)?.toInt() ?? 0,
    };
    final catalog = ref.read(studentDashboardProvider).powerupCatalog;
    final effects = <String>[];
    for (final powerup in catalog) {
      final id = '${powerup['id']}';
      if (!_selectedPowers.contains(id)) continue;
      final code = '${powerup['code']}';
      if ((owned[code] ?? 0) <= 0) continue;
      final ok = await notifier.consumePowerup(id);
      if (ok) effects.add(_abilityFor('${powerup['effect']}'));
    }
    await notifier.load();
    if (!mounted) return;
    final query = <String, String>{
      if (_topic != null) 'topic': _topic!,
      if (effects.isNotEmpty) 'powers': effects.join(','),
    };
    context.push(Uri(path: '/battle/play', queryParameters: query).toString());
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(questionPoolProvider);
    final student = ref.watch(studentDashboardProvider);
    final owned = {
      for (final p in student.powerups)
        '${p['code']}': (p['quantity'] as num?)?.toInt() ?? 0,
    };
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
                    if (student.powerupCatalog.isNotEmpty)
                      PanelBox(
                        span: 'INVENTARIO',
                        title: 'PODERES (${student.points} PUNTOS)',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final powerup in student.powerupCatalog)
                              SectionChip(
                                label:
                                    '${powerup['name']} x${owned['${powerup['code']}'] ?? 0}',
                                color: _selectedPowers.contains('${powerup['id']}')
                                    ? AppColors.aliados
                                    : AppColors.oro300,
                                onTap: (owned['${powerup['code']}'] ?? 0) > 0
                                    ? () => setState(() {
                                        final id = '${powerup['id']}';
                                        if (_selectedPowers.contains(id)) {
                                          _selectedPowers.remove(id);
                                        } else {
                                          _selectedPowers.add(id);
                                        }
                                      })
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (pool.hasQuestions)
                      PanelButton(
                        label: _starting ? '...' : 'COMENZAR BATALLA',
                        onTap: pool.hasQuestions && !_starting ? _start : null,
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
