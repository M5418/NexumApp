import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth_api.dart';
import 'verify_code_page.dart';

class ChangePasswordPage extends StatefulWidget {
  final String currentEmail;
  const ChangePasswordPage({super.key, required this.currentEmail});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  // Show/hide toggles
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text.trim();
    final next = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (next.length < 8) {
      _showSnack('New password must be at least 8 characters');
      return;
    }
    if (next != confirm) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = AuthApi();
      final res = await api.changePassword(current, next);
      if (res['ok'] == true) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodePage(
              purpose: 'change_password',
              sentToEmail: widget.currentEmail,
            ),
          ),
        );
      } else {
        _showSnack((res['error'] ?? 'change_password_failed').toString());
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
                          'Change Password',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter your current password and your new password',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Current password
                        TextField(
                          controller: _currentController,
                          obscureText: !_showCurrent,
                          decoration: _decoration(isDarkMode, 'Current password').copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _showCurrent = !_showCurrent),
                              icon: Icon(
                                _showCurrent ? Icons.visibility_off : Icons.visibility,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              tooltip: _showCurrent ? 'Hide password' : 'Show password',
                            ),
                          ),
                          style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        const SizedBox(height: 16),

                        // New password
                        TextField(
                          controller: _newController,
                          obscureText: !_showNew,
                          decoration: _decoration(isDarkMode, 'New password').copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _showNew = !_showNew),
                              icon: Icon(
                                _showNew ? Icons.visibility_off : Icons.visibility,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              tooltip: _showNew ? 'Hide password' : 'Show password',
                            ),
                          ),
                          style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        const SizedBox(height: 16),

                        // Confirm new password
                        TextField(
                          controller: _confirmController,
                          obscureText: !_showConfirm,
                          decoration: _decoration(isDarkMode, 'Confirm new password').copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _showConfirm = !_showConfirm),
                              icon: Icon(
                                _showConfirm ? Icons.visibility_off : Icons.visibility,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              tooltip: _showConfirm ? 'Hide password' : 'Show password',
                            ),
                          ),
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
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : Text(
                                    'Request Change',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Back to Account Center',
                            style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFFBFAE01), fontWeight: FontWeight.w500),
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