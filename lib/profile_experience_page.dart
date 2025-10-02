import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_training_page.dart';
import 'core/profile_api.dart';
import 'responsive/responsive_breakpoints.dart';

class ProfileExperiencePage extends StatefulWidget {
  final String firstName;
  final String lastName;

  const ProfileExperiencePage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
  });

  @override
  State<ProfileExperiencePage> createState() => _ProfileExperiencePageState();
}

class _ProfileExperiencePageState extends State<ProfileExperiencePage> {
  final List<Map<String, TextEditingController>> _experienceControllers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addExperience(); // Start with one experience field
  }

  @override
  void dispose() {
    for (var experience in _experienceControllers) {
      experience['title']?.dispose();
      experience['subtitle']?.dispose();
    }
    super.dispose();
  }

  void _addExperience() {
    setState(() {
      _experienceControllers.add({
        'title': TextEditingController(),
        'subtitle': TextEditingController(),
      });
    });
  }

  void _removeExperience(int index) {
    if (_experienceControllers.length > 1) {
      setState(() {
        _experienceControllers[index]['title']?.dispose();
        _experienceControllers[index]['subtitle']?.dispose();
        _experienceControllers.removeAt(index);
      });
    }
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

  Future<void> _saveAndNext() async {
    final experiences = _experienceControllers
        .where((experience) => experience['title']!.text.trim().isNotEmpty)
        .map(
          (experience) => {
            'title': experience['title']!.text.trim(),
            if (experience['subtitle']!.text.trim().isNotEmpty)
              'subtitle': experience['subtitle']!.text.trim(),
          },
        )
        .toList();

    setState(() => _isSaving = true);
    try {
      await ProfileApi().update({'professional_experiences': experiences});
      if (!mounted) return;

      final next = ProfileTrainingPage(
        firstName: widget.firstName,
        lastName: widget.lastName,
      );

      if (!context.isMobile) {
        _pushWithPopupTransition(context, next);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => next),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save experiences. Try again.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (context.isMobile) {
      // MOBILE: flat background, no gradient
      return Scaffold(
        backgroundColor:
            isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(100.0),
          child: _MobileAppBar(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                'Professional Experience',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'List your work experiences, positions, or roles',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 32),

              // Experience items
              Expanded(
                child: ListView.builder(
                  itemCount: _experienceControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: _ExperienceItemCard(
                        index: index,
                        isDarkMode: isDarkMode,
                        titleController:
                            _experienceControllers[index]['title']!,
                        subtitleController:
                            _experienceControllers[index]['subtitle']!,
                        canRemove: _experienceControllers.length > 1,
                        onRemove: () => _removeExperience(index),
                      ),
                    );
                  },
                ),
              ),

              // Add Experience Button
              if (_experienceControllers.length < 10)
                TextButton.icon(
                  onPressed: _addExperience,
                  icon: const Icon(Icons.add, color: Color(0xFFBFAE01)),
                  label: Text(
                    'Add Experience',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFFBFAE01),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAndNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    // DESKTOP: centered popup card
    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
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
                      // Header row (replaces app bar)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close,
                                color: isDarkMode ? Colors.white : Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profil details',
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Professional Experience',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'List your work experiences, positions, or roles',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Experience items list
                              Column(
                                children: List.generate(
                                  _experienceControllers.length,
                                  (index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 24.0),
                                    child: _ExperienceItemCard(
                                      index: index,
                                      isDarkMode: isDarkMode,
                                      titleController:
                                          _experienceControllers[index]['title']!,
                                      subtitleController:
                                          _experienceControllers[index]['subtitle']!,
                                      canRemove: _experienceControllers.length > 1,
                                      onRemove: () => _removeExperience(index),
                                    ),
                                  ),
                                ),
                              ),

                              // Add Experience Button
                              if (_experienceControllers.length < 10)
                                TextButton.icon(
                                  onPressed: _addExperience,
                                  icon: const Icon(Icons.add,
                                      color: Color(0xFFBFAE01), size: 20),
                                  label: Text(
                                    'Add Experience',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: const Color(0xFFBFAE01),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveAndNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBFAE01),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : Text(
                                  'Continue',
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileAppBar extends StatelessWidget {
  const _MobileAppBar();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const Spacer(),
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
                    'Experience',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExperienceItemCard extends StatelessWidget {
  final int index;
  final bool isDarkMode;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final bool canRemove;
  final VoidCallback onRemove;

  const _ExperienceItemCard({
    required this.index,
    required this.isDarkMode,
    required this.titleController,
    required this.subtitleController,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Experience ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'Job Title/Position',
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF666666),
              ),
              hintText: 'e.g., Software Engineer',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF999999),
              ),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF666666)),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF666666)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Color(0xFFBFAE01),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: subtitleController,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'Company/Organization (Optional)',
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF666666),
              ),
              hintText: 'e.g., Google Inc.',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF999999),
              ),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF666666)),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF666666)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Color(0xFFBFAE01),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}