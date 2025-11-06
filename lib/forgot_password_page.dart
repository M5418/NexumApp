import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'password_reset_sent_page.dart';
import 'package:provider/provider.dart';
import 'repositories/interfaces/auth_repository.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                  // NEXUM Title
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
                        // Forgot Password Headline
                        Text(
                          'Forgot Password?',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtext
                        Text(
                          'Enter your email address and we\'ll send you a link to reset your password',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Email Field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Email',
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
                        const SizedBox(height: 32),
                        // Send Reset Link Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              final navContext = context;
                              final email = _emailController.text.trim();
                              if (email.isEmpty) {
                                ScaffoldMessenger.of(navContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Enter your email', style: GoogleFonts.inter()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              try {
                                final repo = navContext.read<AuthRepository>();
                                await repo.sendPasswordResetEmail(email);
                                if (!navContext.mounted) return;
                                Navigator.push(
                                  navContext,
                                  MaterialPageRoute(
                                    builder: (_) => PasswordResetSentPage(email: email),
                                  ),
                                );
                              } catch (_) {
                                if (!navContext.mounted) return;
                                ScaffoldMessenger.of(navContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to send reset email', style: GoogleFonts.inter()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFAE01),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Send Reset Link',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Back to Sign In Navigation
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Back to Sign In',
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
