import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'status_selection_page.dart';

class ProfileCompletionWelcome extends StatelessWidget {
  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;

  const ProfileCompletionWelcome({
    super.key,
    this.firstName = 'Dehoua',
    this.lastName = 'Marouf',
    this.hasProfilePhoto = false,
  });

  void _navigateToStatusSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatusSelectionPage(
          firstName: firstName,
          lastName: lastName,
          hasProfilePhoto: hasProfilePhoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),

              // Main Content Card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 26),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5),
                        border: Border.all(
                          color: isDarkMode
                              ? const Color(0xFF333333)
                              : const Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                      child: hasProfilePhoto
                          ? ClipOval(
                              child: Container(
                                color: const Color(
                                  0xFFBFAE01,
                                ).withValues(alpha: 26),
                                child: const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Color(0xFFBFAE01),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                (firstName.trim().isNotEmpty
                                        ? firstName.trim().substring(0, 1)
                                        : '?')
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    Text(
                      '$firstName $lastName',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Welcome Message
                    Text(
                      'Welcome to Nexum',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Slogan
                    Text(
                      'New way to connect the world',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF666666),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Personalization Message
                    Text(
                      'Let\'s personalize your experience',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: const Color(0xFF999999),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Get Started Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _navigateToStatusSelection(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBFAE01),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          'Let\'s start',
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

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
