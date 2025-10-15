import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_home_page.dart' show Podcast;
import 'podcasts_api.dart';
import 'player_page.dart';
import 'add_to_playlist_sheet.dart';

class PodcastDetailsPage extends StatefulWidget {
  final Podcast podcast;
  const PodcastDetailsPage({super.key, required this.podcast});

  @override
  State<PodcastDetailsPage> createState() => _PodcastDetailsPageState();
}

class _PodcastDetailsPageState extends State<PodcastDetailsPage> {
  late Podcast podcast;
  bool _togglingLike = false;
  bool _togglingFav = false;

  @override
  void initState() {
    super.initState();
    podcast = widget.podcast;
  }

  Future<void> _toggleLike() async {
    if (_togglingLike) return;
    setState(() => _togglingLike = true);
    try {
      final api = PodcastsApi.create();
      if (podcast.meLiked) {
        await api.unlike(podcast.id);
        if (!mounted) return;
        setState(() {
          podcast.meLiked = false;
          podcast.likes = (podcast.likes - 1).clamp(0, 1 << 30);
        });
      } else {
        await api.like(podcast.id);
        if (!mounted) return;
        setState(() {
          podcast.meLiked = true;
          podcast.likes = podcast.likes + 1;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e', style: GoogleFonts.inter())),
      );
    } finally {
      if (mounted) setState(() => _togglingLike = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_togglingFav) return;
    setState(() => _togglingFav = true);
    try {
      final api = PodcastsApi.create();
      if (podcast.meFavorite) {
        await api.unfavorite(podcast.id);
        if (!mounted) return;
        setState(() {
          podcast.meFavorite = false;
          podcast.favorites = (podcast.favorites - 1).clamp(0, 1 << 30);
        });
      } else {
        await api.favorite(podcast.id);
        if (!mounted) return;
        setState(() {
          podcast.meFavorite = true;
          podcast.favorites = podcast.favorites + 1;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorite: $e', style: GoogleFonts.inter())),
      );
    } finally {
      if (mounted) setState(() => _togglingFav = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    // Desktop: limit cover width to 250px
    final coverMaxWidth = isWide ? 250.0 : double.infinity;

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                ),
                Expanded(
                  child: Text(
                    podcast.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: podcast.meLiked ? 'Unlike' : 'Like',
                  onPressed: _togglingLike ? null : _toggleLike,
                  icon: Icon(
                    podcast.meLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.pink.shade300,
                  ),
                ),
                IconButton(
                  tooltip: podcast.meFavorite ? 'Unfavorite' : 'Favorite',
                  onPressed: _togglingFav ? null : _toggleFavorite,
                  icon: const Icon(Icons.star, color: Color(0xFFBFAE01)),
                ),
                IconButton(
                  tooltip: 'Add to playlist',
                  onPressed: () => showAddToPlaylistSheet(context, podcast),
                  icon: const Icon(Icons.playlist_add, color: Color(0xFFBFAE01)),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: coverMaxWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: (podcast.coverUrl ?? '').isNotEmpty
                      ? Image.network(
                          podcast.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                            child: const Center(
                              child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 48),
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                          child: const Center(
                            child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 48),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            podcast.author ?? 'Unknown',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF666666)),
          ),
          const SizedBox(height: 6),
          Text(
            podcast.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            [
              podcast.category ?? '',
              podcast.language ?? '',
              if (podcast.durationSec != null && podcast.durationSec! > 0) '${(podcast.durationSec! ~/ 60)} min',
            ].where((s) => s.isNotEmpty).join(' • '),
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF999999)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: Colors.pink.shade300),
              const SizedBox(width: 4),
              Text('${podcast.likes}', style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(width: 12),
              const Icon(Icons.star, size: 16, color: Color(0xFFBFAE01)),
              const SizedBox(width: 4),
              Text('${podcast.favorites}', style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(width: 12),
              Icon(Icons.play_arrow, size: 16, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 4),
              Text('${podcast.plays}', style: GoogleFonts.inter(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (podcast.description ?? '').isNotEmpty ? podcast.description! : 'No description provided.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: (podcast.audioUrl ?? '').isNotEmpty
                    ? () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(podcast: podcast)));
                      }
                    : null,
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text('Play', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => showAddToPlaylistSheet(context, podcast),
                icon: const Icon(Icons.playlist_add, color: Colors.black),
                label: Text('Add to playlist', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}