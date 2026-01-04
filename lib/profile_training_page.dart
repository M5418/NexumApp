import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_bio_page.dart';
import 'core/profile_api.dart';
import 'core/i18n/language_provider.dart';
import 'responsive/responsive_breakpoints.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final res = await ProfileApi().me();
      final body = Map<String, dynamic>.from(res);
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      final trainings = _parseListOfMap(data['trainings']);

      if (!mounted) return;
      setState(() {
        if (trainings.isEmpty) {
          _addTraining(); // Start with one empty field
        } else {
          // Load existing trainings
          for (final training in trainings) {
            _trainingControllers.add({
              'title': TextEditingController(text: (training['title'] ?? '').toString()),
              'subtitle': TextEditingController(text: (training['subtitle'] ?? '').toString()),
            });
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _addTraining(); // Fallback to empty field on error
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseListOfMap(dynamic value) {
    try {
      if (value == null) return [];
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        return [];
      }
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
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

      final next = ProfileBioPage(
        firstName: widget.firstName,
        lastName: widget.lastName,
      );

      if (!context.isMobile) {
        _pushWithPopupTransition(context, next);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(settings: const RouteSettings(name: 'interest_selection'), builder: (context) => next),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('profile_training.save_failed'),
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
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor:
            isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (context.isMobile) {
      // MOBILE: original layout unchanged
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
                "Add your trainings & education",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.t('profile_training.subtitle'),
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
                    return _TrainingItemCard(
                      index: index,
                      isDarkMode: isDarkMode,
                      titleController: _trainingControllers[index]['title']!,
                      subtitleController:
                          _trainingControllers[index]['subtitle']!,
                      canRemove: _trainingControllers.length > 1,
                      onRemove: () => _removeTraining(index),
                    );
                  },
                ),
              ),

              // Add Training Button
              TextButton.icon(
                onPressed: _addTraining,
                icon: const Icon(Icons.add, color: Color(0xFFBFAE01), size: 20),
                label: Text(
                  lang.t('profile_training.add'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFFBFAE01),
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
                    _isSaving ? lang.t('profile_setup.saving') : lang.t('profile_setup.next'),
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
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lang.t('profile_setup.profil_details'),
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
                                "Add your trainings & education",
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                lang.t('profile_training.subtitle'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Training items list (column for scroll area)
                              Column(
                                children: List.generate(
                                  _trainingControllers.length,
                                  (index) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 24.0),
                                    child: _TrainingItemCard(
                                      index: index,
                                      isDarkMode: isDarkMode,
                                      titleController:
                                          _trainingControllers[index]['title']!,
                                      subtitleController:
                                          _trainingControllers[index]
                                              ['subtitle']!,
                                      canRemove:
                                          _trainingControllers.length > 1,
                                      onRemove: () => _removeTraining(index),
                                    ),
                                  ),
                                ),
                              ),

                              // Add Training Button
                              TextButton.icon(
                                onPressed: _addTraining,
                                icon: const Icon(Icons.add,
                                    color: Color(0xFFBFAE01), size: 20),
                                label: Text(
                                  lang.t('profile_training.add'),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFFBFAE01),
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
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            _isSaving ? lang.t('profile_setup.saving') : lang.t('profile_setup.next'),
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
    final lang = context.watch<LanguageProvider>();
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
                    lang.t('profile_training.title'),
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

class _TrainingItemCard extends StatelessWidget {
  final int index;
  final bool isDarkMode;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final VoidCallback? onRemove;
  final bool canRemove;

  const _TrainingItemCard({
    required this.index,
    required this.isDarkMode,
    required this.titleController,
    required this.subtitleController,
    this.onRemove,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${lang.t('profile_training.training_number')} ${index + 1}',
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
                  ),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: lang.t('profile_training.institution'),
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
            controller: subtitleController,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: lang.t('profile_training.degree'),
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
  }
}