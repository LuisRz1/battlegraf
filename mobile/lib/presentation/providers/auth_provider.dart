import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/config/mobile_config.dart';
import '../../core/network/api_client.dart';

class AuthState {
  final bool isLoading;
  final String? token;
  final String? error;
  final Map<String, dynamic>? user;
  final bool isOffline;

  const AuthState({
    this.isLoading = false,
    this.token,
    this.error,
    this.user,
    this.isOffline = false,
  });

  bool get isAuthenticated =>
      token != null && token!.isNotEmpty && user != null;
  bool get usesSupabase => MobileConfig.hasSupabase;
  String? get schoolId => user?['school_id']?.toString();
  String get role => user?['role']?.toString() ?? 'student';
  String get preferredMode =>
      user?['preferred_mode']?.toString() ??
      (schoolId == null ? 'personal' : 'school');
  bool get isPersonalMode => role == 'student' && preferredMode == 'personal';
  String? get playerProfileId => user?['player_profile_id']?.toString();
  List<Map<String, dynamic>> get memberships {
    final rows = user?['memberships'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  bool get hasSchoolMembership => memberships.any(
    (membership) =>
        membership['status'] == 'active' && membership['role'] == 'student',
  );

  AuthState copyWith({
    bool? isLoading,
    String? token,
    String? error,
    Map<String, dynamic>? user,
    bool clearError = false,
    bool? isOffline,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      error: clearError ? null : error ?? this.error,
      user: user ?? this.user,
      isOffline: isOffline ?? this.isOffline,
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
      Map<String, dynamic>? playerProfile;
      try {
        final result = await client
            .from('player_profiles')
            .select(
              'id, display_name, grade, subject, preferred_mode, avatar_config',
            )
            .eq('user_id', session.user.id)
            .maybeSingle();
        if (result != null) {
          playerProfile = Map<String, dynamic>.from(result);
        }
      } catch (_) {
        // Existing staff accounts do not need a player profile.
      }
      if (rows.isEmpty && playerProfile == null) {
        state = const AuthState(
          error: 'Completa el registro como alumno o únete a un colegio.',
        );
        return;
      }
      final preferredMode =
          playerProfile?['preferred_mode']?.toString() ??
          (rows.isEmpty ? 'personal' : 'school');
      final studentMembership = rows
          .where((row) => row['role'] == 'student')
          .firstOrNull;
      final mode = playerProfile == null
          ? 'school'
          : preferredMode == 'personal' || studentMembership == null
          ? 'personal'
          : 'school';
      final membership = playerProfile == null
          ? rows.firstOrNull
          : mode == 'school'
          ? studentMembership
          : null;
      final schoolRaw = membership?['schools'];
      final school = membership == null
          ? <String, dynamic>{}
          : schoolRaw is List
          ? (schoolRaw.isEmpty
                ? <String, dynamic>{}
                : Map<String, dynamic>.from(schoolRaw.first))
          : Map<String, dynamic>.from(schoolRaw as Map? ?? const {});
      final metadata = session.user.userMetadata ?? const <String, dynamic>{};
      state = AuthState(
        token: session.accessToken,
        isOffline: false,
        user: {
          'id': session.user.id,
          'email': session.user.email,
          'full_name':
              playerProfile?['display_name'] ??
              metadata['full_name'] ??
              metadata['name'] ??
              session.user.email ??
              'Usuario',
          'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
          'player_profile_id': playerProfile?['id'],
          'player_profile': playerProfile,
          'grade': playerProfile?['grade'] ?? '5to de primaria',
          'subject': playerProfile?['subject'] ?? 'General',
          'avatar_config': playerProfile?['avatar_config'] ?? const {},
          'preferred_mode': mode,
          'membership_id': membership?['id'],
          'school_id': membership?['school_id'],
          'school_name': school['name'],
          'school_code': school['code'],
          'role': membership?['role'] ?? 'student',
          'active_membership': membership,
          'memberships': rows,
        },
      );
      await _cacheProfile(session.user.id, state.user!);
    } catch (error) {
      final cached = await _readCachedProfile(session.user.id);
      state = cached == null
          ? const AuthState(
              error: 'No se pudo cargar tu perfil. Revisa tu conexión.',
            )
          : AuthState(
              token: session.accessToken,
              user: cached,
              isOffline: true,
              error: 'Sin conexión. Tu avance se guardará en este dispositivo.',
            );
    }
  }

  Future<void> _cacheProfile(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'battlegraf.player_profile.$userId',
        jsonEncode(profile),
      );
    } catch (_) {
      // A cache failure must not block a valid signed-in session.
    }
  }

