import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../repositories/interfaces/playlist_repository.dart';
import 'podcasts_home_page.dart' show Podcast;

Future<void> showAddToPlaylistSheet(BuildContext context, Podcast podcast) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddToPlaylistSheet(podcast: podcast),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  final Podcast podcast;
  const _AddToPlaylistSheet({required this.podcast});

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  bool _loading = true;
  String? _error;
  List<_PlaylistRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final playlistRepo = context.read<PlaylistRepository>();
      final playlists = await playlistRepo.getUserPlaylists();
      
      final rows = <_PlaylistRow>[];
      for (final playlist in playlists) {
        final contains = playlist.podcastIds.contains(widget.podcast.id);
        rows.add(_PlaylistRow(
          id: playlist.id,
          name: playlist.name,
          isPrivate: playlist.isPrivate,
          contains: contains,
          itemsCount: playlist.podcastIds.length,
        ));
      }
      
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load playlists: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String playlistId, bool nextVal) async {
    try {
      final playlistRepo = context.read<PlaylistRepository>();
      
      if (nextVal) {
        await playlistRepo.addPodcastToPlaylist(playlistId, widget.podcast.id);
      } else {
        await playlistRepo.removePodcastFromPlaylist(playlistId, widget.podcast.id);
      }
      
      setState(() {
        _rows = _rows.map((r) => r.id == playlistId ? r.copyWith(contains: nextVal) : r).toList();
      });
      
      final msg = nextVal ? 'Added to playlist' : 'Removed from playlist';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.inter())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    
    final name = await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: Text(
            'New Playlist',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CupertinoTextField(
              controller: nameCtrl,
              placeholder: 'Playlist name',
              autofocus: true,
              style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    
    if (name == null || name.isEmpty) return;
    
    if (!mounted) return;
    
    try {
      final playlistRepo = context.read<PlaylistRepository>();
      final playlistId = await playlistRepo.createPlaylist(name);
      
      // Auto-add current podcast to new playlist
      await playlistRepo.addPodcastToPlaylist(playlistId, widget.podcast.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playlist created', style: GoogleFonts.inter())),
      );
      
      // Reload playlists
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating playlist: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 26),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFBFAE01), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('Add to Playlist', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _rows.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    if (idx == 0) {
                      // Create New Playlist Button
                      return GestureDetector(
                        onTap: _showCreatePlaylistDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFBFAE01).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_circle_outline, color: Color(0xFFBFAE01), size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Create New Playlist',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFBFAE01),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final r = _rows[idx - 1];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${r.itemsCount} items', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF888888))),
                              ],
                            ),
                          ),
                          Switch(
                            value: r.contains,
                            activeThumbColor: const Color(0xFFBFAE01),
                            onChanged: (v) => _toggle(r.id, v),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistRow {
  final String id;
  final String name;
  final bool isPrivate;
  final bool contains;
  final int itemsCount;

  _PlaylistRow({
    required this.id,
    required this.name,
    required this.isPrivate,
    required this.contains,
    required this.itemsCount,
  });

  _PlaylistRow copyWith({bool? contains}) {
    return _PlaylistRow(
      id: id,
      name: name,
      isPrivate: isPrivate,
      contains: contains ?? this.contains,
      itemsCount: itemsCount,
    );
  }
}