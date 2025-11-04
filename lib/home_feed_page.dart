import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/story_ring.dart' as story_widget;
import 'widgets/post_card.dart';
import 'widgets/badge_icon.dart';
import 'widgets/animated_navbar.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'widgets/connection_card.dart';
import 'connections_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart';
import 'profile_page.dart';
import 'post_page.dart';
import 'core/posts_api.dart';
import 'core/stories_api.dart' as stories_api;
import 'models/post.dart';
import 'models/comment.dart';
import 'theme_provider.dart';
import 'search_page.dart';
import 'notification_page.dart';
import 'story_viewer_page.dart';
import 'story_compose_pages.dart';
import 'widgets/tools_overlay.dart';
import 'widgets/my_stories_bottom_sheet.dart';
import 'podcasts/podcasts_home_page.dart';
import 'books/books_home_page.dart';
import 'mentorship/mentorship_home_page.dart';
import 'video_scroll_page.dart';
import 'core/token_store.dart';
import 'sign_in_page.dart';
import 'core/auth_api.dart';
import 'package:dio/dio.dart';
import 'repositories/firebase/firebase_notification_repository.dart';
import 'core/post_events.dart';
import 'core/profile_api.dart'; // Feed preferences
import 'core/users_api.dart'; // Suggested users (right column)
import 'responsive/responsive_breakpoints.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  int _selectedNavIndex = 0;
  List<Post> _posts = [];
  List<stories_api.StoryRing> _storyRings = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  int _conversationsInitialTabIndex = 0; // 0: Chats, 1: Communities
  String? _currentUserId;
  int _desktopSectionIndex =
      0; // 0=Home, 1=Connections, 2=Conversations, 3=Profile

  // Unread notifications badge
  int _unreadCount = 0;

  // Live updates between feed and post page
  StreamSubscription<PostUpdateEvent>? _postEventsSub;

  // Feed preferences (defaults)
  bool _prefShowReposts = true;
  bool _prefShowSuggested = true;
  bool _prefPrioritizeInterests = true;
  List<String> _myInterests = [];

  @override
  void initState() {
    super.initState();
    () async {
      await _loadCurrentUserId();
      await _loadFeedPrefs(); // load prefs before posts
      await _loadData();
      await _loadUnreadCount();
      await _loadSuggestedUsers(); // for desktop right column
    }();

    // Subscribe to post update events to keep feed in sync with PostPage
    _postEventsSub = PostEvents.stream.listen((e) {
      if (!mounted) return;
      setState(() {
        _posts = _posts.map((p) {
          if (p.id == e.originalPostId ||
              p.originalPostId == e.originalPostId) {
            return p.copyWith(
              counts: e.counts,
              userReaction: e.userReaction ?? p.userReaction,
              isBookmarked: e.isBookmarked ?? p.isBookmarked,
            );
          }
          return p;
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _postEventsSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureAuth() async {
    final t = await TokenStore.read();
    if (t == null || t.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignInPage()),
        );
      }
    }
  }

  bool _useDesktopPopup(BuildContext context) {
    if (kIsWeb) {
      // On web, use width to decide "desktop" vs "mobile"
      final w = MediaQuery.of(context).size.width;
      return w >= 900;
    }
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux;
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final res = await AuthApi().me();
      final id = (res['ok'] == true && res['data'] != null)
          ? res['data']['id'] as String?
          : null;
      if (!mounted) return;
      setState(() {
        _currentUserId = id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
      });
    }
  }

  Future<void> _loadFeedPrefs() async {
    try {
      final res = await ProfileApi().me();
      final data = (res['ok'] == true && res['data'] != null)
          ? Map<String, dynamic>.from(res['data'])
          : Map<String, dynamic>.from(res);

      final interestsRaw = data['interest_domains'];
      final interestsList = (interestsRaw is List)
          ? interestsRaw.map((e) => e.toString()).toList()
          : <String>[];

      if (!mounted) return;
      setState(() {
        _prefShowReposts = (data['show_reposts'] is bool)
            ? data['show_reposts']
            : (data['show_reposts'] == 1 ||
                data['show_reposts'] == '1' ||
                (data['show_reposts'] is String &&
                    (data['show_reposts'] as String).toLowerCase() == 'true'));

        _prefShowSuggested = (data['show_suggested_posts'] is bool)
            ? data['show_suggested_posts']
            : (data['show_suggested_posts'] == 1 ||
                data['show_suggested_posts'] == '1' ||
                (data['show_suggested_posts'] is String &&
                    (data['show_suggested_posts'] as String).toLowerCase() ==
                        'true'));

        _prefPrioritizeInterests = (data['prioritize_interests'] is bool)
            ? data['prioritize_interests']
            : (data['prioritize_interests'] == 1 ||
                data['prioritize_interests'] == '1' ||
                (data['prioritize_interests'] is String &&
                    (data['prioritize_interests'] as String).toLowerCase() ==
                        'true'));

        _myInterests = interestsList;
      });
    } catch (_) {
      // Use defaults
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final c = await FirebaseNotificationRepository().getUnreadCount();
      if (!mounted) return;
      setState(() {
        _unreadCount = c;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unreadCount = 0;
      });
    }
  }

  Future<void> _loadData() async {
    List<Post> posts = [];
    List<stories_api.StoryRing> rings = [];
    String? errMsg;

    // Refresh preferences before fetching/applying filters
    await _loadFeedPrefs();

    try {
      posts = await PostsApi().listFeed(limit: 20, offset: 0);
      posts = await _hydrateReposts(posts);
      // Apply filters based on preferences
      posts = _applyFeedFilters(posts);
    } catch (e) {
      errMsg = 'Posts failed: ${_toError(e)}';
    }

    try {
      rings = await stories_api.StoriesApi().getRings();
    } catch (e) {
      final s = 'Stories failed: ${_toError(e)}';
      errMsg = errMsg == null ? s : '$errMsg | $s';
    }

    // Ensure "Your Story" ring shows even if you have no active stories
    if (_currentUserId != null &&
        !rings.any((r) => r.userId == _currentUserId)) {
      rings = [
        stories_api.StoryRing(
          userId: _currentUserId!,
          name: '',
          username: '',
          hasUnseen: false,
          lastStoryAt: DateTime.now(),
          thumbnailUrl: null,
          storyCount: 0,
        ),
        ...rings,
      ];
    }

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _storyRings = rings;
    });

    if (errMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg, style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      final list = await UsersApi().list();
      if (!mounted) return;
      setState(() {
        _suggestedUsers = list
            .where((u) => (u['id']?.toString() ?? '') != (_currentUserId ?? ''))
            .take(12)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
      // ignore suggestions errors
    }
  }

  // Fetch original posts for repost items when the backend didn't hydrate them.
  Future<List<Post>> _hydrateReposts(List<Post> posts) async {
    if (posts.isEmpty) return posts;
    final api = PostsApi();
    final result = List<Post>.from(posts);

    final futures = <Future<void>>[];
    for (int i = 0; i < result.length; i++) {
      final p = result[i];
      if (!p.isRepost) continue;
      final ogId = p.originalPostId;
      if (ogId == null || ogId.isEmpty) continue;

      futures.add(() async {
        final og = await api.getPost(ogId);
        if (og == null) return;
        final merged = p.copyWith(
          userName: og.userName,
          userAvatarUrl: og.userAvatarUrl,
          text: og.text,
          mediaType: og.mediaType,
          imageUrls: og.imageUrls,
          videoUrl: og.videoUrl,
          counts: og.counts,
        );
        result[i] = merged;
      }());
    }

    try {
      await Future.wait(futures);
    } catch (_) {
      // Ignore hydration errors
    }

    return result;
  }

  String _toError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final reason = (data['error'] ?? data['message'] ?? data).toString();
        return 'HTTP ${code ?? 'error'}: $reason';
      }
      return 'HTTP ${code ?? 'error'}';
    }
    return e.toString();
  }

  // === FEED FILTERING HELPERS (hashtags + preference logic) ===
  String _normTag(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<String> _extractTags(String text) {
    final re = RegExp(r'#([A-Za-z0-9_]+)');
    return re
        .allMatches(text)
        .map((m) => m.group(1) ?? '')
        .where((s) => s.isNotEmpty)
        .map(_normTag)
        .toList();
  }

  List<String> _normInterests(List<String> list) =>
      list.map((s) => _normTag(s)).toList();

  List<Post> _applyFeedFilters(List<Post> items) {
    if (items.isEmpty) return items;
    final interestTokens = _normInterests(_myInterests);

    // If the dataset has no hashtags at all, don't apply hashtag-based filters
    final datasetHasTags = items.any((p) => _extractTags(p.text).isNotEmpty);

    return items.where((p) {
      // Repost visibility
      if (!_prefShowReposts && p.isRepost) return false;

      if (!datasetHasTags) return true;

      // Hashtags in text (already hydrated to original content if repost)
      final tags = _extractTags(p.text);
      final hasAnyHashtag = tags.isNotEmpty;
      final matchesInterest = interestTokens.isNotEmpty &&
          tags.any((t) => interestTokens.contains(t));

      // Only enforce interest if user actually has interests set
      final enforceInterest =
          _prefPrioritizeInterests && interestTokens.isNotEmpty;
      final enforceSuggested = _prefShowSuggested;

      // No hashtag filters requested
      if (!enforceInterest && !enforceSuggested) return true;

      if (enforceInterest && enforceSuggested) {
        // Interest OR any hashtag
        return matchesInterest || hasAnyHashtag;
      } else if (enforceInterest) {
        // Only interest matches
        return matchesInterest;
      } else {
        // Only "suggested" (any hashtag)
        return hasAnyHashtag;
      }
    }).toList();
  }

  void _onNavTabChange(int index) {
    setState(() {
      _selectedNavIndex = index;
      if (index != 3) {
        _conversationsInitialTabIndex = 0;
      }
    });

    if (index == 2) {
      () async {
        final created = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        );
        if (created == true) {
          await _loadData();
        }
      }();
    } else if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VideoScrollPage()),
      );
    }
  }

  // Helpers for updating all feed entries tied to the same original post
  List<int> _indexesForOriginal(String originalId) {
    final idxs = <int>[];
    for (int i = 0; i < _posts.length; i++) {
      final p = _posts[i];
      if (p.id == originalId || p.originalPostId == originalId) {
        idxs.add(i);
      }
    }
    return idxs;
  }

  Post? _baseForOriginal(String originalId) {
    final direct = _posts.where((p) => p.id == originalId).toList();
    if (direct.isNotEmpty) return direct.first;
    final viaRepost =
        _posts.where((p) => p.originalPostId == originalId).toList();
    if (viaRepost.isNotEmpty) return viaRepost.first;
    return null;
  }

  void _applyToOriginal(String originalId,
      {required PostCounts counts,
      ReactionType? userReaction,
      bool? isBookmarked}) {
    final idxs = _indexesForOriginal(originalId);
    for (final i in idxs) {
      final p = _posts[i];
      _posts[i] = p.copyWith(
        counts: counts,
        userReaction: userReaction ?? p.userReaction,
        isBookmarked: isBookmarked ?? p.isBookmarked,
      );
    }
  }

  void _onBookmarkToggle(String originalId) async {
    final base = _baseForOriginal(originalId);
    if (base == null) return;

    final willBookmark = !base.isBookmarked;
    final newBookmarks =
        (base.counts.bookmarks + (willBookmark ? 1 : -1)).clamp(0, 1 << 30);

    final updatedCounts = PostCounts(
      likes: base.counts.likes,
      comments: base.counts.comments,
      shares: base.counts.shares,
      reposts: base.counts.reposts,
      bookmarks: newBookmarks,
    );

    final prevPosts = List<Post>.from(_posts);
    setState(() {
      _applyToOriginal(originalId,
          counts: updatedCounts, isBookmarked: willBookmark);
    });

    try {
      if (willBookmark) {
        await PostsApi().bookmark(originalId);
      } else {
        await PostsApi().unbookmark(originalId);
      }
      // Emit for PostPage listeners
      PostEvents.emit(PostUpdateEvent(
        originalPostId: originalId,
        counts: updatedCounts,
        userReaction: base.userReaction,
        isBookmarked: willBookmark,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = prevPosts;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bookmark failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onReactionChanged(String originalId, ReactionType reaction) async {
    final base = _baseForOriginal(originalId);
    if (base == null) return;

    final hadReaction = base.userReaction != null;
    final isSameReaction = base.userReaction == reaction;

    final prevPosts = List<Post>.from(_posts);

    if (!hadReaction) {
      final updatedCounts = PostCounts(
        likes: base.counts.likes + 1,
        comments: base.counts.comments,
        shares: base.counts.shares,
        reposts: base.counts.reposts,
        bookmarks: base.counts.bookmarks,
      );
      setState(() {
        _applyToOriginal(originalId,
            counts: updatedCounts, userReaction: reaction);
      });
      try {
        await PostsApi().like(originalId);
        PostEvents.emit(PostUpdateEvent(
          originalPostId: originalId,
          counts: updatedCounts,
          userReaction: reaction,
          isBookmarked: base.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _posts = prevPosts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Like failed: ${_toError(e)}', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (isSameReaction) {
      final newLikes = (base.counts.likes > 0 ? base.counts.likes - 1 : 0);
      final updatedCounts = PostCounts(
        likes: newLikes,
        comments: base.counts.comments,
        shares: base.counts.shares,
        reposts: base.counts.reposts,
        bookmarks: base.counts.bookmarks,
      );

      setState(() {
        _applyToOriginal(originalId, counts: updatedCounts, userReaction: null);
      });

      try {
        await PostsApi().unlike(originalId);
        PostEvents.emit(PostUpdateEvent(
          originalPostId: originalId,
          counts: updatedCounts,
          userReaction: null,
          isBookmarked: base.isBookmarked,
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _posts = prevPosts;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlike failed: ${_toError(e)}',
                style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Different reaction but still a "like" concept: update icon only (no extra like API)
    setState(() {
      _applyToOriginal(originalId, counts: base.counts, userReaction: reaction);
    });
  }

  void _onShare(String originalId) {
    ShareBottomSheet.show(
      context,
      onStories: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Stories', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      },
      onCopyLink: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Link copied to clipboard', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF9E9E9E),
          ),
        );
      },
      onTelegram: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Telegram', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF0088CC),
          ),
        );
      },
      onFacebook: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Facebook', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      },
      onMore: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('More share options', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF666666),
          ),
        );
      },
      onSendToUsers: (selectedUsers, message) {
        final userNames = selectedUsers.map((user) => user.name).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sent to $userNames${message.isNotEmpty ? ' with message: "$message"' : ''}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFFBFAE01),
          ),
        );
      },
    );
  }

  Future<void> _openCommentsSheet(String originalId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Comment> comments = [];
    try {
      comments = await PostsApi().listComments(originalId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Load comments failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;

    CommentBottomSheet.show(
      context,
      postId: originalId,
      comments: comments,
      currentUserId: _currentUserId ?? '',
      isDarkMode: isDark,
      onAddComment: (text) async {
        try {
          await PostsApi().addComment(originalId, content: text);

          final base = _baseForOriginal(originalId);
          if (base != null) {
            final updatedCounts = PostCounts(
              likes: base.counts.likes,
              comments: base.counts.comments + 1,
              shares: base.counts.shares,
              reposts: base.counts.reposts,
              bookmarks: base.counts.bookmarks,
            );
            setState(() {
              _applyToOriginal(originalId, counts: updatedCounts);
            });
            PostEvents.emit(PostUpdateEvent(
              originalPostId: originalId,
              counts: updatedCounts,
              userReaction: base.userReaction,
              isBookmarked: base.isBookmarked,
            ));
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comment posted!', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post comment failed: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onReplyToComment: (commentId, replyText) async {
        try {
          await PostsApi().addComment(originalId,
              content: replyText, parentCommentId: commentId);

          // Count reply as part of comments for the action row
          final base = _baseForOriginal(originalId);
          if (base != null) {
            final updatedCounts = PostCounts(
              likes: base.counts.likes,
              comments: base.counts.comments + 1,
              shares: base.counts.shares,
              reposts: base.counts.reposts,
              bookmarks: base.counts.bookmarks,
            );
            setState(() {
              _applyToOriginal(originalId, counts: updatedCounts);
            });
            PostEvents.emit(PostUpdateEvent(
              originalPostId: originalId,
              counts: updatedCounts,
              userReaction: base.userReaction,
              isBookmarked: base.isBookmarked,
            ));
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reply posted!', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reply failed: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _onComment(String originalId) => _openCommentsSheet(originalId);

  void _onRepost(String originalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Repost this?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to repost this?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Repost',
                style: GoogleFonts.inter(color: const Color(0xFFBFAE01))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await PostsApi().repost(originalId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Post reposted successfully', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      await _loadData();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final data = e.response?.data;
      final msg = _toError(e);

      final isAlreadyReposted = code == 409 ||
          (data is Map &&
              ((data['error'] ?? data['message'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('already')));

      if (isAlreadyReposted) {
        final remove = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove repost?',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            content: Text('You already reposted this. Remove your repost?',
                style: GoogleFonts.inter()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: GoogleFonts.inter()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child:
                    Text('Remove', style: GoogleFonts.inter(color: Colors.red)),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (remove == true) {
          try {
            await PostsApi().unrepost(originalId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Repost removed', style: GoogleFonts.inter()),
                backgroundColor: const Color(0xFF9E9E9E),
              ),
            );
            await _loadData();
          } catch (e2) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to remove repost: ${_toError(e2)}',
                    style: GoogleFonts.inter()),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Repost failed: $msg', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Repost failed: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onPostTap(String originalId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostPage(postId: originalId)),
    );
    // Refresh after returning from Post page
    await _loadData();
  }

  // ----------------------------
  // BUILD
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final backgroundColor =
            isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

        // Responsive: desktop and largeDesktop → desktop layout; others → mobile
        if (kIsWeb && (context.isDesktop || context.isLargeDesktop)) {
          return _buildDesktopLayout(context, isDark, backgroundColor);
        }

        // Mobile/tablet: keep existing design
        return Scaffold(
          backgroundColor: backgroundColor,
          body: _selectedNavIndex == 1
              ? ConnectionsPage(isDarkMode: isDark, onThemeToggle: () {})
              : _selectedNavIndex == 3
                  ? ConversationsPage(
                      isDarkMode: isDark,
                      onThemeToggle: () {},
                      initialTabIndex: _conversationsInitialTabIndex,
                    )
                  : _selectedNavIndex == 4
                      ? const ProfilePage()
                      : _selectedNavIndex == 5
                          ? const VideoScrollPage()
                          : _buildHomeFeedMobile(
                              context, isDark, backgroundColor),
          bottomNavigationBar: AnimatedNavbar(
            selectedIndex: _selectedNavIndex,
            onTabChange: _onNavTabChange,
            isDarkMode: isDark,
          ),
          floatingActionButton:
              (_selectedNavIndex == 0 || _selectedNavIndex == 1)
                  ? FloatingActionButton(
                      heroTag: 'toolsFabMain',
                      onPressed: _showToolsOverlay,
                      backgroundColor: const Color(0xFFBFAE01),
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.widgets_outlined),
                    )
                  : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  void _showToolsOverlay() {
    ToolsOverlay.show(
      context,
      onCommunities: () {
        setState(() {
          _conversationsInitialTabIndex = 1;
          _selectedNavIndex = 3;
        });
      },
      onPodcasts: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PodcastsHomePage()));
      },
      onBooks: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BooksHomePage()));
      },
      onMentorship: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MentorshipHomePage()));
      },
      onVideos: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VideoScrollPage()));
      },
    );
  }

  // ===========================
  // Desktop (Web) Layout
  // ===========================
  Widget _buildDesktopLayout(
      BuildContext context, bool isDark, Color backgroundColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildDesktopTopNav(isDark),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: IndexedStack(
                        index: _desktopSectionIndex,
                        children: [
                          _buildDesktopColumns(isDark), // Home
                          ConnectionsPage(
                            isDarkMode: isDark,
                            onThemeToggle: () {},
                            hideDesktopTopNav: true,
                          ),
                          ConversationsPage(
                            isDarkMode: isDark,
                            onThemeToggle: () {},
                            initialTabIndex: _conversationsInitialTabIndex,
                            hideDesktopTopNav: true,
                          ),
                          const ProfilePage(hideDesktopTopNav: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_desktopSectionIndex == 0)
            Positioned(
              left: 24,
              bottom: 24,
              child: FloatingActionButton(
                heroTag: 'createPostFabWeb',
                onPressed: () async {
                  final created = await CreatePostPage.showPopup<bool>(context);
                  if (created == true) {
                    await _loadData();
                  }
                },
                backgroundColor: const Color(0xFFBFAE01),
                foregroundColor: Colors.black,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
            floatingActionButton: (_desktopSectionIndex == 0 || _desktopSectionIndex == 1)
          ? FloatingActionButton(
              heroTag: 'toolsFabWeb',
              onPressed: _showToolsOverlay,
              backgroundColor: const Color(0xFFBFAE01),
              foregroundColor: Colors.black,
              child: const Icon(Icons.widgets_outlined),
            )
          : null,
    );
  }

  Widget _buildDesktopTopNav(bool isDark) {
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
              Row(
                children: [
                  Icon(Icons.menu, color: const Color(0xFF666666)),
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
                    badgeCount: _unreadCount,
                    iconColor: const Color(0xFF666666),
                    onTap: () async {
                      final size = MediaQuery.of(context).size;
                      final desktop =
                          kIsWeb && size.width >= 1280 && size.height >= 800;
                      if (desktop) {
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor: Colors.black26,
                          builder: (_) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final double width = 420;
                            final double height = size.height * 0.8;
                            return SafeArea(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 16, right: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: width,
                                      height: height,
                                      child: Material(
                                        color: isDark
                                            ? const Color(0xFF000000)
                                            : Colors.white,
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
                          MaterialPageRoute(
                              builder: (_) => const NotificationPage()),
                        );
                      }
                      if (!mounted) return;
                      await _loadUnreadCount();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TopNavItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    selected: _desktopSectionIndex == 0,
                    onTap: () => setState(() => _desktopSectionIndex = 0),
                  ),
                  _TopNavItem(
                    icon: Icons.people_outline,
                    label: 'Connections',
                    selected: _desktopSectionIndex == 1,
                    onTap: () => setState(() => _desktopSectionIndex = 1),
                  ),
                  _TopNavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Conversations',
                    selected: _desktopSectionIndex == 2,
                    onTap: () => setState(() => _desktopSectionIndex = 2),
                  ),
                  _TopNavItem(
                    icon: Icons.person_outline,
                    label: 'My Profil',
                    selected: _desktopSectionIndex == 3,
                    onTap: () => setState(() => _desktopSectionIndex = 3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopColumns(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Stories panel
        SizedBox(width: 240, child: _buildLeftStoriesPanel(isDark)),

        const SizedBox(width: 16),

        // Center: Feed
        Expanded(child: _buildCenterFeedPanel(isDark)),

        const SizedBox(width: 16),

        // Right: Suggestions panel
        SizedBox(width: 360, child: _buildRightSuggestionsPanel(isDark)),
      ],
    );
  }

  Widget _buildLeftStoriesPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stories',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                )),
            const SizedBox(height: 12),
            // Vertical list of story rings
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _storyRings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ring = _storyRings[index];
                  final isMine = ring.userId == _currentUserId;

                  return Row(
                    children: [
                      story_widget.StoryRing(
                        imageUrl: ring.thumbnailUrl ?? ring.avatarUrl,
                        label: isMine
                            ? 'Your Story'
                            : (ring.name.isNotEmpty
                                ? ring.name
                                : (ring.username.startsWith('@')
                                    ? ring.username
                                    : '@${ring.username}')),
                        isMine: isMine,
                        isSeen: !ring.hasUnseen,
                        onAddTap: isMine
                            ? () {
                                if (ring.storyCount > 0 &&
                                    _currentUserId != null) {
                                  MyStoriesBottomSheet.show(
                                    context,
                                    currentUserId: _currentUserId!,
                                    onAddStory: () {
                                      StoryTypePicker.show(
                                        context,
                                        onSelected: (type) async {
                                          if (_useDesktopPopup(context)) {
                                            await StoryComposerPopup.show(
                                                context,
                                                type: type);
                                          } else {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      _composerPage(type)),
                                            );
                                          }
                                        },
                                      );
                                    },
                                  );
                                } else {
                                  StoryTypePicker.show(
                                    context,
                                    onSelected: (type) async {
                                      if (_useDesktopPopup(context)) {
                                        await StoryComposerPopup.show(context,
                                            type: type);
                                      } else {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  _composerPage(type)),
                                        );
                                      }
                                    },
                                  );
                                }
                              }
                            : null,
                        onTap: () async {
                          if (isMine) {
                            if (ring.storyCount > 0 && _currentUserId != null) {
                              MyStoriesBottomSheet.show(
                                context,
                                currentUserId: _currentUserId!,
                                onAddStory: () {
                                  StoryTypePicker.show(
                                    context,
                                    onSelected: (type) async {
                                      if (_useDesktopPopup(context)) {
                                        await StoryComposerPopup.show(context,
                                            type: type);
                                      } else {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  _composerPage(type)),
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            } else {
                              StoryTypePicker.show(
                                context,
                                onSelected: (type) async {
                                  if (_useDesktopPopup(context)) {
                                    await StoryComposerPopup.show(context,
                                        type: type);
                                  } else {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => _composerPage(type)),
                                    );
                                  }
                                },
                              );
                            }
                          } else {
                            if (_useDesktopPopup(context)) {
                              await StoryViewerPopup.show(
                                context,
                                rings: _storyRings
                                    .map((r) => {
                                          'userId': r.userId,
                                          'imageUrl':
                                              r.thumbnailUrl ?? r.avatarUrl,
                                          'label': r.name,
                                          'isMine': r.userId == _currentUserId,
                                          'isSeen': !r.hasUnseen,
                                        })
                                    .toList(),
                                initialRingIndex: index,
                              );
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoryViewerPage(
                                    rings: _storyRings
                                        .map((r) => {
                                              'userId': r.userId,
                                              'imageUrl':
                                                  r.thumbnailUrl ?? r.avatarUrl,
                                              'label': r.name,
                                              'isMine':
                                                  r.userId == _currentUserId,
                                              'isSeen': !r.hasUnseen,
                                            })
                                        .toList(),
                                    initialRingIndex: index,
                                  ),
                                ),
                              );
                            }
                            await _loadData();
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterFeedPanel(bool isDark) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return PostCard(
            post: _posts[index],
            onReactionChanged: _onReactionChanged,
            onBookmarkToggle: _onBookmarkToggle,
            onTap: _onPostTap,
            onShare: _onShare,
            onComment: _onComment,
            onRepost: _onRepost,
            isDarkMode: isDark,
            currentUserId: _currentUserId,
          );
        },
      ),
    );
  }

  Widget _buildRightSuggestionsPanel(bool isDark) {
    final cardColor = isDark ? Colors.black : Colors.white;

    List<Map<String, dynamic>> users = _suggestedUsers;
    if (users.isEmpty) {
      // Create a small placeholder list to avoid an empty panel
      users = List.generate(6, (i) {
        return {
          'id': 'user_$i',
          'name': 'User $i',
          'username': '@user$i',
          'bio': 'Hello Nexum',
          'avatarUrl': '',
          'coverUrl': '',
        };
      });
    }

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'Connections',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ConnectionsPage(
                              isDarkMode: isDark, onThemeToggle: () {})),
                    );
                  },
                  child:
                      Text('See more', style: GoogleFonts.inter(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Card rail
            SizedBox(
              height: 276, // fits ConnectionCard height + padding
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final u = users[i];
                  final uid = (u['id'] ?? '').toString();
                  final fullName = _pickFullName(u);
                  final username = _pickUsername(u);
                  final bio = (u['bio'] ?? '').toString();
                  final avatar = _pickAvatar(u);
                  final cover = _pickCover(u);
                  return ConnectionCard(
                    userId: uid,
                    coverUrl: cover,
                    avatarUrl: avatar,
                    fullName: fullName,
                    username: username,
                    bio: bio,
                    initialConnectionStatus: false,
                    theyConnectToYou: false,
                    onMessage: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationsPage(
                              isDarkMode: isDark,
                              onThemeToggle: () {},
                              initialTabIndex: 0),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Spacer for visual balance (tools are via FAB bottom-right)
            Expanded(child: Container()),
          ],
        ),
      ),
    );
  }

  // Helpers to safely map user fields from /api/users/all
  String _pickFullName(Map u) {
    final name = (u['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final fn = (u['firstName'] ?? u['first_name'] ?? '').toString().trim();
    final ln = (u['lastName'] ?? u['last_name'] ?? '').toString().trim();
    final both = [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
    if (both.isNotEmpty) return both;
    final username = _pickUsername(u);
    if (username.isNotEmpty) return username.replaceFirst('@', '');
    final email = (u['email'] ?? '').toString();
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String _pickUsername(Map u) {
    final un = (u['username'] ?? u['userName'] ?? '').toString().trim();
    if (un.isNotEmpty) return un.startsWith('@') ? un : '@$un';
    final email = (u['email'] ?? '').toString();
    if (email.contains('@')) return '@${email.split('@').first}';
    return '@user';
  }

  String _pickAvatar(Map u) {
    return (u['avatarUrl'] ??
            u['avatar_url'] ??
            u['imageUrl'] ??
            u['image_url'] ??
            '')
        .toString();
  }

  String _pickCover(Map u) {
    final cover = (u['coverUrl'] ?? u['cover_url'] ?? '').toString();
    if (cover.isNotEmpty) return cover;
    // fallback to avatar to avoid empty image blocks
    return _pickAvatar(u);
  }

  // ===========================
  // Mobile layout (unchanged)
  // ===========================
  Widget _buildHomeFeedMobile(
    BuildContext context,
    bool isDark,
    Color backgroundColor,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification) {
          // Hide reaction picker when scrolling starts
          ReactionPickerManager.hideReactions();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar + stories as a scrollable sliver
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(25),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row with search, title, and notifications
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchPage(),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.search,
                              color: Color(0xFF666666),
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'NEXUM',
                                style: GoogleFonts.inika(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          BadgeIcon(
                            icon: Icons.notifications_outlined,
                            badgeCount: _unreadCount,
                            iconColor: const Color(0xFF666666),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationPage(),
                                ),
                              );
                              await _loadUnreadCount();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Stories row
                    SizedBox(
                      height: 90,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _storyRings.length,
                          itemBuilder: (context, index) {
                            final ring = _storyRings[index];
                            final isMine = ring.userId == _currentUserId;

                            return Container(
                              width: 70,
                              margin: EdgeInsets.only(
                                right: index < _storyRings.length - 1 ? 16 : 0,
                              ),
                              child: story_widget.StoryRing(
                                imageUrl: ring.thumbnailUrl ?? ring.avatarUrl,
                                label: isMine
                                    ? 'Your Story'
                                    : (ring.name.isNotEmpty
                                        ? ring.name
                                        : (ring.username.startsWith('@')
                                            ? ring.username
                                            : '@${ring.username}')),
                                isMine: isMine,
                                isSeen: !ring.hasUnseen,

                                // Full ring AND plus icon follow the same conditions
                                onAddTap: isMine
                                    ? () {
                                        if (ring.storyCount > 0 &&
                                            _currentUserId != null) {
                                          MyStoriesBottomSheet.show(
                                            context,
                                            currentUserId: _currentUserId!,
                                            onAddStory: () {
                                              StoryTypePicker.show(
                                                context,
                                                onSelected: (type) async {
                                                  if (_useDesktopPopup(
                                                      context)) {
                                                    await StoryComposerPopup
                                                        .show(context,
                                                            type: type);
                                                  } else {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              _composerPage(
                                                                  type)),
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                          );
                                        } else {
                                          StoryTypePicker.show(
                                            context,
                                            onSelected: (type) async {
                                              if (_useDesktopPopup(context)) {
                                                await StoryComposerPopup.show(
                                                    context,
                                                    type: type);
                                              } else {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          _composerPage(type)),
                                                );
                                              }
                                            },
                                          );
                                        }
                                      }
                                    : null,
                                onTap: () async {
                                  if (isMine) {
                                    if (ring.storyCount > 0 &&
                                        _currentUserId != null) {
                                      MyStoriesBottomSheet.show(
                                        context,
                                        currentUserId: _currentUserId!,
                                        onAddStory: () {
                                          StoryTypePicker.show(
                                            context,
                                            onSelected: (type) async {
                                              if (_useDesktopPopup(context)) {
                                                await StoryComposerPopup.show(
                                                    context,
                                                    type: type);
                                              } else {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          _composerPage(type)),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      );
                                    } else {
                                      StoryTypePicker.show(
                                        context,
                                        onSelected: (type) async {
                                          if (_useDesktopPopup(context)) {
                                            await StoryComposerPopup.show(
                                                context,
                                                type: type);
                                          } else {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      _composerPage(type)),
                                            );
                                          }
                                        },
                                      );
                                    }
                                  } else {
                                    if (_useDesktopPopup(context)) {
                                      await StoryViewerPopup.show(
                                        context,
                                        rings: _storyRings
                                            .map((r) => {
                                                  'userId': r.userId,
                                                  'imageUrl': r.thumbnailUrl ??
                                                      r.avatarUrl,
                                                  'label': r.name,
                                                  'isMine': r.userId ==
                                                      _currentUserId,
                                                  'isSeen': !r.hasUnseen,
                                                })
                                            .toList(),
                                        initialRingIndex: index,
                                      );
                                    } else {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StoryViewerPage(
                                            rings: _storyRings
                                                .map((r) => {
                                                      'userId': r.userId,
                                                      'imageUrl':
                                                          r.thumbnailUrl ??
                                                              r.avatarUrl,
                                                      'label': r.name,
                                                      'isMine': r.userId ==
                                                          _currentUserId,
                                                      'isSeen': !r.hasUnseen,
                                                    })
                                                .toList(),
                                            initialRingIndex: index,
                                          ),
                                        ),
                                      );
                                    }
                                    await _loadData(); // refresh rings after viewing
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Feed as a sliver list so it scrolls together with the header
          SliverPadding(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return PostCard(
                  post: _posts[index],
                  onReactionChanged: _onReactionChanged,
                  onBookmarkToggle: _onBookmarkToggle,
                  onTap: _onPostTap,
                  onShare: _onShare,
                  onComment: _onComment,
                  onRepost: _onRepost,
                  isDarkMode: isDark,
                  currentUserId: _currentUserId,
                );
              }, childCount: _posts.length),
            ),
          ),
        ],
      ),
    );
  }

  // Map story compose type to its page
  Widget _composerPage(StoryComposeType type) {
    switch (type) {
      case StoryComposeType.text:
        return const TextStoryComposerPage();
      case StoryComposeType.image:
      case StoryComposeType.video:
      case StoryComposeType.mixed:
        return const MixedMediaStoryComposerPage();
    }
  }
}

// Simple top navigation item used in desktop header
class _TopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TopNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFBFAE01) : const Color(0xFF666666);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 14, color: color, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }
}