  Future<Map<String, dynamic>?> _readCachedProfile(String userId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final cached = preferences.getString('battlegraf.player_profile.$userId');
      if (cached == null) return null;
      final decoded = jsonDecode(cached);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
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
        await _clearPendingOnboardingForOtherEmail(identity);
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

  Future<bool> loginWithGoogle({
    String? role,
    String studentMode = 'school',
    String schoolCode = '',
    String schoolName = '',
    String region = '',
    String grade = '',
    String subject = '',
  }) async {
    if (!MobileConfig.hasSupabase) {
      state = const AuthState(
        error: 'Google requiere configurar Supabase en esta compilación.',
      );
      _controller.add(state);
      return false;
    }
    try {
      if (role != null) {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'pending_role', value: role);
        await storage.write(key: 'pending_student_mode', value: studentMode);
        await storage.write(
          key: 'pending_school_code',
          value: schoolCode.trim(),
        );
        await storage.write(
          key: 'pending_school_name',
          value: schoolName.trim(),
        );
        await storage.write(key: 'pending_region', value: region.trim());
        await storage.write(key: 'pending_grade', value: grade.trim());
        await storage.write(key: 'pending_subject', value: subject.trim());
        await storage.delete(key: 'pending_account_email');
      } else {
        await _clearPendingOnboarding();
      }
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
    String studentMode = 'school',
    String grade = '',
    String subject = '',
    String schoolCode = '',
    String schoolName = '',
    String region = '',
  }) async {
    if (!MobileConfig.hasSupabase) return null;
    state = state.copyWith(isLoading: true, clearError: true);
    const storage = FlutterSecureStorage();
    final normalizedRole = role == 'professor' ? 'teacher' : role;
    await storage.write(key: 'pending_role', value: normalizedRole);
    await storage.write(
      key: 'pending_account_email',
      value: email.trim().toLowerCase(),
    );
    await storage.write(key: 'pending_student_mode', value: studentMode);
    await storage.write(key: 'pending_grade', value: grade.trim());
    await storage.write(key: 'pending_subject', value: subject.trim());
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
      return normalizedRole == 'student' && studentMode == 'personal'
          ? 'Cuenta personal creada. Tu ruta de aprendizaje está lista.'
          : 'Cuenta institucional creada correctamente.';
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
    final pendingEmail = await storage.read(key: 'pending_account_email');
    final currentEmail = supabase
        .Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.email
        ?.toLowerCase();
    if (pendingEmail != null &&
        pendingEmail.isNotEmpty &&
        currentEmail != pendingEmail.trim().toLowerCase()) {
      await _clearPendingOnboarding();
      return;
    }
    final studentMode =
        await storage.read(key: 'pending_student_mode') ?? 'school';
    final code = await storage.read(key: 'pending_school_code') ?? '';
    final schoolName = await storage.read(key: 'pending_school_name') ?? '';
    final region = await storage.read(key: 'pending_region') ?? '';
    final client = supabase.Supabase.instance.client;
    if (role == 'student' && studentMode == 'personal') {
      final user = client.auth.currentUser;
      final metadata = user?.userMetadata ?? const <String, dynamic>{};
      await client.rpc(
        'complete_personal_student_onboarding',
        params: {
          'p_display_name':
              metadata['full_name'] ??
              metadata['name'] ??
              user?.email ??
              'Alumno',
          'p_grade': await storage.read(key: 'pending_grade') ?? '',
          'p_subject': await storage.read(key: 'pending_subject') ?? '',
        },
      );
    } else {
      await client.rpc(
        'complete_mobile_onboarding',
        params: {
          'p_role': role,
          'p_school_code': code,
          'p_school_name': schoolName,
          'p_region': region,
          'p_plan_slug': 'explorador',
        },
      );
    }
    await _clearPendingOnboarding();
  }

  Future<void> _clearPendingOnboarding() async {
    const storage = FlutterSecureStorage();
    for (final key in [
      'pending_role',
      'pending_account_email',
      'pending_student_mode',
      'pending_grade',
      'pending_subject',
      'pending_school_code',
      'pending_school_name',
      'pending_region',
    ]) {
      await storage.delete(key: key);
    }
  }

  Future<void> _clearPendingOnboardingForOtherEmail(String email) async {
    const storage = FlutterSecureStorage();
    final pendingEmail = await storage.read(key: 'pending_account_email');
    if (pendingEmail == null ||
        pendingEmail.trim().toLowerCase() != email.trim().toLowerCase()) {
      await _clearPendingOnboarding();
    }
  }

