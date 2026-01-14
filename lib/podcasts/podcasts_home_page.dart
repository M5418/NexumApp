import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../repositories/interfaces/podcast_repository.dart';
import '../repositories/firebase/firebase_podcast_repository.dart';
import '../core/i18n/language_provider.dart';
import 'podcast_details_page.dart';
import 'create_podcast_page.dart';
import 'player_page.dart';
import 'podcast_categories_page.dart';
import 'favorites_page.dart';
import 'my_library_page.dart';
import 'podcast_search_page.dart';
import 'podcasts_three_column_page.dart';
import '../responsive/responsive_breakpoints.dart';
import '../core/performance_monitor.dart';
import '../local/local_store.dart';
import '../local/repositories/local_podcast_repository.dart';

// Podcast model used across pages (e.g., PodcastDetailsPage imports this).
class Podcast {
    final String id;
  final String title;
  final String? author;
  final String? authorId;
  final String? coverUrl;
  final String? coverThumbUrl; // Small thumbnail for fast list loading
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
    this.authorId,
    this.coverUrl,
    this.coverThumbUrl,
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

  /// Get the best URL for list display (thumbnail if available, else full)
  String? get listCoverUrl => coverThumbUrl ?? coverUrl;

  factory Podcast.fromModel(PodcastModel m) {
    return Podcast(
      id: m.id,
      title: m.title,
      author: m.author,
      authorId: m.authorId,
      coverUrl: m.coverUrl,
      coverThumbUrl: m.coverThumbUrl,
      audioUrl: m.audioUrl,
      durationSec: m.durationSec,
      language: m.language,
      category: m.category,
      description: m.description,
      tags: m.tags,
      createdAt: m.createdAt,
      likes: m.likeCount,
      favorites: m.isBookmarked ? 1 : 0,
      plays: m.playCount,
      meLiked: m.isLiked,
      meFavorite: m.isBookmarked,
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

  // All podcasts for vertical list
  bool _loadingAll = true;
  String? _errorAll;
  List<Podcast> _allPodcasts = [];

  String _selectedLanguage = 'All';
  bool _hasInitializedLanguage = false;
  
  // FASTFEED: Direct repository access for cache-first loading
  final FirebasePodcastRepository _firebasePodcastRepo = FirebasePodcastRepository();

  @override
  void initState() {
    super.initState();
    // FASTFEED: Load cached podcasts instantly, then refresh
    _loadFromCacheInstantly();
    _loadTop();
    _loadAllPodcasts();
  }

  /// INSTANT: Load cached podcasts (no network wait)
  Future<void> _loadFromCacheInstantly() async {
    PerformanceMonitor().startPodcastsLoad();
    
    // ISAR-FIRST: Try Isar local cache first (mobile only)
    if (isIsarSupported) {
      final isarPodcasts = LocalPodcastRepository().getLocalSync(limit: 50);
      if (isarPodcasts.isNotEmpty && mounted) {
        final mapped = _mapIsarPodcastsToUI(isarPodcasts);
        setState(() {
          _top = mapped.take(10).toList();
          _allPodcasts = mapped;
          _loadingTop = false;
          _loadingAll = false;
        });
        PerformanceMonitor().stopPodcastsLoad(count: mapped.length);
        debugPrint('📱 [FastPodcasts] Loaded ${mapped.length} podcasts from Isar');
        return;
      }
    }
    
    // Fallback: Firestore cache
    try {
      // Load top podcasts from cache
      final topModels = await _firebasePodcastRepo.listPodcastsFromCache(
        limit: 10,
        isPublished: true,
      );
      if (topModels.isNotEmpty && mounted) {
        setState(() {
          _top = topModels.map(Podcast.fromModel).toList();
          _loadingTop = false;
        });
      }
      
      // Load all podcasts from cache
      final allModels = await _firebasePodcastRepo.listPodcastsFromCache(
        limit: 50,
        isPublished: true,
      );
      if (allModels.isNotEmpty && mounted) {
        setState(() {
          _allPodcasts = allModels.map(Podcast.fromModel).toList();
          _loadingAll = false;
        });
        PerformanceMonitor().stopPodcastsLoad(count: allModels.length);
      } else {
        PerformanceMonitor().stopPodcastsLoad(count: topModels.length);
      }
    } catch (_) {
      // Cache miss - will load from server
      PerformanceMonitor().stopPodcastsLoad(count: 0);
    }
  }
  
  /// Convert Isar PodcastLite models to UI Podcast objects
  List<Podcast> _mapIsarPodcastsToUI(List<PodcastLite> isarPodcasts) {
    return isarPodcasts.map((p) => Podcast(
      id: p.id,
      title: p.title,
      author: p.author,
      authorId: p.authorId,
      coverUrl: p.coverUrl,
      coverThumbUrl: p.coverThumbUrl,
      audioUrl: p.audioUrl,
      durationSec: p.durationSeconds,
      language: p.language,
      category: p.category,
      description: p.description,
      createdAt: p.createdAt,
    )).toList();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedLanguage) {
      _initializeLanguageFilter();
      _hasInitializedLanguage = true;
    }
  }
  
  void _initializeLanguageFilter() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final userLanguageCode = languageProvider.code;
    
    // Map language code to display name
    final languageMap = {
      'en': 'English',
      'fr': 'Français',
      'pt': 'Português',
      'es': 'Español',
      'de': 'Deutsch',
    };
    
    final preferredLanguage = languageMap[userLanguageCode];
    
    // Set to user's preferred language if available in podcasts, otherwise keep 'All'
    if (preferredLanguage != null && _languages.contains(preferredLanguage)) {
      setState(() {
        _selectedLanguage = preferredLanguage;
      });
    }
  }

