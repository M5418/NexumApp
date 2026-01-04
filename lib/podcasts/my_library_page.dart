import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../repositories/interfaces/playlist_repository.dart';
import '../repositories/firebase/firebase_playlist_repository.dart';
import 'my_episodes_page.dart';
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
  
  // FASTFEED: Direct repository access for cache-first loading
  final FirebasePlaylistRepository _firebasePlaylistRepo = FirebasePlaylistRepository();

  @override
  void initState() {
    super.initState();
    // FASTFEED: Load cached playlists instantly, then refresh
    _loadFromCacheInstantly();
    _load();
  }

  /// INSTANT: Load cached playlists (no network wait)
  Future<void> _loadFromCacheInstantly() async {
    try {
      final playlists = await _firebasePlaylistRepo.getUserPlaylistsFromCache();
      if (playlists.isNotEmpty && mounted) {
        final rows = playlists.map((p) => _PlaylistRow(
          id: p.id,
          name: p.name,
          isPrivate: p.isPrivate,
          itemsCount: p.podcastIds.length,
        )).toList();
        setState(() {
          _playlists = rows;
          _loading = false;
        });
      }
    } catch (_) {
      // Cache miss - will load from server
    }
  }

  Future<void> _load() async {
    // Only show loading if we don't have cached data
    if (_playlists.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final playlistRepo = context.read<PlaylistRepository>();
      final playlists = await playlistRepo.getUserPlaylists();
      
      final rows = playlists.map((p) => _PlaylistRow(
        id: p.id,
        name: p.name,
        isPrivate: p.isPrivate,
        itemsCount: p.podcastIds.length,
      )).toList();
      
      setState(() {
        _playlists = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (_playlists.isEmpty) {
        setState(() {
          _error = 'Failed to load playlists: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _createPlaylist() async {
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
      await playlistRepo.createPlaylist(name);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playlist created', style: GoogleFonts.inter())),
      );
      
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: GoogleFonts.inter()), backgroundColor: Colors.red),
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : CustomScrollView(
                  slivers: [
                    // Quick actions (restored original design)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.6,
                        ),
                        delegate: SliverChildListDelegate([
                          _ActionCard(
                            icon: Icons.drafts_outlined,
                            label: 'Drafts',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Drafts coming soon', style: GoogleFonts.inter())),
                              );
                            },
                            isDark: isDark,
                          ),
                          _ActionCard(
                            icon: Icons.podcasts_outlined,
                            label: 'My Episodes',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(settings: const RouteSettings(name: 'my_episodes'), builder: (context) => const MyEpisodesPage()),
                            ),
                            isDark: isDark,
                          ),
                          _ActionCard(
                            icon: Icons.playlist_add,
                            label: 'New Playlist',
                            onTap: _createPlaylist,
                            isDark: isDark,
                          ),
                        ]),
                      ),
                    ),

                    // Header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'My Playlists',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),

                    // Playlists grid (restored taller card design)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 240,
                        ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final pl = _playlists[i];
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(name: 'favorite_playlist'),
                                builder: (_) => FavoritePlaylistPage(playlistId: pl.id),
                              ),
                            ).then((_) => _load()),
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
                                    child: Container(
                                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                      child: const Center(
                                        child: Icon(Icons.playlist_play, color: Color(0xFFBFAE01)),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                    child: Text(
                                      pl.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
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

// Grid action card used at the top (restored)
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBFAE01), size: 18),
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
  final int itemsCount;

  _PlaylistRow({
    required this.id,
    required this.name,
    required this.isPrivate,
    required this.itemsCount,
  });
}