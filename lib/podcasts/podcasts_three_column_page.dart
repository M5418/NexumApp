import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'podcasts_api.dart';
import 'podcasts_home_page.dart' show Podcast;
import 'podcast_details_page.dart';
import 'my_library_page.dart';
import 'my_episodes_page.dart';
import 'podcast_categories_page.dart';
import 'favorites_page.dart';
import 'add_to_playlist_sheet.dart';
import 'podcast_search_page.dart';

class PodcastsThreeColumnPage extends StatefulWidget {
  const PodcastsThreeColumnPage({super.key});

  @override
  State<PodcastsThreeColumnPage> createState() => _PodcastsThreeColumnPageState();
}

class _PodcastsThreeColumnPageState extends State<PodcastsThreeColumnPage> {
  final GlobalKey<NavigatorState> _leftNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _middleNavKey = GlobalKey<NavigatorState>();

  // Left grid data
  bool _loadingLeft = true;
  String? _errorLeft;
  List<Podcast> _leftItems = [];

  // Right top section data
  bool _loadingTop = true;
  String? _errorTop;
  List<Podcast> _topItems = [];

  @override
  void initState() {
    super.initState();
    _loadLeft();
    _loadTop();
  }

  Future<void> _loadLeft() async {
    setState(() {
      _loadingLeft = true;
      _errorLeft = null;
    });
    try {
      final api = PodcastsApi.create();
      final res = await api.list(page: 1, limit: 40, isPublished: true);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['podcasts'] ?? const []);
      _leftItems = list.map(Podcast.fromApi).toList();
    } catch (e) {
      _errorLeft = 'Failed to load podcasts: $e';
    } finally {
      if (mounted) setState(() => _loadingLeft = false);
    }
  }

  Future<void> _loadTop() async {
    setState(() {
      _loadingTop = true;
      _errorTop = null;
    });
    try {
      final api = PodcastsApi.create();
      final res = await api.list(page: 1, limit: 30, isPublished: true);
      final data = Map<String, dynamic>.from(res);
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      final list = List<Map<String, dynamic>>.from(d['podcasts'] ?? const []);
      _topItems = list.map(Podcast.fromApi).toList();
    } catch (e) {
      _errorTop = 'Failed to load top podcasts: $e';
    } finally {
      if (mounted) setState(() => _loadingTop = false);
    }
  }

  void _openInMiddle(Podcast p) {
    _middleNavKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: p)),
      (route) => false,
    );
  }

  Widget _header(bool isDark) {
    final barColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    return Material(
      color: barColor,
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
            const SizedBox(width: 8),
            Text(
              'NEXUM',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(isDark),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: fixed width (450)
                        _LeftColumn(
                          width: 450,
                          isDark: isDark,
                          leftNavKey: _leftNavKey,
                          items: _leftItems,
                          loading: _loadingLeft,
                          error: _errorLeft,
                          onRefresh: _loadLeft,
                          onOpenInMiddle: _openInMiddle,
                        ),
                        const SizedBox(width: 16),

                        // Middle: fixed width (450) with nested navigator for details/player
                        SizedBox(
                          width: 450,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: isDark ? Colors.black : Colors.white,
                              child: Navigator(
                                key: _middleNavKey,
                                onGenerateInitialRoutes: (_, __) {
                                  return [
                                    MaterialPageRoute(
                                      builder: (_) => const _MiddlePlaceholder(),
                                    ),
                                  ];
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Right: small fixed width (320)
                        SizedBox(
                          width: 320,
                          child: _RightTopList(
                            isDark: isDark,
                            items: _topItems,
                            loading: _loadingTop,
                            error: _errorTop,
                            onTap: _openInMiddle,
                            onRefresh: _loadTop,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  final double width;
  final bool isDark;
  final GlobalKey<NavigatorState> leftNavKey;

  final List<Podcast> items;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(Podcast) onOpenInMiddle;

  const _LeftColumn({
    required this.width,
    required this.isDark,
    required this.leftNavKey,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenInMiddle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          // Small header inside the left column
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Text(
                  'Podcast',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => leftNavKey.currentState?.push(
                    MaterialPageRoute(builder: (_) => const PodcastSearchPage()),
                  ),
                  icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Left column nested navigator hosting landing + subpages (fills the whole column below header)
          Expanded(
            child: Navigator(
              key: leftNavKey,
              onGenerateInitialRoutes: (_, __) {
                return [
                  MaterialPageRoute(
                    builder: (_) => _LeftLandingPage(
                      isDark: isDark,
                      items: items,
                      loading: loading,
                      error: error,
                      onRefresh: onRefresh,
                      onOpenInMiddle: onOpenInMiddle,
                    ),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftLandingPage extends StatelessWidget {
  final bool isDark;
  final List<Podcast> items;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(Podcast) onOpenInMiddle;

  const _LeftLandingPage({
    required this.isDark,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenInMiddle,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error!, style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFBFAE01),
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _LeftQuickActions(isDark: isDark),
          const SizedBox(height: 12),

          // Two-axis grid of podcast cards
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length + (loading ? 1 : 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (ctx, idx) {
              if (idx >= items.length) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)));
              }
              final p = items[idx];
              return _PodcastGridCard(
                isDark: isDark,
                podcast: p,
                onTap: () => onOpenInMiddle(p),
                onAddToPlaylist: () => showAddToPlaylistSheet(ctx, p),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeftQuickActions extends StatelessWidget {
  final bool isDark;
  const _LeftQuickActions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      children: [
        _QuickActionPill(
          icon: Icons.podcasts_outlined,
          label: 'My Episodes',
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyEpisodesPage())),
        ),
        _QuickActionPill(
          icon: Icons.video_library_outlined,
          label: 'My Library',
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLibraryPage())),
        ),
        _QuickActionPill(
          icon: Icons.star_border,
          label: 'Favorites',
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage())),
        ),
        _QuickActionPill(
          icon: Icons.category_outlined,
          label: 'Categories',
          isDark: isDark,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PodcastsCategoriesPage())),
        ),
      ],
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _QuickActionPill({
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

class _PodcastGridCard extends StatelessWidget {
  final bool isDark;
  final Podcast podcast;
  final VoidCallback onTap;
  final VoidCallback onAddToPlaylist;
  const _PodcastGridCard({
    required this.isDark,
    required this.podcast,
    required this.onTap,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: (podcast.coverUrl ?? '').isNotEmpty
                      ? Image.network(
                          podcast.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                            child: const Center(child: Icon(Icons.podcasts, color: Color(0xFFBFAE01))),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                          child: const Center(child: Icon(Icons.podcasts, color: Color(0xFFBFAE01))),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        podcast.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        podcast.author ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF666666)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onAddToPlaylist,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.playlist_add, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiddlePlaceholder extends StatelessWidget {
  const _MiddlePlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Text(
          'Select a podcast from the left',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: isDark ? Colors.white70 : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

class _RightTopList extends StatelessWidget {
  final bool isDark;
  final List<Podcast> items;
  final bool loading;
  final String? error;
  final void Function(Podcast) onTap;
  final Future<void> Function() onRefresh;

  const _RightTopList({
    required this.isDark,
    required this.items,
    required this.loading,
    required this.error,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Text(
                  'Top Podcasts',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error!, style: GoogleFonts.inter(color: Colors.red)),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    color: const Color(0xFFBFAE01),
                    onRefresh: onRefresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length + (loading ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        if (idx >= items.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                            ),
                          );
                        }
                        final p = items[idx];
                        return ListTile(
                          onTap: () => onTap(p),
                          tileColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: (p.coverUrl ?? '').isNotEmpty
                                  ? Image.network(
                                      p.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                        child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
                                      ),
                                    )
                                  : Container(
                                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                      child: const Icon(Icons.podcasts, color: Color(0xFFBFAE01)),
                                    ),
                            ),
                          ),
                          title: Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            p.author ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: const Color(0xFF888888)),
                          ),
                          trailing: IconButton(
                            tooltip: 'Play',
                            onPressed: () => onTap(p),
                            icon: const Icon(Icons.play_circle_fill, color: Color(0xFFBFAE01)),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}