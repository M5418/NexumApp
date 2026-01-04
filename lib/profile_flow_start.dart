import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'profile_name_page.dart';
import 'responsive/responsive_breakpoints.dart';

class ProfileFlowStart extends StatelessWidget {
  const ProfileFlowStart({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (context.isMobile) {
      // MOBILE: original layout unchanged
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        appBar: AppBar(
          backgroundColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            lang.t('profile_flow.title'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  lang.t('profile_flow.heading'),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.t('profile_flow.subtitle'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildProgressStep(
                          context,
                          stepNumber: 1,
                          title: lang.t('profile_flow.step1_title'),
                          description: lang.t('profile_flow.step1_desc'),
                          icon: Icons.person_outline,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _buildProgressStep(
                          context,
                          stepNumber: 2,
                          title: lang.t('profile_flow.step2_title'),
                          description: lang.t('profile_flow.step2_desc'),
                          icon: Icons.cake_outlined,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _buildProgressStep(
                          context,
                          stepNumber: 3,
                          title: lang.t('profile_flow.step3_title'),
                          description: lang.t('profile_flow.step3_desc'),
                          icon: Icons.people_outline,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _buildProgressStep(
                          context,
                          stepNumber: 4,
                          title: lang.t('profile_flow.step4_title'),
                          description: lang.t('profile_flow.step4_desc'),
                          icon: Icons.location_on_outlined,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _buildProgressStep(
                          context,
                          stepNumber: 5,
                          title: lang.t('profile_flow.step5_title'),
                          description: lang.t('profile_flow.step5_desc'),
                          icon: Icons.photo_camera_outlined,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        _buildProgressStep(
                          context,
                          stepNumber: 6,
                          title: lang.t('profile_flow.step6_title'),
                          description: lang.t('profile_flow.step6_desc'),
                          icon: Icons.image_outlined,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFFBFAE01), size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.t('profile_flow.estimated_time'),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFBFAE01),
                                      ),
                                    ),
                                    Text(
                                      lang.t('profile_flow.time_to_complete'),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: const Color(0xFF666666),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'profile_name'), builder: (_) => const ProfileNamePage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFAE01),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      lang.t('profile_flow.start_button'),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // DESKTOP (tablet/desktop/largeDesktop): centered popup card
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: isDarkMode ? const Color(0xFF000000) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header row (replacing app bar)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profile Setup',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0x1A666666)),

                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Complete Your Profile',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Help others connect with you by completing your profile in just a few steps.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildProgressStep(
                                context,
                                stepNumber: 1,
                                title: lang.t('common.personal_information'),
                                description: 'Add your name and username',
                                icon: Icons.person_outline,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildProgressStep(
                                context,
                                stepNumber: 2,
                                title: lang.t('common.birthday'),
                                description: 'Tell us when you were born',
                                icon: Icons.cake_outlined,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildProgressStep(
                                context,
                                stepNumber: 3,
                                title: lang.t('common.gender'),
                                description: 'Select your gender identity',
                                icon: Icons.people_outline,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildProgressStep(
                                context,
                                stepNumber: 4,
                                title: lang.t('common.location'),
                                description: 'Share your address details',
                                icon: Icons.location_on_outlined,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildProgressStep(
                                context,
                                stepNumber: 5,
                                title: lang.t('common.profile_photo'),
                                description: 'Add a profile picture (optional)',
                                icon: Icons.photo_camera_outlined,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildProgressStep(
                                context,
                                stepNumber: 6,
                                title: lang.t('profile.cover_photo'),
                                description: 'Add a cover image (optional)',
                                icon: Icons.image_outlined,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Color(0xFFBFAE01), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Estimated Time',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFBFAE01),
                                            ),
                                          ),
                                          Text(
                                            '3-5 minutes to complete',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: const Color(0xFF666666),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            _pushWithPopupTransition(context, const ProfileNamePage());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBFAE01),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          child: Text(
                            'Start Profile Setup',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pushWithPopupTransition(BuildContext context, Widget page) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ));
  }

  Widget _buildProgressStep(
    BuildContext context, {
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
              border: Border.all(color: const Color(0xFFBFAE01), width: 2),
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFBFAE01),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, size: 24, color: isDarkMode ? Colors.white : Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}