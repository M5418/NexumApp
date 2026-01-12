import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/i18n/language_provider.dart';
import '../sign_in_page.dart';
import '../forgot_password_page.dart';
import '../services/onboarding_service.dart';

/// Reusable app bar actions for onboarding pages
/// Shows a dropdown with "Already have an account" and "Forgot password" options
class OnboardingAppBarActions extends StatelessWidget {
  final bool isDark;
  
  const OnboardingAppBarActions({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: isDark ? Colors.white : Colors.black,
      ),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'login':
            await _handleAlreadyHaveAccount(context, lang);
            break;
          case 'forgot':
            await _handleForgotPassword(context, lang);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'login',
          child: Row(
            children: [
              Icon(
                Icons.login,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 12),
              Text(
                lang.t('onboarding.already_have_account'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'forgot',
          child: Row(
            children: [
              Icon(
                Icons.lock_reset,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 12),
              Text(
                lang.t('onboarding.forgot_password'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAlreadyHaveAccount(BuildContext context, LanguageProvider lang) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang.t('onboarding.already_have_account'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          lang.t('onboarding.already_have_account_confirm'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.t('common.cancel'),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBFAE01),
              foregroundColor: Colors.black,
            ),
            child: Text(
              lang.t('common.continue'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Mark account as mistakenly created and sign out
    await _markAccountAsMistaken(reason: 'user_already_has_account');
    
    if (!context.mounted) return;
    
    // Navigate to sign in page
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'sign_in'),
        builder: (_) => const SignInPage(),
      ),
      (route) => false,
    );
  }

  Future<void> _handleForgotPassword(BuildContext context, LanguageProvider lang) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang.t('onboarding.forgot_password'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          lang.t('onboarding.forgot_password_confirm'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.t('common.cancel'),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBFAE01),
              foregroundColor: Colors.black,
            ),
            child: Text(
              lang.t('common.continue'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Mark account as mistakenly created and sign out
    await _markAccountAsMistaken(reason: 'user_forgot_password');
    
    if (!context.mounted) return;
    
    // Navigate to forgot password page
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'forgot_password'),
        builder: (_) => const ForgotPasswordPage(),
      ),
      (route) => false,
    );
  }

  /// Mark the current account as mistakenly created in Firebase
  /// This helps admins identify accounts that were created by mistake
  static Future<void> _markAccountAsMistaken({required String reason}) async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final email = user.email;

      // Update user document to mark as mistakenly created
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'accountMistakenlyCreated': true,
        'mistakenCreationReason': reason,
        'mistakenCreationTimestamp': FieldValue.serverTimestamp(),
      });

      // Also log to a separate collection for admin review
      await FirebaseFirestore.instance.collection('mistaken_accounts').add({
        'uid': uid,
        'email': email,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'onboardingStep': OnboardingService().currentStep.index,
        'onboardingStepName': OnboardingService().currentStep.name,
      });

      debugPrint('⚠️ Account marked as mistakenly created: $uid ($reason)');

      // Clear onboarding state
      OnboardingService().clear();

      // Sign out the user
      await fb.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('❌ Error marking account as mistaken: $e');
      // Still try to sign out even if marking fails
      try {
        await fb.FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
  }
}
