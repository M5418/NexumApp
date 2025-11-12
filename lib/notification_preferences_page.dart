import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _inAppEnabled = true;

  bool _likesPush = true;
  bool _commentsPush = true;
  bool _mentionsPush = true;
  bool _followsPush = true;

  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;

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
          lang.t('notif_prefs.title'),
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
                _sectionTitle(lang.t('notif_prefs.channels')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('notif_prefs.push'),
                  subtitle: lang.t('notif_prefs.push_subtitle'),
                  value: _pushEnabled,
                  onChanged: (v) => setState(() => _pushEnabled = v),
                ),
                _switchTile(
                  title: lang.t('notif_prefs.email'),
                  subtitle: lang.t('notif_prefs.email_subtitle'),
                  value: _emailEnabled,
                  onChanged: (v) => setState(() => _emailEnabled = v),
                ),
                _switchTile(
                  title: lang.t('notif_prefs.in_app'),
                  subtitle: lang.t('notif_prefs.in_app_subtitle'),
                  value: _inAppEnabled,
                  onChanged: (v) => setState(() => _inAppEnabled = v),
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
                _sectionTitle(lang.t('notif_prefs.categories')),
                const SizedBox(height: 8),
                _switchTile(
                  title: lang.t('notif_prefs.likes'),
                  subtitle: lang.t('notif_prefs.likes_subtitle'),
                  value: _likesPush,
                  onChanged: (v) => setState(() => _likesPush = v),
                ),
                _switchTile(
                  title: lang.t('notif_prefs.comments'),
                  subtitle: lang.t('notif_prefs.comments_subtitle'),
                  value: _commentsPush,
                  onChanged: (v) => setState(() => _commentsPush = v),
                ),
                _switchTile(
                  title: lang.t('notif_prefs.mentions'),
                  subtitle: lang.t('notif_prefs.mentions_subtitle'),
                  value: _mentionsPush,
                  onChanged: (v) => setState(() => _mentionsPush = v),
                ),
                _switchTile(
                  title: lang.t('notif_prefs.new_connections'),
                  subtitle: lang.t('notif_prefs.new_connections_subtitle'),
                  value: _followsPush,
                  onChanged: (v) => setState(() => _followsPush = v),
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
                _sectionTitle(Provider.of<LanguageProvider>(context, listen: false).t('notif_prefs.quiet_hours')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _timePickerTile(
                        Provider.of<LanguageProvider>(context, listen: false).t('notif_prefs.start'),
                        _quietStart,
                        (t) => setState(() => _quietStart = t),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePickerTile(
                        Provider.of<LanguageProvider>(context, listen: false).t('notif_prefs.end'),
                        _quietEnd,
                        (t) => setState(() => _quietEnd = t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('notif_prefs.quiet_description'),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('notif_prefs.test_sent'),
                  style: GoogleFonts.inter(),
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBFAE01),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Send Test Notification',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Color color, required Widget child}) => Container(
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

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
  );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
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

  Widget _timePickerTile(
    String label,
    TimeOfDay? current,
    ValueChanged<TimeOfDay?> onPicked,
  ) {
    final text = current == null ? 'Off' : current.format(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      subtitle: Text(
        text,
        style: GoogleFonts.inter(color: const Color(0xFF666666), fontSize: 12),
      ),
      trailing: const Icon(Icons.schedule),
      onTap: () async {
        final now = TimeOfDay.now();
        final picked = await showTimePicker(
          context: context,
          initialTime: current ?? now,
        );
        onPicked(picked);
      },
    );
  }
}
