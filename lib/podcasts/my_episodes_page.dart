import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'podcast_sample_data.dart';
import 'player_page.dart';

class MyEpisodesPage extends StatelessWidget {
  const MyEpisodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final items = PodcastSampleData.topPodcasts
        .expand((p) => p.episodes)
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'My Episodes',
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
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final e = items[i];
                return _EpisodeRow(
                  title: e.title,
                  author: e.author,
                  coverUrl: e.coverUrl,
                  date: PodcastSampleData.shortDate(e.publishedAt),
                  onPlay: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerPage(episode: e),
                    ),
                  ),
                );
              }, childCount: items.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final String title;
  final String author;
  final String coverUrl;
  final String date;
  final VoidCallback onPlay;
  const _EpisodeRow({
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.date,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                      child: Icon(
                        Icons.podcasts,
                        color: Color(0xFFBFAE01),
                        size: 20,
                      ),
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
                    '$author • $date',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.play_circle_fill,
                color: Color(0xFFBFAE01),
              ),
              onPressed: onPlay,
            ),
            const Icon(Icons.more_vert, color: Color(0xFF666666)),
          ],
        ),
      ),
    );
  }
}
