import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth_api.dart';
import 'account_center_page.dart';

class VerifyCodePage extends StatefulWidget {
  final String purpose; // 'change_password' | 'change_email'
  final String sentToEmail;

  const VerifyCodePage({
    super.key,
    required this.purpose,
    required this.sentToEmail,
  });

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: GoogleFonts.inter())),
    );
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 5) {
      _showSnack('Enter the 5-digit code');
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = AuthApi();
      final res = widget.purpose == 'change_password'
          ? await api.verifyChangePassword(code)
          : await api.verifyChangeEmail(code);

      if (res['ok'] == true) {
        if (!mounted) return;
        _showSnack(widget.purpose == 'change_password'
            ? 'Password changed successfully'
            : 'Email changed successfully');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AccountCenterPage()),
          (_) => false,
        );
      } else {
        _showSnack((res['error'] ?? 'verification_failed').toString());
      }
    } catch (_) {
      _showSnack('Network error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      color: isDark ? const Color(0xFF000000) : Colors.white,
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
                          'Enter 5-digit code',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'We sent a code to ${widget.sentToEmail}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '12345',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white : Colors.black,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white : Colors.black,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(color: Color(0xFFBFAE01), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          ),
                          style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black, letterSpacing: 4),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
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
                                    'Verify',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
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