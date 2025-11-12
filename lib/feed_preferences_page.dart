import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/profile_api.dart';
import 'core/i18n/language_provider.dart';

class FeedPreferencesPage extends StatefulWidget {
  const FeedPreferencesPage({super.key});

  @override
  State<FeedPreferencesPage> createState() => _FeedPreferencesPageState();
}

class _FeedPreferencesPageState extends State<FeedPreferencesPage> {
  bool _showReposts = true;
  bool _showSuggested = true;
  bool _prioritizeInterests = true;

  // Loading/saving state
  bool _loading = true;
  bool _saving = false;

  // Robust bool parser for MySQL 0/1, strings, or booleans
  bool _toBool(dynamic v, [bool defaultValue = true]) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      final n = num.tryParse(s);
      if (n != null) return n != 0;
    }
    return defaultValue;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ProfileApi().me();
      final data = (res['ok'] == true && res['data'] != null)
          ? Map<String, dynamic>.from(res['data'])
          : Map<String, dynamic>.from(res);

      setState(() {
        _showReposts = _toBool(data['show_reposts'], true);
        _showSuggested = _toBool(data['show_suggested_posts'], true);
        _prioritizeInterests = _toBool(data['prioritize_interests'], true);
      });
    } catch (_) {
      // Defaults already set
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      await ProfileApi().update({
        'show_reposts': _showReposts,
        'show_suggested_posts': _showSuggested,
        'prioritize_interests': _prioritizeInterests,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('feed_prefs.preferences_saved'), style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('feed_prefs.save_failed'), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePartial(String key, bool value) async {
    // Persist each toggle change immediately to keep table updated.
    try {
      await ProfileApi().update({key: value});
    } catch (_) {
      // Ignore errors silently; user can retry with Save.
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
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
          lang.t('feed_prefs.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: _saving || _loading ? null : _saveAll,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(lang.t('common.save'), style: GoogleFonts.inter(color: const Color(0xFFBFAE01), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildCard(
                  color: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(lang.t('feed_prefs.title')),
                      const SizedBox(height: 8),
                      _switchTile(
                        title: lang.t('feed_prefs.show_reposts'),
                        subtitle: lang.t('feed_prefs.show_reposts_subtitle'),
                        value: _showReposts,
                        onChanged: (v) => setState(() {
                          _showReposts = v;
                          _savePartial('show_reposts', v);
                        }),
                      ),
                      _switchTile(
                        title: lang.t('feed_prefs.show_suggested'),
                        subtitle: lang.t('feed_prefs.show_suggested_subtitle'),
                        value: _showSuggested,
                        onChanged: (v) => setState(() {
                          _showSuggested = v;
                          _savePartial('show_suggested_posts', v);
                        }),
                      ),
                      _switchTile(
                        title: lang.t('feed_prefs.prioritize_interests'),
                        subtitle: lang.t('feed_prefs.prioritize_interests_subtitle'),
                        value: _prioritizeInterests,
                        onChanged: (v) => setState(() {
                          _prioritizeInterests = v;
                          _savePartial('prioritize_interests', v);
                        }),
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
                      _sectionTitle(Provider.of<LanguageProvider>(context, listen: false).t('feed.media_section')),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark)
                              ? const Color(0xFF0E0E0E)
                              : const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          lang.t('feed_prefs.coming_soon'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _saving ? null : _resetDefaults,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBFAE01),
                    side: const BorderSide(color: Color(0xFFBFAE01), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(lang.t('feed_prefs.reset'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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

  Future<void> _resetDefaults() async {
    setState(() {
      _showReposts = true;
      _showSuggested = true;
      _prioritizeInterests = true;
    });
    await _saveAll();
  }
}