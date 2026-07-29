import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/retro_ui.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: BattleBackdrop(
        intense: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SchoolTower(color: AppColors.brightRed, size: 78),
                        SizedBox(width: 8),
                        AcademicHexBadge(
                          label: 'Σ',
                          color: AppColors.brightRed,
                          size: 44,
                        ),
                        AcademicHexBadge(
                          label: 'LAB',
                          color: AppColors.cyan,
                          size: 44,
                        ),
                        AcademicHexBadge(
                          label: 'ABC',
                          color: AppColors.neonPurple,
                          size: 44,
                        ),
                        SizedBox(width: 8),
                        SchoolTower(
                          color: AppColors.neonPurple,
                          size: 78,
                          flagRight: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Text(
                          'BATTLE',
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            color: AppColors.gold,
                            fontSize: 48,
                          ),
                        ),
                        Text(
                          'GRAF',
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            color: AppColors.brightRed,
                            fontSize: 64,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const HudLabel(
                    'APRENDER ES CONQUISTAR',
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      color: AppColors.brightRed,
                      backgroundColor: AppColors.shadowPurple,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const HudLabel('CARGANDO TERRITORIO'),
                  const SizedBox(height: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey('splash-prototype-button'),
                        onPressed: () => context.go('/battle/demo-bot'),
                        child: const Text('ENTRAR AL PROTOTIPO'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const HudLabel(
                    'JUGAR VS BOT · SIN CREDENCIALES',
                    color: AppColors.cyan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
