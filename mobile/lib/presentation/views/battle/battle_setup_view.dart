import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _soundKey = 'battlegraf_mobile_sound';

  String? _topic;
  final Set<String> _selectedPowers = {};
  bool _starting = false;
  int _layers = 5;
  int _nodesPerLayer = 3;
  bool _godotMode = true;
  String _botDifficulty = 'balanced';
  bool _sound = false;

  @override
  void initState() {
    super.initState();
    _loadSound();
  }

  Future<void> _loadSound() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _sound = prefs.getBool(_soundKey) ?? false);
  }

  Future<void> _toggleSound() async {
    final next = !_sound;
    setState(() => _sound = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, next);
  }

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
    // Version Godot: el mapa completo corre en el motor y usa las preguntas
    // del colegio; no consume poderes de la batalla clasica.
    if (_godotMode) {
      final query = <String, String>{
        if (_topic != null) 'topic': _topic!,
        'layers': '$_layers',
        'nodes': '$_nodesPerLayer',
        'bot': _botDifficulty,
        'teams': '2',
        if (!_sound) 'mute': '1',
      };
      if (!mounted) return;
      context.push(
        Uri(path: '/battle/godot', queryParameters: query).toString(),
      );
      return;
    }
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
      'layers': '$_layers',
      'nodes': '$_nodesPerLayer',
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
                                color:
                                    _selectedPowers.contains('${powerup['id']}')
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
                    PanelBox(
                      span: 'DIFICULTAD',
                      title: 'TAMAÑO DEL MAPA',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SectionChip(
                            label: 'PEQUEÑO',
                            color: _layers == 4
                                ? AppColors.aliados
                                : AppColors.oro300,
                            onTap: () => setState(() {
                              _layers = 4;
                              _nodesPerLayer = 3;
                            }),
                          ),
                          SectionChip(
                            label: 'MEDIANO',
                            color: _layers == 5
                                ? AppColors.aliados
                                : AppColors.oro300,
                            onTap: () => setState(() {
                              _layers = 5;
                              _nodesPerLayer = 3;
                            }),
                          ),
                          SectionChip(
                            label: 'GRANDE',
                            color: _layers == 6
                                ? AppColors.aliados
                                : AppColors.oro300,
                            onTap: () => setState(() {
                              _layers = 6;
                              _nodesPerLayer = 4;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    PanelBox(
                      span: 'MOTOR DE BATALLA',
                      title: _godotMode
                          ? 'GODOT · MAPA COMPLETO'
                          : 'CLASICA · RAPIDA',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SectionChip(
                                label: 'GODOT',
                                color: _godotMode
                                    ? AppColors.aliados
                                    : AppColors.oro300,
                                onTap: () => setState(() => _godotMode = true),
                              ),
                              SectionChip(
                                label: 'CLASICA',
                                color: !_godotMode
                                    ? AppColors.aliados
                                    : AppColors.oro300,
                                onTap: () => setState(() => _godotMode = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _godotMode
                                ? 'Castillos, animaciones y efectos del juego original. Los poderes se usan en la arena clasica.'
                                : 'Arena ligera dentro de la app con poderes equipables.',
                            style: const TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              color: AppColors.crema500,
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_godotMode) ...[
                      const SizedBox(height: 12),
                      PanelBox(
                        span: 'IA RIVAL',
                        title: 'NIVEL DEL BOT',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in const [
                              ['facil', 'FACIL'],
                              ['balanced', 'EQUILIBRADO'],
                              ['hard', 'DIFICIL'],
                              ['adaptive', 'ADAPTATIVO'],
                            ])
                              SectionChip(
                                label: entry[1],
                                color: _botDifficulty == entry[0]
                                    ? AppColors.aliados
                                    : AppColors.oro300,
                                onTap: () =>
                                    setState(() => _botDifficulty = entry[0]),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      PanelBox(
                        span: 'AUDIO',
                        title: _sound ? 'SONIDO ACTIVO' : 'SILENCIO',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SectionChip(
                              label: _sound
                                  ? 'SILENCIAR MUSICA'
                                  : 'ACTIVAR SONIDO',
                              color: _sound
                                  ? AppColors.aliados
                                  : AppColors.oro300,
                              onTap: _toggleSound,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (pool.hasQuestions)
                      PanelButton(
                        label: _starting
                            ? '...'
                            : _godotMode
                            ? 'COMENZAR EN GODOT'
                            : 'COMENZAR BATALLA',
                        onTap: pool.hasQuestions && !_starting ? _start : null,
                      ),
                    const SizedBox(height: 8),
                    PanelButton(
                      label: 'RECARGAR PREGUNTAS',
                      ghost: true,
                      onTap: () =>
                          ref.read(questionPoolProvider.notifier).load(),
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
