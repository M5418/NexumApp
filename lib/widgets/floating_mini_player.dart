import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../providers/podcast_player_provider.dart';
import '../podcasts/player_page.dart';

/// Floating mini-player bar that shows the currently playing podcast
/// Displays at the bottom of podcast pages when audio is playing
class FloatingMiniPlayer extends StatelessWidget {
  const FloatingMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PodcastPlayerProvider>(
      builder: (context, player, child) {
        // Don't show if no podcast is playing
        if (!player.hasActivePodcast) {
          return const SizedBox.shrink();
        }

        final podcast = player.currentPodcast!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () {
            // Navigate to full player page
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'podcast_player'),
                builder: (_) => PlayerPage(podcast: podcast),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cover image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: (podcast.coverUrl ?? '').isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: podcast.coverUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 96,
                            memCacheHeight: 96,
                            placeholder: (context, url) => Container(
                              color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                              child: const Center(
                                child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 20),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                              child: const Center(
                                child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 20),
                              ),
                            ),
                          )
                        : Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                            child: const Center(
                              child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 20),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title and author
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        podcast.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        podcast.author ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress indicator (circular)
                if (player.isLoading)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFBFAE01),
                      ),
                    ),
                  )
                else
                  // Play/Pause button
                  IconButton(
                    onPressed: () => player.togglePlayPause(),
                    icon: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: const Color(0xFFBFAE01),
                      size: 32,
                    ),
                  ),

                // Close button
                IconButton(
                  onPressed: () => player.stop(),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white54 : const Color(0xFF999999),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper widget that adds the floating mini-player to any page
/// Use this to wrap the body of podcast-related pages
class WithFloatingMiniPlayer extends StatelessWidget {
  final Widget child;
  final bool showMiniPlayer;

  const WithFloatingMiniPlayer({
    super.key,
    required this.child,
    this.showMiniPlayer = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showMiniPlayer) {
      return child;
    }

    return Stack(
      children: [
        child,
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FloatingMiniPlayer(),
        ),
      ],
    );
  }
}
