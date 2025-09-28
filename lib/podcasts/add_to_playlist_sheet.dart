import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_api.dart';
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
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = PodcastsApi.create();
      final res = await api.playlistsForPodcast(widget.podcast.id);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['playlists'] ?? const []);
      _rows = list
          .map((m) => _PlaylistRow(
                id: (m['id'] ?? '').toString(),
                name: (m['name'] ?? '').toString(),
                isPrivate: (m['isPrivate'] ?? false) == true,
                contains: (m['contains'] ?? false) == true,
                itemsCount: int.tryParse((m['itemsCount'] ?? 0).toString()) ?? 0,
              ))
          .toList();
    } catch (e) {
      _error = 'Failed to load playlists: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String playlistId, bool nextVal) async {
    try {
      final api = PodcastsApi.create();
      if (nextVal) {
        await api.addToPlaylist(playlistId: playlistId, podcastId: widget.podcast.id);
      } else {
        await api.removeFromPlaylist(playlistId: playlistId, podcastId: widget.podcast.id);
      }
      setState(() {
        _rows = _rows.map((r) => r.id == playlistId ? r.copyWith(contains: nextVal) : r).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e', style: GoogleFonts.inter())),
      );
    }
  }

  Future<void> _createPlaylist() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _creating = true);
    try {
      final api = PodcastsApi.create();
      final res = await api.createPlaylist(name: _nameCtrl.text.trim(), isPrivate: false);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final p = Map<String, dynamic>.from(d['playlist'] ?? {});
      final pid = (p['id'] ?? '').toString();

      // auto-add current podcast
      if (pid.isNotEmpty) {
        await api.addToPlaylist(playlistId: pid, podcastId: widget.podcast.id);
      }

      _nameCtrl.clear();
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e', style: GoogleFonts.inter())),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
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
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                hintText: 'New playlist name',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _creating ? null : _createPlaylist,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFAE01),
                              foregroundColor: Colors.black,
                              elevation: 0,
                            ),
                            child: _creating
                                ? const SizedBox(
                                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          ),
                        ],
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