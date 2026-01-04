import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_birthday_page.dart';
import 'core/profile_api.dart';
import 'core/i18n/language_provider.dart';
import 'responsive/responsive_breakpoints.dart';

class ProfileNamePage extends StatefulWidget {
  const ProfileNamePage({super.key});

  @override
  State<ProfileNamePage> createState() => _ProfileNamePageState();
}

class _ProfileNamePageState extends State<ProfileNamePage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (context.isMobile) {
      // MOBILE: original layout unchanged
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Container(
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
                          lang.t('profile_setup.profil_details'),
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
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                "What's your name?",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter your real names and choose an unique username',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _firstNameController,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: lang.t('profile_name.first_name'),
                  labelStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
                  hintText: lang.t('profile_name.first_name_hint'),
                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2)),
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _lastNameController,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: lang.t('profile_name.last_name'),
                  labelStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
                  hintText: lang.t('profile_name.last_name_hint'),
                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2)),
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: lang.t('profile_name.username'),
                  labelStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
                  hintText: lang.t('profile_name.username_hint'),
                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2)),
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAndNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFAE01),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: Text(
                    lang.t('profile_setup.next'),
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
                      // Header row (replaces app bar)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                "What's your name?",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter your real names and choose an unique username',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 24),

                              TextField(
                                controller: _firstNameController,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                  labelStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
                                  hintText: 'Enter your first name',
                                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2)),
                                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _lastNameController,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                  labelStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
                                  hintText: 'Enter your last name',
                                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2)),
                                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _usernameController,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
                                  hintText: 'Choose a username',
                                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF666666))),
                                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBFAE01), width: 2)),
                                  contentPadding: EdgeInsets.symmetric(vertical: 16),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: Text(
                            lang.t('profile_setup.next'),
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
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final username = _usernameController.text.trim();

    if (first.isEmpty || last.isEmpty || username.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields', style: GoogleFonts.inter()),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      debugPrint('📝 Updating user profile: $first $last (@$username)');
      
      // Update only the name and username fields
      await ProfileApi().update({
        'first_name': first,
        'last_name': last,
        'username': username,
      });
      
      debugPrint('✅ Name and username saved successfully');
      if (!mounted) return;

      final next = ProfileBirthdayPage(firstName: first, lastName: last);
      if (!context.isMobile) {
        _pushWithPopupTransition(context, next);
      } else {
        Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'profile_birthday'), builder: (_) => next));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('profile_name.save_failed'),
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}