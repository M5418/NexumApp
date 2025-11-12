import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';

class PrivacyVisibilityPage extends StatefulWidget {
  const PrivacyVisibilityPage({super.key});

  @override
  State<PrivacyVisibilityPage> createState() => _PrivacyVisibilityPageState();
}

class _PrivacyVisibilityPageState extends State<PrivacyVisibilityPage> {
  bool _privateProfile = false;
  bool _showActivityStatus = true;
  bool _approveConnections = true;
  bool _allowMentions = true;
  bool _allowTags = true;
  bool _showOnline = true;
  bool _showLastSeen = false;

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
          lang.t('privacy.title'),
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
                _sectionTitle(lang.t('privacy.profile_visibility')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('privacy.private_profile'),
                  subtitle: lang.t('privacy.private_profile_subtitle'),
                  value: _privateProfile,
                  onChanged: (v) => setState(() => _privateProfile = v),
                ),
                _switchTile(
                  title: lang.t('privacy.show_activity'),
                  subtitle: lang.t('privacy.show_activity_subtitle'),
                  value: _showActivityStatus,
                  onChanged: (v) => setState(() => _showActivityStatus = v),
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
                _sectionTitle(lang.t('privacy.connections')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('privacy.approve_connections'),
                  subtitle: lang.t('privacy.approve_connections_subtitle'),
                  value: _approveConnections,
                  onChanged: (v) => setState(() => _approveConnections = v),
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
                _sectionTitle(lang.t('privacy.mentions_tags')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('privacy.allow_mentions'),
                  subtitle: lang.t('privacy.allow_mentions_subtitle'),
                  value: _allowMentions,
                  onChanged: (v) => setState(() => _allowMentions = v),
                ),
                _switchTile(
                  title: lang.t('privacy.allow_tags'),
                  subtitle: lang.t('privacy.allow_tags_subtitle'),
                  value: _allowTags,
                  onChanged: (v) => setState(() => _allowTags = v),
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
                _sectionTitle(lang.t('privacy.status_visibility')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('privacy.show_online'),
                  subtitle: lang.t('privacy.show_online_subtitle'),
                  value: _showOnline,
                  onChanged: (v) => setState(() => _showOnline = v),
                ),
                _switchTile(
                  title: lang.t('privacy.show_last_seen'),
                  subtitle: lang.t('privacy.show_last_seen_subtitle'),
                  value: _showLastSeen,
                  onChanged: (v) => setState(() => _showLastSeen = v),
                ),
              ],
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
}
