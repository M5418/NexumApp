import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class StoryRing extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final bool isMine;
  final bool isSeen;
  final bool hasActiveStories; // For "Your Story" - show avatar with highlight if has stories
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const StoryRing({
    super.key,
    this.imageUrl,
    required this.label,
    this.isMine = false,
    this.isSeen = false,
    this.hasActiveStories = false,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isMine
                    ? (hasActiveStories
                        ? const LinearGradient(
                            colors: [Color(0xFFBFAE01), Color(0xFFBFAE01)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null)
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
                border: isMine && !hasActiveStories
                    ? Border.all(
                        color: const Color(0xFF666666),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside,
                      )
                    : null,
              ),
              child: isMine
                  ? (hasActiveStories
                      // Show avatar with yellow ring + small add button when has active stories
                      ? Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl!,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: 72,
                                          height: 72,
                                          color: const Color(0xFF666666).withValues(alpha: 0.2),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: 72,
                                          height: 72,
                                          color: const Color(0xFF666666).withValues(alpha: 0.2),
                                          child: const Icon(Icons.person, color: Color(0xFF666666), size: 36),
                                        ),
                                      )
                                    : Container(
                                        width: 72,
                                        height: 72,
                                        color: const Color(0xFF666666).withValues(alpha: 0.2),
                                        child: const Icon(Icons.person, color: Color(0xFF666666), size: 36),
                                      ),
                              ),
                            ),
                            // Small + button at bottom right
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: onAddTap,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBFAE01),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.add, size: 14, color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        )
                      // Show + icon when no active stories
                      : Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF666666).withValues(alpha: 0.2),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl!,
                                        width: 75,
                                        height: 75,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: 75,
                                          height: 75,
                                          color: const Color(0xFF666666).withValues(alpha: 0.2),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: 75,
                                          height: 75,
                                          color: const Color(0xFF666666).withValues(alpha: 0.2),
                                          child: const Icon(Icons.person, color: Color(0xFF666666), size: 38),
                                        ),
                                      )
                                    : const Center(child: Icon(Icons.person, color: Color(0xFF666666), size: 38)),
                              ),
                            ),
                            // Small + button at bottom right
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: onAddTap ?? onTap,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBFAE01),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.add, size: 14, color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ))
                  : Padding(
                      padding: const EdgeInsets.all(4),
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
