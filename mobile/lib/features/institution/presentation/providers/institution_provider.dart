import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../presentation/providers/auth_provider.dart';
import '../../application/use_cases/load_institution_dashboard.dart';
import '../../domain/entities/institution_dashboard.dart';
import '../../domain/repositories/institution_repository.dart';
import '../../infrastructure/data_sources/panel_remote_data_source.dart';
import '../../infrastructure/repositories/institution_repository_impl.dart';

final panelApiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authProvider.select((state) => state.token));
  return ApiClient(token: token);
});

final institutionRepositoryProvider = Provider<InstitutionRepository>((ref) {
  return InstitutionRepositoryImpl(
    PanelRemoteDataSource(ref.watch(panelApiClientProvider)),
  );
});

class InstitutionState {
  const InstitutionState({this.dashboard, this.loading = false, this.error});

  final InstitutionDashboard? dashboard;
  final bool loading;
  final String? error;

  InstitutionState copyWith({
    InstitutionDashboard? dashboard,
    bool? loading,
    String? error,
  }) => InstitutionState(
    dashboard: dashboard ?? this.dashboard,
    loading: loading ?? this.loading,
    error: error,
  );
}

class InstitutionNotifier extends StateNotifier<InstitutionState> {
  InstitutionNotifier(this.ref) : super(const InstitutionState()) {
    load();
  }

  final Ref ref;

  Future<void> load() async {
    final schoolId = ref.read(authProvider).schoolId;
    if (schoolId == null) {
      state = const InstitutionState(error: 'Cuenta sin institución activa.');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final dashboard = await LoadInstitutionDashboard(
        ref.read(institutionRepositoryProvider),
      )(schoolId);
      state = InstitutionState(dashboard: dashboard);
    } catch (error) {
      state = InstitutionState(
        dashboard: state.dashboard,
        error: panelFailureMessage(error),
      );
    }
  }

  Future<bool> mutate(
    Future<void> Function(InstitutionRepository repository, String schoolId)
    action,
  ) async {
    final schoolId = ref.read(authProvider).schoolId;
    if (schoolId == null) return false;
    state = state.copyWith(loading: true, error: null);
    try {
      await action(ref.read(institutionRepositoryProvider), schoolId);
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, error: panelFailureMessage(error));
      return false;
    }
  }
}

final institutionProvider =
    StateNotifierProvider<InstitutionNotifier, InstitutionState>((ref) {
      return InstitutionNotifier(ref);
    });
