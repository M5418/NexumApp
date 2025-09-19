import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InterestChip extends StatelessWidget {
  final String text;

  const InterestChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(
            0xFF666666,
          ).withValues(alpha: 51), // 0.2 * 255 = 51
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
