import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

class LanguageProvider extends ChangeNotifier {
  static const _prefKey = 'app_language_code';

  Locale _locale = const Locale('en');

  LanguageProvider() {
    _load();
  }

  Locale get locale => _locale;
  String get code => _locale.languageCode;

  static List<String> get supportedCodes => Translations.supportedCodes;

  static Map<String, String> get displayNames => Translations.displayNames;

  static Map<String, String> get flags => Translations.flags;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && Translations.supportedCodes.contains(saved)) {
        _locale = Locale(saved);
      } else {
        _locale = const Locale('en');
      }
    } catch (_) {
      _locale = const Locale('en');
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