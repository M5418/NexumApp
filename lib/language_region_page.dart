import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/i18n/language_provider.dart';
import 'widgets/country_selector.dart';

class LanguageRegionPage extends StatefulWidget {
  const LanguageRegionPage({super.key});

  @override
  State<LanguageRegionPage> createState() => _LanguageRegionPageState();
}

class _LanguageRegionPageState extends State<LanguageRegionPage> {
  String _selectedRegion = 'Canada';
  bool _use24hTime = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('settings.language_region.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Display Language (Provider-backed and synced with Sign Up dropdown)
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(lang.t('settings.display_language')),
                const SizedBox(height: 8),
                _languageDropdown(lang),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Region Settings (local state)
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Provider.of<LanguageProvider>(context, listen: false).t('region.settings')),
                const SizedBox(height: 8),
                _regionSelector(),
                const SizedBox(height: 8),
                _switchTile(
                  title: Provider.of<LanguageProvider>(context, listen: false).t('region.24hour'),
                  subtitle: Provider.of<LanguageProvider>(context, listen: false).t('region.24hour_subtitle'),
                  value: _use24hTime,
                  onChanged: (v) => setState(() => _use24hTime = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Translation settings
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Provider.of<LanguageProvider>(context, listen: false).t('region.translation')),
                const SizedBox(height: 8),
                _switchTile(
                  title: 'Enable Post Translation',
                  subtitle: 'Show translate button on posts and comments',
                  value: lang.postTranslationEnabled,
                  onChanged: (v) => lang.setPostTranslationEnabled(v),
                ),
                if (lang.postTranslationEnabled) ...[
                  const SizedBox(height: 12),
                  _ugcTargetDropdown(lang),
                ],
                const SizedBox(height: 8),
                _comingSoonTile(
                  title: 'Auto-translate posts & comments',
                  subtitle: 'Automatically translate content to your language',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton(
            onPressed: _resetDefaults,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBFAE01),
              side: const BorderSide(color: Color(0xFFBFAE01), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('region.reset_defaults'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Display Language dropdown (Provider-backed)
  Widget _languageDropdown(LanguageProvider lang) {
    final codes = LanguageProvider.supportedCodes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: lang.code,
          isExpanded: true,
          items: codes
              .map(
                (code) => DropdownMenuItem<String>(
                  value: code,
                  child: Row(
                    children: [
                      Text(
                        LanguageProvider.flags[code] ?? '🌐',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        LanguageProvider.displayNames[code] ?? code.toUpperCase(),
                        style: GoogleFonts.inter(),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) async {
            if (v != null && v != lang.code) {
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return PopScope(
                    canPop: false,
                    child: Dialog(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              lang.t('settings.language_applying'),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.t('settings.language_refresh'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF666666),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );

              // Change language
              context.read<LanguageProvider>().setLocale(v);

              // Wait 5 seconds
              await Future.delayed(const Duration(seconds: 5));

              // Close dialog
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            }
          },
        ),
      ),
    );
  }

  // Target language for translating posts/comments (Provider-backed)
  Widget _ugcTargetDropdown(LanguageProvider lang) {
    final codes = LanguageProvider.supportedCodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Translate posts to'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: lang.ugcTargetCode,
              isExpanded: true,
              items: codes
                  .map(
                    (code) => DropdownMenuItem<String>(
                      value: code,
                      child: Row(
                        children: [
                          Text(
                            LanguageProvider.flags[code] ?? '🌐',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LanguageProvider.displayNames[code] ?? code.toUpperCase(),
                            style: GoogleFonts.inter(),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) lang.setUgcTarget(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // Region selector with search (comprehensive country list)
  Widget _regionSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Region', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => CountrySelector(
                initialCountry: _selectedRegion,
                isDarkMode: isDark,
                onCountrySelected: (country) {
                  setState(() => _selectedRegion = country);
                },
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedRegion,
                  style: GoogleFonts.inter(color: textColor),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: textColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Keep subtle/no shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: const Color(0xFF666666), fontSize: 12),
      ),
      activeTrackColor: const Color(0xFFBFAE01),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _comingSoonTile({
    required String title,
    required String subtitle,
  }) {
    return Opacity(
      opacity: 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFBFAE01).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                Provider.of<LanguageProvider>(context, listen: false).t('region.coming_soon'),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFBFAE01),
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(color: const Color(0xFF666666), fontSize: 12),
        ),
      ),
    );
  }

  void _resetDefaults() {
    // Reset provider language to English, keep other toggles to sensible defaults
    final lang = context.read<LanguageProvider>();
    lang.setLocale('en');
    lang.setPostTranslationEnabled(false);
    setState(() {
      _selectedRegion = 'Canada';
      _use24hTime = true;
    });
  }
}