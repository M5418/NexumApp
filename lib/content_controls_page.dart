import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';

class ContentControlsPage extends StatefulWidget {
  const ContentControlsPage({super.key});

  @override
  State<ContentControlsPage> createState() => _ContentControlsPageState();
}

class _ContentControlsPageState extends State<ContentControlsPage> {
  bool _hideSensitive = true;
  bool _blurSensitiveMedia = true;
  bool _filterProfanity = true;
  bool _hideSpoilers = true;
  bool _safeMode = true;

  final TextEditingController _keywordCtrl = TextEditingController();
  List<String> _mutedKeywords = [];

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
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
          lang.t('content_controls.title'),
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
                _sectionTitle(lang.t('content_controls.safety')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('content_controls.safe_mode'),
                  subtitle:
                      lang.t('content_controls.safe_mode_subtitle'),
                  value: _safeMode,
                  onChanged: (v) => setState(() => _safeMode = v),
                ),
                _switchTile(
                  title: lang.t('content_controls.hide_sensitive'),
                  subtitle:
                      lang.t('content_controls.hide_sensitive_subtitle'),
                  value: _hideSensitive,
                  onChanged: (v) => setState(() => _hideSensitive = v),
                ),
                _switchTile(
                  title: lang.t('content_controls.blur_media'),
                  subtitle:
                      lang.t('content_controls.blur_media_subtitle'),
                  value: _blurSensitiveMedia,
                  onChanged: (v) => setState(() => _blurSensitiveMedia = v),
                ),
                _switchTile(
                  title: lang.t('content_controls.filter_profanity'),
                  subtitle: lang.t('content_controls.filter_profanity_subtitle'),
                  value: _filterProfanity,
                  onChanged: (v) => setState(() => _filterProfanity = v),
                ),
                _switchTile(
                  title: lang.t('content_controls.hide_spoilers'),
                  subtitle: lang.t('content_controls.hide_spoilers_subtitle'),
                  value: _hideSpoilers,
                  onChanged: (v) => setState(() => _hideSpoilers = v),
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
                _sectionTitle(lang.t('content_controls.muted_keywords')),
                const SizedBox(height: 6),
                Text(
                  lang.t('content_controls.muted_keywords_subtitle'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mutedKeywords
                      .map(
                        (k) => InputChip(
                          label: Text(k, style: GoogleFonts.inter()),
                          onDeleted: () =>
                              setState(() => _mutedKeywords.remove(k)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _keywordCtrl,
                        decoration: InputDecoration(
                          hintText: Provider.of<LanguageProvider>(context, listen: false).t('content.add_keyword'),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                        ),
                        onSubmitted: (_) => _addKeyword(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addKeyword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFAE01),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('content.add'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
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
              Provider.of<LanguageProvider>(context, listen: false).t('content.clear_reset'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _addKeyword() {
    final value = _keywordCtrl.text.trim();
    if (value.isEmpty) return;
    if (_mutedKeywords.contains(value)) return;
    setState(() {
      _mutedKeywords = [..._mutedKeywords, value];
      _keywordCtrl.clear();
    });
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
      _hideSensitive = true;
      _blurSensitiveMedia = true;
      _filterProfanity = true;
      _hideSpoilers = true;
      _safeMode = true;
      _mutedKeywords = [];
      _keywordCtrl.clear();
    });
  }
}
