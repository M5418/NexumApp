import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_api.dart';
import 'podcast_details_page.dart';
import 'create_podcast_page.dart';
import 'player_page.dart';
import 'podcast_categories_page.dart';
import 'favorites_page.dart';
import 'my_library_page.dart';
import '../data/interest_domains.dart';
import 'podcast_search_page.dart';
import 'podcasts_three_column_page.dart';

// Podcast model used across pages (e.g., PodcastDetailsPage imports this).
class Podcast {
    final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? audioUrl;
  final int? durationSec;
  final String? language;
  final String? category;
  final String? description;
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
    this.description,
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
      coverUrl: ((m['coverUrl'] ?? m['cover_url'])?.toString() ?? '').isNotEmpty
          ? (m['coverUrl'] ?? m['cover_url']).toString()
          : null,
      audioUrl: ((m['audioUrl'] ?? m['audio_url'])?.toString() ?? '').isNotEmpty
          ? (m['audioUrl'] ?? m['audio_url']).toString()
          : null,
      durationSec: (m['durationSec'] ?? m['duration_sec']) == null
          ? null
          : int.tryParse((m['durationSec'] ?? m['duration_sec']).toString()),
      language: m['language']?.toString(),
      category: m['category']?.toString(),
      description: m['description']?.toString(),
      tags: List<String>.from((m['tags'] ?? const []) as List),
      createdAt: m['createdAt'] != null
          ? DateTime.tryParse(m['createdAt'].toString())
          : (m['created_at'] != null
              ? DateTime.tryParse(m['created_at'].toString())
              : null),
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
  // Data for sections
  bool _loadingTop = true;
  String? _errorTop;
  List<Podcast> _top = [];

  bool _loadingDomain = true;
  String? _errorDomain;
  List<Podcast> _domainItems = [];
  String _domainTitle = 'Educations'; // UI label
  String? _domainCategoryParam; // actual category string from interestDomains

  @override
  void initState() {
    super.initState();
    _pickDomainSection();
    _loadTop();
    _loadDomain();
  }

  void _pickDomainSection() {
    // Try to find a domain that matches Education in your interests, else fallback to the first.
    final fallback = interestDomains.isNotEmpty ? interestDomains.first : null;
    final edu = interestDomains.where((d) => d.toLowerCase().contains('educ')).toList();
    _domainCategoryParam = (edu.isNotEmpty ? edu.first : fallback);
    // Keep the UI label matching your screenshot
    _domainTitle = 'Educations';
  }

