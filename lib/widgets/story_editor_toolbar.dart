import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/i18n/language_provider.dart';

class StoryEditorToolbar extends StatelessWidget {
  final bool isImage;
  final bool canRemove;
  final VoidCallback? onEdit;
  final VoidCallback onPickMusic;
  final VoidCallback onPickMedia;
  final VoidCallback? onRemove;
  final VoidCallback onReset;

  const StoryEditorToolbar({
    super.key,
    required this.isImage,
    required this.canRemove,
    this.onEdit,
    required this.onPickMusic,
    required this.onPickMedia,
    this.onRemove,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 77),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isImage)
            Builder(builder: (ctx) => _toolIcon(icon: Icons.edit, label: Provider.of<LanguageProvider>(ctx, listen: false).t('story.edit'), onTap: onEdit))
          else
            const SizedBox(width: 56),
          Builder(builder: (ctx) => _toolIcon(icon: Icons.music_note, label: Provider.of<LanguageProvider>(ctx, listen: false).t('story.music'), onTap: onPickMusic)),
          Builder(builder: (ctx) => _toolIcon(
              icon: Icons.perm_media, label: Provider.of<LanguageProvider>(ctx, listen: false).t('story.choose'), onTap: onPickMedia)),
          if (canRemove)
            Builder(builder: (ctx) => _toolIcon(
                icon: Icons.delete_outline, label: Provider.of<LanguageProvider>(ctx, listen: false).t('story.delete'), onTap: onRemove)),
          Builder(builder: (ctx) => _toolIcon(icon: Icons.refresh, label: Provider.of<LanguageProvider>(ctx, listen: false).t('story.reset'), onTap: onReset)),
        ],
      ),
    );
  }

  Widget _toolIcon({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    const double kSize = 56;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: kSize,
            height: kSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFBFAE01), size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
