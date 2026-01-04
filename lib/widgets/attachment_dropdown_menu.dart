import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_image_editor_page.dart';

class AttachmentDropdownMenu extends StatelessWidget {
  final VoidCallback onSendVideos;
  final VoidCallback onSendFiles;
  final bool isDark;

  const AttachmentDropdownMenu({
    super.key,
    required this.onSendVideos,
    required this.onSendFiles,
    required this.isDark,
  });

  Future<void> _openImageEditor(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'image_editor'),
        builder: (context) => ChatImageEditorPage(
          onSendImages: (imageBytesList) {
            // Handle sending the edited images
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${imageBytesList.length} image(s) sent!'),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.white; // screenshot shows white card
    final textColor = Colors.black;
    final divider = const Color(0xFFE5E7EB);

    // Full-screen tap area to dismiss on background tap
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 12,
              bottom: 86,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {}, // absorb taps on the card
                  child: Container(
                    width: 250,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _menuItem(
                          context,
                          icon: Icons.edit,
                          label: 'Send Image',
                          onTap: () => _openImageEditor(context),
                          textColor: textColor,
                        ),
                        _divider(divider),
                        _menuItem(
                          context,
                          icon: Icons.videocam_outlined,
                          label: 'Send Videos',
                          onTap: onSendVideos,
                          textColor: textColor,
                        ),
                        _divider(divider),
                        _menuItem(
                          context,
                          icon: Icons.insert_drive_file_outlined,
                          label: 'Send Files',
                          onTap: onSendFiles,
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color color) => Container(height: 1, color: color);

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
