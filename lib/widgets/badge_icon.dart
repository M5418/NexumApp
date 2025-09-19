import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final double iconSize;
  final Color iconColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final VoidCallback? onTap;

  const BadgeIcon({
    super.key,
    required this.icon,
    this.badgeCount = 0,
    this.iconSize = 18,
    this.iconColor = const Color(0xFF666666),
    this.badgeColor = const Color(0xFFBFAE01),
    this.badgeTextColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          if (badgeCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
