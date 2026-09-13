import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_ui.dart';
import '../../widgets/retro_controls.dart';

/// Mis clases — estilo panel web (cajas con codigo CL-XXXX).
class ClassListView extends ConsumerWidget {
  const ClassListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isProfessor = user?['role'] == 'professor';
    final classState = ref.watch(classProvider);

    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      appBar: AppBar(
        title: const Text('MIS CLASES'),
        backgroundColor: AppColors.piedra950,
        foregroundColor: AppColors.crema100,
        titleTextStyle: const TextStyle(
          fontFamily: AppTheme.displayFont,
          color: AppColors.oro300,
          fontSize: 15,
          letterSpacing: 2,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.oro500,
        foregroundColor: AppColors.piedra950,
        onPressed: () {
          if (isProfessor) {
            // Mostrar dialogo de creacion
          } else {
            context.push('/classes/join');
          }
        },
        child: const Icon(Icons.add),
      ),
      body: BattleBackdrop(
        child: classState.isLoading
            ? const Center(
                child: HudLabel('CARGANDO CLASES', color: AppColors.oro300),
              )
            : classState.error != null
            ? PanelEmpty(
                title: 'ERROR AL CARGAR',
                message: classState.error!,
                icon: Icons.error_outline,
              )
            : classState.classes.isEmpty
            ? const PanelEmpty(
                title: 'SIN CLASES',
                message: 'Usa el boton + para unirte con el codigo de tu clase (CL-XXXX).',
                icon: Icons.school_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < classState.classes.length; i++)
                    _ClassCard(cls: classState.classes[i]),
                ],
              ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final dynamic cls;

  const _ClassCard({required this.cls});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PanelBox(
        span: 'CLASE',
        title: cls['name'] ?? 'Sin nombre',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatPair(value: cls['code'] ?? '---', label: 'CODIGO'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.legion.withAlpha(24),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.legion.withAlpha(150), width: 1),
                  ),
                  child: const Text(
                    'VIGENTE',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      color: AppColors.legion,
                      fontSize: 9,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            if (cls['subject'] != null) ...[
              const SizedBox(height: 8),
              Text(
                cls['subject'] ?? '',
                style: const TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  color: AppColors.crema500,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                PanelMiniButton(
                                  label: 'COPIAR CODIGO',
                                  onTap: () {
                                    final code = cls['code'] ?? '';
                                    if (code.isNotEmpty) {
                                      showRetroMessage(context, 'Codigo $code copiado (simulado).');
                                    }
                                  },
                                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}