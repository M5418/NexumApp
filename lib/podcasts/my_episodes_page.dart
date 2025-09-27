import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_api.dart';
import 'favorite_playlist_page.dart';

class MyLibraryPage extends StatefulWidget {
  const MyLibraryPage({super.key});

  @override
  State<MyLibraryPage> createState() => _MyLibraryPageState();
}

class _MyLibraryPageState extends State<MyLibraryPage> {
  bool _loading = true;
  String? _error;
  List<_PlaylistRow> _playlists = [];

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
      final res = await api.listMyPlaylists();
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['playlists'] ?? const []);
      _playlists = list
          .map((m) => _PlaylistRow(
                id: (m['id'] ?? '').toString(),
                name: (m['name'] ?? '').toString(),
                isPrivate: (m['isPrivate'] ?? false) == true,
                itemsCount: int.tryParse((m['itemsCount'] ?? 0).toString()) ?? 0,
              ))
          .toList();
    } catch (e) {
      _error = 'Failed to load playlists: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPlaylist() async {
    final nameCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          title: Text('New Playlist', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(hintText: 'Playlist name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01), foregroundColor: Colors.black),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    try {
      final api = PodcastsApi.create();
      await api.createPlaylist(name: name, isPrivate: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
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
        title: Text('My Library',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            tooltip: 'New Playlist',
            onPressed: _createPlaylist,
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : CustomScrollView(
                  slivers: [
                    // Playlists header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text('My Playlists',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            )),
                      ),
                    ),
                    // Playlists grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 160,
                        ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final pl = _playlists[i];
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FavoritePlaylistPage(playlistId: pl.id)),
                            ).then((_) => _load()),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.13),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.queue_music, color: Color(0xFFBFAE01)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          pl.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text('${pl.itemsCount} items',
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666))),
                                ],
                              ),
                            ),
                          );
                        }, childCount: _playlists.length),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _PlaylistRow {
  final String id;
  final String name;
  final bool isPrivate;
  final int itemsCount;

  _PlaylistRow({
    required this.id,
    required this.name,
    required this.isPrivate,
    required this.itemsCount,
  });
}