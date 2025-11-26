import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Badge widget for official Nexum Team accounts
/// Displays a yellow badge with checkmark and "NEXUM TEAM" text
class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFBFAE01), // App's yellow color
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'NEXUM TEAM',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
