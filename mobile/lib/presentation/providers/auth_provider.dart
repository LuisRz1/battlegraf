import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';

class AuthState {
  final bool isLoading;
  final String? token;
  final String? error;
  final Map<String, dynamic>? user;

  const AuthState({this.isLoading = false, this.token, this.error, this.user});

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    bool? isLoading,
    String? token,
    String? error,
    Map<String, dynamic>? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _loadToken();
  }

  final _controller = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get stream => _controller.stream;

  Future<void> _loadToken() async {
    const secureStorage = FlutterSecureStorage();
    final token = await secureStorage.read(key: 'token');
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(token: token);
      await _fetchUser(token);
      state = state.copyWith(isLoading: false);
      _controller.add(state);
      return;
    }
    state = state.copyWith(isLoading: false);
    _controller.add(state);
  }

  Future<void> _fetchUser(String token) async {
    final client = ApiClient(token: token);
    try {
      final response = await client.dio.get('/auth/me');
      state = state.copyWith(
        isLoading: false,
        user: response.data as Map<String, dynamic>,
      );
    } catch (_) {
      await logout();
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final client = ApiClient();
    try {
      final response = await client.dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final token = response.data['access_token'] as String;
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'token', value: token);

      state = state.copyWith(isLoading: false, token: token);
      await _fetchUser(token);
      _controller.add(state);
      return true;
    } on DioException catch (e) {
      final message = e.response?.data?['detail'] ?? 'Error de conexion';
      state = state.copyWith(isLoading: false, error: message);
      _controller.add(state);
      return false;
    }
  }

  Future<void> logout() async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'token');
    state = const AuthState();
    _controller.add(state);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
