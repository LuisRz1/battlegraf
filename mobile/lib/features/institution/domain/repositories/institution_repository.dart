import '../entities/institution_dashboard.dart';

abstract interface class InstitutionRepository {
  Future<InstitutionDashboard> loadDashboard(String schoolId);
  Future<AcademicOverview> loadAcademicOverview(String schoolId);
  Future<JsonMap> loadStudentTracking(String schoolId, String studentId);

  Future<void> saveAttendance(String schoolId, List<JsonMap> records);
  Future<void> createGradeItem(String schoolId, JsonMap payload);
  Future<void> saveGrade(String itemId, String studentId, JsonMap payload);
  Future<void> addObservation(
    String schoolId,
    String studentId,
    JsonMap payload,
  );

  Future<void> createSection(String schoolId, JsonMap payload);
  Future<void> createSubject(String schoolId, JsonMap payload);
  Future<void> createStaff(String schoolId, JsonMap payload);
  Future<void> createStudent(String schoolId, JsonMap payload);
  Future<void> createQuestion(String schoolId, JsonMap payload);
  Future<void> createMaterial(String schoolId, JsonMap payload);
  Future<void> createAssignment(String schoolId, JsonMap payload);
  Future<void> createBattle(String schoolId, JsonMap payload);
  Future<void> createRank(String schoolId, JsonMap payload);
  Future<void> createClass(String schoolId, JsonMap payload);
  Future<void> joinClass(String code);
  Future<void> updateSchool(String schoolId, JsonMap payload);

  Future<void> deleteSection(String id);
  Future<void> updateSection(String id, JsonMap payload);
  Future<void> deleteSubject(String id);
  Future<void> updateSubject(String id, JsonMap payload);
  Future<void> deleteStaff(String id);
  Future<void> updateStaff(String id, JsonMap payload);
  Future<void> deleteStudent(String id);
  Future<void> updateStudent(String id, JsonMap payload);
  Future<void> deleteQuestion(String id);
  Future<void> updateQuestion(String id, JsonMap payload);
  Future<void> approveQuestion(String id);
  Future<void> deleteMaterial(String id);
  Future<void> deleteAssignment(String id);
  Future<void> updateAssignment(String id, JsonMap payload);
  Future<void> deleteBattle(String id);
  Future<void> updateBattle(String id, JsonMap payload);
  Future<void> deleteRank(String id);
}
