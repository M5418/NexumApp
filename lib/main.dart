import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'theme_provider.dart';
import 'app_wrapper.dart';
import 'core/i18n/language_provider.dart';
import 'core/i18n/translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            title: languageProvider.t('app.title'),
            locale: languageProvider.locale,
            supportedLocales: Translations.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: const Color(0xFFBFAE01),
              scaffoldBackgroundColor: const Color(0xFFF1F4F8),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              cardColor: Colors.white,
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFBFAE01),
                secondary: Color(0xFF666666),
                surface: Colors.white,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFFBFAE01),
              scaffoldBackgroundColor: const Color(0xFF0C0C0C),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF000000),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              cardColor: const Color(0xFF000000),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFBFAE01),
                secondary: Color(0xFF999999),
                surface: Color(0xFF000000),
              ),
            ),
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}