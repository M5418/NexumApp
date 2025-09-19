import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          'Notification Preferences',
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
                _sectionTitle('Channels'),
                const SizedBox(height: 8),
                _switchTile(
                  title: 'Push Notifications',
                  subtitle: 'Enable notifications on this device',
                  value: _pushEnabled,
                  onChanged: (v) => setState(() => _pushEnabled = v),
                ),
                _switchTile(
                  title: 'Email Notifications',
                  subtitle: 'Receive notifications via email',
                  value: _emailEnabled,
                  onChanged: (v) => setState(() => _emailEnabled = v),
                ),
                _switchTile(
                  title: 'In-App Notifications',
                  subtitle: 'Show notifications when using the app',
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
                _sectionTitle('Categories (Push)'),
                const SizedBox(height: 8),
                _switchTile(
                  title: 'Likes',
                  subtitle: 'When someone likes your post',
                  value: _likesPush,
                  onChanged: (v) => setState(() => _likesPush = v),
                ),
                _switchTile(
                  title: 'Comments',
                  subtitle: 'When someone comments on your post',
                  value: _commentsPush,
                  onChanged: (v) => setState(() => _commentsPush = v),
                ),
                _switchTile(
                  title: 'Mentions',
                  subtitle: 'When someone mentions you',
                  value: _mentionsPush,
                  onChanged: (v) => setState(() => _mentionsPush = v),
                ),
                _switchTile(
                  title: 'New Connections',
                  subtitle: 'When someone is connected to you',
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
                _sectionTitle('Quiet Hours'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _timePickerTile(
                        'Start',
                        _quietStart,
                        (t) => setState(() => _quietStart = t),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePickerTile(
                        'End',
                        _quietEnd,
                        (t) => setState(() => _quietEnd = t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'No push notifications during quiet hours.',
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
                  'Test notification sent',
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
