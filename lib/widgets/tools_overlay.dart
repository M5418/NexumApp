import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Navigation is delegated via callbacks. No direct imports here to keep this reusable.

class ToolsOverlay {
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onCommunities,
    VoidCallback? onPodcasts,
    VoidCallback? onBooks,
    VoidCallback? onMentorship,
    VoidCallback? onVideos,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tools',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, a1, a2) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Blurred background + dismiss on tap
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      // Semi-transparent overlay to help blur work better with videos
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),

              // Tools circle
              Center(
                child: _ToolsCircle(
                  onItemTap: (label) {
                    final nav = Navigator.of(context, rootNavigator: true);
                    nav.pop(); // close overlay first
                    if (label == 'Communities') {
                      // Delegate to caller to switch bottom nav and set tab
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onCommunities?.call();
                      });
                    } else if (label == 'Podcasts') {
                      // Schedule navigation after overlay pop animation
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onPodcasts?.call();
                      });
                    } else if (label == 'Books') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onBooks?.call();
                      });
                    } else if (label == 'Mentorship') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onMentorship?.call();
                      });
                    } else if (label == 'Videos') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onVideos?.call();
                      });
                    } else {
                      // Placeholder action for other tools
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$label (UI only)',
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: const Color(0xFFBFAE01),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

typedef _OnItemTap = void Function(String label);

class _ToolsCircle extends StatelessWidget {
  final _OnItemTap onItemTap;
  const _ToolsCircle({required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    // Ordered top-center then clockwise to match the mock:
    // Books (top), Videos (top-right), Podcasts (bottom-right),
    // Live (bottom), Communities (bottom-left), Mentorship (top-left)
    const items = [
      _Tool(label: 'Books', icon: Icons.menu_book_outlined),
      _Tool(label: 'Videos', icon: Icons.ondemand_video_outlined),
      _Tool(label: 'Podcasts', icon: Icons.mic_none_outlined),
      _Tool(label: 'Live', icon: Icons.live_tv_outlined),
      _Tool(label: 'Communities', icon: Icons.hub_outlined),
      _Tool(label: 'Mentorship', icon: Icons.groups_outlined),
    ];

    return Container(
      width: 290,
      height: 290,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 51), // ~20%
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          // Radius where icons/titles will sit
          final r = (size / 2) - 60; // keeps items inside the circle nicely
          final angleStep = 2 * math.pi / items.length; // 6 items

          return Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < items.length; i++)
                Transform.translate(
                  offset: Offset(
                    r * math.cos(-math.pi / 2 + i * angleStep),
                    r * math.sin(-math.pi / 2 + i * angleStep),
                  ),
                  transformHitTests: true,
                  child: SizedBox(
                    width: 92,
                    height: 84,
                    child: _ToolTile(
                      tool: items[i],
                      onTap: () => onItemTap(items[i].label),
                    ),
                  ),
                ),
              // Center dot for visual balance
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFBFAE01),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tool {
  final String label;
  final IconData icon;
  const _Tool({required this.label, required this.icon});
}

class _ToolTile extends StatelessWidget {
  final _Tool tool;
  final VoidCallback onTap;
  const _ToolTile({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tool.icon, color: Colors.black, size: 24),
          const SizedBox(height: 6),
          Text(
            tool.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
