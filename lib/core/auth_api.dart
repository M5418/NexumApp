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
        return {'ok': data['ok'] ?? false, 'error': data['error'] ?? 'signup_failed'};
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
        return {'ok': false, 'error': data['error'] ?? 'invalid_credentials'};
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

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final res = await _dio.delete('/api/auth/delete-account');
      return Map<String, dynamic>.from(res.data ?? {'ok': false});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {'ok': data['ok'] ?? false, 'error': data['error'] ?? 'delete_failed'};
      }
      return {'ok': false, 'error': 'network_error'};
    } catch (_) {
      return {'ok': false, 'error': 'unknown_error'};
    }
  }

  // Request change password (sends code to current email)
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final res = await _dio.patch(
        '/api/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      return Map<String, dynamic>.from(res.data ?? {'ok': false});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {'ok': data['ok'] ?? false, 'error': data['error'] ?? 'change_password_failed'};
      }
      return {'ok': false, 'error': 'network_error'};
    } catch (_) {
      return {'ok': false, 'error': 'unknown_error'};
    }
  }

  // Verify code for password change
  Future<Map<String, dynamic>> verifyChangePassword(String code) async {
    try {
      final res = await _dio.post(
        '/api/auth/change-password/verify',
        data: {'code': code},
      );
      return Map<String, dynamic>.from(res.data ?? {'ok': false});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {'ok': data['ok'] ?? false, 'error': data['error'] ?? 'verify_password_failed'};
      }
      return {'ok': false, 'error': 'network_error'};
    } catch (_) {
      return {'ok': false, 'error': 'unknown_error'};
    }
  }

  // Request change email (sends code to current email)
  Future<Map<String, dynamic>> changeEmail(
    String currentPassword,
    String newEmail,
  ) async {
    try {
      final res = await _dio.patch(
        '/api/auth/change-email',
        data: {
          'current_password': currentPassword,
          'new_email': newEmail,
        },
      );
      return Map<String, dynamic>.from(res.data ?? {'ok': false});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {'ok': data['ok'] ?? false, 'error': data['error'] ?? 'change_email_failed'};
      }
      return {'ok': false, 'error': 'network_error'};
    } catch (_) {
      return {'ok': false, 'error': 'unknown_error'};
    }
  }

  // Verify code for email change
  Future<Map<String, dynamic>> verifyChangeEmail(String code) async {
    try {
      final res = await _dio.post(
        '/api/auth/change-email/verify',
        data: {'code': code},
      );
      return Map<String, dynamic>.from(res.data ?? {'ok': false});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return {'ok': data['ok'] ?? false, 'error': data['error'] ?? 'verify_email_failed'};
      }
      return {'ok': false, 'error': 'network_error'};
    } catch (_) {
      return {'ok': false, 'error': 'unknown_error'};
    }
  }
}