import 'package:dio/dio.dart';

import '../providers/purchase_provider.dart';

class TestFlightApplicationResult {
  const TestFlightApplicationResult({
    required this.status,
    required this.email,
  });

  final String status;
  final String email;
}

class TestFlightApplicationException implements Exception {
  const TestFlightApplicationException(this.code);

  final String code;
}

class TestFlightApplicationService {
  TestFlightApplicationService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  bool get isConfigured => RevenueCatConfig.testFlightApiBaseUrl.isNotEmpty;

  Future<TestFlightApplicationResult> apply({
    required String email,
    required String revenueCatCustomerId,
  }) async {
    if (!isConfigured) {
      throw const TestFlightApplicationException('service_not_configured');
    }
    final baseUrl = RevenueCatConfig.testFlightApiBaseUrl.replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/v1/apps/mono-dash/testflight-applications',
        data: {'email': email, 'revenuecat_customer_id': revenueCatCustomerId},
        options: Options(
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 35),
        ),
      );
      final data = response.data ?? const {};
      return TestFlightApplicationResult(
        status: data['status'] as String? ?? 'pending',
        email: data['email'] as String? ?? email,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['code'] as String? : null;
      throw TestFlightApplicationException(code ?? 'service_unavailable');
    }
  }
}
