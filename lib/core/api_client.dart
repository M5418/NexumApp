import 'package:dio/dio.dart';
import 'env.dart';
import 'token_store.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kReleaseMode;

class ApiClient {
  static final ApiClient _i = ApiClient._();
  ApiClient._() {
    final base = kIsWeb
        ? (kReleaseMode ? '/api' : kApiBaseUrl)
        : kApiBaseUrl;
    dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
        // Enable credentials for web to include cookies
        extra: kIsWeb ? {'withCredentials': true} : {},
      ),
    );

    // Configure web-specific adapter if needed
    if (kIsWeb) {
      // For web, ensure credentials are included in all requests
      dio.options.extra['withCredentials'] = true;
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Ensure credentials are included for web requests
          if (kIsWeb) {
            options.extra['withCredentials'] = true;
          }

          final t = await TokenStore.read();
          debugPrint(
              '🔑 [${DateTime.now().toIso8601String()}] Token check for ${options.method} ${options.path}');
          debugPrint(
              '   Token: ${t != null ? "EXISTS (${t.substring(0, 20)}...)" : "NULL"}');
          debugPrint('   Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
          debugPrint(
              '   WithCredentials: ${options.extra['withCredentials'] ?? false}');

          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
            debugPrint('   ✅ Authorization header added');
          } else {
            debugPrint('   ⚠️  NO TOKEN - Request will be unauthorized');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
              '✅ [${DateTime.now().toIso8601String()}] ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;
          debugPrint(
              '❌ [${DateTime.now().toIso8601String()}] Error $statusCode on $path');
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
