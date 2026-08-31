import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'auth_provider.dart';

class ClassState {
  final bool isLoading;
  final List<dynamic> classes;
  final String? error;

  const ClassState({
    this.isLoading = false,
    this.classes = const [],
    this.error,
  });

  ClassState copyWith({
    bool? isLoading,
    List<dynamic>? classes,
    String? error,
  }) {
    return ClassState(
      isLoading: isLoading ?? this.isLoading,
      classes: classes ?? this.classes,
      error: error,
    );
  }
}

class ClassNotifier extends StateNotifier<ClassState> {
  final AuthState authState;

  ClassNotifier(this.authState) : super(const ClassState()) {
    if (authState.isAuthenticated) {
      fetchClasses();
    }
  }

  Future<void> fetchClasses() async {
    if (authState.token == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ApiClient(token: authState.token);
      final response = await client.dio.get('/classes');
      state = state.copyWith(
        isLoading: false,
        classes: response.data as List<dynamic>,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail'] ?? 'Error fetching classes',
      );
    }
  }

  Future<bool> createClass(String name, String subject) async {
    if (authState.token == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ApiClient(token: authState.token);
      await client.dio.post(
        '/classes',
        data: {'name': name, 'subject': subject},
      );
      await fetchClasses();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail'] ?? 'Error creating class',
      );
      return false;
    }
  }

  Future<bool> joinClass(String code) async {
    if (authState.token == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ApiClient(token: authState.token);
      await client.dio.post('/classes/join', data: {'code': code});
      await fetchClasses();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail'] ?? 'Error joining class',
      );
      return false;
    }
  }
}

final classProvider = StateNotifierProvider<ClassNotifier, ClassState>((ref) {
  final auth = ref.watch(authProvider);
  return ClassNotifier(auth);
});
