// File: lib/core/reports_api.dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class ReportsApi {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> create({
    required String targetType, // 'post' | 'story' | 'user'
    required String targetId,
    required String cause, // snake_case like 'harmful_content'
    String? comment,
  }) async {
    final res = await _dio.post('/api/reports', data: {
      'targetType': targetType,
      'targetId': targetId,
      'cause': cause,
      'comment': comment ?? '',
    });
    return Map<String, dynamic>.from(res.data ?? {});
  }
}