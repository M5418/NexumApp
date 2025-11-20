import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'sign_in_page.dart';
import 'profile_flow_start.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/i18n/language_provider.dart';
import 'core/i18n/translations.dart';
import 'repositories/interfaces/auth_repository.dart';
import 'repositories/interfaces/user_repository.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showLanguageDropdown = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<LanguageProvider>();

    final currentCode = lang.code;
    final currentFlag = LanguageProvider.flags[currentCode] ?? '🌐';
    final currentName =
        LanguageProvider.displayNames[currentCode] ?? currentCode.toUpperCase();

    // Use activeCodes to show only EN + FR (PT/ES/DE hidden for now)
    final allCodes = Translations.activeCodes;

    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
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
                  // NEXUM Title (brand)
                  Text(
                    'NEXUM',
                    style: GoogleFonts.inika(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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
                        // Welcome Headline
                        Text(
                          lang.t('auth.welcome'),
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtext
                        Text(
                          lang.t('auth.start_subtext'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // Email Field
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: lang.t('auth.email'),
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF666666),
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
                            hintText: lang.t('auth.password'),
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF666666),
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
                                color: const Color(0xFF666666),
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
                        const SizedBox(height: 20),
                        // Confirm Password Field
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: lang.t('auth.confirm_password'),
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF666666),
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
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF666666),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          style: GoogleFonts.inter(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Terms Text
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF666666),
                            ),
                            children: [
                              TextSpan(
                                text: lang.t('auth.terms_prefix'),
                              ),
                              TextSpan(
                                text: lang.t('auth.terms'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFF666666),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ', '),
                              TextSpan(
                                text: lang.t('auth.conditions'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFF666666),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ', and '),
                              TextSpan(
                                text: lang.t('auth.privacy'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFF666666),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
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
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  )
                                : Text(
                                    lang.t('auth.sign_up'),
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
                                TextSpan(
                                  text: lang.t('auth.already_have_account'),
                                ),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SignInPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      lang.t('auth.sign_in'),
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
                        const SizedBox(height: 24),
                        // Language Selector (synced with provider)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showLanguageDropdown = !_showLanguageDropdown;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDarkMode ? Colors.white : Colors.black,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      currentFlag,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      currentName,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _showLanguageDropdown
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showLanguageDropdown) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF0C0C0C)
                                  : const Color(0xFFF1F4F8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode ? Colors.white : Colors.black,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: allCodes.map((code) {
                                final flag =
                                    LanguageProvider.flags[code] ?? '🌐';
                                final name =
                                    LanguageProvider.displayNames[code] ??
                                        code.toUpperCase();
                                final isLast =
                                    allCodes.last == code;
                                return GestureDetector(
                                  onTap: () async {
                                    await lang.setLocale(code);
                                    setState(() {
                                      _showLanguageDropdown = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isLast
                                              ? Colors.transparent
                                              : (isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(flag,
                                            style: const TextStyle(
                                                fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
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

  Future<void> _handleSignUp() async {
    final lang = context.read<LanguageProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack(lang.t('errors.fill_all_fields'));
      return;
    }
    if (password.length < 8) {
      _showSnack(lang.t('errors.password_min'));
      return;
    }
    if (password != confirm) {
      _showSnack(lang.t('errors.password_mismatch'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Create Firebase account first and seed user profile
      final authRepo = context.read<AuthRepository>();
      final userRepo = context.read<UserRepository>();
      final authRes = await authRepo.signUpWithEmail(email: email, password: password);
      if (!authRes.success || authRes.user == null) {
        if (!mounted) return;
        _showSnack(authRes.error ?? lang.t('errors.sign_up_failed'));
        return;
      }
      final uid = authRes.user!.uid;
      await userRepo.updateUserProfile(uid, {
        'uid': uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });

      // Navigate to profile setup; user is already signed in with Firebase
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileFlowStart()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(lang.t('errors.sign_up_failed_try'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text, style: GoogleFonts.inter())));
  }
}