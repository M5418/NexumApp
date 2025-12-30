import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../repositories/interfaces/podcast_repository.dart';
import '../repositories/firebase/firebase_podcast_repository.dart';
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
  
  // FASTFEED: Direct repository access for cache-first loading
  final FirebasePodcastRepository _firebasePodcastRepo = FirebasePodcastRepository();

  @override
  void initState() {
    super.initState();
    // FASTFEED: Load cached categories instantly, then refresh
    _loadFromCacheInstantly();
    _load();
  }

  /// INSTANT: Load cached podcasts and extract categories (no network wait)
  Future<void> _loadFromCacheInstantly() async {
    try {
      final podcasts = await _firebasePodcastRepo.listPodcastsFromCache(
        limit: 500,
        isPublished: true,
      );
      if (podcasts.isNotEmpty && mounted) {
        final categoryList = _buildCategoryList(podcasts);
        setState(() {
          _cats = categoryList;
          _loading = false;
        });
      }
    } catch (_) {
      // Cache miss - will load from server
    }
  }

  List<Map<String, dynamic>> _buildCategoryList(List<PodcastModel> podcasts) {
    final categoryMap = <String, int>{};
    for (final podcast in podcasts) {
      final category = podcast.category?.trim() ?? '';
      if (category.isNotEmpty) {
        final categories = category.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty);
        for (final cat in categories) {
          categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
        }
      }
    }
    return categoryMap.entries
        .map((e) => {'category': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  Future<void> _load() async {
    // Only show loading if we don't have cached data
    if (_cats.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final podcastRepo = context.read<PodcastRepository>();
      final podcasts = await podcastRepo.listPodcasts(
        page: 1,
        limit: 1000,
        isPublished: true,
      );
      
      final categoryList = _buildCategoryList(podcasts);
      
      setState(() {
        _cats = categoryList;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (_cats.isEmpty) {
        setState(() {
          _error = 'Failed to load categories: $e';
          _loading = false;
        });
      }
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
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
      final repo = context.read<PodcastRepository>();
      final models = await repo.listPodcasts(
        page: _page,
        limit: _limit,
        isPublished: true,
        category: widget.category,
      );
      final newItems = models.map(Podcast.fromModel).toList();

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
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_podcasts.length} ${_podcasts.length == 1 ? 'podcast' : 'podcasts'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFAE01).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.podcasts, size: 14, color: Color(0xFFBFAE01)),
                        const SizedBox(width: 4),
                        Text(
                          'CATEGORY',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBFAE01),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFBFAE01),
              onRefresh: () => _fetch(reset: true),
              child: _podcasts.isEmpty && !_loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.podcasts,
                            size: 80,
                            color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No podcasts in this category',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      controller: _controller,
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _podcasts.length + (_loading && _podcasts.isNotEmpty ? 2 : 0),
                      itemBuilder: (ctx, idx) {
                        if (idx >= _podcasts.length) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                          );
                        }
                        final p = _podcasts[idx];
                        return _buildPodcastCard(p, isDark);
                      },
                    ),
            ),
    );
  }

  Widget _buildPodcastCard(Podcast podcast, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: podcast)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    // FASTFEED: Use listCoverUrl (thumbnail) for fast list loading
                    child: (podcast.listCoverUrl ?? '').isNotEmpty
                        ? Image.network(
                            podcast.listCoverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                              child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 48),
                            ),
                          )
                        : Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                            child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 48),
                          ),
                  ),
                ),
                // Play Button Overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      if ((podcast.audioUrl ?? '').isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlayerPage(podcast: podcast)),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Podcast Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      podcast.author ?? 'Unknown',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Stats
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 14, color: Colors.pink),
                        const SizedBox(width: 4),
                        Text(
                          '${podcast.likes}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999)),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.play_arrow, size: 14, color: Color(0xFFBFAE01)),
                        const SizedBox(width: 4),
                        Text(
                          '${podcast.plays}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF999999)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}