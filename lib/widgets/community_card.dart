import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../conversations_page.dart';

class CommunityCard extends StatelessWidget {
  final CommunityItem community;
  final VoidCallback onTap;

  const CommunityCard({
    super.key,
    required this.community,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Community Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CachedNetworkImage(
                imageUrl: community.avatarUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666).withValues(alpha: 51),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.group,
                    color: Color(0xFF666666),
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666).withValues(alpha: 51),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.group,
                    color: Color(0xFF666666),
                    size: 24,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Community name
                  Text(
                    community.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Bio/Description
                  Text(
                    community.bio,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF666666),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Member avatars and badges
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Member avatars stack
                SizedBox(
                  width: 80,
                  height: 24,
                  child: Stack(
                    children: [
                      // Generate 3 overlapping member avatars
                      for (int i = 0; i < 3; i++)
                        Positioned(
                          right: i * 16.0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _getMemberAvatarColor(i),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.black : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      // Friends count
                      Positioned(
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF666666,
                            ).withValues(alpha: 26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            community.friendsInCommon,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF666666),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Unread posts badge
                if (community.unreadPosts > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      community.unreadPosts.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMemberAvatarColor(int index) {
    const colors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFFF44336),
    ];
    return colors[index % colors.length];
  }
}
