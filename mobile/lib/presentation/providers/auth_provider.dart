import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/config/mobile_config.dart';
import '../../core/network/api_client.dart';

class AuthState {
  final bool isLoading;
  final String? token;
  final String? error;
  final Map<String, dynamic>? user;

  const AuthState({this.isLoading = false, this.token, this.error, this.user});

  bool get isAuthenticated => token != null && token!.isNotEmpty;
  bool get usesSupabase => MobileConfig.hasSupabase;
  String? get schoolId => user?['school_id']?.toString();
  String get role => user?['role']?.toString() ?? 'student';

  AuthState copyWith({
    bool? isLoading,
    String? token,
    String? error,
    Map<String, dynamic>? user,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      error: clearError ? null : error ?? this.error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _bootstrap();
  }

  final _controller = StreamController<AuthState>.broadcast();
  StreamSubscription<supabase.AuthState>? _supabaseSubscription;

  @override
  Stream<AuthState> get stream => _controller.stream;

  Future<void> _bootstrap() async {
    if (MobileConfig.hasSupabase) {
      final client = supabase.Supabase.instance.client;
      _supabaseSubscription = client.auth.onAuthStateChange.listen((
        event,
      ) async {
        if (event.session == null) {
          state = const AuthState();
        } else {
          await _loadSupabaseProfile(event.session!);
        }
        _controller.add(state);
      });
      final session = client.auth.currentSession;
      if (session != null) {
        await _loadSupabaseProfile(session);
      } else {
        state = const AuthState();
      }
      _controller.add(state);
      return;
    }
    await _loadBackendToken();
  }

  Future<void> _loadBackendToken() async {
    const secureStorage = FlutterSecureStorage();
    final token = await secureStorage.read(key: 'token');
    if (token != null && token.isNotEmpty) {
      state = state.copyWith(token: token, clearError: true);
      await _fetchBackendUser(token);
      _controller.add(state);
      return;
    }
    state = const AuthState();
    _controller.add(state);
  }

  Future<void> _loadSupabaseProfile(supabase.Session session) async {
    final client = supabase.Supabase.instance.client;
    try {
      await _completePendingOnboarding();
      final memberships = await client
          .from('memberships')
          .select(
            'id, school_id, role, status, '
            'schools(id, name, code, region, city, ugel, address, onboarding_complete)',
          )
          .eq('user_id', session.user.id)
          .eq('status', 'active')
          .order('created_at');
      final rows = List<Map<String, dynamic>>.from(memberships);
      if (rows.isEmpty) {
        state = AuthState(
          token: session.accessToken,
          error: 'Tu cuenta aún no pertenece a una institución.',
        );
        return;
      }
      final membership = rows.first;
      final schoolRaw = membership['schools'];
      final school = schoolRaw is List
          ? (schoolRaw.isEmpty
                ? <String, dynamic>{}
                : Map<String, dynamic>.from(schoolRaw.first))
          : Map<String, dynamic>.from(schoolRaw as Map? ?? const {});
      final metadata = session.user.userMetadata ?? const <String, dynamic>{};
      state = AuthState(
        token: session.accessToken,
        user: {
          'id': session.user.id,
          'email': session.user.email,
          'full_name':
              metadata['full_name'] ??
              metadata['name'] ??
              session.user.email ??
              'Usuario',
          'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
          'membership_id': membership['id'],
          'school_id': membership['school_id'],
          'school_name': school['name'] ?? 'Institución BattleGraph',
          'school_code': school['code'],
          'role': membership['role'] ?? 'student',
          'memberships': rows,
        },
      );
    } catch (error) {
      state = AuthState(
        token: session.accessToken,
        error: 'No se pudo cargar el perfil institucional: $error',
      );
    }
  }

  Future<void> _fetchBackendUser(String token) async {
    final client = ApiClient(token: token);
    try {
      final response = await client.dio.get('/auth/me');
      state = AuthState(
        token: token,
        user: Map<String, dynamic>.from(response.data as Map),
      );
    } catch (_) {
      await logout();
    }
  }

  Future<bool> login(String identity, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    if (MobileConfig.hasSupabase) {
      try {
        final response = await supabase.Supabase.instance.client.auth
            .signInWithPassword(email: identity, password: password);
        if (response.session == null) {
          throw const supabase.AuthException('Sesión no creada');
        }
        await _loadSupabaseProfile(response.session!);
        _controller.add(state);
        return state.isAuthenticated && state.user != null;
      } on supabase.AuthException catch (error) {
        state = AuthState(error: _friendlyAuthError(error.message));
        _controller.add(state);
        return false;
      } catch (_) {
        state = const AuthState(
          error: 'No se pudo conectar con la institución.',
        );
        _controller.add(state);
        return false;
      }
    }

    final client = ApiClient();
    try {
      final response = await client.dio.post(
        '/auth/login',
        data: {'username': identity, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final token = response.data['access_token'] as String;
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'token', value: token);
      await _fetchBackendUser(token);
      _controller.add(state);
      return state.isAuthenticated;
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map ? data['detail']?.toString() : null;
      state = AuthState(error: message ?? 'Error de conexión');
      _controller.add(state);
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    if (!MobileConfig.hasSupabase) {
      state = const AuthState(
        error: 'Google requiere configurar Supabase en esta compilación.',
      );
      _controller.add(state);
      return false;
    }
    try {
      return await supabase.Supabase.instance.client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: MobileConfig.authCallbackUrl,
      );
    } on supabase.AuthException catch (error) {
      state = AuthState(error: _friendlyAuthError(error.message));
      _controller.add(state);
      return false;
    }
  }

  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String schoolCode = '',
    String schoolName = '',
    String region = '',
  }) async {
    if (!MobileConfig.hasSupabase) return null;
    state = state.copyWith(isLoading: true, clearError: true);
    const storage = FlutterSecureStorage();
    final normalizedRole = role == 'professor' ? 'teacher' : role;
    await storage.write(key: 'pending_role', value: normalizedRole);
    await storage.write(key: 'pending_school_code', value: schoolCode.trim());
    await storage.write(key: 'pending_school_name', value: schoolName.trim());
    await storage.write(key: 'pending_region', value: region.trim());
    try {
      final response = await supabase.Supabase.instance.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: MobileConfig.authCallbackUrl,
        data: {'full_name': fullName.trim()},
      );
      if (response.session == null) {
        state = const AuthState();
        _controller.add(state);
        return 'Revisa tu correo y confirma la cuenta. Luego abre nuevamente BattleGraph.';
      }
      await _completePendingOnboarding();
      await _loadSupabaseProfile(response.session!);
      _controller.add(state);
      return 'Cuenta institucional creada correctamente.';
    } on supabase.AuthException catch (error) {
      state = AuthState(error: _friendlyAuthError(error.message));
      _controller.add(state);
      return null;
    } catch (error) {
      state = AuthState(error: 'No se pudo completar el registro: $error');
      _controller.add(state);
      return null;
    }
  }

  Future<void> _completePendingOnboarding() async {
    const storage = FlutterSecureStorage();
    final role = await storage.read(key: 'pending_role');
    if (role == null || role.isEmpty) return;
    final code = await storage.read(key: 'pending_school_code') ?? '';
    final schoolName = await storage.read(key: 'pending_school_name') ?? '';
    final region = await storage.read(key: 'pending_region') ?? '';
    await supabase.Supabase.instance.client.rpc(
      'complete_mobile_onboarding',
      params: {
        'p_role': role,
        'p_school_code': code,
        'p_school_name': schoolName,
        'p_region': region,
        'p_plan_slug': 'explorador',
      },
    );
    for (final key in [
      'pending_role',
      'pending_school_code',
      'pending_school_name',
      'pending_region',
    ]) {
      await storage.delete(key: key);
    }
  }

  Future<void> logout() async {
    if (MobileConfig.hasSupabase) {
      await supabase.Supabase.instance.client.auth.signOut();
    } else {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.delete(key: 'token');
    }
    state = const AuthState();
    _controller.add(state);
  }

  String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirma tu correo antes de ingresar.';
    }
    return message;
  }

  @override
  void dispose() {
    _supabaseSubscription?.cancel();
    _controller.close();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
