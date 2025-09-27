import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_api.dart';
import 'podcast_details_page.dart';
import 'create_podcast_page.dart';
// Removed: import 'categories_page.dart';
import 'player_page.dart';

class Podcast {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? audioUrl;
  final int? durationSec;
  final String? language;
  final String? category;
  final List<String> tags;
  final DateTime? createdAt;

  int likes;
  int favorites;
  int plays;
  bool meLiked;
  bool meFavorite;

  Podcast({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.audioUrl,
    this.durationSec,
    this.language,
    this.category,
    this.tags = const [],
    this.createdAt,
    this.likes = 0,
    this.favorites = 0,
    this.plays = 0,
    this.meLiked = false,
    this.meFavorite = false,
  });

  factory Podcast.fromApi(Map<String, dynamic> m) {
    final counts = Map<String, dynamic>.from(m['counts'] ?? {});
    final me = Map<String, dynamic>.from(m['me'] ?? {});
    return Podcast(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      author: m['author']?.toString(),
      coverUrl: (m['coverUrl'] ?? '').toString().isEmpty ? null : (m['coverUrl'] as String),
      audioUrl: (m['audioUrl'] ?? '').toString().isEmpty ? null : (m['audioUrl'] as String),
      durationSec: m['durationSec'] == null ? null : int.tryParse(m['durationSec'].toString()),
      language: m['language']?.toString(),
      category: m['category']?.toString(),
      tags: List<String>.from((m['tags'] ?? const []) as List),
      createdAt: m['createdAt'] != null ? DateTime.tryParse(m['createdAt'].toString()) : null,
      likes: int.tryParse((counts['likes'] ?? 0).toString()) ?? 0,
      favorites: int.tryParse((counts['favorites'] ?? 0).toString()) ?? 0,
      plays: int.tryParse((counts['plays'] ?? 0).toString()) ?? 0,
      meLiked: (me['liked'] ?? false) == true,
      meFavorite: (me['favorite'] ?? false) == true,
    );
  }
}

class PodcastsHomePage extends StatefulWidget {
  const PodcastsHomePage({super.key});

  @override
  State<PodcastsHomePage> createState() => _PodcastsHomePageState();
}

class _PodcastsHomePageState extends State<PodcastsHomePage> {
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
      final res = await api.list(page: _page, limit: _limit, isPublished: true);
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
        _error = 'Failed to load podcasts: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 2) return '${diff.inDays} days ago';
    if (diff.inDays >= 1) return 'Yesterday';
    if (diff.inHours >= 1) return '${diff.inHours} hr';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min';
    return 'Just now';
    }

  Future<void> _openCreate() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePodcastPage()),
    );
    if (changed == true && mounted) {
      await _fetch(reset: true);
    }
  }

  Future<void> _openCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PodcastsCategoriesPage()),
    );
  }

  Future<void> _toggleFavorite(Podcast p) async {
    try {
      final api = PodcastsApi.create();
      if (p.meFavorite) {
        await api.unfavorite(p.id);
        setState(() {
          p.meFavorite = false;
          p.favorites = (p.favorites - 1).clamp(0, 1 << 30);
        });
      } else {
        await api.favorite(p.id);
        setState(() {
          p.meFavorite = true;
          p.favorites = p.favorites + 1;
        });
      }
    } catch (e) {
      if (!mounted) return; // guard BuildContext across async gap
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorite: $e', style: GoogleFonts.inter())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  ),
                  Text(
                    'Podcasts',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Categories',
                    onPressed: _openCategories,
                    icon: Icon(Icons.category_outlined, color: isDark ? Colors.white : const Color(0xFF666666)),
                  ),
                  IconButton(
                    onPressed: _openCreate,
                    icon: Icon(Icons.add, color: isDark ? Colors.white : const Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFBFAE01),
        onRefresh: () => _fetch(reset: true),
        child: _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)),
                  ),
                ],
              )
            : ListView.separated(
                controller: _controller,
                padding: const EdgeInsets.all(16),
                itemCount: _podcasts.length + (_loading ? 1 : 0),
                separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
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
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (ctx) => PodcastDetailsPage(podcast: p)),
                    ),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            child: SizedBox(
                              width: 110,
                              height: 120,
                              child: (p.coverUrl ?? '').isNotEmpty
                                  ? Image.network(
                                      p.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                        child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 24),
                                      ),
                                    )
                                  : Container(
                                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                      child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 24),
                                    ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.author ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF999999)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _timeAgo(p.createdAt),
                                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF999999)),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.play_arrow, size: 14, color: isDark ? Colors.white : Colors.black),
                                      const SizedBox(width: 4),
                                      Text('${p.plays}',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  tooltip: p.meFavorite ? 'Unfavorite' : 'Favorite',
                                  onPressed: () => _toggleFavorite(p),
                                  icon: Icon(
                                    p.meFavorite ? Icons.star : Icons.star_border,
                                    size: 22,
                                    color: const Color(0xFFBFAE01),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => (p.audioUrl ?? '').isNotEmpty
                                      ? Navigator.push(
                                          ctx,
                                          MaterialPageRoute(builder: (ctx) => PlayerPage(podcast: p)),
                                        )
                                      : null,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFBFAE01),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow, color: Colors.black, size: 18),
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
      ),
    );
  }
}

// Temporary placeholder to fix missing import/class until categories_page.dart exists
class PodcastsCategoriesPage extends StatelessWidget {
  const PodcastsCategoriesPage({super.key});

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
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          'Categories',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Categories page coming soon',
          style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}