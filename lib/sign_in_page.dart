import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/i18n/language_provider.dart';
import 'sign_up_page.dart';
import 'forgot_password_page.dart';
import 'home_feed_page.dart';
import 'theme_provider.dart';
import 'repositories/interfaces/auth_repository.dart';
import 'services/profile_cache_service.dart';
import 'services/app_cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill default dev credentials in debug mode only
    if (kDebugMode) {
      _emailController.text = 'maroufguy7@gmail.com';
      _passwordController.text = 'Marouf0@!';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('signin.error_empty'),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final repo = context.read<AuthRepository>();
      final res = await repo.signInWithEmail(email: email, password: password);

      if (res.success) {
        // Clear old cached data first, then preload new user's data
        final user = fb.FirebaseAuth.instance.currentUser;
        if (user != null) {
          ProfileCacheService().clear();
          AppCacheService().clear();
          await Future.wait([
            ProfileCacheService().preloadCurrentUserData(user.uid),
            AppCacheService().preloadAppData(user.uid),
          ]);
        }
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(settings: const RouteSettings(name: 'sign_up'), builder: (_) => const HomeFeedPage()),
          );
        }
      } else {
        if (mounted) {
          final err = res.error ?? 'invalid_credentials';
          String msg;
          switch (err) {
            case 'invalid-credential':
            case 'wrong-password':
            case 'user-not-found':
              msg = Provider.of<LanguageProvider>(context, listen: false).t('signin.error_invalid');
              break;
            case 'invalid-email':
              msg = Provider.of<LanguageProvider>(context, listen: false).t('signin.error_validation');
              break;
            case 'too-many-requests':
              msg = Provider.of<LanguageProvider>(context, listen: false).t('signin.error_too_many');
              break;
            default:
              msg = '${Provider.of<LanguageProvider>(context, listen: false).t('signin.error_failed')}$err';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                msg,
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('signin.error_generic'),
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep provider if you need dark text color logic elsewhere
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        // Match Sign-Up page gradient exactly
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFF0C0C0C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  // NEXUM Title
                  Text(
                    Provider.of<LanguageProvider>(context, listen: false).t('signin.nexum'),
                    style: GoogleFonts.inika(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Auth Card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF000000)
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Welcome Back Headline
                        Text(
                          Provider.of<LanguageProvider>(context, listen: false).t('signin.welcome_back'),
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtext
                        Text(
                          Provider.of<LanguageProvider>(context, listen: false).t('signin.subtitle'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isDarkMode
                                ? const Color(0xFFAAAAAA)
                                : const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Email Field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: Provider.of<LanguageProvider>(context, listen: false).t('signin.email_hint'),
                            hintStyle: GoogleFonts.inter(
                              color: isDarkMode
                                  ? const Color(0xFFAAAAAA)
                                  : const Color(0xFF666666),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.white : Colors.black,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.white : Colors.black,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: Color(0xFFBFAE01),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                          ),
                          style: GoogleFonts.inter(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: Provider.of<LanguageProvider>(context, listen: false).t('signin.password_hint'),
                            hintStyle: GoogleFonts.inter(
                              color: isDarkMode
                                  ? const Color(0xFFAAAAAA)
                                  : const Color(0xFF666666),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.white : Colors.black,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.white : Colors.black,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: Color(0xFFBFAE01),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: isDarkMode
                                    ? const Color(0xFFAAAAAA)
                                    : const Color(0xFF666666),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          style: GoogleFonts.inter(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Forgot Password
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(name: 'forgot_password'),
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: Text(
                            Provider.of<LanguageProvider>(context, listen: false).t('signin.forgot_password'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? const Color(0xFFAAAAAA)
                                  : const Color(0xFF666666),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFAE01),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  )
                                : Text(
                                    Provider.of<LanguageProvider>(context, listen: false).t('signin.sign_in'),
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Footer Navigation
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              children: [
                                TextSpan(text: Provider.of<LanguageProvider>(context, listen: false).t('signin.no_account')),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          settings: const RouteSettings(name: 'sign_up'),
                                          builder: (context) =>
                                              const SignUpPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      Provider.of<LanguageProvider>(context, listen: false).t('signin.sign_up'),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: const Color(0xFFBFAE01),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}