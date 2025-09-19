import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kApiBaseUrl = 'https://api.nexum-connects.com';
const String _kTokenKey = 'token';

class TokenStore {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> save(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      return;
    }
    await _secure.write(key: _kTokenKey, value: token);
  }

  Future<String?> read() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kTokenKey);
    }
    return _secure.read(key: _kTokenKey);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTokenKey);
      return;
    }
    await _secure.delete(key: _kTokenKey);
  }
}

class ApiClient {
  final Dio _dio;
  final TokenStore _store;

  ApiClient(this._store)
    : _dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'content-type': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _store.read();
          if (token != null && token.isNotEmpty) {
            options.headers['authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await _store.clear();
          }
          handler.next(e);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(path, data: body);
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.put<Map<String, dynamic>>(path, data: body);
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return res.data ?? <String, dynamic>{};
  }
}
