import 'package:dio/dio.dart';
import 'api_client.dart';

class TranslateApi {
  final Dio _dio = ApiClient().dio;

  static String _mapTarget(String code) {
    switch ((code).toLowerCase()) {
      case 'en':
        return 'EN';
      case 'fr':
        return 'FR';
      case 'es':
        return 'ES';
      case 'de':
        return 'DE';
      case 'pt':
        return 'PT-PT';
      default:
        return (code).toUpperCase();
    }
  }

  Future<List<String>> translateTexts(List<String> texts, String targetCode) async {
    final res = await _dio.post('/api/translate', data: {
      'texts': texts,
      'target_lang': _mapTarget(targetCode),
    });
    final body = Map<String, dynamic>.from(res.data ?? {});
    final data = Map<String, dynamic>.from(body['data'] ?? body);
    final list = (data['translations'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return list;
  }
}