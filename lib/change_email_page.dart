import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth_api.dart';
import 'verify_code_page.dart';

class ChangeEmailPage extends StatefulWidget {
  final String currentEmail;
  const ChangeEmailPage({super.key, required this.currentEmail});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newEmail = _newEmailController.text.trim();
    final pwd = _passwordController.text.trim();

    if (newEmail.isEmpty || pwd.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(newEmail)) {
      _showSnack('Enter a valid email');
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = AuthApi();
      final res = await api.changeEmail(pwd, newEmail);
      if (res['ok'] == true) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodePage(
              purpose: 'change_email',
              sentToEmail: widget.currentEmail,
            ),
          ),
        );
      } else {
        _showSnack((res['error'] ?? 'change_email_failed').toString());
      }
    } catch (_) {
      _showSnack('Network error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: GoogleFonts.inter())),
    );
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
                  Text(
                    'NEXUM',
                    style: GoogleFonts.inika(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
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
                        Text(
                          'Change Email',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter your new email and your current password to confirm',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _newEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _decoration(isDarkMode, 'New email'),
                          style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _decoration(isDarkMode, 'Current password'),
                          style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFAE01),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              elevation: 0,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Text(
                                    'Request Change',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Back to Account Center',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFFBFAE01),
                              fontWeight: FontWeight.w500,
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

  InputDecoration _decoration(bool isDarkMode, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide(color: isDarkMode ? Colors.white : Colors.black, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide(color: isDarkMode ? Colors.white : Colors.black, width: 1.5),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(25)),
        borderSide: BorderSide(color: Color(0xFFBFAE01), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }
}