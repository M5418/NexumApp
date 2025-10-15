import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/i18n/language_provider.dart';

class LanguageRegionPage extends StatefulWidget {
  const LanguageRegionPage({super.key});

  @override
  State<LanguageRegionPage> createState() => _LanguageRegionPageState();
}

class _LanguageRegionPageState extends State<LanguageRegionPage> {
  final List<String> _regions = [
    'United States',
    'Canada',
    'France',
    'Germany',
    'United Kingdom',
    'Côte d’Ivoire',
  ];

  String _selectedRegion = 'Canada';
  bool _autoTranslateUI = true;   // UI auto-translate (keep as a local toggle for now)
  bool _autoTranslateUGC = true;  // user-generated content translation
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
                _sectionTitle('Region Settings'),
                const SizedBox(height: 8),
                _regionDropdown(),
                const SizedBox(height: 8),
                _switchTile(
                  title: 'Use 24-hour time',
                  subtitle: 'Switch between 24-hour and 12-hour time formats',
                  value: _use24hTime,
                  onChanged: (v) => setState(() => _use24hTime = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Translation toggles (local state)
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Translation'),
                const SizedBox(height: 8),
                _switchTile(
                  title: 'Auto-translate UI',
                  subtitle: 'Match the app interface to your device language',
                  value: _autoTranslateUI,
                  onChanged: (v) => setState(() => _autoTranslateUI = v),
                ),
                _switchTile(
                  title: 'Auto-translate posts & comments',
                  subtitle:
                      'Translate user-generated content to your display language',
                  value: _autoTranslateUGC,
                  onChanged: (v) => setState(() => _autoTranslateUGC = v),
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
              'Reset to defaults',
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
          onChanged: (v) {
            if (v != null) context.read<LanguageProvider>().setLocale(v);
          },
        ),
      ),
    );
  }

  // Region dropdown (kept local)
  Widget _regionDropdown() {
    return _dropdown<String>(
      label: 'Region',
      value: _selectedRegion,
      items: _regions,
      onChanged: (v) => setState(() => _selectedRegion = v ?? _selectedRegion),
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

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (e) => DropdownMenuItem<T>(
                      value: e,
                      child: Text('$e', style: GoogleFonts.inter()),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

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

  void _resetDefaults() {
    // Reset provider language to English, keep other toggles to sensible defaults
    context.read<LanguageProvider>().setLocale('en');
    setState(() {
      _selectedRegion = 'Canada';
      _autoTranslateUI = true;
      _autoTranslateUGC = true;
      _use24hTime = true;
    });
  }
}