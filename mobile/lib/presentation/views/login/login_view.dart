import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/retro_ui.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await ref
        .read(authProvider.notifier)
        .login(
          _usernameController.text.trim(),
          _passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: BattleBackdrop(
        intense: true,
        child: SafeArea(
          child: CustomScrollView(
            key: const ValueKey('login-scroll-view'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              width: 92,
                              height: 92,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.piedra900,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.bordeOro, width: 1.6),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Image.asset(
                                  'assets/images/battlegraph_icon.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stack) => const ColoredBox(
                                    color: AppColors.fondoPanel,
                                    child: Center(
                                      child: Icon(
                                        Icons.games,
                                        color: AppColors.oro500,
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ).animate()
                              .fadeIn(duration: 500.ms)
                              .scale(
                                begin: const Offset(.75, .75),
                                curve: Curves.easeOutBack,
                              ),
                          const SizedBox(height: 14),
                          FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'BATTLEGRAF',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        fontSize: 36,
                                        letterSpacing: 4,
                                      ),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: -0.3),
                          const SizedBox(height: 8),
                          Text(
                            'Aprender es conquistar',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.gold),
                            textAlign: TextAlign.center,
                          ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
                          const SizedBox(height: 28),
                          PixelPanel(
                            accent: AppColors.neonPurple,
                            glow: true,
                            child: Column(
                              children: [
                                const HudLabel(
                                  'ACCESO A LA ACADEMIA',
                                  color: AppColors.cyan,
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _usernameController,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  keyboardType: authState.usesSupabase
                                      ? TextInputType.emailAddress
                                      : TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: authState.usesSupabase
                                        ? 'Correo institucional'
                                        : 'Usuario',
                                    prefixIcon: const Icon(Icons.person),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) {
                                    if (!authState.isLoading) _login();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: Icon(Icons.lock),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (authState.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Text(
                                      authState.error!,
                                      style: const TextStyle(
                                        color: AppColors.brightRed,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ).animate().shakeX(),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : _login,
                                    child: authState.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.offWhite,
                                            ),
                                          )
                                        : const Text('ENTRAR AL GRAFO'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                                                SizedBox(
                                                                  width: double.infinity,
                                                                  child: OutlinedButton.icon(
                                                                    onPressed: authState.isLoading
                                                                        ? null
                                                                        : () => ref
                                                                              .read(authProvider.notifier)
                                                                              .loginWithGoogle(),
                                                                    icon: const Icon(Icons.login),
                                                                    label: const Text('CONTINUAR CON GOOGLE'),
                                                                    style: OutlinedButton.styleFrom(
                                                                      foregroundColor: AppColors.oro300,
                                                                      side: const BorderSide(color: AppColors.bordeOro, width: 1.3),
                                                                      shape: RoundedRectangleBorder(
                                                                        borderRadius: BorderRadius.circular(4),
                                                                      ),
                                                                      textStyle: const TextStyle(
                                                                        fontFamily: AppTheme.displayFont,
                                                                        fontSize: 11,
                                                                        letterSpacing: 1.4,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => context.go('/register'),
                                    child: const Text('CREAR CUENTA'),
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: 400.ms).fadeIn().slideY(begin: .12),
                          const SizedBox(height: 18),
                          PixelPanel(
                            accent: AppColors.brightRed,
                            glow: true,
                            child: Column(
                              children: [
                                const HudLabel(
                                  'ENTRAR AL PROTOTIPO',
                                  color: AppColors.gold,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prueba una batalla completa por turnos '
                                  'sin cuenta ni conexión.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    key: const ValueKey(
                                      'login-prototype-button',
                                    ),
                                    onPressed: () =>
                                        context.go('/battle/demo-bot'),
                                    child: const Text('JUGAR VS BOT'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const HudLabel(
                                  'MODO OFFLINE · SIN CREDENCIALES',
                                  color: AppColors.cyan,
                                ),
                              ],
                            ),
                          ).animate(delay: 520.ms).fadeIn().slideY(begin: .12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