  Future<void> _loadTop() async {
    setState(() {
      _loadingTop = true;
      _errorTop = null;
    });
    try {
      final api = PodcastsApi.create();
      final res = await api.list(page: 1, limit: 20, isPublished: true);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['podcasts'] ?? const []);
      _top = list.map(Podcast.fromApi).toList();
    } catch (e) {
      _errorTop = 'Failed to load top podcasts: $e';
    } finally {
      if (mounted) setState(() => _loadingTop = false);
    }
  }

  Future<void> _loadDomain() async {
    setState(() {
      _loadingDomain = true;
      _errorDomain = null;
    });
    try {
      if (_domainCategoryParam == null) {
        _domainItems = [];
      } else {
        final api = PodcastsApi.create();
        final res = await api.list(page: 1, limit: 20, isPublished: true, category: _domainCategoryParam);
        final data = Map<String, dynamic>.from(res);
        final d = Map<String, dynamic>.from(data['data'] ?? {});
        final list = List<Map<String, dynamic>>.from(d['podcasts'] ?? const []);
        _domainItems = list.map(Podcast.fromApi).toList();
      }
    } catch (e) {
      _errorDomain = 'Failed to load $_domainTitle: $e';
    } finally {
      if (mounted) setState(() => _loadingDomain = false);
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

  Future<void> _openSearch() async {
    final queryCtrl = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          title: Text('Search', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: queryCtrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
            decoration: const InputDecoration(
              hintText: 'Search podcasts',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, queryCtrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01), foregroundColor: Colors.black),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
    if (!mounted || q == null || q.isEmpty) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AllPodcastsPage(q: q)));
  }

  void _openCreate() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePodcastPage())).then((changed) {
      if (changed == true) {
        _loadTop();
        _loadDomain();
      }
    });
  }

  void _openLibrary() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLibraryPage()));
  }

  void _openFavorites() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()));
  }

  void _openCategories() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PodcastsCategoriesPage()));
  }

    @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    if (size.width >= 1000) {
      return const PodcastsThreeColumnPage();
    }
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Podcast',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PodcastSearchPage()),
            );
          },
          icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black),
        ),
          const SizedBox(width: 4),
        ],
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFBFAE01),
        onRefresh: () async {
          await _loadTop();
          await _loadDomain();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick actions grid (4 items, pill style) - matches screenshot
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
              ),
              children: [
                _QuickActionCard(
                  icon: Icons.add_circle_outline,
                  label: 'Add a Podcast',
                  onTap: _openCreate,
                  isDark: isDark,
                ),
                _QuickActionCard(
                  icon: Icons.video_library_outlined,
                  label: 'My Library',
                  onTap: _openLibrary,
                  isDark: isDark,
                ),
                _QuickActionCard(
                  icon: Icons.star_border,
                  label: 'Favorites',
                  onTap: _openFavorites,
                  isDark: isDark,
                ),
                _QuickActionCard(
                  icon: Icons.category_outlined,
                  label: 'Categories',
                  onTap: _openCategories,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Podcast section
            _SectionHeader(
              title: 'Top Podcast',
              onMore: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllPodcastsPage())),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            if (_loadingTop)
              const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
              )
            else if (_errorTop != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_errorTop!, style: GoogleFonts.inter(color: Colors.red)),
              )
            else
              _HorizontalPodcastList(
                items: _top,
                isDark: isDark,
                onTap: (p) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: p)),
                ),
              ),

            const SizedBox(height: 16),

            // Educations (domain) section
            _SectionHeader(
              title: _domainTitle,
              onMore: (_domainCategoryParam == null)
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryPodcastsPage(category: _domainCategoryParam!),
                        ),
                      ),
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            if (_loadingDomain)
              const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
              )
            else if (_errorDomain != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_errorDomain!, style: GoogleFonts.inter(color: Colors.red)),
              )
            else
              _HorizontalPodcastList(
                items: _domainItems,
                isDark: isDark,
                onTap: (p) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: p)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  final bool isDark;
  const _SectionHeader({required this.title, this.onMore, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const Spacer(),
        if (onMore != null)
          TextButton(
            onPressed: onMore,
            child: Text('More', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _HorizontalPodcastList extends StatelessWidget {
  final List<Podcast> items;
  final bool isDark;
  final void Function(Podcast p) onTap;
  const _HorizontalPodcastList({
    required this.items,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = items[i];
          return SizedBox(
            width: 140,
            child: GestureDetector(
              onTap: () => onTap(p),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: (p.coverUrl ?? '').isNotEmpty
                          ? Image.network(
                              p.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
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
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Author
                  Text(
                    p.author ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// All published podcasts (for Top Podcast -> More and for search)
class AllPodcastsPage extends StatefulWidget {
  final String? q;
  const AllPodcastsPage({super.key, this.q});

  @override
  State<AllPodcastsPage> createState() => _AllPodcastsPageState();
}

class _AllPodcastsPageState extends State<AllPodcastsPage> {
  final _controller = ScrollController();

  List<Podcast> _items = [];
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
        _items = [];
        _hasMore = true;
      }
    });
    try {
      final api = PodcastsApi.create();
      final res = await api.list(
        page: _page,
        limit: _limit,
        isPublished: true,
        q: (widget.q != null && widget.q!.trim().isNotEmpty) ? widget.q!.trim() : null,
      );
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['podcasts'] ?? const []);
      final newItems = list.map(Podcast.fromApi).toList();
      setState(() {
        _items.addAll(newItems);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          widget.q?.isNotEmpty == true ? 'Search: ${widget.q}' : 'All Podcasts',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: GoogleFonts.inter(color: Colors.red)))
          : ListView.separated(
              controller: _controller,
              padding: const EdgeInsets.all(16),
              itemCount: _items.length + (_loading ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                if (idx >= _items.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                    ),
                  );
                }
                final p = _items[idx];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: p)),
                  ),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
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
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => (p.audioUrl ?? '').isNotEmpty
                                ? Navigator.push(
                                    ctx,
                                    MaterialPageRoute(builder: (_) => PlayerPage(podcast: p)),
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
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
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
}