import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/institution_dashboard.dart';

class PanelRemoteDataSource {
  const PanelRemoteDataSource(this.client);

  final ApiClient client;

  Future<JsonMap> getDashboard(String schoolId) =>
      _get('/panel/$schoolId/dashboard');

  Future<JsonMap> getAcademicOverview(String schoolId) =>
      _get('/panel/$schoolId/academics/overview');

  Future<JsonMap> getStudentTracking(String schoolId, String studentId) =>
      _get('/panel/$schoolId/students/$studentId/tracking');

  Future<JsonMap> _get(String path) async {
    final response = await client.dio.get(path);
    return JsonMap.from(response.data as Map);
  }

  Future<void> post(String path, JsonMap payload) async {
    await client.dio.post(path, data: payload);
  }

  Future<void> put(String path, JsonMap payload) async {
    await client.dio.put(path, data: payload);
  }

  Future<void> patch(String path, JsonMap payload) async {
    await client.dio.patch(path, data: payload);
  }

  Future<void> delete(String path) async {
    await client.dio.delete(path);
  }
}

String panelFailureMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) return '${data['detail']}';
    if (data is Map && data['detail'] is List) {
      final details = data['detail'] as List;
      final messages = details
          .whereType<Map>()
          .map((item) => '${item['msg'] ?? 'Datos no válidos'}')
          .toSet()
          .join(' ');
      if (messages.isNotEmpty) return messages;
    }
    if (error.response?.statusCode == 401) {
      return 'La sesión institucional venció. Vuelve a ingresar.';
    }
  }
  return 'No se pudo conectar con el centro de mando.';
}
