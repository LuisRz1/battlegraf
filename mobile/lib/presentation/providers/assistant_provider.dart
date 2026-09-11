import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/institution/presentation/providers/institution_provider.dart';
import 'auth_provider.dart';

/// Chat del asistente con memoria persistente por cuenta.
class AssistantState {
  final bool isLoading;
  final bool isSending;
  final String? error;
  final List<Map<String, dynamic>> messages;

  const AssistantState({
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.messages = const [],
  });
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  AssistantNotifier(this.ref) : super(const AssistantState()) {
    load();
  }

  final Ref ref;

  String get _schoolId => ref.read(authProvider).schoolId ?? '';

  Future<void> load() async {
    if (_schoolId.isEmpty) {
      state = const AssistantState(error: 'No hay una institución activa.');
      return;
    }
    state = AssistantState(isLoading: true, messages: state.messages);
    try {
      final data = Map<String, dynamic>.from(
        (await ref
                .read(panelApiClientProvider)
                .dio
                .get('/panel/$_schoolId/me/memory'))
            .data as Map,
      );
      final raw = data['messages'];
      final messages = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      state = AssistantState(messages: messages);
    } catch (_) {
      state = AssistantState(
        error: 'No se pudo cargar la conversación.',
        messages: state.messages,
      );
    }
  }

  Future<void> send(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || _schoolId.isEmpty) return;
    final pending = [
      ...state.messages,
      {'role': 'user', 'content': text},
    ];
    state = AssistantState(isSending: true, messages: pending);
    try {
      final data = Map<String, dynamic>.from(
        (await ref
                .read(panelApiClientProvider)
                .dio
                .post('/panel/$_schoolId/me/assistant', data: {'prompt': text}))
            .data as Map,
      );
      final raw = data['messages'];
      final messages = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : pending;
      state = AssistantState(messages: messages);
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? '${(error.response!.data as Map)['detail'] ?? ''}'
          : '';
      state = AssistantState(
        messages: pending,
        error: detail.isEmpty ? 'El asistente no respondió.' : detail,
      );
    }
  }
}

final assistantProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>(
      (ref) => AssistantNotifier(ref),
    );
