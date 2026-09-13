import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/assistant_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/retro_ui.dart';

/// Asistente IA con memoria persistente de la cuenta.
class AssistantView extends ConsumerStatefulWidget {
  const AssistantView({super.key});

  @override
  ConsumerState<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends ConsumerState<AssistantView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await ref.read(assistantProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: BattleBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelHeader(
                span: 'MEMORIA DE LA CUENTA',
                title: 'ASISTENTE IA',
                description:
                    'Pregunta sobre tus clases, tareas o cómo estudiar.',
                action: PanelButton(
                  label: 'VOLVER',
                  ghost: true,
                  onTap: () => context.go('/lobby'),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  children: [
                    if (state.isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.oro500,
                        ),
                      ),
                    if (state.messages.isEmpty && !state.isLoading)
                      const PanelEmpty(
                        icon: Icons.smart_toy,
                        title: 'EMPIEZA A CONVERSAR',
                        message:
                            'Pide una idea de clase, un resumen o una explicación.',
                      ),
                    for (final message in state.messages)
                      PanelBox(
                        margin: const EdgeInsets.only(bottom: 8),
                        borderColor: message['role'] == 'user'
                            ? AppColors.oro500
                            : AppColors.bordeOro,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['role'] == 'user'
                                  ? 'TÚ'
                                  : 'ASISTENTE',
                              style: const TextStyle(
                                fontFamily: AppTheme.displayFont,
                                color: AppColors.oro300,
                                fontSize: 10,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${message['content'] ?? ''}',
                              style: const TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                color: AppColors.crema100,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (state.error != null)
                      Text(
                        state.error!,
                        style: const TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          color: AppColors.imperio,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          color: AppColors.crema100,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Escribe tu pregunta...',
                          hintStyle: TextStyle(color: AppColors.crema500),
                          filled: true,
                          fillColor: AppColors.fondoPanel,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PanelButton(
                      label: state.isSending ? '...' : 'ENVIAR',
                      onTap: state.isSending ? null : _send,
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
