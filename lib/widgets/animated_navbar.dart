import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class AnimatedNavbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;
  final bool? isDarkMode;

  const AnimatedNavbar({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
    this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        isDarkMode ?? Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        boxShadow: [
          BoxShadow(blurRadius: 20, color: Colors.black.withValues(alpha: 0.1)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
          child: GNav(
            rippleColor: const Color(0xFFBFAE01).withValues(alpha: 0.1),
            hoverColor: const Color(0xFFBFAE01).withValues(alpha: 0.1),
            gap: 6,
            activeColor: const Color(0xFFBFAE01),
            iconSize: 22,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: const Color(0xFFBFAE01).withValues(alpha: 0.1),
            color: const Color(0xFF666666),
            tabs: const [
              GButton(icon: Icons.home_outlined, text: 'Home'),
              GButton(icon: Icons.people_outline, text: 'Connections'),
              GButton(icon: Icons.add_circle_outline, text: '', iconSize: 28),
              GButton(icon: Icons.chat_bubble_outline, text: 'Conversations'),
              GButton(icon: Icons.person_outline, text: 'Profile'),
            ],
            selectedIndex: selectedIndex,
            onTabChange: onTabChange,
          ),
        ),
      ),
    );
  }
}
