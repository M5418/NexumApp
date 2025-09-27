import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_api.dart';
import 'podcasts_home_page.dart' show Podcast;
import 'player_page.dart';

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
  bool _isPrivate = false;
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
      final api = PodcastsApi.create();
      final res = await api.getPlaylist(widget.playlistId);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final pl = Map<String, dynamic>.from(d['playlist'] ?? {});
      final items = List<Map<String, dynamic>>.from(d['items'] ?? const []);

      _name = (pl['name'] ?? '').toString();
      _isPrivate = (pl['isPrivate'] ?? false) == true;
      _items = items.map(Podcast.fromApi).toList();
    } catch (e) {
      _error = 'Failed to load playlist: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        title: Text('Rename Playlist', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Playlist name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01), foregroundColor: Colors.black),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      final api = PodcastsApi.create();
      await api.updatePlaylist(widget.playlistId, name: newName);
      setState(() => _name = newName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rename failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _togglePrivacy() async {
    try {
      final api = PodcastsApi.create();
      await api.updatePlaylist(widget.playlistId, isPrivate: !_isPrivate);
      setState(() => _isPrivate = !_isPrivate);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete playlist?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('This cannot be undone.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final api = PodcastsApi.create();
      await api.deletePlaylist(widget.playlistId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeItem(Podcast p) async {
    try {
      final api = PodcastsApi.create();
      await api.removeFromPlaylist(playlistId: widget.playlistId, podcastId: p.id);
      setState(() => _items.removeWhere((x) => x.id == p.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    }
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
        actions: [
          IconButton(
            tooltip: 'Rename',
            onPressed: _loading ? null : _rename,
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: _isPrivate ? 'Make Public' : 'Make Private',
            onPressed: _loading ? null : _togglePrivacy,
            icon: Icon(_isPrivate ? Icons.lock : Icons.lock_open),
          ),
          IconButton(
            tooltip: 'Delete Playlist',
            onPressed: _loading ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : CustomScrollView(
                  slivers: [
                    // Playlist header
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(Icons.queue_music, color: Color(0xFFBFAE01)),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              child: Text(_isPrivate ? 'Private' : 'Public', style: GoogleFonts.inter(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Items
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverList.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final p = _items[i];
                          return Container(
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: (p.coverUrl ?? '').isNotEmpty
                                        ? Image.network(p.coverUrl!, fit: BoxFit.cover)
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
                                        p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        p.author ?? 'Unknown',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Play',
                                  onPressed: (p.audioUrl ?? '').isNotEmpty
                                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(podcast: p)))
                                      : null,
                                  icon: const Icon(Icons.play_circle_fill, color: Color(0xFFBFAE01)),
                                ),
                                PopupMenuButton<String>(
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'remove', child: Text('Remove from playlist')),
                                  ],
                                  onSelected: (v) {
                                    if (v == 'remove') _removeItem(p);
                                  },
                                ),
                              ],
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