  Future<bool> setStudentMode(String mode) async {
    if (!{'personal', 'school'}.contains(mode) ||
        state.playerProfileId == null) {
      return false;
    }
    if (mode == 'school' &&
        !state.memberships.any(
          (membership) => membership['role'] == 'student',
        )) {
      return false;
    }
    try {
      if (state.isOffline) {
        final updatedUser = Map<String, dynamic>.from(state.user ?? const {});
        final player = Map<String, dynamic>.from(
          updatedUser['player_profile'] as Map? ?? const {},
        )..['preferred_mode'] = mode;
        updatedUser['player_profile'] = player;
        updatedUser['preferred_mode'] = mode;
        final membership = mode == 'school'
            ? state.memberships
                  .where((row) => row['role'] == 'student')
                  .firstOrNull
            : null;
        final schoolValue = membership?['schools'];
        final school = schoolValue is List
            ? (schoolValue.isEmpty ? null : schoolValue.first as Map?)
            : schoolValue as Map?;
        updatedUser['active_membership'] = membership;
        updatedUser['membership_id'] = membership?['id'];
        updatedUser['school_id'] = membership?['school_id'];
        updatedUser['school_name'] = school?['name'];
        updatedUser['school_code'] = school?['code'];
        updatedUser['role'] = membership?['role'] ?? 'student';
        state = AuthState(
          token: state.token,
          user: updatedUser,
          isOffline: true,
          error: state.error,
        );
        final userId = updatedUser['id']?.toString();
        if (userId != null) await _cacheProfile(userId, updatedUser);
        final profileId = updatedUser['player_profile_id']?.toString();
        if (profileId != null) {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(
            'battlegraf.player.pending.$profileId',
            jsonEncode({'preferred_mode': mode}),
          );
        }
        _controller.add(state);
        return true;
      }
      await supabase.Supabase.instance.client
          .from('player_profiles')
          .update({'preferred_mode': mode})
          .eq('id', state.playerProfileId!);
      await refreshProfile();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> joinSchoolByCode(String schoolCode) async {
    final code = schoolCode.trim().toUpperCase();
    if (code.length < 3 || state.playerProfileId == null) return false;
    if (state.isOffline) return false;
    try {
      await supabase.Supabase.instance.client.rpc(
        'join_school_by_code',
        params: {'p_code': code},
      );
      await supabase.Supabase.instance.client
          .from('player_profiles')
          .update({'preferred_mode': 'school'})
          .eq('id', state.playerProfileId!);
      await refreshProfile();
      return true;
    } catch (error) {
      state = state.copyWith(error: _friendlyAuthError('$error'));
      _controller.add(state);
      return false;
    }
  }

  Future<void> refreshProfile() async {
    final session = supabase.Supabase.instance.client.auth.currentSession;
    if (MobileConfig.hasSupabase && session != null) {
      await _loadSupabaseProfile(session);
      _controller.add(state);
    }
  }

  Future<void> cachePlayerProfilePatch(Map<String, dynamic> patch) async {
    final user = Map<String, dynamic>.from(state.user ?? const {});
    final profile = Map<String, dynamic>.from(
      user['player_profile'] as Map? ?? const {},
    )..addAll(patch);
    user['player_profile'] = profile;
    for (final key in ['display_name', 'grade', 'subject', 'avatar_config']) {
      if (patch.containsKey(key)) user[key] = patch[key];
    }
    state = AuthState(
      token: state.token,
      user: user,
      isOffline: true,
      error: state.error,
    );
    final userId = user['id']?.toString();
    if (userId != null) await _cacheProfile(userId, user);
    _controller.add(state);
  }

  Future<void> syncPlayerProfileSnapshot(Map<String, dynamic> profile) async {
    final user = Map<String, dynamic>.from(state.user ?? const {});
    user['player_profile'] = profile;
    user['player_profile_id'] = profile['id'] ?? user['player_profile_id'];
    user['display_name'] = profile['display_name'] ?? user['display_name'];
    user['grade'] = profile['grade'] ?? user['grade'] ?? '5to de primaria';
    user['subject'] = profile['subject'] ?? user['subject'] ?? 'General';
    user['avatar_config'] = profile['avatar_config'] ?? const {};
    user['preferred_mode'] =
        profile['preferred_mode'] ?? user['preferred_mode'];
    state = AuthState(
      token: state.token,
      user: user,
      isOffline: state.isOffline,
      error: state.error,
    );
    final userId = user['id']?.toString();
    if (userId != null) await _cacheProfile(userId, user);
    _controller.add(state);
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
    if (normalized.contains('school not found')) {
      return 'No encontramos un colegio con ese código.';
    }
    if (normalized.contains('school code is ambiguous')) {
      return 'Ese código no identifica un solo colegio. Contacta a la dirección.';
    }
    if (normalized.contains('membership already exists')) {
      return 'Tu cuenta ya está vinculada a ese colegio.';
    }
    if (normalized.contains('membership is inactive')) {
      return 'Tu acceso a ese colegio no está activo. Contacta a la dirección.';
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
