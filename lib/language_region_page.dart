import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageRegionPage extends StatefulWidget {
  const LanguageRegionPage({super.key});

  @override
  State<LanguageRegionPage> createState() => _LanguageRegionPageState();
}

class _LanguageRegionPageState extends State<LanguageRegionPage> {
  final List<String> _languages = [
    'English',
    'Français',
    'Español',
    'Deutsch',
    'Português',
    'العربية',
  ];
  final List<String> _regions = [
    'United States',
    'Canada',
    'France',
    'Germany',
    'United Kingdom',
    'Côte d’Ivoire',
  ];

  String _selectedLanguage = 'English';
  String _selectedRegion = 'Canada';
  bool _autoTranslateUI = true;
  bool _autoTranslateUGC = true; // user-generated content translation
  bool _use24hTime = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

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
          'Language & Region',
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
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Display Language'),
                const SizedBox(height: 8),
                _dropdown<String>(
                  label: 'Language',
                  value: _selectedLanguage,
                  items: _languages,
                  onChanged: (v) => setState(
                    () => _selectedLanguage = v ?? _selectedLanguage,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Region Settings'),
                const SizedBox(height: 8),
                _dropdown<String>(
                  label: 'Region',
                  value: _selectedRegion,
                  items: _regions,
                  onChanged: (v) =>
                      setState(() => _selectedRegion = v ?? _selectedRegion),
                ),
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

  Widget _buildCard({required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
    setState(() {
      _selectedLanguage = 'English';
      _selectedRegion = 'Canada';
      _autoTranslateUI = true;
      _autoTranslateUGC = true;
      _use24hTime = true;
    });
  }
}
