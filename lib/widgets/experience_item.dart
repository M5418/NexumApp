import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExperienceItem extends StatelessWidget {
  final String role;
  final String organization;
  final String period;

  const ExperienceItem({
    super.key,
    required this.role,
    required this.organization,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$organization • $period',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}
