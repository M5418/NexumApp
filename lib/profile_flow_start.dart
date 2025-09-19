import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_name_page.dart';

class ProfileFlowStart extends StatelessWidget {
  const ProfileFlowStart({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile Setup',
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
              // Title
              Text(
                'Complete Your Profile',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                'Help others connect with you by completing your profile in just a few steps.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 40),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Progress Steps
                      _buildProgressStep(
                        context,
                        stepNumber: 1,
                        title: 'Personal Information',
                        description: 'Add your name and username',
                        icon: Icons.person_outline,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),

                      _buildProgressStep(
                        context,
                        stepNumber: 2,
                        title: 'Birthday',
                        description: 'Tell us when you were born',
                        icon: Icons.cake_outlined,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),

                      _buildProgressStep(
                        context,
                        stepNumber: 3,
                        title: 'Gender',
                        description: 'Select your gender identity',
                        icon: Icons.people_outline,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),

                      _buildProgressStep(
                        context,
                        stepNumber: 4,
                        title: 'Location',
                        description: 'Share your address details',
                        icon: Icons.location_on_outlined,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),

                      _buildProgressStep(
                        context,
                        stepNumber: 5,
                        title: 'Profile Photo',
                        description: 'Add a profile picture (optional)',
                        icon: Icons.photo_camera_outlined,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),

                      _buildProgressStep(
                        context,
                        stepNumber: 6,
                        title: 'Cover Photo',
                        description: 'Add a cover image (optional)',
                        icon: Icons.image_outlined,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Estimated Time
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFBFAE01,
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Color(0xFFBFAE01),
                              size: 24,
                            ),
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
                                      fontWeight: FontWeight.normal,
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
              // Start Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileNamePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Start Profile Setup',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          // Step Number Circle
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

          // Icon
          Icon(icon, size: 24, color: isDarkMode ? Colors.white : Colors.black),
          const SizedBox(width: 16),

          // Text Content
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
                    fontWeight: FontWeight.normal,
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
