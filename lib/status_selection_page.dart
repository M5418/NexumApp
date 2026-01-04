import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'profile_experience_page.dart';
import 'core/profile_api.dart';
import 'responsive/responsive_breakpoints.dart';

class StatusSelectionPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;

  const StatusSelectionPage({
    super.key,
    this.firstName = '',  // Will use translation for default
    this.lastName = '',
    this.hasProfilePhoto = false,
  });

  @override
  State<StatusSelectionPage> createState() => _StatusSelectionPageState();
}

class _StatusSelectionPageState extends State<StatusSelectionPage> {
  String? _selectedStatus;
  bool _isSaving = false;

  void _selectStatus(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  Future<void> _navigateNext() async {
    if (_selectedStatus == null) return;
    setState(() => _isSaving = true);
    try {
      await ProfileApi().update({'status': _selectedStatus});
      if (!mounted) return;

      final next = ProfileExperiencePage(
        firstName: widget.firstName,
        lastName: widget.lastName,
      );

      if (!context.isMobile) {
        _pushWithPopupTransition(context, next);
      } else {
        Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'profile_experience'), builder: (_) => next));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('status.save_failed'),
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
                          Provider.of<LanguageProvider>(context, listen: false).t('status.title'),
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Question Text
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('status.question'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 40),

                // Status Options
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusOption(
                        Provider.of<LanguageProvider>(context, listen: false).t('status.entrepreneur'),
                        _selectedStatus == 'Entrepreneur',
                        isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatusOption(
                        Provider.of<LanguageProvider>(context, listen: false).t('status.investor'),
                        _selectedStatus == 'Investor',
                        isDarkMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                const Spacer(),

                // Next Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedStatus != null && !_isSaving ? _navigateNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedStatus != null && !_isSaving
                          ? const Color(0xFFBFAE01)
                          : (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                      foregroundColor: _selectedStatus != null && !_isSaving ? Colors.black : (isDarkMode ? Colors.grey : Colors.grey),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _isSaving ? Provider.of<LanguageProvider>(context, listen: false).t('status.saving') : Provider.of<LanguageProvider>(context, listen: false).t('status.next'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    }

    // DESKTOP/TABLET/LARGE DESKTOP: centered popup
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
                            Provider.of<LanguageProvider>(context, listen: false).t('status.title'),
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  Provider.of<LanguageProvider>(context, listen: false).t('status.question'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatusOption(
                                        Provider.of<LanguageProvider>(context, listen: false).t('status.entrepreneur'),
                                        _selectedStatus == 'Entrepreneur',
                                        isDarkMode,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatusOption(
                                        Provider.of<LanguageProvider>(context, listen: false).t('status.investor'),
                                        _selectedStatus == 'Investor',
                                        isDarkMode,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selectedStatus != null && !_isSaving ? _navigateNext : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedStatus != null && !_isSaving
                                ? const Color(0xFFBFAE01)
                                : (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                            foregroundColor: _selectedStatus != null && !_isSaving ? Colors.black : (isDarkMode ? Colors.grey : Colors.grey),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            _isSaving ? Provider.of<LanguageProvider>(context, listen: false).t('status.saving') : Provider.of<LanguageProvider>(context, listen: false).t('status.next'),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(String status, bool isSelected, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _selectStatus(status),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFBFAE01)
              : (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFBFAE01)
                : (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
            width: 1,
          ),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.black : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black : (isDarkMode ? const Color(0xFF666666) : const Color(0xFFCCCCCC)),
                  width: 2,
                ),
                color: Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
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
}