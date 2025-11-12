import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as dev;
import '../interfaces/translate_repository.dart';

class FirebaseTranslateRepository implements TranslateRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  Future<List<String>> translateTexts(List<String> texts, String targetLanguage) async {
    try {
      final callable = _functions.httpsCallable('translateTexts');
      final result = await callable.call({
        'texts': texts,
        'target_lang': _mapTargetCode(targetLanguage),
      });
      
      final data = result.data as Map<String, dynamic>;
      final translations = data['translations'] as List<dynamic>?;
      
      if (translations == null) {
        return texts; // Return original if translation fails
      }
      
      return translations.map((e) => e.toString()).toList();
    } catch (e, st) {
      // Fallback to original texts if translation service fails
      dev.log('Translation error', name: 'FirebaseTranslateRepository', error: e, stackTrace: st);
      return texts;
    }
  }

  @override
  Future<String> translateText(String text, String targetLanguage) async {
    final results = await translateTexts([text], targetLanguage);
    return results.isNotEmpty ? results.first : text;
  }

  // Map language codes to expected format (e.g., PT-PT for Portuguese)
  String _mapTargetCode(String code) {
    switch (code.toLowerCase()) {
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
        return code.toUpperCase();
    }
  }
}
