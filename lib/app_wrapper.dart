import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'home_feed_page.dart';
import 'sign_in_page.dart';
import 'theme_provider.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  final AuthService _authService = AuthService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _authService.initialize();
    if (_authService.isLoggedIn) {
      await _authService.refreshUser();
    }
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isInitializing) {
      return Scaffold(
        backgroundColor:
            themeProvider.isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _authService,
      builder: (context, child) {
        if (_authService.isLoggedIn) {
          return const HomeFeedPage();
        } else {
          return const SignInPage();
        }
      },
    );
  }
}