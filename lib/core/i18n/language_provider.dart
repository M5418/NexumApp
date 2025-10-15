import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

class LanguageProvider extends ChangeNotifier {
  static const _prefKey = 'app_language_code';
    static const _prefUgcKey = 'ugc_translate_code';

  Locale _locale = const Locale('en');
  String _ugcTargetCode = 'en';

  LanguageProvider() {
    _load();
  }

  Locale get locale => _locale;
  String get code => _locale.languageCode;
  String get ugcTargetCode => _ugcTargetCode;

  static List<String> get supportedCodes => Translations.supportedCodes;

  static Map<String, String> get displayNames => Translations.displayNames;

  static Map<String, String> get flags => Translations.flags;

   Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Display language
      final saved = prefs.getString(_prefKey);
      if (saved != null && Translations.supportedCodes.contains(saved)) {
        _locale = Locale(saved);
      } else {
        _locale = const Locale('en');
      }

      // UGC translation target (default to display language)
      final savedUgc = prefs.getString(_prefUgcKey);
      if (savedUgc != null && Translations.supportedCodes.contains(savedUgc)) {
        _ugcTargetCode = savedUgc;
      } else {
        _ugcTargetCode = _locale.languageCode;
      }
    } catch (_) {
      _locale = const Locale('en');
      _ugcTargetCode = 'en';
    }
    notifyListeners();
  }

  Future<void> setLocale(String langCode) async {
    if (!Translations.supportedCodes.contains(langCode)) return;
    _locale = Locale(langCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, langCode);
    } catch (_) {
      // ignore persistence failure
    }
    notifyListeners();
  }
    Future<void> setUgcTarget(String langCode) async {
    if (!Translations.supportedCodes.contains(langCode)) return;
    _ugcTargetCode = langCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUgcKey, langCode);
    } catch (_) {
      // ignore persistence failure
    }
    notifyListeners();
  }


  String t(String key, {Map<String, String>? params}) {
    final langMap =
        Translations.map[code] ?? Translations.map['en']!;
    String value =
        langMap[key] ?? Translations.map['en']![key] ?? key;

    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}