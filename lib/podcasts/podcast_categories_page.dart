import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_api.dart';
import 'podcasts_home_page.dart';
import 'podcast_details_page.dart';
import 'player_page.dart';

class PodcastsCategoriesPage extends StatefulWidget {
  const PodcastsCategoriesPage({super.key});

  @override
  State<PodcastsCategoriesPage> createState() => _PodcastsCategoriesPageState();
}

class _PodcastsCategoriesPageState extends State<PodcastsCategoriesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cats = [];

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
      final res = await api.categories();
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      _cats = List<Map<String, dynamic>>.from(d['categories'] ?? const []);
    } catch (e) {
      _error = 'Failed to load categories: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text('Categories',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final c = _cats[idx];
                    final name = (c['category'] ?? '').toString();
                    final count = int.tryParse((c['count'] ?? 0).toString()) ?? 0;
                    return ListTile(
                      tileColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      subtitle: Text('$count podcasts', style: GoogleFonts.inter(color: const Color(0xFF888888))),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CategoryPodcastsPage(category: name)),
                      ),
                    );
                  },
                ),
    );
  }
}

class CategoryPodcastsPage extends StatefulWidget {
  final String category;
  const CategoryPodcastsPage({super.key, required this.category});

  @override
  State<CategoryPodcastsPage> createState() => _CategoryPodcastsPageState();
}

class _CategoryPodcastsPageState extends State<CategoryPodcastsPage> {
  final _controller = ScrollController();

  List<Podcast> _podcasts = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200) {
      _fetch(reset: false);
    }
  }

  Future<void> _fetch({required bool reset}) async {
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _page = 1;
        _podcasts = [];
        _hasMore = true;
      }
    });
    try {
      final api = PodcastsApi.create();
      final res = await api.list(page: _page, limit: _limit, isPublished: true, category: widget.category);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['podcasts'] ?? const []);
      final newItems = list.map(Podcast.fromApi).toList();

      setState(() {
        _podcasts.addAll(newItems);
        _hasMore = newItems.length >= _limit;
        _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(widget.category,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            )),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
          : ListView.separated(
              controller: _controller,
              padding: const EdgeInsets.all(16),
              itemCount: _podcasts.length + (_loading ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                if (idx >= _podcasts.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                    ),
                  );
                }
                final p = _podcasts[idx];
                return ListTile(
                  tileColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: (p.coverUrl ?? '').isNotEmpty
                          ? Image.network(p.coverUrl!, fit: BoxFit.cover)
                          : Container(
                              color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                              child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
                            ),
                    ),
                  ),
                  title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter()),
                  subtitle: Text(p.author ?? 'Unknown', style: GoogleFonts.inter(color: const Color(0xFF888888))),
                  trailing: IconButton(
                    onPressed: () => (p.audioUrl ?? '').isNotEmpty
                        ? Navigator.push(ctx, MaterialPageRoute(builder: (_) => PlayerPage(podcast: p)))
                        : null,
                    icon: const Icon(Icons.play_circle_fill, color: Color(0xFFBFAE01)),
                  ),
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: p)),
                  ),
                );
              },
            ),
    );
  }
}