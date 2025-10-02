import 'package:dio/dio.dart';
import 'env.dart';
import 'token_store.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ApiClient {
  static final ApiClient _i = ApiClient._();
  ApiClient._() {
    dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = await TokenStore.read();
          debugPrint('🔑 [${DateTime.now().toIso8601String()}] Token check for ${options.method} ${options.path}');
          debugPrint('   Token: ${t != null ? "EXISTS (${t.substring(0, 20)}...)" : "NULL"}');
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
            debugPrint('   ✅ Authorization header added');
          } else {
            debugPrint('   ⚠️  NO TOKEN - Request will be unauthorized');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('✅ [${DateTime.now().toIso8601String()}] ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;
          debugPrint('❌ [${DateTime.now().toIso8601String()}] Error $statusCode on $path');
          if (statusCode == 401) {
            debugPrint('   🚨 401 UNAUTHORIZED - but NOT auto-logging out');
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio dio;

  factory ApiClient() => _i;
}