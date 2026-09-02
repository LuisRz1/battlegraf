import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/retro_ui.dart';

/// Pantalla de inicio con la identidad visual de la landing web:
/// logo real del juego, fondo piedra/oro y tipografia VCR OSD Mono.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: BattleBackdrop(
        intense: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo real (misma imagen que la landing /game/)
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.piedra900,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.bordeOro, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.oro500.withAlpha(70),
                          blurRadius: 22,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/battlegraph_icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const ColoredBox(
                          color: AppColors.fondoPanel,
                          child: Center(
                            child: Icon(Icons.games, color: AppColors.oro500, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Text(
                          'BATTLE',
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            color: AppColors.crema100,
                            fontSize: 48,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(color: AppColors.oro700, offset: Offset(3, 3)),
                            ],
                          ),
                        ),
                        Text(
                          'GRAPH',
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            color: AppColors.oro500,
                            fontSize: 64,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(color: AppColors.oro700, offset: Offset(3, 3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const HudLabel(
                    'APRENDER ES CONQUISTAR',
                    color: AppColors.oro300,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      color: AppColors.oro500,
                      backgroundColor: AppColors.piedra700,
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
                    color: AppColors.crema500,
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