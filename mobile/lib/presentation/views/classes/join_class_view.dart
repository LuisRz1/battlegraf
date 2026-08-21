import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/class_provider.dart';
import '../../widgets/retro_ui.dart';

class JoinClassView extends ConsumerStatefulWidget {
  const JoinClassView({super.key});

  @override
  ConsumerState<JoinClassView> createState() => _JoinClassViewState();
}

class _JoinClassViewState extends ConsumerState<JoinClassView> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final success = await ref
        .read(classProvider.notifier)
        .joinClass(_codeController.text.trim());
    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final classState = ref.watch(classProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UNIRSE A CLASE'),
      ),
      body: BattleBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PixelPanel(
                  accent: AppColors.cyan,
                  glow: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HudLabel('CÓDIGO DE CLASE', color: AppColors.gold),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Ej. MAT-1234',
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (classState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            classState.error!,
                            style: const TextStyle(color: AppColors.brightRed),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: classState.isLoading ? null : _join,
                          child: classState.isLoading
                              ? const CircularProgressIndicator()
                              : const Text('UNIRSE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
