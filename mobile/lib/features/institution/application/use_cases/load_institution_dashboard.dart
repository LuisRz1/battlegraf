import '../../domain/entities/institution_dashboard.dart';
import '../../domain/repositories/institution_repository.dart';

class LoadInstitutionDashboard {
  const LoadInstitutionDashboard(this.repository);

  final InstitutionRepository repository;

  Future<InstitutionDashboard> call(String schoolId) =>
      repository.loadDashboard(schoolId);
}
