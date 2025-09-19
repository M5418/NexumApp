import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'podcast_models.dart';
import 'player_page.dart';
import 'podcast_sample_data.dart';

class FavoritePlaylistPage extends StatelessWidget {
  final Playlist playlist;
  const FavoritePlaylistPage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'My Playlist',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: CachedNetworkImage(
                        imageUrl: playlist.coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 140,
                        memCacheHeight: 140,
                        placeholder: (context, url) => Container(
                          color: isDark
                              ? const Color(0xFF111111)
                              : const Color(0xFFEAEAEA),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDark
                              ? const Color(0xFF111111)
                              : const Color(0xFFEAEAEA),
                          child: const Center(
                            child: Icon(
                              Icons.playlist_play,
                              color: Color(0xFFBFAE01),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      playlist.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: Color(0xFF666666)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            sliver: SliverList.builder(
              itemCount: playlist.episodes.length,
              itemBuilder: (context, i) {
                final e = playlist.episodes[i];
                return _EpisodeRow(
                  title: e.title,
                  subtitle:
                      '${e.author} • ${PodcastSampleData.shortDate(e.publishedAt)}',
                  coverUrl: e.coverUrl,
                  duration: e.duration,
                  onPlay: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlayerPage(episode: e)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String coverUrl;
  final Duration duration;
  final VoidCallback onPlay;
  const _EpisodeRow({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.duration,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 13),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 112,
                  memCacheHeight: 112,
                  placeholder: (context, url) => Container(
                    color: isDark
                        ? const Color(0xFF111111)
                        : const Color(0xFFEAEAEA),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark
                        ? const Color(0xFF111111)
                        : const Color(0xFFEAEAEA),
                    child: const Center(
                      child: Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$mm:$ss',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.play_circle_fill,
                color: Color(0xFFBFAE01),
              ),
              onPressed: onPlay,
            ),
          ],
        ),
      ),
    );
  }
}
