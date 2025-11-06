import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'widgets/home_post_card.dart';
import 'widgets/activity_post_card.dart';
import 'widgets/message_invite_card.dart';
import 'models/post.dart';
import 'theme_provider.dart';
import 'core/connections_api.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'core/api_client.dart';
import 'core/profile_api.dart';
import 'models/message.dart' hide MediaType;
import 'widgets/report_bottom_sheet.dart';
import 'chat_page.dart';


class OtherUserProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String userBio;
  final String userCoverUrl;
  final bool isConnected;
  final bool theyConnectToYou;

  const OtherUserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.userBio,
    this.userCoverUrl = '',
    this.isConnected = false,
    this.theyConnectToYou = false,
  });

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late bool _isConnected;
  late ConversationRepository _convRepo;

  // Backend profile data for OTHER user
  Map<String, dynamic>? _userProfile;
  String? _profilePhotoUrl;
  String _coverPhotoUrl = '';

  int _connectionsInboundCount = 0;   // inbound to this user
  int _connectionsTotalCount = 0;

  List<Map<String, dynamic>> _experiences = [];
  List<Map<String, dynamic>> _trainings = [];
  List<String> _interests = [];


  // Data: Activity (their engagements), Posts (created by other user), Media (images from posts), Podcasts
  List<Post> _activityPosts = [];
  bool _loadingActivity = true;
  String? _errorActivity;

  List<Post> _userPosts = [];
  bool _loadingPosts = true;
  String? _errorPosts;

  List<String> _mediaImageUrls = [];
  bool _loadingMedia = true;

  List<Map<String, dynamic>> _podcasts = [];
  bool _loadingPodcasts = true;
  String? _errorPodcasts;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
    _convRepo = context.read<ConversationRepository>();
    // Load profile first so header and stats use real backend
    _loadUserProfile();
    // Kick off tabs
    _loadUserPosts();     // posts authored by this user (with repost hydration)
    _loadActivity();      // "their activity": likes/bookmarks/reposts they did
    _loadPodcasts();      // podcasts authored by this user
  }

  // Utilities
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final i = int.tryParse(v);
      if (i != null) return i;
    }
    return 0;
  }

  DateTime _parseCreatedAt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    final s = v.toString();
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return DateTime.now();
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

  String _formatCount(dynamic v) {
    final n = _toInt(v);
    if (n >= 1000000) {
      final m = n / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }

  Future<void> _loadUserProfile() async {

    try {
      final api = ProfileApi();
      final res = await api.getByUserId(widget.userId);
      final body = Map<String, dynamic>.from(res);
      final data = Map<String, dynamic>.from(body['data'] ?? {});

      final experiences = _parseListOfMap(data['professional_experiences']);
      final trainings = _parseListOfMap(data['trainings']);
      final interests = _parseStringList(data['interest_domains']);

      final profileUrl = (data['profile_photo_url'] ?? '').toString();
      final coverUrl = (data['cover_photo_url'] ?? '').toString();

      setState(() {
        _userProfile = data;
        _profilePhotoUrl = profileUrl.isNotEmpty ? profileUrl : null;
        _coverPhotoUrl = coverUrl.isNotEmpty ? coverUrl : (widget.userCoverUrl);
        _experiences = experiences;
        _trainings = trainings;
        _interests = interests;

        _connectionsInboundCount = _toInt(data['connections_inbound_count']);
        _connectionsTotalCount = _toInt(data['connections_total_count']);
      });
    } catch (e) {
      if (!mounted) return;

    }
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

    // Media
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

    // Reposter info (header) — for other user's page we keep generic
    final repostAuthor = asMap(p['repost_author']);
    RepostedBy? repostedBy;
    if (repostAuthor.isNotEmpty) {
      repostedBy = RepostedBy(
        userName: (repostAuthor['name'] ?? repostAuthor['username'] ?? 'User').toString(),
        userAvatarUrl: (repostAuthor['avatarUrl'] ?? repostAuthor['avatar_url'] ?? '').toString(),
        actionType: 'reposted this',
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
      originalPostId: (p['repost_of'] ?? original['id'] ?? original['post_id'] ?? '')
              .toString()
              .isEmpty
          ? null
          : (p['repost_of'] ?? original['id'] ?? original['post_id']).toString(),
    );
  }

    Future<void> _loadUserPosts() async {
    setState(() {
      _loadingPosts = true;
      _errorPosts = null;
      _loadingMedia = true;
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/api/posts', queryParameters: {
        'user_id': widget.userId,
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

      // Build media grid from this user's ORIGINAL posts containing images
      // - Exclude repost rows to avoid duplicated media from originals
      // - Deduplicate URLs across posts
      final urls = <String>{};
      for (final post in posts) {
        if (post.isRepost) continue; // exclude repost media from Media tab
        if (post.mediaType == MediaType.image && post.imageUrls.isNotEmpty) {
          urls.add(post.imageUrls.first);
        } else if (post.mediaType == MediaType.images && post.imageUrls.isNotEmpty) {
          urls.addAll(post.imageUrls);
        }
      }

      if (!mounted) return;
      setState(() {
        _userPosts = posts;
        _mediaImageUrls = urls.toList();
        _loadingPosts = false;
        _loadingMedia = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPosts = 'Failed to load posts';
        _loadingPosts = false;
        _loadingMedia = false;
      });
    }
  }

  Future<void> _loadActivity() async {
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

      // 1) Reposts done by this user
      final included = <Map<String, dynamic>>[];
      for (final p in raw) {
        final userId = (p['user_id'] ?? '').toString();
        final isRepostRowByUser = userId == widget.userId && (p['repost_of'] != null);
        if (isRepostRowByUser) {
          p['__activity_action'] = 'reposted_this';
          included.add(p);
        }
      }

      // 2) Posts liked/bookmarked/shared by this user (via engagement per post)
      final toCheck = raw.take(100).toList();
      for (final p in toCheck) {
        final pid = (p['id'] ?? '').toString();
        if (pid.isEmpty) continue;
        try {
          final r = await dio.get('/api/posts/$pid/engagement');
          final rb = Map<String, dynamic>.from(r.data ?? {});
          final d2 = Map<String, dynamic>.from(rb['data'] ?? {});
          final likes =
              (d2['likes'] as List? ?? const []).map((e) => e.toString()).toSet();
          final bookmarks =
              (d2['bookmarks'] as List? ?? const []).map((e) => e.toString()).toSet();
          final shares =
              (d2['shares'] as List? ?? const []).map((e) => e.toString()).toSet();

          String? action;
          if (likes.contains(widget.userId)) action ??= 'liked_this';
          if (bookmarks.contains(widget.userId)) action ??= 'bookmarked_this';
          if (shares.contains(widget.userId)) action ??= 'shared_this';

          if (action != null) {
            final clone = Map<String, dynamic>.from(p);
            clone['__activity_action'] = action;
            included.add(clone);
          }
        } catch (_) {
          // ignore failed engagement fetch
        }
      }

      // Hydrate original posts for repost rows (so we can show original content/media/author)
      final origIds = included
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

      for (final p in included) {
        final ro = p['repost_of'];
        if (ro != null) {
          final op = originals[ro.toString()];
          if (op != null) p['original_post'] = op;
        }
      }

      // Convert to Post models and add activity headers
      final results = <Post>[];
      for (final p in included) {
        final post = _mapRawPostToModel(p);
        final action = p['__activity_action'] as String?;
        if (action != null) {
          // Override repostedBy to show this user's activity action
          final activityPost = post.copyWith(
            repostedBy: RepostedBy(
              userName: widget.userName,
              userAvatarUrl: widget.userAvatarUrl,
              actionType: action,
            ),
          );
          results.add(activityPost);
        } else {
          results.add(post);
        }
      }

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

  Future<void> _loadPodcasts() async {
    setState(() {
      _loadingPodcasts = true;
      _errorPodcasts = null;
    });

    try {
      // Placeholder: podcasts will be loaded elsewhere
      if (!mounted) return;
      setState(() {
        _podcasts = [];
        _loadingPodcasts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPodcasts = 'Failed to load podcasts';
        _loadingPodcasts = false;
      });
    }
  }

  Future<void> _handleMessageUser() async {
    final ctx = context;
    try {
      // Check if conversation already exists
      final conversationId = await _convRepo.checkConversationExists(
        widget.userId,
      );

      if (!ctx.mounted) return;

      if (conversationId != null) {
        // Conversation exists - navigate to chat
        final chatUser = ChatUser(
          id: widget.userId,
          name: widget.userName,
          avatarUrl: widget.userAvatarUrl,
        );

        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              otherUser: chatUser,
              isDarkMode: false,
              conversationId: conversationId,
            ),
          ),
        );
      } else {
        // No conversation - show invite bottom sheet
        if (ctx.mounted) {
          _showMessageBottomSheet(ctx);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling message user: $e');
      // Fallback to invite sheet on error
      if (ctx.mounted) {
        _showMessageBottomSheet(ctx);
      }
    }
  }

  void _showMessageBottomSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: MessageInviteCard(
          receiverId: widget.userId,
          fullName: widget.userName,
          bio: widget.userBio,
          avatarUrl: widget.userAvatarUrl,
          coverUrl: _coverPhotoUrl.isNotEmpty ? _coverPhotoUrl : widget.userCoverUrl,
          onClose: () => Navigator.pop(ctx),
          onInvitationSent: (invitation) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Invitation sent to ${widget.userName}')),
            );
          },
        ),
      ),
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

          // Derive display name and @username from backend if available
          final String displayName = (() {
            final p = _userProfile ?? {};
            final fullName = (p['full_name'] ?? '').toString().trim();
            if (fullName.isNotEmpty) return fullName;
            return widget.userName;
          })();
          final String atUsername = (() {
            final p = _userProfile ?? {};
            final u = (p['username'] ?? '').toString().trim();
            return u.isNotEmpty ? '@$u' : '';
          })();

          final String coverUrl = _coverPhotoUrl.isNotEmpty
              ? _coverPhotoUrl
              : widget.userCoverUrl;

          return Scaffold(
            key: scaffoldKey,
            backgroundColor:
                isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
            endDrawer: _buildDrawer(isDark),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header with Cover Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: (coverUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(coverUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: coverUrl.isEmpty
                          ? (isDark ? Colors.black : Colors.grey[300])
                          : null,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  scaffoldKey.currentState!.openEndDrawer(),
                              child: const Icon(
                                Icons.more_horiz,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                              : Colors.black.withValues(alpha: 13),
                          blurRadius: 1,
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
                                      color: isDark
                                          ? const Color(0xFF000000)
                                          : Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 58,
                                    backgroundImage: (_profilePhotoUrl != null &&
                                            _profilePhotoUrl!.isNotEmpty)
                                        ? NetworkImage(_profilePhotoUrl!)
                                        : null,
                                    child: (_profilePhotoUrl == null ||
                                            _profilePhotoUrl!.isEmpty)
                                        ? Text(
                                            (displayName.isNotEmpty
                                                    ? displayName[0]
                                                    : 'U')
                                                .toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),

                              // Stats Row (real backend counts)
                              Transform.translate(
                                offset: const Offset(0, -30),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStatColumn(
                                      _formatCount(_connectionsTotalCount),
                                      'Connections',
                                    ),
                                    const SizedBox(width: 40),
                                    _buildStatColumn(
                                      _formatCount(_connectionsInboundCount),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          displayName,
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
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
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.userBio,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[600],
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
                                          final ctx = context;
                                          final api = ConnectionsApi();
                                          final next = !_isConnected;
                                          setState(() {
                                            _isConnected = next;
                                          });
                                          try {
                                            if (next) {
                                              await api.connect(widget.userId);
                                            } else {
                                              await api.disconnect(
                                                widget.userId,
                                              );
                                            }
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              setState(() {
                                                _isConnected = !next;
                                              });
                                              ScaffoldMessenger.of(
                                                ctx,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to ${next ? 'connect' : 'disconnect'}',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isConnected
                                              ? Colors.grey[300]
                                              : const Color(0xFFBFAE01),
                                          foregroundColor: _isConnected
                                              ? Colors.black87
                                              : Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _isConnected
                                              ? 'Disconnect'
                                              : (widget.theyConnectToYou
                                                  ? 'Connect Back'
                                                  : 'Connect'),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _handleMessageUser,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF000000)
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          'Message',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF000000)
                                              : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                      child: const Icon(
                                        Icons.person_add_outlined,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Professional Experiences Section (real backend data)
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
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Professional Experiences',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_experiences.isEmpty) ...[
                                Text(
                                  'No professional experiences to display',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ] else ...[
                                for (final exp in _experiences) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      (exp['title'] ?? 'Experience')
                                          .toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (exp['subtitle'] != null &&
                                      exp['subtitle'].toString().isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        exp['subtitle'].toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Trainings Section (real backend data)
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
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Trainings',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_trainings.isEmpty) ...[
                                Text(
                                  'No trainings to display',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ] else ...[
                                for (final t in _trainings) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      (t['title'] ?? 'Training').toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (t['subtitle'] != null &&
                                      t['subtitle'].toString().isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        t['subtitle'].toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Interest Section (real backend data)
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
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Interest',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_interests.isEmpty) ...[
                                Text(
                                  'No interests to display',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ] else ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _interests
                                      .map((i) => _buildInterestChip(i))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab Section
                  _buildTabSection(isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.report,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
              title: Text(
                'Report User',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                ReportBottomSheet.show(
                  context,
                  targetType: 'user',
                  targetId: widget.userId,
                  authorName: widget.userName,
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
              title: Text(
                'Block User',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // Add block functionality here
              },
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildInterestChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTabSection(bool isDark) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF000000) : Colors.black,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.grey[300] : Colors.white,
              unselectedLabelColor:
                  isDark ? const Color(0xFF666666) : const Color(0xFF666666),
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
                _buildActivityTab(isDark),
                _buildPostsTab(isDark),
                _buildPodcastsTab(isDark),
                _buildMediaTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(bool isDark) {
    if (_loadingActivity) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorActivity != null) {
      return Center(child: Text(_errorActivity!));
    }
    if (_activityPosts.isEmpty) {
      return const Center(child: Text('No activity found'));
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _activityPosts.length,
      itemBuilder: (context, index) {
        return ActivityPostCard(
          post: _activityPosts[index],
          onReactionChanged: (postId, reaction) {
            // Handle reaction change
          },
          onBookmarkToggle: (postId) {
            // Handle bookmark toggle
          },
          onShare: (postId) {
            // Handle share
          },
          onComment: (postId) {
            // Handle comment
          },
          onRepost: (postId) {
            // Handle repost
          },
        );
      },
    );
  }

  Widget _buildPostsTab(bool isDark) {
    if (_loadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPosts != null) {
      return Center(child: Text(_errorPosts!));
    }
    if (_userPosts.isEmpty) {
      return const Center(child: Text('No posts found'));
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        return HomePostCard(
          post: _userPosts[index],
          onReactionChanged: (postId, reaction) {
            // Handle reaction change
          },
          onBookmarkToggle: (postId) {
            // Handle bookmark toggle
          },
          onShare: (postId) {
            // Handle share
          },
          onComment: (postId) {
            // Handle comment
          },
          onRepost: (postId) {
            // Handle repost
          },
        );
      },
    );
  }

  Widget _buildPodcastsTab(bool isDark) {
    if (_loadingPodcasts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPodcasts != null) {
      return Center(child: Text(_errorPodcasts!));
    }
    if (_podcasts.isEmpty) {
      return const Center(child: Text('No podcasts found'));
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: _podcasts.length,
      itemBuilder: (context, index) {
        final podcast = _podcasts[index];
        return _buildPodcastItem(
          (podcast['title'] ?? 'Untitled').toString(),
          (podcast['description'] ?? 'No description').toString(),
          '${podcast['durationSec'] ?? 0}s',
          (podcast['coverUrl'] ?? '').toString(),
          isDark,
        );
      },
    );
  }

  Widget _buildPodcastItem(
    String title,
    String description,
    String duration,
    String imageUrl,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF000000)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill, size: 32),
        ],
      ),
    );
  }

  Widget _buildMediaTab(bool isDark) {
    if (_loadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mediaImageUrls.isEmpty) {
      return const Center(child: Text('No media found'));
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