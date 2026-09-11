import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/institution/presentation/providers/institution_provider.dart';
import 'auth_provider.dart';

/// Estado del dashboard del alumno: identidad + ficha de seguimiento.
class StudentDashboardState {
  final bool isLoading;
  final String? error;
  final String? studentProfileId;
  final String? sectionId;
  final String? fullName;
  final Map<String, dynamic>? tracking;

  const StudentDashboardState({
    this.isLoading = false,
    this.error,
    this.studentProfileId,
    this.sectionId,
    this.fullName,
    this.tracking,
  });

  int get xpTotal => (tracking?['xp_total'] as num?)?.toInt() ?? 0;
  String get rankName =>
      (tracking?['rank'] as Map?)?['name']?.toString() ?? 'Sin rango';
  int? get rankPosition => (tracking?['rank_position'] as num?)?.toInt();
  int? get sectionRankSize =>
      (tracking?['section_rank_size'] as num?)?.toInt();
  double? get attendanceRate =>
      (tracking?['attendance_summary'] as Map?)?['rate'] is num
      ? ((tracking!['attendance_summary'] as Map)['rate'] as num).toDouble()
      : null;
  double? get gradeAverage =>
      (tracking?['grade_average'] as num?)?.toDouble();

  List<Map<String, dynamic>> _list(String key) {
    final raw = tracking?[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> get courses => _list('courses');
  List<Map<String, dynamic>> get gradesBySubject => _list('grades_by_subject');
  List<Map<String, dynamic>> get grades => _list('grades');
  List<Map<String, dynamic>> get assignments => _list('assignments');
  List<Map<String, dynamic>> get battleResults => _list('battle_results');
  List<Map<String, dynamic>> get observations => _list('observations');
  List<Map<String, dynamic>> get attendance => _list('attendance');

  List<Map<String, dynamic>> get pendingAssignments =>
      assignments.where((a) => a['submitted'] != true).toList();
}

class StudentDashboardNotifier extends StateNotifier<StudentDashboardState> {
  StudentDashboardNotifier(this.ref) : super(const StudentDashboardState()) {
    load();
  }

  final Ref ref;

  String get _schoolId => ref.read(authProvider).schoolId ?? '';

  Future<void> load() async {
    if (_schoolId.isEmpty) {
      state = const StudentDashboardState(error: 'No hay una institución activa.');
      return;
    }
    state = StudentDashboardState(
      isLoading: true,
      tracking: state.tracking,
      studentProfileId: state.studentProfileId,
    );
    final client = ref.read(panelApiClientProvider);
    try {
      final me = Map<String, dynamic>.from(
        (await client.dio.get('/panel/$_schoolId/me')).data as Map,
      );
      final profile = me['student_profile'];
      if (profile is! Map) {
        state = const StudentDashboardState(
          error: 'Esta cuenta no tiene perfil de alumno en la institución.',
        );
        return;
      }
      final studentId = '${profile['id']}';
      final tracking = Map<String, dynamic>.from(
        (await client.dio.get(
          '/panel/$_schoolId/students/$studentId/tracking',
        )).data as Map,
      );
      state = StudentDashboardState(
        studentProfileId: studentId,
        sectionId: profile['section_id']?.toString(),
        fullName: profile['full_name']?.toString(),
        tracking: tracking,
      );
    } catch (error) {
      state = StudentDashboardState(
        error: _message(error),
        tracking: state.tracking,
        studentProfileId: state.studentProfileId,
      );
    }
  }

  Future<bool> recordBattleResult({
    required String subject,
    required String result,
    required int score,
    required int opponentScore,
    int nodesOwned = 0,
  }) async {
    if (_schoolId.isEmpty) return false;
    try {
      await ref.read(panelApiClientProvider).dio.post(
        '/panel/$_schoolId/battles/results',
        data: {
          'subject': subject,
          'mode': 'bot',
          'result': result,
          'score': score,
          'opponent_score': opponentScore,
          'nodes_owned': nodesOwned,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitAssignment(String assignmentId, String answer) async {
    if (_schoolId.isEmpty) return false;
    try {
      await ref.read(panelApiClientProvider).dio.post(
        '/panel/$_schoolId/assignments/$assignmentId/submissions',
        data: {'answer': answer},
      );
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _message(Object error) {
    if (error is DioException && error.response?.statusCode == 401) {
      return 'Tu sesión venció. Vuelve a ingresar.';
    }
    return 'No se pudo cargar tu avance. Revisa tu conexión.';
  }
}

final studentDashboardProvider =
    StateNotifierProvider<StudentDashboardNotifier, StudentDashboardState>(
      (ref) => StudentDashboardNotifier(ref),
    );
