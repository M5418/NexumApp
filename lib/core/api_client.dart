import 'package:dio/dio.dart';
import 'env.dart';
import 'token_store.dart';

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
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio dio;

  factory ApiClient() => _i;
}
