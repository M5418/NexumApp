import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'widgets/post_card.dart';
import 'widgets/home_post_card.dart';
import 'models/post.dart';
import 'settings_page.dart';
import 'insights_page.dart';
import 'theme_provider.dart';
import 'my_connections_page.dart';
import 'edit_profil.dart';
import 'monetization_page.dart';
import 'premium_subscription_page.dart';
import 'core/auth_api.dart';
import 'core/token_store.dart';
import 'sign_in_page.dart';
import 'core/profile_api.dart';
import 'core/api_client.dart';
import 'podcasts/podcasts_api.dart';
import 'dart:convert';
import 'dart:io';
import 'core/kyc_api.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/notifications_api.dart';
import 'widgets/badge_icon.dart';
import 'notification_page.dart';
import 'conversations_page.dart';
import 'connections_page.dart';
import 'responsive/responsive_breakpoints.dart';



class ProfilePage extends StatefulWidget {
  final bool hideDesktopTopNav;

  const ProfilePage({super.key, this.hideDesktopTopNav = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}


class _ProfilePageState extends State<ProfilePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;

  String? _myUserId;

  // Activity: posts I engaged with (like/bookmark/share/repost), excluding my own original posts
  List<Post> _activityPosts = [];
  bool _loadingActivity = true;
  String? _errorActivity;

  // Posts: created by me
  List<Post> _myPosts = [];
  bool _loadingMyPosts = true;
  String? _errorMyPosts;

  // Media grid: image URLs from my posts
  List<String> _mediaImageUrls = [];
  bool _loadingMedia = true;

  // Podcasts: created by me
  List<Map<String, dynamic>> _myPodcasts = [];
  bool _loadingPodcasts = true;
  String? _errorPodcasts;

  // Notifications badge
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadUnreadNotifications();

  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ProfileApi().me();
      final data = Map<String, dynamic>.from(res['data'] ?? {});
      final meId = (data['user_id'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _myUserId = meId.isNotEmpty ? meId : null;
        _loadingProfile = false;
      });
      if (_myUserId != null) {
        _loadAllTabs();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
      });
    }
  }
    Future<void> _loadUnreadNotifications() async {
    try {
      final c = await NotificationsApi().unreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotifications = 0);
    }
  }

  List<Map<String, dynamic>> _parseListOfMap(dynamic value) {
    try {
      if (value == null) return [];
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        return [];
      }
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  List<String> _parseStringList(dynamic value) {
    try {
      if (value == null) return [];
      if (value is String) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        return [];
      }
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _formatCount(dynamic v) {
    final n = _toInt(v);
    if (n >= 1000000) {
      final m = (n / 1000000);
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final k = (n / 1000);
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }

  DateTime _parseCreatedAt(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?$',
    ).firstMatch(s);
    if (m != null) {
      final year = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      final hour = int.parse(m.group(4)!);
      final minute = int.parse(m.group(5)!);
      final second = int.parse(m.group(6)!);
      final ms = int.tryParse(m.group(7) ?? '0') ?? 0;
      return DateTime.utc(year, month, day, hour, minute, second, ms);
    }
    return DateTime.now();
  }

  Post _mapRawPostToModel(Map<String, dynamic> p) {
    Map<String, dynamic> asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    final original = asMap(p['original_post']);
    // Use original post for content/media/author if it was hydrated
    final contentSource = original.isNotEmpty ? original : p;

    // Author (from content source)
    final author = asMap(contentSource['author']);
    final authorName = (author['name'] ?? author['username'] ?? 'User').toString();
    final authorAvatar = (author['avatarUrl'] ?? author['avatar_url'] ?? '').toString();

    // Counts
    Map<String, dynamic> countsMap = {};
    final directCounts = asMap(p['counts']);
    final originalCounts = asMap(contentSource['counts']);
    if (originalCounts.isNotEmpty) {
      countsMap = originalCounts;
    } else if (directCounts.isNotEmpty) {
      countsMap = directCounts;
    } else {
      countsMap = {
        'likes': p['likes_count'] ?? 0,
        'comments': p['comments_count'] ?? 0,
        'shares': p['shares_count'] ?? 0,
        'reposts': p['reposts_count'] ?? 0,
        'bookmarks': p['bookmarks_count'] ?? 0,
      };
    }

    // Media: prefer `media` list; fallback to image_url/image_urls/video_url if needed
    MediaType mediaType = MediaType.none;
    String? videoUrl;
    List<String> imageUrls = [];

    List<dynamic> mediaList = [];
    if (contentSource['media'] is List) {
      mediaList = List<dynamic>.from(contentSource['media']);
    } else if (p['media'] is List) {
      mediaList = List<dynamic>.from(p['media']);
    }

    if (mediaList.isNotEmpty) {
      final asMaps = mediaList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      String urlOf(Map<String, dynamic> m) =>
          (m['url'] ?? m['src'] ?? m['link'] ?? '').toString();

      final videos = asMaps.where((m) {
        final t = (m['type'] ?? m['media_type'] ?? m['kind'] ?? '').toString().toLowerCase();
        return t.contains('video');
      }).toList();

      final images = asMaps.where((m) {
        final t = (m['type'] ?? m['media_type'] ?? m['kind'] ?? '').toString().toLowerCase();
        return t.contains('image') || t.contains('photo') || t.isEmpty;
      }).toList();

      if (videos.isNotEmpty) {
        mediaType = MediaType.video;
        videoUrl = urlOf(videos.first);
      } else if (images.length > 1) {
        mediaType = MediaType.images;
        imageUrls = images.map(urlOf).where((u) => u.isNotEmpty).toList();
      } else if (images.length == 1) {
        mediaType = MediaType.image;
        final u = urlOf(images.first);
        if (u.isNotEmpty) imageUrls = [u];
      }
    } else {
      // Fallbacks for alternate schemas
      List<String> parseImageUrls(dynamic v) {
        if (v == null) return [];
        if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        if (v is String && v.isNotEmpty) {
          try {
            final decoded = jsonDecode(v);
            if (decoded is List) {
              return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
            }
          } catch (_) {}
        }
        return [];
      }

      final csVideo = (contentSource['video_url'] ?? '').toString();
      final csImageUrl = (contentSource['image_url'] ?? '').toString();
      final csImageUrls = parseImageUrls(contentSource['image_urls']);

      if (csVideo.isNotEmpty) {
        mediaType = MediaType.video;
        videoUrl = csVideo;
      } else if (csImageUrls.length > 1) {
        mediaType = MediaType.images;
        imageUrls = csImageUrls;
      } else if (csImageUrls.length == 1) {
        mediaType = MediaType.image;
        imageUrls = csImageUrls;
      } else if (csImageUrl.isNotEmpty) {
        mediaType = MediaType.image;
        imageUrls = [csImageUrl];
      }
    }

    // Me flags (from row, not original)
    final me = asMap(p['me']);
    final likedByMe = (me['liked'] ?? false) == true;
    final bookmarkedByMe = (me['bookmarked'] ?? false) == true;

    // Repost detection
    final isRepost = p['repost_of'] != null || original.isNotEmpty;

    // Reposter info (header)
    final repostAuthor = asMap(p['repost_author']);
    RepostedBy? repostedBy;
    if (repostAuthor.isNotEmpty) {
      // Only show "reposted this" when this repost row belongs to me
      final isRepostRowByMe = (_myUserId != null) &&
          (p['user_id'] != null) &&
          p['repost_of'] != null &&
          p['user_id'].toString() == _myUserId;
      repostedBy = RepostedBy(
        userName: (repostAuthor['name'] ?? repostAuthor['username'] ?? 'User').toString(),
        userAvatarUrl: (repostAuthor['avatarUrl'] ?? repostAuthor['avatar_url'] ?? '').toString(),
        actionType: isRepostRowByMe ? 'reposted this' : null,
      );
    }

    // Text
    final text = (contentSource['content'] ??
            contentSource['text'] ??
            p['original_content'] ??
            p['text'] ??
            p['content'] ??
            '')
        .toString();

    return Post(
      id: (p['id'] ?? '').toString(),
      userName: authorName,
      userAvatarUrl: authorAvatar,
      createdAt: _parseCreatedAt(
        p['created_at'] ?? p['createdAt'] ?? contentSource['created_at'] ?? contentSource['createdAt'],
      ),
      text: text,
      mediaType: mediaType,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      counts: PostCounts(
        likes: _toInt(countsMap['likes']),
        comments: _toInt(countsMap['comments']),
        shares: _toInt(countsMap['shares']),
        reposts: _toInt(countsMap['reposts']),
        bookmarks: _toInt(countsMap['bookmarks']),
      ),
      userReaction: likedByMe ? ReactionType.like : null,
      isBookmarked: bookmarkedByMe,
      isRepost: isRepost,
      repostedBy: repostedBy,
      originalPostId: (p['repost_of'] ?? original['id'] ?? original['post_id'] ?? '').toString().isEmpty
          ? null
          : (p['repost_of'] ?? original['id'] ?? original['post_id']).toString(),
    );
  }

  Future<void> _loadAllTabs() async {
    _loadMyPosts();
    _loadActivity();
    _loadMyPodcasts();
  }

  Future<void> _loadMyPosts() async {
    if (_myUserId == null) return;
    setState(() {
      _loadingMyPosts = true;
      _errorMyPosts = null;
      _loadingMedia = true;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/api/posts', queryParameters: {
        'user_id': _myUserId,
        'limit': 50,
        'offset': 0,
      });

      final body = Map<String, dynamic>.from(res.data ?? {});
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      final list = (data['posts'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Hydrate original posts for repost rows
      final origIds = list
          .map((p) => p['repost_of'])
          .where((id) => id != null && id.toString().isNotEmpty)
          .map((id) => id.toString())
          .toSet();

      final Map<String, Map<String, dynamic>> originals = {};
      await Future.wait(origIds.map((id) async {
        try {
          final r = await dio.get('/api/posts/$id');
          final rb = Map<String, dynamic>.from(r.data ?? {});
          final rd = Map<String, dynamic>.from(rb['data'] ?? {});
          if (rd['post'] is Map) {
            originals[id] = Map<String, dynamic>.from(rd['post'] as Map);
          }
        } catch (_) {}
      }));

      for (final p in list) {
        final ro = p['repost_of'];
        if (ro != null) {
          final op = originals[ro.toString()];
          if (op != null) p['original_post'] = op;
        }
      }

      final posts = list.map(_mapRawPostToModel).toList();

      // Build media grid only from my posts containing images
      final mediaImages = <String>[];
      for (final post in posts) {
        if (post.mediaType == MediaType.image && post.imageUrls.isNotEmpty) {
          mediaImages.add(post.imageUrls.first);
        } else if (post.mediaType == MediaType.images && post.imageUrls.length > 1) {
          mediaImages.addAll(post.imageUrls);
        }
      }

      if (!mounted) return;
      setState(() {
        _myPosts = posts;
        _mediaImageUrls = mediaImages;
        _loadingMyPosts = false;
        _loadingMedia = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMyPosts = 'Failed to load your posts';
        _loadingMyPosts = false;
        _loadingMedia = false;
      });
    }
  }

   Future<void> _loadActivity() async {
    if (_myUserId == null) return;
    setState(() {
      _loadingActivity = true;
      _errorActivity = null;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/api/posts', queryParameters: {
        'limit': 100,
        'offset': 0,
      });

      final body = Map<String, dynamic>.from(res.data ?? {});
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      final raw = (data['posts'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Activity filter: include reposts done by me, or posts I liked/shared/bookmarked; exclude my own originals
      final filtered = <Map<String, dynamic>>[];
      for (final p in raw) {
        final userId = (p['user_id'] ?? '').toString();
        final me = p['me'] is Map ? Map<String, dynamic>.from(p['me']) : <String, dynamic>{};
        final isMineOriginalRow = userId == _myUserId && (p['repost_of'] == null);
        final isRepostRowByMe = userId == _myUserId && (p['repost_of'] != null);
        final likedByMe = (me['liked'] ?? false) == true;
        final sharedByMe = (me['shared'] ?? false) == true;
        final bookmarkedByMe = (me['bookmarked'] ?? false) == true;

        final include = isRepostRowByMe || likedByMe || sharedByMe || bookmarkedByMe;
        if (!include) continue;
        if (isMineOriginalRow && !isRepostRowByMe) continue;

        filtered.add(p);
      }

      // Hydrate original posts for repost rows (so we can display original content/media/author)
      final origIds = filtered
          .map((p) => p['repost_of'])
          .where((id) => id != null && id.toString().isNotEmpty)
          .map((id) => id.toString())
          .toSet();

      final Map<String, Map<String, dynamic>> originals = {};
      await Future.wait(origIds.map((id) async {
        try {
          final r = await dio.get('/api/posts/$id');
          final rb = Map<String, dynamic>.from(r.data ?? {});
          final rd = Map<String, dynamic>.from(rb['data'] ?? {});
          if (rd['post'] is Map) {
            originals[id] = Map<String, dynamic>.from(rd['post'] as Map);
          }
        } catch (_) {}
      }));

      for (final p in filtered) {
        final ro = p['repost_of'];
        if (ro != null) {
          final op = originals[ro.toString()];
          if (op != null) p['original_post'] = op;
        }
      }

      final results = filtered.map(_mapRawPostToModel).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _activityPosts = results;
        _loadingActivity = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorActivity = 'Failed to load activity';
        _loadingActivity = false;
      });
    }
  }

  Future<void> _loadMyPodcasts() async {
    setState(() {
      _loadingPodcasts = true;
      _errorPodcasts = null;
    });

    try {
      final api = PodcastsApi();
      final res = await api.list(mine: true, limit: 50, page: 1);
      final body = Map<String, dynamic>.from(res);
      final data = Map<String, dynamic>.from(body['data'] ?? {});
      final podcasts = (data['podcasts'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _myPodcasts = podcasts;
        _loadingPodcasts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPodcasts = 'Failed to load your podcasts';
        _loadingPodcasts = false;
      });
    }
  }
    bool _isWideLayout(BuildContext context) {
    return kIsWeb && (context.isDesktop || context.isLargeDesktop);
  }
  
    void _openPremium(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desktop = _isWideLayout(context);

    if (!desktop) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumSubscriptionPage()),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF000000) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Text(
                            'Premium',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Close',
                            icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Body
                    const Expanded(
                      child: PremiumSubscriptionView(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDark = themeProvider.isDarkMode;
          final p = _profile ?? {};
          final String fullName = (() {
            final fn = (p['full_name'] ?? '').toString().trim();
            if (fn.isNotEmpty) return fn;
            final f = (p['first_name'] ?? '').toString().trim();
            final l = (p['last_name'] ?? '').toString().trim();
            if (f.isNotEmpty || l.isNotEmpty) return ('$f $l').trim();
            // Avoid showing email as the main display name; fall back to generic label
            return 'User';
          })();
          final String username = (p['username'] ?? '').toString().trim();
          final String atUsername = username.isNotEmpty ? '@$username' : '';
          final String? bioText = p['bio'] as String?;
          final String? coverUrl = (p['cover_photo_url'] as String?);
          final String? profileUrl = p['profile_photo_url'] as String?;
          final List<Map<String, dynamic>> experiences = _parseListOfMap(
            p['professional_experiences'],
          );
          final List<Map<String, dynamic>> trainings = _parseListOfMap(
            p['trainings'],
          );
          final List<String> interests = _parseStringList(
            p['interest_domains'],
          );
                    if (_isWideLayout(context)) {
            return _buildDesktopProfile(context, isDark);
          }
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
            endDrawer: _buildDrawer(),
            body: _loadingProfile
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Header with Cover Image
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                            image: (coverUrl != null && coverUrl.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(coverUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () => scaffoldKey.currentState?.openEndDrawer(),
                                        child: Icon(
                                          Icons.more_horiz,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (coverUrl == null || coverUrl.isEmpty)
                                Center(
                                  child: Text(
                                    'Add cover image',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : const Color(0xFF666666),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                ),
                            ],
                          ),
                        ),                       // Main Profile Card
                        Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF000000) : Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black.withValues(alpha: 0) : Colors.black.withValues(alpha: 10),
                                blurRadius: 25,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Profile Avatar and Stats
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    // Avatar positioned to overlap cover
                                    Transform.translate(
                                      offset: const Offset(0, -50),
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                                            width: 4,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 58,
                                          backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                                              ? NetworkImage(profileUrl)
                                              : null,
                                          child: (profileUrl == null || profileUrl.isEmpty)
                                              ? Text(
                                                  (fullName.isNotEmpty ? fullName.substring(0, 1) : '?').toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 40,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : Colors.black,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                                                        // Stats Row
                                    Transform.translate(
                                      offset: const Offset(0, -30),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildStatColumn(
                                            _formatCount(p['connections_total_count']),
                                            'Connections',
                                          ),
                                          const SizedBox(width: 40),
                                          _buildStatColumn(
                                            _formatCount(p['connections_inbound_count']),
                                            'Connected',
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Name and Bio
                                    Transform.translate(
                                      offset: const Offset(0, -20),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                fullName,
                                                style: GoogleFonts.inter(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.verified,
                                                color: Color(0xFFBFAE01),
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                          if (atUsername.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                atUsername,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            bioText ?? '',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: isDark ? Colors.white70 : Colors.grey[600],
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Action Buttons
                                    Transform.translate(
                                      offset: const Offset(0, -10),
                                      child: Row(
                                        children: [
                                                                                   Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                final expItems = experiences
                                                    .map(
                                                      (e) => ExperienceItem(
                                                        title: (e['title'] ?? '').toString(),
                                                        subtitle: (e['subtitle'] as String?)?.toString(),
                                                      ),
                                                    )
                                                    .toList();
                                                final trainItems = trainings
                                                    .map(
                                                      (t) => TrainingItem(
                                                        title: (t['title'] ?? '').toString(),
                                                        subtitle: (t['subtitle'] as String?)?.toString(),
                                                      ),
                                                    )
                                                    .toList();

                                                bool canEditFullName = true;
                                                try {
                                                  final kycRes = await KycApi().getMine();
                                                  final kycData = Map<String, dynamic>.from(kycRes['data'] ?? {});
                                                  if (kycData.isEmpty) {
                                                    canEditFullName = true;
                                                  } else {
                                                    final status = (kycData['status'] ?? '').toString().toLowerCase();
                                                    final isApproved =
                                                        ((kycData['is_approved'] ?? 0) == 1) || status == 'approved';
                                                    final isRejected =
                                                        ((kycData['is_rejected'] ?? 0) == 1) || status == 'rejected';
                                                    if (status == 'pending' || isApproved) {
                                                      canEditFullName = false;
                                                    } else if (isRejected) {
                                                      canEditFullName = true;
                                                    } else {
                                                      canEditFullName = false;
                                                    }
                                                  }
                                                } catch (_) {
                                                  canEditFullName = true;
                                                }

                                                final page = EditProfilPage(
                                                  fullName: fullName,
                                                  canEditFullName: canEditFullName,
                                                  username: (p['username'] ?? '').toString(),
                                                  bio: bioText ?? '',
                                                  profilePhotoUrl: profileUrl,
                                                  coverPhotoUrl: coverUrl,
                                                  experiences: expItems,
                                                  trainings: trainItems,
                                                  interests: interests,
                                                );

                                                                                                if (!mounted) return;
                                                ProfileEditResult? result;
                                                if (_isWideLayout(context)) {
                                                  result = await showDialog<ProfileEditResult>(
                                                    context: context,
                                                    barrierDismissible: true,
                                                    builder: (_) {
                                                      return Dialog(
                                                        backgroundColor: Colors.transparent,
                                                        insetPadding:
                                                            const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
                                                        child: Center(
                                                          child: ConstrainedBox(
                                                            constraints:
                                                                const BoxConstraints(maxWidth: 980, maxHeight: 760),
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(20),
                                                              child: Material(
                                                                color: isDark ? const Color(0xFF000000) : Colors.white,
                                                                child: page,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  result = await Navigator.push<ProfileEditResult>(
                                                    context,
                                                    MaterialPageRoute(builder: (_) => page),
                                                  );
                                                }

                                                if (!mounted) return;
                                                if (result != null) {
                                                  final api = ProfileApi();

                                                  try {
                                                    if (result.profileImagePath != null &&
                                                        result.profileImagePath!.isNotEmpty) {
                                                      await api.uploadAndAttachProfilePhoto(File(result.profileImagePath!));
                                                    } else if ((result.profileImageUrl == null ||
                                                            result.profileImageUrl!.isEmpty) &&
                                                        (p['profile_photo_url'] != null)) {
                                                      await api.update({'profile_photo_url': null});
                                                    }

                                                    if (result.coverImagePath != null &&
                                                        result.coverImagePath!.isNotEmpty) {
                                                      await api.uploadAndAttachCoverPhoto(File(result.coverImagePath!));
                                                    } else if ((result.coverImageUrl == null ||
                                                            result.coverImageUrl!.isEmpty) &&
                                                        (p['cover_photo_url'] != null)) {
                                                      await api.update({'cover_photo_url': null});
                                                    }
                                                  } catch (_) {}

                                                  final updates = <String, dynamic>{};

                                                  final newFullName = result.fullName.trim();
                                                  if (newFullName.isNotEmpty && newFullName != fullName.trim()) {
                                                    final parts = newFullName.split(RegExp(r'\s+'));
                                                    final firstName = parts.isNotEmpty ? parts.first : '';
                                                    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                                                    if (firstName.isNotEmpty) updates['first_name'] = firstName;
                                                    updates['last_name'] = lastName;
                                                  }

                                                  final newUsername = result.username.trim();
                                                  if (newUsername.isNotEmpty && newUsername != (p['username'] ?? '')) {
                                                    updates['username'] = newUsername;
                                                  }
                                                  updates['bio'] = result.bio;

                                                  updates['professional_experiences'] = result.experiences
                                                      .map((e) {
                                                        final m = <String, dynamic>{'title': e.title};
                                                        if ((e.subtitle ?? '').trim().isNotEmpty) m['subtitle'] = e.subtitle;
                                                        return m;
                                                      })
                                                      .toList();

                                                  updates['trainings'] = result.trainings
                                                      .map((t) {
                                                        final m = <String, dynamic>{'title': t.title};
                                                        if ((t.subtitle ?? '').trim().isNotEmpty) m['subtitle'] = t.subtitle;
                                                        return m;
                                                      })
                                                      .toList();

                                                  updates['interest_domains'] = result.interests;

                                                  try {
                                                    await api.update(updates);
                                                  } catch (_) {}
                                                }

                                                await _loadProfile();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFBFAE01),
                                                foregroundColor: isDark ? Colors.black : Colors.black,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(25),
                                                ),
                                              ),
                                              child: Text(
                                                'Edit Profile',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.black : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                if (_isWideLayout(context)) {
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: true,
                                                    builder: (_) {
                                                      return Dialog(
                                                        backgroundColor: Colors.transparent,
                                                        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
                                                        child: Center(
                                                          child: ConstrainedBox(
                                                            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(20),
                                                              child: Material(
                                                                color: isDark ? const Color(0xFF000000) : Colors.white,
                                                                child: const MyConnectionsPage(),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => const MyConnectionsPage(),
                                                    ),
                                                  );
                                                }
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(25),
                                                ),
                                                side: BorderSide(
                                                  color: isDark ? Colors.white70 : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Text(
                                                'My Connections',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.white70 : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isDark ? Colors.white70 : Colors.grey[300]!,
                                              ),
                                              borderRadius: BorderRadius.circular(40),
                                            ),
                                            child: Icon(
                                              Icons.person_add_outlined,
                                              size: 20,
                                              color: isDark ? Colors.white70 : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Professional Experiences Section
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.work,
                                          size: 20,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Professional Experiences',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (experiences.isEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'No experiences added yet.',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                 
                                  if (experiences.isNotEmpty)
                                    ...experiences.map(
                                      (exp) => Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              (exp['title'] ?? '').toString(),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if ((exp['subtitle'] ?? '').toString().trim().isNotEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                (exp['subtitle'] ?? '').toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                              // Trainings Section
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.school,
                                          size: 20,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Trainings',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (trainings.isEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'No trainings added yet.',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    if (trainings.isNotEmpty)
                                      ...trainings.map(
                                        (tr) => Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                (tr['title'] ?? '').toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if ((tr['subtitle'] ?? '').toString().trim().isNotEmpty)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  (tr['subtitle'] ?? '').toString(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                              // Interest Section
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 20,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Interest',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: interests.isNotEmpty
                                          ? interests.map((i) => _buildInterestChip(i)).toList()
                                          : [
                                              Text(
                                                'No interests selected yet.',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tab Section
                        _buildTabSection(),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
    Widget _buildDesktopTopNav(BuildContext context, bool isDark) {
    final barColor = isDark ? Colors.black : Colors.white;

    return Material(
      color: barColor,
      elevation: isDark ? 0 : 2,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row: burger | title | notifications
              Row(
                children: [
                  const Icon(Icons.menu, color: Color(0xFF666666)),
                  const Spacer(),
                  Text(
                    'NEXUM',
                    style: GoogleFonts.inika(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  BadgeIcon(
                    icon: Icons.notifications_outlined,
                    badgeCount: _unreadNotifications,
                    iconColor: const Color(0xFF666666),
                                        onTap: () async {
                      if (_isWideLayout(context)) {
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor: Colors.black26,
                          builder: (_) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final size = MediaQuery.of(context).size;
                            final double width = 420;
                            final double height = size.height * 0.8;

                            return SafeArea(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 16, right: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: width,
                                      height: height,
                                      child: Material(
                                        color: isDark ? const Color(0xFF000000) : Colors.white,
                                        child: const NotificationPage(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationPage()),
                        );
                      }
                      if (!mounted) return;
                      await _loadUnreadNotifications();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Top nav row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _navButton(
                    isDark,
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  _navButton(
                    isDark,
                    icon: Icons.people_outline,
                    label: 'Connections',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ConnectionsPage()),
                      );
                    },
                  ),
                  _navButton(
                    isDark,
                    icon: Icons.chat_bubble_outline,
                    label: 'Conversations',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationsPage(
                            isDarkMode: isDark,
                            onThemeToggle: () {},
                            initialTabIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  _navButton(
                    isDark,
                    icon: Icons.person_outline,
                    label: 'My Profil',
                    selected: true,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(
    bool isDark, {
    required IconData icon,
    required String label,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final color = selected ? const Color(0xFFBFAE01) : const Color(0xFF666666);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: color, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }
    Widget _buildDesktopProfile(BuildContext context, bool isDark) {
    if (_loadingProfile) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        endDrawer: _buildDrawer(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final p = _profile ?? {};
    final String fullName = (() {
      final fn = (p['full_name'] ?? '').toString().trim();
      if (fn.isNotEmpty) return fn;
      final f = (p['first_name'] ?? '').toString().trim();
      final l = (p['last_name'] ?? '').toString().trim();
      if (f.isNotEmpty || l.isNotEmpty) return ('$f $l').trim();
      return 'User';
    })();
    final String username = (p['username'] ?? '').toString().trim();
    final String atUsername = username.isNotEmpty ? '@$username' : '';
    final String? bioText = p['bio'] as String?;
    final String? coverUrl = (p['cover_photo_url'] as String?);
    final String? profileUrl = p['profile_photo_url'] as String?;
    final List<Map<String, dynamic>> experiences = _parseListOfMap(p['professional_experiences']);
    final List<Map<String, dynamic>> trainings = _parseListOfMap(p['trainings']);
    final List<String> interests = _parseStringList(p['interest_domains']);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      endDrawer: _buildDrawer(),
      body: Column(
        children: [
          if (!widget.hideDesktopTopNav) _buildDesktopTopNav(context, isDark),
          Expanded( 
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: Profile card + Pro experience + Trainings + Interest
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Cover
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                                  image: (coverUrl != null && coverUrl.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(coverUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: Stack(
                                  children: [
                                    SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () => scaffoldKey.currentState?.openEndDrawer(),
                                              child: Icon(
                                                Icons.more_horiz,
                                                color: isDark ? Colors.white70 : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (coverUrl == null || coverUrl.isEmpty)
                                      Center(
                                        child: Text(
                                          'Add cover image',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : const Color(0xFF666666),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Main Profile Card
                              Container(
                                margin: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF000000) : Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0)
                                          : Colors.black.withValues(alpha: 10),
                                      blurRadius: 25,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Profile Avatar and Stats
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          // Avatar positioned to overlap cover
                                          Transform.translate(
                                            offset: const Offset(0, -50),
                                            child: Container(
                                              width: 120,
                                              height: 120,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                                                  width: 4,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 58,
                                                backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                                                    ? NetworkImage(profileUrl)
                                                    : null,
                                                child: (profileUrl == null || profileUrl.isEmpty)
                                                    ? Text(
                                                        (fullName.isNotEmpty ? fullName.substring(0, 1) : '?')
                                                            .toUpperCase(),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 40,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark ? Colors.white : Colors.black,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),

                                          // Stats Row
                                          Transform.translate(
                                            offset: const Offset(0, -30),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                _buildStatColumn(
                                                  _formatCount(p['connections_total_count']),
                                                  'Connections',
                                                ),
                                                const SizedBox(width: 40),
                                                _buildStatColumn(
                                                  _formatCount(p['connections_inbound_count']),
                                                  'Connected',
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Name and Bio
                                          Transform.translate(
                                            offset: const Offset(0, -20),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      fullName,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 24,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? Colors.white70 : Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.verified, color: Color(0xFFBFAE01), size: 20),
                                                  ],
                                                ),
                                                if (atUsername.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text(
                                                      atUsername,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: isDark ? Colors.white70 : Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  bioText ?? '',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Action Buttons
                                          Transform.translate(
                                            offset: const Offset(0, -10),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      final expItems = experiences
                                                          .map((e) => ExperienceItem(
                                                                title: (e['title'] ?? '').toString(),
                                                                subtitle: (e['subtitle'] as String?)?.toString(),
                                                              ))
                                                          .toList();
                                                      final trainItems = trainings
                                                          .map((t) => TrainingItem(
                                                                title: (t['title'] ?? '').toString(),
                                                                subtitle: (t['subtitle'] as String?)?.toString(),
                                                              ))
                                                          .toList();

                                                      bool canEditFullName = true;
                                                      try {
                                                        final kycRes = await KycApi().getMine();
                                                        final kycData = Map<String, dynamic>.from(kycRes['data'] ?? {});
                                                        if (kycData.isEmpty) {
                                                          canEditFullName = true;
                                                        } else {
                                                          final status = (kycData['status'] ?? '').toString().toLowerCase();
                                                          final isApproved =
                                                              ((kycData['is_approved'] ?? 0) == 1) || status == 'approved';
                                                          final isRejected =
                                                              ((kycData['is_rejected'] ?? 0) == 1) || status == 'rejected';
                                                          if (status == 'pending' || isApproved) {
                                                            canEditFullName = false;
                                                          } else if (isRejected) {
                                                            canEditFullName = true;
                                                          } else {
                                                            canEditFullName = false;
                                                          }
                                                        }
                                                      } catch (_) {
                                                        canEditFullName = true;
                                                      }

                                                      final page = EditProfilPage(
                                                        fullName: fullName,
                                                        canEditFullName: canEditFullName,
                                                        username: (p['username'] ?? '').toString(),
                                                        bio: bioText ?? '',
                                                        profilePhotoUrl: profileUrl,
                                                        coverPhotoUrl: coverUrl,
                                                        experiences: expItems,
                                                        trainings: trainItems,
                                                        interests: interests,
                                                      );

                                                                                                            if (!mounted) return;
                                                      ProfileEditResult? result;
                                                      if (_isWideLayout(context)) {
                                                        result = await showDialog<ProfileEditResult>(
                                                          context: context,
                                                          barrierDismissible: true,
                                                          builder: (_) {
                                                            return Dialog(
                                                              backgroundColor: Colors.transparent,
                                                              insetPadding:
                                                                  const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
                                                              child: Center(
                                                                child: ConstrainedBox(
                                                                  constraints:
                                                                      const BoxConstraints(maxWidth: 980, maxHeight: 760),
                                                                  child: ClipRRect(
                                                                    borderRadius: BorderRadius.circular(20),
                                                                    child: Material(
                                                                      color: isDark ? const Color(0xFF000000) : Colors.white,
                                                                      child: page,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      } else {
                                                        result = await Navigator.push<ProfileEditResult>(
                                                          context,
                                                          MaterialPageRoute(builder: (_) => page),
                                                        );
                                                      }

                                                      if (!mounted) return;
                                                      if (result != null) {
                                                        final api = ProfileApi();

                                                        try {
                                                          if (result.profileImagePath != null &&
                                                              result.profileImagePath!.isNotEmpty) {
                                                            await api.uploadAndAttachProfilePhoto(File(result.profileImagePath!));
                                                          } else if ((result.profileImageUrl == null ||
                                                                  result.profileImageUrl!.isEmpty) &&
                                                              (p['profile_photo_url'] != null)) {
                                                            await api.update({'profile_photo_url': null});
                                                          }

                                                          if (result.coverImagePath != null &&
                                                              result.coverImagePath!.isNotEmpty) {
                                                            await api.uploadAndAttachCoverPhoto(File(result.coverImagePath!));
                                                          } else if ((result.coverImageUrl == null ||
                                                                  result.coverImageUrl!.isEmpty) &&
                                                              (p['cover_photo_url'] != null)) {
                                                            await api.update({'cover_photo_url': null});
                                                          }
                                                        } catch (_) {}

                                                        final updates = <String, dynamic>{};

                                                        final newFullName = result.fullName.trim();
                                                        if (newFullName.isNotEmpty && newFullName != fullName.trim()) {
                                                          final parts = newFullName.split(RegExp(r'\s+'));
                                                          final firstName = parts.isNotEmpty ? parts.first : '';
                                                          final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                                                          if (firstName.isNotEmpty) updates['first_name'] = firstName;
                                                          updates['last_name'] = lastName;
                                                        }

                                                        final newUsername = result.username.trim();
                                                        if (newUsername.isNotEmpty && newUsername != (p['username'] ?? '')) {
                                                          updates['username'] = newUsername;
                                                        }
                                                        updates['bio'] = result.bio;

                                                        updates['professional_experiences'] = result.experiences
                                                            .map((e) {
                                                              final m = <String, dynamic>{'title': e.title};
                                                              if ((e.subtitle ?? '').trim().isNotEmpty) m['subtitle'] = e.subtitle;
                                                              return m;
                                                            })
                                                            .toList();

                                                        updates['trainings'] = result.trainings
                                                            .map((t) {
                                                              final m = <String, dynamic>{'title': t.title};
                                                              if ((t.subtitle ?? '').trim().isNotEmpty) m['subtitle'] = t.subtitle;
                                                              return m;
                                                            })
                                                            .toList();

                                                        updates['interest_domains'] = result.interests;

                                                        try {
                                                          await api.update(updates);
                                                        } catch (_) {}
                                                      }

                                                      await _loadProfile();
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFBFAE01),
                                                      foregroundColor: isDark ? Colors.black : Colors.black,
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(25),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Edit Profile',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: isDark ? Colors.black : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () {
                                                      if (_isWideLayout(context)) {
                                                        showDialog(
                                                          context: context,
                                                          barrierDismissible: true,
                                                          builder: (_) {
                                                            return Dialog(
                                                              backgroundColor: Colors.transparent,
                                                              insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
                                                              child: Center(
                                                                child: ConstrainedBox(
                                                                  constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
                                                                  child: ClipRRect(
                                                                    borderRadius: BorderRadius.circular(20),
                                                                    child: Material(
                                                                      color: isDark ? const Color(0xFF000000) : Colors.white,
                                                                      child: const MyConnectionsPage(),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      } else {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => const MyConnectionsPage(),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    style: OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(25),
                                                      ),
                                                      side: BorderSide(
                                                        color: isDark ? Colors.white70 : Colors.grey[300]!,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'My Connections',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: isDark ? Colors.white70 : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: isDark ? Colors.white70 : Colors.grey[300]!,
                                                    ),
                                                    borderRadius: BorderRadius.circular(40),
                                                  ),
                                                  child: Icon(
                                                    Icons.person_add_outlined,
                                                    size: 20,
                                                    color: isDark ? Colors.white70 : Colors.black,
                                                  ),
                                                ),
                                            ], 
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Professional Experiences Section
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.work, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Professional Experiences',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (experiences.isEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'No experiences added yet.',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          if (experiences.isNotEmpty)
                                            ...experiences.map(
                                              (exp) => Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      (exp['title'] ?? '').toString(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: isDark ? Colors.white70 : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if ((exp['subtitle'] ?? '').toString().trim().isNotEmpty)
                                                    Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        (exp['subtitle'] ?? '').toString(),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          color: isDark ? Colors.white70 : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                    ),

                                    // Trainings Section
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.school, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Trainings',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (trainings.isEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'No trainings added yet.',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          if (trainings.isNotEmpty)
                                            ...trainings.map(
                                              (tr) => Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      (tr['title'] ?? '').toString(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: isDark ? Colors.white70 : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if ((tr['subtitle'] ?? '').toString().trim().isNotEmpty)
                                                    Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        (tr['subtitle'] ?? '').toString(),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          color: isDark ? Colors.white70 : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                    ),

                                    // Interest Section
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.favorite, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Interest',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: interests.isNotEmpty
                                                ? interests.map((i) => _buildInterestChip(i)).toList()
                                                : [
                                                    Text(
                                                      'No interests selected yet.',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: isDark ? Colors.white70 : Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Right column: Tabs (Activity, Posts, Podcasts, Media)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildTabSection(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Helper: Drawer menu
  Widget _buildDrawer() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Drawer(
          backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                    Icons.settings,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Settings',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.monetization_on_outlined,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Monetization',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MonetizationPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.workspace_premium_outlined,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Premium',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                                   onTap: () {
                    Navigator.pop(context);
                    _openPremium(context);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.bar_chart,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 22,
                  ),
                  title: Text(
                    'Insights',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InsightsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.brightness_6,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme();
                        },
                        activeThumbColor: const Color(0xFFBFAE01),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Help Center',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Help Center',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Support',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Support',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Terms & Conditions',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Terms & Conditions',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 22,
                  ),
                  title: Text(
                    'Logout',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                                    onTap: () async {
                    Navigator.pop(context);
                    final ctx = context;
                                        await TokenStore.clear();
                    // Remove Authorization header from Dio client
                    ApiClient().dio.options.headers.remove('Authorization');
                    try {
                      await AuthApi().logout();
                    } catch (_) {}
                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SignInPage()),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper: Stats column
  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Helper: Interest chip
  Widget _buildInterestChip(String label) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white70 : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        );
      },
    );
  }

  // Helper: Tab section
  Widget _buildTabSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF000000) : Colors.black,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? Colors.white70 : Colors.white,
                  unselectedLabelColor:
                      isDark ? Colors.white70 : const Color(0xFF666666),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(text: 'Activity'),
                    Tab(text: 'Posts'),
                    Tab(text: 'Podcasts'),
                    Tab(text: 'Media'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 650,
                child: TabBarView(
                  children: [
                    _buildActivityTab(),
                    _buildPostsTab(),
                    _buildPodcastsTab(),
                    _buildMediaTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

Widget _buildActivityTab() {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (_loadingActivity) return const Center(child: CircularProgressIndicator());

  if (_errorActivity != null) {
    return Center(
      child: Text(
        _errorActivity!,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white70 : const Color(0xFF666666),
        ),
      ),
    );
  }

  if (_activityPosts.isEmpty) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      children: [
        Center(
          child: Text(
            'No recent activity yet.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
            ),
          ),
        ),
      ],
    );
  }

  return ListView.builder(
    primary: false,
    padding: const EdgeInsets.only(top: 10, bottom: 20),
    itemCount: _activityPosts.length,
    itemBuilder: (context, index) {
      return PostCard(
        post: _activityPosts[index],
        isDarkMode: isDark,
        onReactionChanged: (postId, reaction) {},
        onBookmarkToggle: (postId) {},
        onShare: (postId) {},
        onComment: (postId) {},
        onRepost: (postId) {},
      );
    },
  );
}

Widget _buildPostsTab() {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (_loadingMyPosts) return const Center(child: CircularProgressIndicator());

  if (_errorMyPosts != null) {
    return Center(
      child: Text(
        _errorMyPosts!,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white70 : const Color(0xFF666666),
        ),
      ),
    );
  }

  if (_myPosts.isEmpty) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      children: [
        Center(
          child: Text(
            'No posts yet.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
            ),
          ),
        ),
      ],
    );
  }

  return ListView.builder(
    primary: false,
    padding: const EdgeInsets.only(top: 10, bottom: 20),
    itemCount: _myPosts.length,
    itemBuilder: (context, index) {
      return HomePostCard(
        post: _myPosts[index],
        isDarkMode: isDark,
        onReactionChanged: (postId, reaction) {},
        onBookmarkToggle: (postId) {},
        onShare: (postId) {},
        onComment: (postId) {},
        onRepost: (postId) {},
      );
    },
  );
}

  Widget _buildPodcastsTab() {
    if (_loadingPodcasts) return const Center(child: CircularProgressIndicator());
    if (_errorPodcasts != null) return Center(child: Text(_errorPodcasts!));
    if (_myPodcasts.isEmpty) {
      return ListView(
        primary: false,
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: Text('No podcasts yet.')),
        ],
      );
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: _myPodcasts.length,
      itemBuilder: (context, i) {
        final p = _myPodcasts[i];
        final title = (p['title'] ?? '').toString();
        final episode = (p['description'] ?? '').toString();
        final durationSec =
            (p['durationSec'] is num) ? (p['durationSec'] as num).toInt() : null;
        final duration = durationSec != null ? '${durationSec ~/ 60} min' : '';
        final imageUrl = ((p['coverUrl'] ?? '') as String).isNotEmpty
            ? (p['coverUrl'] as String)
            : 'https://via.placeholder.com/300x300.png?text=Podcast';
        return _buildPodcastItem(title, episode, duration, imageUrl);
      },
    );
  }

  Widget _buildPodcastItem(
    String title,
    String episode,
    String duration,
    String imageUrl,
  ) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1F1F1F)
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill, size: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaTab() {
    if (_loadingMedia) return const Center(child: CircularProgressIndicator());
    if (_mediaImageUrls.isEmpty) {
      return GridView.count(
        primary: false,
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: const [],
      );
    }
    return GridView.count(
      primary: false,
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: _mediaImageUrls.map((imageUrl) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(imageUrl, fit: BoxFit.cover),
        );
      }).toList(),
    );
  }
}