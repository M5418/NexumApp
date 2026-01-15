import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'podcasts_home_page.dart' show Podcast;
import 'podcast_details_page.dart';
import '../repositories/interfaces/playlist_repository.dart';
import '../repositories/interfaces/podcast_repository.dart';

class FavoritePlaylistPage extends StatefulWidget {
  final String playlistId;
  const FavoritePlaylistPage({super.key, required this.playlistId});

  @override
  State<FavoritePlaylistPage> createState() => _FavoritePlaylistPageState();
}

class _FavoritePlaylistPageState extends State<FavoritePlaylistPage> {
  bool _loading = true;
  String? _error;

  late String _name;
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
      final playlistRepo = context.read<PlaylistRepository>();
      final podcastRepo = context.read<PodcastRepository>();
      
      // Get the playlist details
      final playlist = await playlistRepo.getPlaylist(widget.playlistId);
      if (playlist == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Playlist not found';
          _loading = false;
        });
        return;
      }
      
      _name = playlist.name;
      
      // Load all podcasts in the playlist
      final podcasts = <Podcast>[];
      for (final podcastId in playlist.podcastIds) {
        final model = await podcastRepo.getPodcast(podcastId);
        if (model != null) {
          podcasts.add(Podcast.fromModel(model));
        }
      }
      
      if (!mounted) return;
      setState(() {
        _items = podcasts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load playlist: $e';
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
        title: Text('My Playlist',
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
              : CustomScrollView(
                  slivers: [
                    // Header (restored original style with cover + title)
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
                                child: Container(
                                  color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                  child: const Center(
                                    child: Icon(Icons.playlist_play, color: Color(0xFFBFAE01)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _name,
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

                    // Empty state or items
                    if (_items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.playlist_add,
                                size: 64,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Playlist is empty',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : const Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add podcasts to this playlist',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: isDark ? Colors.white54 : const Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        sliver: SliverList.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final e = _items[i];
                            return _EpisodeRow(
                              title: e.title,
                              subtitle: e.author ?? 'Unknown',
                              // FASTFEED: Use listCoverUrl (thumbnail) for fast loading
                              coverUrl: e.listCoverUrl ?? '',
                              durationLabel: _mmss(e.durationSec),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(name: 'podcast_details'),
                                  builder: (_) => PodcastDetailsPage(podcast: e),
                                ),
                              ),
                              isDark: isDark,
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
  final String durationLabel;
  final VoidCallback onTap;
  final bool isDark;
  const _EpisodeRow({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.durationLabel,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
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
                            child: Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
                          ),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                        child: const Center(
                          child: Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
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
              durationLabel,
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
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}