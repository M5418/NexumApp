import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreatePodcastPage extends StatefulWidget {
  const CreatePodcastPage({super.key});

  @override
  State<CreatePodcastPage> createState() => _CreatePodcastPageState();
}

class _CreatePodcastPageState extends State<CreatePodcastPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 26),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    'Add Podcast',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Saved as Draft',
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: const Color(0xFF9E9E9E),
                        ),
                      );
                    },
                    child: Text(
                      'Save as Draft',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Podcast Submitted (UI only)',
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: const Color(0xFFBFAE01),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFAE01),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      'Add',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InputCard(
            child: TextField(
              controller: _titleCtrl,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF999999)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InputCard(
            height: 160,
            child: TextField(
              controller: _descCtrl,
              style: GoogleFonts.inter(),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Describe your show…',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF999999)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InputCard(
            child: Row(
              children: [
                _SquareButton(
                  icon: Icons.image_outlined,
                  label: 'Cover',
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _SquareButton(
                  icon: Icons.audiotrack_outlined,
                  label: 'Audio',
                  onTap: () {},
                ),
                const Spacer(),
                Text(
                  '00:00',
                  style: GoogleFonts.inter(color: const Color(0xFF666666)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final Widget child;
  final double? height;
  const _InputCard({required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 13),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
