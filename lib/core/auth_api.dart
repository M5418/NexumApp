import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthApi {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> signup(String email, String password) async {
    final res = await _dio.post(
      '/api/auth/signup',
      data: {'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(res.data);
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
