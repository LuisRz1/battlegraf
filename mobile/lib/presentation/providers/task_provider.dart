import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/school_task.dart';
import 'auth_provider.dart';

class TaskState {
  final List<SchoolTask> tasks;
  final bool isLoading;
  final String? error;
  final String? feedback;

  const TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.feedback,
  });

  TaskState copyWith({
    List<SchoolTask>? tasks,
    bool? isLoading,
    String? error,
    String? feedback,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      feedback: feedback,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskState> {
  final ApiClient apiClient;

  TaskNotifier(this.apiClient) : super(const TaskState());

  Future<void> loadTasks() async {
    state = state.copyWith(isLoading: true, error: null, feedback: null);
    try {
      final response = await apiClient.dio.get('/tasks');
      final tasks = (response.data as List<dynamic>)
          .map((item) => SchoolTask.fromJson(item as Map<String, dynamic>))
          .toList();
      state = state.copyWith(isLoading: false, tasks: tasks);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error));
    }
  }

  Future<TaskSubmission?> submit(SchoolTask task, String answer) async {
    state = state.copyWith(isLoading: true, error: null, feedback: null);
    try {
      final response = await apiClient.dio.post(
        '/tasks/${task.id}/submissions',
        data: {'answer': answer},
      );
      final submission = TaskSubmission.fromJson(
        response.data as Map<String, dynamic>,
      );
      final message = submission.isGraded
          ? 'Resultado: ${submission.score}% · ${submission.xpAwarded} XP'
          : 'Entrega registrada. Pendiente de revision.';
      state = state.copyWith(isLoading: false, feedback: message);
      return submission;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error));
      return null;
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
    }
    return 'No se pudo completar la operacion.';
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  final auth = ref.watch(authProvider);
  return TaskNotifier(ApiClient(token: auth.token));
});
