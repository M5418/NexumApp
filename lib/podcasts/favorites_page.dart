import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'podcast_details_page.dart';
import 'podcasts_home_page.dart' show Podcast;
import '../repositories/interfaces/podcast_repository.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
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
      final repo = context.read<PodcastRepository>();
      final models = await repo.getBookmarkedPodcasts();
      
      if (!mounted) return;
      setState(() {
        _items = models.map(Podcast.fromModel).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load favorites: $e';
        _loading = false;
      });
    }
  }

  String _mmss(int? sec) {
    if (sec == null || sec <= 0) return '00:00';
    final d = Duration(seconds: sec);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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
        centerTitle: false,
        title: Text('My Favorites',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_border,
                            size: 64,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No favorites yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : const Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Podcasts you favorite will appear here',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : const Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68, // original taller tile
                  ),
                  itemBuilder: (context, i) {
                    final e = _items[i];
                    return GestureDetector(
                      onTap: () {
                        // Navigate to podcast details page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'podcast_details'),
                            builder: (_) => PodcastDetailsPage(podcast: e),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.13),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // FASTFEED: Use listCoverUrl (thumbnail) for fast loading
                                  (e.listCoverUrl ?? '').isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: e.listCoverUrl!,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 400,
                                          memCacheHeight: 400,
                                          placeholder: (context, url) => Container(
                                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                            child: const Center(
                                              child: Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                          child: const Center(child: Icon(Icons.podcasts, color: Color(0xFFBFAE01))),
                                        ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            _mmss(e.durationSec),
                                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    e.author ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}