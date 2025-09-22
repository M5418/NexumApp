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
          debugPrint(' Token from storage: $t');
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
            debugPrint(' Added Authorization header');
          } else {
            debugPrint(' No token found in storage');
          }
          debugPrint(' Request headers: ${options.headers}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(' Response status: ${response.statusCode}');
          debugPrint(' Response data: ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) {
          debugPrint(
            ' API Error: ${error.response?.statusCode} - ${error.response?.data}',
          );
          handler.next(error);
        },
      ),
    );
  }

  late final Dio dio;

  factory ApiClient() => _i;
}
