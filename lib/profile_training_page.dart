import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_bio_page.dart';
import 'core/profile_api.dart';

class ProfileTrainingPage extends StatefulWidget {
  final String firstName;
  final String lastName;

  const ProfileTrainingPage({
    super.key,
    this.firstName = 'User',
    this.lastName = '',
  });

  @override
  State<ProfileTrainingPage> createState() => _ProfileTrainingPageState();
}

class _ProfileTrainingPageState extends State<ProfileTrainingPage> {
  final List<Map<String, TextEditingController>> _trainingControllers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addTraining(); // Start with one training field
  }

  @override
  void dispose() {
    for (var training in _trainingControllers) {
      training['title']?.dispose();
      training['subtitle']?.dispose();
    }
    super.dispose();
  }

  void _addTraining() {
    setState(() {
      _trainingControllers.add({
        'title': TextEditingController(),
        'subtitle': TextEditingController(),
      });
    });
  }

  void _removeTraining(int index) {
    if (_trainingControllers.length > 1) {
      setState(() {
        _trainingControllers[index]['title']?.dispose();
        _trainingControllers[index]['subtitle']?.dispose();
        _trainingControllers.removeAt(index);
      });
    }
  }

  Future<void> _saveAndNext() async {
    final trainings = _trainingControllers
        .where((training) => training['title']!.text.trim().isNotEmpty)
        .map(
          (training) => {
            'title': training['title']!.text.trim(),
            if (training['subtitle']!.text.trim().isNotEmpty)
              'subtitle': training['subtitle']!.text.trim(),
          },
        )
        .toList();

    setState(() => _isSaving = true);
    try {
      await ProfileApi().update({'trainings': trainings});
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileBioPage(
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
            'Failed to save trainings. Try again.',
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
                        'Trainings',
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
              "Add your trainings & education",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'List your educational background, certifications, or courses',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 32),

            // Training Fields
            Expanded(
              child: ListView.builder(
                itemCount: _trainingControllers.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1A1A1A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? const Color(0xFF333333)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Training ${index + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            if (_trainingControllers.length > 1)
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeTraining(index),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _trainingControllers[index]['title']!,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Institution/Course Title',
                            labelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF666666),
                            ),
                            hintText: 'e.g., University of California',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 16,
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
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _trainingControllers[index]['subtitle']!,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Degree/Certificate (Optional)',
                            labelStyle: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF666666),
                            ),
                            hintText: 'e.g., Bachelor of Computer Science',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 16,
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
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Add Training Button
            TextButton.icon(
              onPressed: _trainingControllers.length < 10 ? _addTraining : null,
              icon: Icon(Icons.add, color: Color(0xFFBFAE01)),
              label: Text(
                'Add Training',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Color(0xFFBFAE01),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Next Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isSaving ? 'Saving...' : 'Next',
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
}