  List<String> get _languages {
    final set = <String>{'All'};
    for (final p in _top) {
      if ((p.language ?? '').isNotEmpty) set.add(p.language!);
    }
    for (final p in _allPodcasts) {
      if ((p.language ?? '').isNotEmpty) set.add(p.language!);
    }
    return set.toList();
  }

  List<Podcast> get _filteredTop =>
      _selectedLanguage == 'All' ? _top : _top.where((p) => (p.language ?? '') == _selectedLanguage).toList();

  List<Podcast> get _filteredAll =>
      _selectedLanguage == 'All' ? _allPodcasts : _allPodcasts.where((p) => (p.language ?? '') == _selectedLanguage).toList();

  Future<void> _loadTop() async {
    setState(() {
      _loadingTop = true;
      _errorTop = null;
    });
    try {
      final repo = context.read<PodcastRepository>();
      final models = await repo.listPodcasts(page: 1, limit: 10, isPublished: true);
      _top = models.map(Podcast.fromModel).toList();
    } catch (e) {
      _errorTop = 'Failed to load top podcasts: $e';
    } finally {
      if (mounted) setState(() => _loadingTop = false);
    }
  }

  Future<void> _loadAllPodcasts() async {
    setState(() {
      _loadingAll = true;
      _errorAll = null;
    });
    try {
      final repo = context.read<PodcastRepository>();
      final models = await repo.listPodcasts(page: 1, limit: 50, isPublished: true);
      _allPodcasts = models.map(Podcast.fromModel).toList();
    } catch (e) {
      _errorAll = 'Failed to load podcasts: $e';
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  void _openCreate() {
    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'create_podcast'), builder: (_) => const CreatePodcastPage())).then((changed) {
      if (changed == true) {
        _loadTop();
        _loadAllPodcasts();
      }
    });
  }

  void _openLibrary() {
    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'my_library'), builder: (_) => const MyLibraryPage()));
  }

  void _openFavorites() {
    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'favorites'), builder: (_) => const FavoritesPage()));
  }

  void _openCategories() {
    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'podcast_categories'), builder: (_) => const PodcastsCategoriesPage()));
  }

      @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (context.isDesktop || context.isLargeDesktop) {
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
          Provider.of<LanguageProvider>(context, listen: false).t('podcasts.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          _LanguageFilter(
            selected: _selectedLanguage,
            options: _languages,
            onChanged: (v) => setState(() => _selectedLanguage = v),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(settings: const RouteSettings(name: 'podcast_search'), builder: (_) => const PodcastSearchPage()),
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
          await _loadAllPodcasts();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick actions grid (4 items, pill style)
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
                  label: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.add_podcast'),
                  onTap: _openCreate,
                  isDark: isDark,
                ),
                _QuickActionCard(
                  icon: Icons.video_library_outlined,
                  label: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.my_library'),
                  onTap: _openLibrary,
                  isDark: isDark,
                ),
                _QuickActionCard(
                  icon: Icons.star_border,
                  label: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.favorites'),
                  onTap: _openFavorites,
                  isDark: isDark,
                ),
                _QuickActionCard(
                  icon: Icons.category_outlined,
                  label: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.categories'),
                  onTap: _openCategories,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Podcast section (horizontal, max 10)
            _SectionHeader(
              title: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.top_podcast'),
              onMore: () => Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'all_podcasts'), builder: (_) => const AllPodcastsPage())),
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
                items: _filteredTop.take(10).toList(),
                isDark: isDark,
                onTap: (p) => Navigator.push(
                  context,
                  MaterialPageRoute(settings: const RouteSettings(name: 'podcast_details'), builder: (_) => PodcastDetailsPage(podcast: p)),
                ),
              ),

            const SizedBox(height: 24),

            // All Podcasts section (vertical scroll)
            _SectionHeader(
              title: Provider.of<LanguageProvider>(context, listen: false).t('podcasts.all_podcasts'),
              onMore: null,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            if (_loadingAll)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
              )
            else if (_errorAll != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_errorAll!, style: GoogleFonts.inter(color: Colors.red)),
              )
            else
              // Vertical list of all podcasts
              ..._filteredAll.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VerticalPodcastCard(
                  podcast: p,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(settings: const RouteSettings(name: 'podcast_details'), builder: (_) => PodcastDetailsPage(podcast: p)),
                  ),
                  onPlay: (p.audioUrl ?? '').isNotEmpty
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(settings: const RouteSettings(name: 'podcast_player'), builder: (_) => PlayerPage(podcast: p)),
                          )
                      : null,
                ),
              )),
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
                  color: Colors.black.withValues(alpha: 0.06),
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
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('podcasts.more'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = items[i];
          return SizedBox(
            width: 130,
            child: GestureDetector(
              onTap: () => onTap(p),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover (fixed size)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 130,
                      height: 130,
                      // FASTFEED: Use listCoverUrl (thumbnail) for fast list loading
                      child: (p.listCoverUrl ?? '').isNotEmpty
                          ? Image.network(
                              p.listCoverUrl!,
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
                  const SizedBox(height: 8),
                  // Title (flexible to take remaining space)
                  Expanded(
                    child: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                        height: 1.2,
                      ),
                    ),
                  ),
                  // Author
                  Text(
                    p.author ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
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

// Vertical podcast card for the all podcasts list (larger with description)
class _VerticalPodcastCard extends StatelessWidget {
  final Podcast podcast;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  const _VerticalPodcastCard({
    required this.podcast,
    required this.isDark,
    required this.onTap,
    this.onPlay,
  });

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final mins = seconds ~/ 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final remainMins = mins % 60;
      return '${hrs}h ${remainMins}m';
    }
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Cover + Info + Play button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image (larger)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: (podcast.listCoverUrl ?? '').isNotEmpty
                          ? Image.network(
                              podcast.listCoverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 32),
                              ),
                            )
                          : Container(
                              color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                              child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 32),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title, Author, Stats
                  Expanded(
                    child: SizedBox(
                      height: 90, // Match cover image height
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              podcast.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                                height: 1.2,
                              ),
                            ),
                          ),
                          Text(
                            podcast.author ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF888888),
                            ),
                          ),
                          // Stats row
                          Row(
                            children: [
                              if (podcast.durationSec != null && podcast.durationSec! > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, size: 10, color: Color(0xFF888888)),
                                      const SizedBox(width: 3),
                                      Text(
                                        _formatDuration(podcast.durationSec),
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF888888)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.headphones, size: 10, color: Color(0xFF888888)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${podcast.plays}',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF888888)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Play button
                  if (onPlay != null)
                    GestureDetector(
                      onTap: onPlay,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFBFAE01),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.black, size: 26),
                      ),
                    ),
                ],
              ),
            ),
            // Description (if available)
            if ((podcast.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  podcast.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
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
      final repo = context.read<PodcastRepository>();
      final models = await repo.listPodcasts(
        page: _page,
        limit: _limit,
        isPublished: true,
        query: (widget.q != null && widget.q!.trim().isNotEmpty) ? widget.q!.trim() : null,
      );
      final newItems = models.map(Podcast.fromModel).toList();
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
                    MaterialPageRoute(settings: const RouteSettings(name: 'podcast_details'), builder: (_) => PodcastDetailsPage(podcast: p)),
                  ),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
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
                            // FASTFEED: Use listCoverUrl (thumbnail) for fast list loading
                            child: (p.listCoverUrl ?? '').isNotEmpty
                                ? Image.network(
                                    p.listCoverUrl!,
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
                                    MaterialPageRoute(settings: const RouteSettings(name: 'podcast_player'), builder: (_) => PlayerPage(podcast: p)),
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

class _LanguageFilter extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _LanguageFilter({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
      ),
      child: PopupMenuButton<String>(
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (final o in options) PopupMenuItem<String>(value: o, child: Text(o, style: GoogleFonts.inter(fontSize: 13))),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.translate, size: 16, color: Color(0xFFBFAE01)),
              const SizedBox(width: 6),
              Text(
                selected,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFFBFAE01)),
            ],
          ),
        ),
      ),
    );
  }
}