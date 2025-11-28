import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class StoryRing extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final bool isMine;
  final bool isSeen;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const StoryRing({
    super.key,
    this.imageUrl,
    required this.label,
    this.isMine = false,
    this.isSeen = false,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isMine
                    ? null
                    : LinearGradient(
                        colors: !isSeen  // if has unseen stories
                            ? [
                                const Color(0xFFBFAE01),
                                const Color(0xFFBFAE01),
                              ]
                            : [
                                const Color(0xFF666666).withValues(alpha: 0.5),
                                const Color(0xFF666666).withValues(alpha: 0.5),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: isMine
                    ? Border.all(
                        color: const Color(0xFF666666),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside,
                      )
                    : null,
              ),
              child: isMine
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF666666),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: onAddTap ?? onTap,
                          behavior: HitTestBehavior.opaque,
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFF666666),
                            size: 24,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(
                                    0xFF666666,
                                  ).withValues(alpha: 0.2),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFBFAE01),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(
                                    0xFF666666,
                                  ).withValues(alpha: 0.2),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF666666),
                                    size: 30,
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(
                                  0xFF666666,
                                ).withValues(alpha: 0.2),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF666666),
                                  size: 30,
                                ),
                              ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label.length > 8 ? '${label.substring(0, 8)}...' : label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
