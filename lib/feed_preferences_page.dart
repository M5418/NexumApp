import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedPreferencesPage extends StatefulWidget {
  const FeedPreferencesPage({super.key});

  @override
  State<FeedPreferencesPage> createState() => _FeedPreferencesPageState();
}

class _FeedPreferencesPageState extends State<FeedPreferencesPage> {
  bool _showReposts = true;
  bool _showSuggested = true;
  bool _autoplayVideos = true;
  bool _muteAutoplaySound = true;
  bool _prioritizeInterests = true;
  bool _highQualityOnMobile = false;
  bool _reduceMotion = false;

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
          'Feed Preferences',
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
                _sectionTitle('Timeline Content'),
                const SizedBox(height: 8),
                _switchTile(
                  title: 'Show Reposts',
                  subtitle: 'Include posts that others have reposted',
                  value: _showReposts,
                  onChanged: (v) => setState(() => _showReposts = v),
                ),
                _switchTile(
                  title: 'Show Suggested Posts',
                  subtitle:
                      'Recommendations based on your activity and interests',
                  value: _showSuggested,
                  onChanged: (v) => setState(() => _showSuggested = v),
                ),
                _switchTile(
                  title: 'Prioritize Your Interests',
                  subtitle: 'See more posts matching your selected interests',
                  value: _prioritizeInterests,
                  onChanged: (v) => setState(() => _prioritizeInterests = v),
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
                _sectionTitle('Media'),
                const SizedBox(height: 8),
                _switchTile(
                  title: 'Autoplay Videos',
                  subtitle: 'Videos will play automatically as you scroll',
                  value: _autoplayVideos,
                  onChanged: (v) => setState(() => _autoplayVideos = v),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _autoplayVideos
                      ? Padding(
                          key: const ValueKey('muteAuto'),
                          padding: const EdgeInsets.only(left: 16),
                          child: _switchTile(
                            title: 'Mute Sound on Autoplay',
                            subtitle: 'Start videos muted; tap to unmute',
                            value: _muteAutoplaySound,
                            onChanged: (v) =>
                                setState(() => _muteAutoplaySound = v),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                _switchTile(
                  title: 'High Quality on Mobile Data',
                  subtitle:
                      'Stream media in higher quality when using mobile data',
                  value: _highQualityOnMobile,
                  onChanged: (v) => setState(() => _highQualityOnMobile = v),
                ),
                _switchTile(
                  title: 'Reduce Motion',
                  subtitle: 'Limit animations and motion effects',
                  value: _reduceMotion,
                  onChanged: (v) => setState(() => _reduceMotion = v),
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
      _showReposts = true;
      _showSuggested = true;
      _autoplayVideos = true;
      _muteAutoplaySound = true;
      _prioritizeInterests = true;
      _highQualityOnMobile = false;
      _reduceMotion = false;
    });
  }
}
