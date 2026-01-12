import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ionicons/ionicons.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/interfaces/livestream_repository.dart';
import '../repositories/models/livestream_model.dart';
import 'create_livestream_page.dart';
import 'livestream_page.dart';

class LiveStreamListPage extends StatefulWidget {
  const LiveStreamListPage({super.key});

  @override
  State<LiveStreamListPage> createState() => _LiveStreamListPageState();
}

class _LiveStreamListPageState extends State<LiveStreamListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<LiveStreamModel> _liveStreams = [];
  List<LiveStreamModel> _upcomingStreams = [];
  List<LiveStreamModel> _pastStreams = [];
  
  // Pagination state
  bool _isLoadingMore = false;
  bool _hasMoreLive = true;
  bool _hasMoreUpcoming = true;
  bool _hasMorePast = true;
  
  // Prefetch buffers
  List<LiveStreamModel> _prefetchedLive = [];
  List<LiveStreamModel> _prefetchedUpcoming = [];
  List<LiveStreamModel> _prefetchedPast = [];
  
  // Stream cache for instant navigation
  final Map<String, LiveStreamModel> _streamCache = {};

  static const int _streamsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadFromCacheInstantly();
    _loadFreshStreams();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Prefetch next batch for current tab if needed
    _prefetchNextBatch();
  }

  /// Load cached streams instantly for immediate display
  Future<void> _loadFromCacheInstantly() async {
    try {
      final repo = context.read<LiveStreamRepository>();
      
      final cachedResults = await Future.wait([
        repo.getActiveLiveStreamsFromCache(limit: _streamsPerPage),
        repo.getUpcomingLiveStreamsFromCache(limit: _streamsPerPage),
        repo.getPastLiveStreamsFromCache(limit: _streamsPerPage),
      ]);

      if (!mounted) return;
      
      // Only update if we got cached data and don't have fresh data yet
      if (cachedResults[0].isNotEmpty || 
          cachedResults[1].isNotEmpty || 
          cachedResults[2].isNotEmpty) {
        setState(() {
          if (_liveStreams.isEmpty) _liveStreams = cachedResults[0];
          if (_upcomingStreams.isEmpty) _upcomingStreams = cachedResults[1];
          if (_pastStreams.isEmpty) _pastStreams = cachedResults[2];
          _isLoading = false;
        });
        
        // Cache for instant access
        for (final stream in [...cachedResults[0], ...cachedResults[1], ...cachedResults[2]]) {
          _streamCache[stream.id] = stream;
        }
      }
    } catch (e) {
      debugPrint('Cache load error (expected on first run): $e');
    }
  }

  /// Load fresh streams from server in background
  Future<void> _loadFreshStreams() async {
    try {
      final repo = context.read<LiveStreamRepository>();
      
      final results = await Future.wait([
        repo.getActiveLiveStreams(limit: _streamsPerPage),
        repo.getUpcomingLiveStreams(limit: _streamsPerPage),
        repo.getPastLiveStreams(limit: _streamsPerPage),
      ]);

      if (!mounted) return;
      setState(() {
        _liveStreams = results[0];
        _upcomingStreams = results[1];
        _pastStreams = results[2];
        _isLoading = false;
        _hasMoreLive = results[0].length >= _streamsPerPage;
        _hasMoreUpcoming = results[1].length >= _streamsPerPage;
        _hasMorePast = results[2].length >= _streamsPerPage;
      });
      
      // Update cache
      for (final stream in [...results[0], ...results[1], ...results[2]]) {
        _streamCache[stream.id] = stream;
      }
      
      // Prefetch next batch in background
      _prefetchNextBatch();
    } catch (e) {
      debugPrint('Error loading streams: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Prefetch next batch for smoother scrolling
  Future<void> _prefetchNextBatch() async {
    final repo = context.read<LiveStreamRepository>();
    
    try {
      switch (_tabController.index) {
        case 0:
          if (_hasMoreLive && _prefetchedLive.isEmpty && _liveStreams.isNotEmpty) {
            _prefetchedLive = await repo.getActiveLiveStreams(
              limit: _streamsPerPage,
              lastStream: _liveStreams.last,
            );
          }
          break;
        case 1:
          if (_hasMoreUpcoming && _prefetchedUpcoming.isEmpty && _upcomingStreams.isNotEmpty) {
            _prefetchedUpcoming = await repo.getUpcomingLiveStreams(
              limit: _streamsPerPage,
              lastStream: _upcomingStreams.last,
            );
          }
          break;
        case 2:
          if (_hasMorePast && _prefetchedPast.isEmpty && _pastStreams.isNotEmpty) {
            _prefetchedPast = await repo.getPastLiveStreams(
              limit: _streamsPerPage,
              lastStream: _pastStreams.last,
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('Prefetch error: $e');
    }
  }

  /// Load more streams when scrolling near bottom
  Future<void> _loadMore(int tabIndex) async {
    if (_isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final repo = context.read<LiveStreamRepository>();
      List<LiveStreamModel> newStreams;
      
      switch (tabIndex) {
        case 0:
          if (!_hasMoreLive) return;
          if (_prefetchedLive.isNotEmpty) {
            newStreams = _prefetchedLive;
            _prefetchedLive = [];
          } else {
            newStreams = await repo.getActiveLiveStreams(
              limit: _streamsPerPage,
              lastStream: _liveStreams.last,
            );
          }
          if (!mounted) return;
          setState(() {
            _liveStreams.addAll(newStreams);
            _hasMoreLive = newStreams.length >= _streamsPerPage;
          });
          break;
        case 1:
          if (!_hasMoreUpcoming) return;
          if (_prefetchedUpcoming.isNotEmpty) {
            newStreams = _prefetchedUpcoming;
            _prefetchedUpcoming = [];
          } else {
            newStreams = await repo.getUpcomingLiveStreams(
              limit: _streamsPerPage,
              lastStream: _upcomingStreams.last,
            );
          }
          if (!mounted) return;
          setState(() {
            _upcomingStreams.addAll(newStreams);
            _hasMoreUpcoming = newStreams.length >= _streamsPerPage;
          });
          break;
        case 2:
          if (!_hasMorePast) return;
          if (_prefetchedPast.isNotEmpty) {
            newStreams = _prefetchedPast;
            _prefetchedPast = [];
          } else {
            newStreams = await repo.getPastLiveStreams(
              limit: _streamsPerPage,
              lastStream: _pastStreams.last,
            );
          }
          if (!mounted) return;
          setState(() {
            _pastStreams.addAll(newStreams);
            _hasMorePast = newStreams.length >= _streamsPerPage;
          });
          break;
      }
      
      // Prefetch next batch
      _prefetchNextBatch();
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshStreams() async {
    _prefetchedLive = [];
    _prefetchedUpcoming = [];
    _prefetchedPast = [];
    _hasMoreLive = true;
    _hasMoreUpcoming = true;
    _hasMorePast = true;
    await _loadFreshStreams();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        elevation: 0,
        title: Text(
          lang.t('livestream.title'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Ionicons.add_circle_outline,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'create_livestream'),
                builder: (_) => const CreateLiveStreamPage(),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFBFAE01),
          labelColor: const Color(0xFFBFAE01),
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: lang.t('livestream.live_now')),
            Tab(text: lang.t('livestream.upcoming')),
            Tab(text: lang.t('livestream.past')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStreamList(_liveStreams, lang, isLive: true),
          _buildStreamList(_upcomingStreams, lang, isUpcoming: true),
          _buildStreamList(_pastStreams, lang, isPast: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(settings: const RouteSettings(name: 'livestream'), builder: (_) => const CreateLiveStreamPage()),
        ),
        backgroundColor: const Color(0xFFBFAE01),
        icon: const Icon(Ionicons.videocam, color: Colors.black),
        label: Text(
          lang.t('livestream.go_live'),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStreamList(
    List<LiveStreamModel> streams,
    LanguageProvider lang, {
    bool isLive = false,
    bool isUpcoming = false,
    bool isPast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (streams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLive
                  ? Ionicons.radio_outline
                  : isUpcoming
                      ? Ionicons.calendar_outline
                      : Ionicons.play_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isLive
                  ? lang.t('livestream.no_live_streams')
                  : isUpcoming
                      ? lang.t('livestream.no_upcoming')
                      : lang.t('livestream.no_past'),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            if (isLive) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'create_livestream'),
                    builder: (_) => const CreateLiveStreamPage(),
                  ),
                ),
                icon: const Icon(Ionicons.videocam, size: 20),
                label: Text(lang.t('livestream.start_streaming')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Determine which tab we're in for pagination
    final tabIndex = isLive ? 0 : (isUpcoming ? 1 : 2);
    final hasMore = isLive ? _hasMoreLive : (isUpcoming ? _hasMoreUpcoming : _hasMorePast);

    return RefreshIndicator(
      onRefresh: _refreshStreams,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          // Load more when near bottom
          if (scrollInfo.metrics.pixels > scrollInfo.metrics.maxScrollExtent - 200) {
            if (hasMore && !_isLoadingMore) {
              _loadMore(tabIndex);
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: streams.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Loading indicator at bottom
            if (index >= streams.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _isLoadingMore
                      ? const CircularProgressIndicator(color: Color(0xFFBFAE01))
                      : const SizedBox.shrink(),
                ),
              );
            }
            final stream = streams[index];
            return _buildStreamCard(stream, lang, isDark, isLive: isLive);
          },
        ),
      ),
    );
  }

  Widget _buildStreamCard(
    LiveStreamModel stream,
    LanguageProvider lang,
    bool isDark, {
    bool isLive = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'livestream'),
          builder: (_) => LiveStreamPage(streamId: stream.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    // Use thumbUrl for fast loading, fallback to full thumbnailUrl
                    child: (stream.thumbUrl ?? stream.thumbnailUrl) != null
                        ? CachedNetworkImage(
                            imageUrl: stream.thumbUrl ?? stream.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Ionicons.videocam,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Ionicons.videocam,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                  ),
                ),
                // Live badge
                if (isLive)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lang.t('livestream.live').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Viewer count
                if (isLive)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Ionicons.eye,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatViewerCount(stream.viewerCount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Duration for past streams
                if (stream.hasEnded && stream.startedAt != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stream.durationString,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Host info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: stream.hostAvatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(stream.hostAvatarUrl)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: stream.hostAvatarUrl.isEmpty
                            ? Text(
                                stream.hostName.isNotEmpty
                                    ? stream.hostName[0].toUpperCase()
                                    : 'H',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stream.title,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stream.hostName,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (stream.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      stream.description,
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Scheduled time for upcoming
                  if (stream.isScheduled && stream.scheduledAt != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Ionicons.calendar,
                            size: 16,
                            color: Color(0xFFBFAE01),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatScheduledTime(stream.scheduledAt!, lang),
                            style: const TextStyle(
                              color: Color(0xFFBFAE01),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Stats for past streams
                  if (stream.hasEnded) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStat(
                          Ionicons.eye_outline,
                          _formatViewerCount(stream.totalViews),
                          lang.t('livestream.views'),
                        ),
                        const SizedBox(width: 16),
                        _buildStat(
                          Ionicons.chatbubble_outline,
                          stream.messageCount.toString(),
                          lang.t('livestream.messages'),
                        ),
                        const SizedBox(width: 16),
                        _buildStat(
                          Ionicons.heart_outline,
                          stream.reactionCount.toString(),
                          lang.t('livestream.reactions'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String count, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatScheduledTime(DateTime time, LanguageProvider lang) {
    final now = DateTime.now();
    final difference = time.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${lang.t('livestream.days_away')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${lang.t('livestream.hours_away')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${lang.t('livestream.minutes_away')}';
    } else {
      return lang.t('livestream.starting_soon');
    }
  }
}
