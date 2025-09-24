import 'api_client.dart';
import 'package:dio/dio.dart';

class AuthApi {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> signup(String email, String password) async {
    try {
      final res = await _dio.post(
        '/api/auth/signup',
        data: {'email': email, 'password': password},
      );
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {
          'ok': data['ok'] ?? false,
          'error': data['error'] ?? 'signup_failed',
        };
      }
      return {'ok': false, 'error': 'signup_failed'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {
          'ok': false,
          'error': data['error'] ?? 'invalid_credentials',
        };
      }
      return {'ok': false, 'error': 'network_error'};
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/api/auth/me');
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (_) {}
  }
}
