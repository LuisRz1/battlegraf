import '../../domain/entities/institution_dashboard.dart';
import '../../domain/repositories/institution_repository.dart';
import '../data_sources/panel_remote_data_source.dart';

class InstitutionRepositoryImpl implements InstitutionRepository {
  const InstitutionRepositoryImpl(this.remote);

  final PanelRemoteDataSource remote;

  @override
  Future<InstitutionDashboard> loadDashboard(String schoolId) async =>
      InstitutionDashboard.fromJson(await remote.getDashboard(schoolId));

  @override
  Future<AcademicOverview> loadAcademicOverview(String schoolId) async =>
      AcademicOverview(await remote.getAcademicOverview(schoolId));

  @override
  Future<JsonMap> loadStudentTracking(String schoolId, String studentId) =>
      remote.getStudentTracking(schoolId, studentId);

  @override
  Future<void> saveAttendance(String schoolId, List<JsonMap> records) =>
      remote.post('/panel/$schoolId/attendance/batch', {'records': records});

  @override
  Future<void> createGradeItem(String schoolId, JsonMap payload) =>
      remote.post('/panel/$schoolId/grade-items', payload);

  @override
  Future<void> saveGrade(String itemId, String studentId, JsonMap payload) =>
      remote.put('/panel/grade-items/$itemId/students/$studentId', payload);

  @override
  Future<void> addObservation(
    String schoolId,
    String studentId,
    JsonMap payload,
  ) =>
      remote.post('/panel/$schoolId/students/$studentId/observations', payload);

  Future<void> _create(String schoolId, String resource, JsonMap payload) =>
      remote.post('/panel/$schoolId/$resource', payload);

  @override
  Future<void> createSection(String schoolId, JsonMap payload) =>
      _create(schoolId, 'sections', payload);

  @override
  Future<void> createSubject(String schoolId, JsonMap payload) =>
      _create(schoolId, 'subjects', payload);

  @override
  Future<void> createStaff(String schoolId, JsonMap payload) =>
      _create(schoolId, 'staff', payload);

  @override
  Future<void> createStudent(String schoolId, JsonMap payload) =>
      _create(schoolId, 'students', payload);

  @override
  Future<void> createQuestion(String schoolId, JsonMap payload) =>
      _create(schoolId, 'questions', payload);

  @override
  Future<void> createMaterial(String schoolId, JsonMap payload) =>
      _create(schoolId, 'materials', payload);

  @override
  Future<void> createAssignment(String schoolId, JsonMap payload) =>
      _create(schoolId, 'assignments', payload);

  @override
  Future<void> createBattle(String schoolId, JsonMap payload) =>
      _create(schoolId, 'battles', payload);

  @override
  Future<void> createRank(String schoolId, JsonMap payload) =>
      _create(schoolId, 'ranks', payload);

  @override
  Future<void> createClass(String schoolId, JsonMap payload) =>
      _create(schoolId, 'classes', payload);

  @override
  Future<void> joinClass(String code) =>
      remote.post('/panel/classes/join', {'class_code': code});

  @override
  Future<void> updateSchool(String schoolId, JsonMap payload) =>
      remote.patch('/panel/$schoolId', payload);

  @override
  Future<void> deleteSection(String id) => remote.delete('/panel/sections/$id');

  @override
  Future<void> updateSection(String id, JsonMap payload) =>
      remote.patch('/panel/sections/$id', payload);

  @override
  Future<void> deleteSubject(String id) => remote.delete('/panel/subjects/$id');

  @override
  Future<void> updateSubject(String id, JsonMap payload) =>
      remote.patch('/panel/subjects/$id', payload);

  @override
  Future<void> deleteStaff(String id) => remote.delete('/panel/staff/$id');

  @override
  Future<void> updateStaff(String id, JsonMap payload) =>
      remote.patch('/panel/staff/$id', payload);

  @override
  Future<void> deleteStudent(String id) => remote.delete('/panel/students/$id');

  @override
  Future<void> updateStudent(String id, JsonMap payload) =>
      remote.patch('/panel/students/$id', payload);

  @override
  Future<void> deleteQuestion(String id) =>
      remote.delete('/panel/questions/$id');

  @override
  Future<void> updateQuestion(String id, JsonMap payload) =>
      remote.patch('/panel/questions/$id', payload);

  @override
  Future<void> approveQuestion(String id) =>
      remote.post('/panel/questions/$id/approve', const {});

  @override
  Future<void> deleteMaterial(String id) =>
      remote.delete('/panel/materials/$id');

  @override
  Future<void> deleteAssignment(String id) =>
      remote.delete('/panel/assignments/$id');

  @override
  Future<void> updateAssignment(String id, JsonMap payload) =>
      remote.patch('/panel/assignments/$id', payload);

  @override
  Future<void> deleteBattle(String id) => remote.delete('/panel/battles/$id');

  @override
  Future<void> updateBattle(String id, JsonMap payload) =>
      remote.patch('/panel/battles/$id', payload);

  @override
  Future<void> deleteRank(String id) => remote.delete('/panel/ranks/$id');
}
