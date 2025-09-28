import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'podcasts_api.dart';
import 'podcasts_home_page.dart' show Podcast;
import 'player_page.dart';

class MyEpisodesPage extends StatefulWidget {
  const MyEpisodesPage({super.key});

  @override
  State<MyEpisodesPage> createState() => _MyEpisodesPageState();
}

class _MyEpisodesPageState extends State<MyEpisodesPage> {
  bool _loading = true;
  String? _error;
  List<Podcast> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Use published list as "episodes" source; backend stays unchanged.
      final api = PodcastsApi.create();
      final res = await api.list(page: 1, limit: 100, isPublished: true);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['podcasts'] ?? const []);
      _items = list.map(Podcast.fromApi).toList();
    } catch (e) {
      _error = 'Failed to load episodes: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _shortDate(DateTime? d) {
    if (d == null) return '';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

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
          'My Episodes',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final e = _items[i];
                          return _EpisodeRow(
                            title: e.title,
                            author: e.author ?? 'Unknown',
                            coverUrl: e.coverUrl ?? '',
                            date: _shortDate(e.createdAt),
                            onPlay: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlayerPage(podcast: e),
                              ),
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
                color: Colors.black.withOpacity(0.13),
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
                child: (coverUrl).isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 112,
                        memCacheHeight: 112,
                        placeholder: (context, url) => Container(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                          child: const Center(
                            child: Icon(
                              Icons.podcasts,
                              color: Color(0xFFBFAE01),
                              size: 20,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
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