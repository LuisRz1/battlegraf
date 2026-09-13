import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../views/battle/bot_battle_demo_controller.dart';
import 'auth_provider.dart';

/// Preguntas aprobadas del colegio (endpoint publico) para jugar en el movil.
class QuestionPoolState {
  final bool isLoading;
  final String? error;
  final List<DemoQuestion> questions;
  final List<String> topics;

  const QuestionPoolState({
    this.isLoading = false,
    this.error,
    this.questions = const [],
    this.topics = const [],
  });

  bool get hasQuestions => questions.isNotEmpty;

  List<DemoQuestion> forTopic(String? topic) {
    if (topic == null || topic.isEmpty) return questions;
    final key = _normalize(topic);
    return questions
        .where((q) => _normalize(q.subject) == key)
        .toList(growable: false);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .trim();
}

class QuestionPoolNotifier extends StateNotifier<QuestionPoolState> {
  QuestionPoolNotifier(this._schoolId) : super(const QuestionPoolState()) {
    load();
  }

  final String? _schoolId;

  Future<void> load() async {
    if (_schoolId == null || _schoolId.isEmpty) {
      state = const QuestionPoolState(error: 'No hay institución activa.');
      return;
    }
    state = QuestionPoolState(
      isLoading: true,
      questions: state.questions,
      topics: state.topics,
    );
    try {
      final client = ApiClient();
      final response = await client.dio.get(
        '/public/questions',
        queryParameters: {'school_id': _schoolId, 'limit': 150},
      );
      final data = response.data;
      final list = (data is Map ? data['questions'] : data) as List? ?? const [];
      final questions = <DemoQuestion>[];
      final topics = <String>[];
      final seen = <String>{};
      for (final item in list) {
        if (item is! Map) continue;
        final question = DemoQuestion.fromRemote(
          Map<String, dynamic>.from(item),
          'pool',
        );
        if (question.prompt.trim().isEmpty || question.options.isEmpty) {
          continue;
        }
        questions.add(question);
        final key = QuestionPoolState._normalize(question.subject);
        if (key.isNotEmpty && seen.add(key)) topics.add(question.subject);
      }
      state = QuestionPoolState(questions: questions, topics: topics);
    } on DioException {
      state = QuestionPoolState(
        error: 'No se pudieron cargar las preguntas del colegio.',
        questions: state.questions,
        topics: state.topics,
      );
    }
  }
}

final questionPoolProvider =
    StateNotifierProvider<QuestionPoolNotifier, QuestionPoolState>((ref) {
      final schoolId = ref.watch(authProvider.select((s) => s.schoolId));
      return QuestionPoolNotifier(schoolId);
    });
