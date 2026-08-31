import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/institution/domain/entities/institution_dashboard.dart';
import '../../features/institution/domain/repositories/institution_repository.dart';
import '../../features/institution/infrastructure/data_sources/panel_remote_data_source.dart';
import '../../features/institution/presentation/providers/institution_provider.dart';
import 'auth_provider.dart';

class AcademicState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? overview;

  const AcademicState({this.isLoading = false, this.error, this.overview});

  List<Map<String, dynamic>> get students => List<Map<String, dynamic>>.from(
    overview?['students'] as List? ?? const [],
  );
  List<Map<String, dynamic>> get gradeItems => List<Map<String, dynamic>>.from(
    overview?['grade_items'] as List? ?? const [],
  );
  Map<String, dynamic> get metrics =>
      Map<String, dynamic>.from(overview?['metrics'] as Map? ?? const {});
}

class AcademicNotifier extends StateNotifier<AcademicState> {
  AcademicNotifier(this.auth, this.repository) : super(const AcademicState()) {
    load();
  }

  final AuthState auth;
  final InstitutionRepository repository;

  String get _schoolId => auth.schoolId ?? '';

  Future<void> load() async {
    if (!auth.isAuthenticated || _schoolId.isEmpty) {
      state = const AcademicState(error: 'No hay una institución activa.');
      return;
    }
    state = AcademicState(isLoading: true, overview: state.overview);
    try {
      final overview = await repository.loadAcademicOverview(_schoolId);
      state = AcademicState(overview: overview.data);
    } catch (error) {
      state = AcademicState(
        error: panelFailureMessage(error),
        overview: state.overview,
      );
    }
  }

  Future<JsonMap> loadStudent(String studentId) =>
      repository.loadStudentTracking(_schoolId, studentId);

  Future<bool> saveAttendance(
    DateTime day,
    Map<String, String> statuses,
  ) async {
    final isoDate = day.toIso8601String().split('T').first;
    return _mutate(
      () => repository.saveAttendance(
        _schoolId,
        statuses.entries
            .map<JsonMap>(
              (entry) => {
                'student_profile_id': entry.key,
                'attendance_date': isoDate,
                'status': entry.value,
                'minutes_late': entry.value == 'late' ? 5 : 0,
              },
            )
            .toList(),
      ),
    );
  }

  Future<bool> createGradeItem({
    required String title,
    required String subjectId,
    String? sectionId,
    double maxScore = 20,
  }) async {
    return _mutate(
      () => repository.createGradeItem(_schoolId, {
        'title': title,
        'subject_id': subjectId,
        'section_id': sectionId,
        'category': 'assessment',
        'max_score': maxScore,
        'weight': 1,
        'status': 'published',
      }),
    );
  }

  Future<bool> saveGrade({
    required String gradeItemId,
    required String studentId,
    required double score,
    String? feedback,
  }) async {
    return _mutate(
      () => repository.saveGrade(gradeItemId, studentId, {
        'score': score,
        'status': 'graded',
        'feedback': feedback,
      }),
    );
  }

  Future<bool> addObservation({
    required String studentId,
    required String category,
    required String note,
    bool visibleToStudent = false,
  }) async {
    return _mutate(
      () => repository.addObservation(_schoolId, studentId, {
        'category': category,
        'note': note,
        'visibility': visibleToStudent ? 'student' : 'academic_team',
        'status': 'open',
      }),
    );
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    state = AcademicState(isLoading: true, overview: state.overview);
    try {
      await action();
      await load();
      return true;
    } catch (error) {
      state = AcademicState(
        error: panelFailureMessage(error),
        overview: state.overview,
      );
      return false;
    }
  }
}

final academicProvider = StateNotifierProvider<AcademicNotifier, AcademicState>(
  (ref) => AcademicNotifier(
    ref.watch(authProvider),
    ref.watch(institutionRepositoryProvider),
  ),
);
