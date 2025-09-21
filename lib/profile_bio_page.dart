import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'interest_selection_page.dart';
import 'core/profile_api.dart';

class ProfileBioPage extends StatefulWidget {
  final String firstName;
  final String lastName;

  const ProfileBioPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
  });

  @override
  State<ProfileBioPage> createState() => _ProfileBioPageState();
}

class _ProfileBioPageState extends State<ProfileBioPage> {
  final TextEditingController _bioController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveAndNext() async {
    final bio = _bioController.text.trim();

    setState(() => _isSaving = true);
    try {
      await ProfileApi().update({'bio': bio.isEmpty ? null : bio});
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InterestSelectionPage(
            firstName: widget.firstName,
            lastName: widget.lastName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save bio. Try again.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF000000) : Color(0xFFFFFFFF),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Spacer(),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Bio',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              "Tell us about yourself",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Write a short bio that describes who you are and what you do',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 32),

            // Bio Text Field
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF333333)
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                child: TextField(
                  controller: _bioController,
                  maxLines: null,
                  expands: true,
                  maxLength: 1000,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Wellness enthusiast 💪 Lover of clean living, mindful habits, and healthy vibes ✨🌱\n\nTell your story, share your passions, or describe what makes you unique...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF999999),
                    ),
                    border: InputBorder.none,
                    counterStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Skip/Next Button Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            // Skip bio and go to next page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InterestSelectionPage(
                                  firstName: widget.firstName,
                                  lastName: widget.lastName,
                                ),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF666666),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAndNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFAE01),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isSaving ? 'Saving...' : 'Next',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
