import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Box schema version for migration tracking.
/// Increment when changing data structure.
const int kHiveBoxVersion = 2;
const String kHiveVersionKey = '_hive_box_version';

/// Size caps for in-memory caches (LRU eviction)
const int kMaxPostsCache = 500;
const int kMaxProfilesCache = 200;
const int kMaxConversationsCache = 100;
const int kMaxMessagesCache = 1000;
const int kMaxPodcastsCache = 200;
const int kMaxBooksCache = 200;
const int kMaxStoriesCache = 100;
const int kMaxMentorshipMessagesCache = 500;

/// Web-specific local store using Hive for instant reads.
/// Provides in-memory cache + Hive persistence for web platform.
/// 
/// Production hardening:
/// - Box versioning with safe migration
/// - Size caps with LRU eviction
/// - Graceful fallback on init failure
class WebLocalStore {
  static final WebLocalStore _instance = WebLocalStore._internal();
  factory WebLocalStore() => _instance;
  WebLocalStore._internal();

  bool _initialized = false;
  bool _initFailed = false;

  // Hive boxes
  Box<Map>? _postsBox;
  Box<Map>? _profilesBox;
  Box<Map>? _conversationsBox;
  Box<Map>? _messagesBox;
  Box<Map>? _podcastsBox;
  Box<Map>? _booksBox;
  Box<Map>? _storiesBox;
  Box<Map>? _mentorshipMessagesBox;
  Box<dynamic>? _metaBox;

  // In-memory caches for sync reads (with insertion order for LRU)
  final Map<String, Map<String, dynamic>> _postsCache = {};
  final Map<String, Map<String, dynamic>> _profilesCache = {};
  final Map<String, Map<String, dynamic>> _conversationsCache = {};
  final Map<String, Map<String, dynamic>> _messagesCache = {};
  final Map<String, Map<String, dynamic>> _podcastsCache = {};
  final Map<String, Map<String, dynamic>> _booksCache = {};
  final Map<String, Map<String, dynamic>> _storiesCache = {};
  final Map<String, Map<String, dynamic>> _mentorshipMessagesCache = {};

  bool get isAvailable => _initialized && !_initFailed;

  /// Initialize Hive and open all boxes
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();
      
      // Open meta box first for version tracking
      _metaBox = await _openBoxSafe<dynamic>('nexum_meta');
      
      // Check version and migrate if needed
      final needsMigration = await _checkBoxVersion();
      if (needsMigration) {
        await _performSafeMigration();
      }
      
      // Open all data boxes with validation
      _postsBox = await _openBoxSafe<Map>('posts_lite');
      _profilesBox = await _openBoxSafe<Map>('profiles_lite');
      _conversationsBox = await _openBoxSafe<Map>('conversations_lite');
      _messagesBox = await _openBoxSafe<Map>('messages_lite');
      _podcastsBox = await _openBoxSafe<Map>('podcasts_lite');
      _booksBox = await _openBoxSafe<Map>('books_lite');
      _storiesBox = await _openBoxSafe<Map>('stories_lite');
      _mentorshipMessagesBox = await _openBoxSafe<Map>('mentorship_messages_lite');

      // Load into memory for sync reads
      await _loadAllToMemory();
      
      // Record version after successful init
      await _recordBoxVersion();

      _initialized = true;
      _debugLog('✅ WebLocalStore initialized with ${_postsCache.length} posts, ${_conversationsCache.length} conversations');
    } catch (e) {
      _initFailed = true;
      _debugLog('❌ WebLocalStore init failed: $e');
      // Graceful fallback - app will use Firestore cache-first
    }
  }

  /// Open a box safely with error recovery
  Future<Box<T>?> _openBoxSafe<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (e) {
      _debugLog('⚠️ Failed to open box $name: $e, attempting recovery...');
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<T>(name);
      } catch (e2) {
        _debugLog('❌ Box recovery failed for $name: $e2');
        return null;
      }
    }
  }

  /// Check if box version migration is needed
  Future<bool> _checkBoxVersion() async {
    try {
      final storedVersion = _metaBox?.get(kHiveVersionKey) as int? ?? 0;
      return storedVersion != kHiveBoxVersion;
    } catch (e) {
      _debugLog('⚠️ Could not check box version: $e');
      return false;
    }
  }

  /// Record current box version
  Future<void> _recordBoxVersion() async {
    try {
      await _metaBox?.put(kHiveVersionKey, kHiveBoxVersion);
    } catch (e) {
      _debugLog('⚠️ Could not record box version: $e');
    }
  }

  /// Perform safe migration by clearing incompatible boxes
  Future<void> _performSafeMigration() async {
    _debugLog('🔄 Hive box migration needed, clearing old data...');
    try {
      final boxNames = [
        'posts_lite', 'profiles_lite', 'conversations_lite',
        'messages_lite', 'podcasts_lite', 'books_lite',
        'stories_lite', 'mentorship_messages_lite',
      ];
      for (final name in boxNames) {
        try {
          await Hive.deleteBoxFromDisk(name);
        } catch (e) {
          _debugLog('⚠️ Could not delete box $name: $e');
        }
      }
      _debugLog('✅ Hive migration complete');
    } catch (e) {
      _debugLog('❌ Hive migration failed: $e');
    }
  }

  /// Load all Hive data into memory caches with validation
  Future<void> _loadAllToMemory() async {
    _loadBoxToCache(_postsBox, _postsCache, kMaxPostsCache);
    _loadBoxToCache(_profilesBox, _profilesCache, kMaxProfilesCache);
    _loadBoxToCache(_conversationsBox, _conversationsCache, kMaxConversationsCache);
    _loadBoxToCache(_messagesBox, _messagesCache, kMaxMessagesCache);
    _loadBoxToCache(_podcastsBox, _podcastsCache, kMaxPodcastsCache);
    _loadBoxToCache(_booksBox, _booksCache, kMaxBooksCache);
    _loadBoxToCache(_storiesBox, _storiesCache, kMaxStoriesCache);
    _loadBoxToCache(_mentorshipMessagesBox, _mentorshipMessagesCache, kMaxMentorshipMessagesCache);
  }

  void _loadBoxToCache(Box<Map>? box, Map<String, Map<String, dynamic>> cache, int maxSize) {
    if (box == null) return;
    cache.clear();
    
    final keys = box.keys.toList();
    // Load most recent items up to maxSize
    final startIndex = keys.length > maxSize ? keys.length - maxSize : 0;
    
    for (int i = startIndex; i < keys.length; i++) {
      final key = keys[i];
      try {
        final value = box.get(key);
        if (value != null && _isValidPayload(value)) {
          cache[key.toString()] = Map<String, dynamic>.from(value);
        }
      } catch (e) {
        _debugLog('⚠️ Skipping invalid entry $key: $e');
      }
    }
  }

  /// Validate payload shape (must have 'id' field)
  bool _isValidPayload(Map<dynamic, dynamic> data) {
    return data.containsKey('id') && data['id'] != null;
  }

  /// Enforce size cap with LRU eviction
  void _enforceSizeCap(Map<String, Map<String, dynamic>> cache, int maxSize) {
    if (cache.length <= maxSize) return;
    
    final keysToRemove = cache.keys.take(cache.length - maxSize).toList();
    for (final key in keysToRemove) {
      cache.remove(key);
    }
  }

  // ============================================
  // POSTS
  // ============================================

  /// Get posts synchronously from memory cache
  List<Map<String, dynamic>> getPostsSync({int limit = 20, String? communityId}) {
    if (!isAvailable) return [];

    var posts = _postsCache.values.toList();
    
    // Filter by community if specified
    if (communityId != null) {
      posts = posts.where((p) => p['communityId'] == communityId).toList();
    }

    // Sort by createdAt descending
    posts.sort((a, b) {
      final aTime = _parseDateTime(a['createdAt']);
      final bTime = _parseDateTime(b['createdAt']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return posts.take(limit).toList();
  }

  /// Put a post (async write to Hive, sync write to memory)
  Future<void> putPost(String id, Map<String, dynamic> data) async {
    if (!isAvailable) return;
    _postsCache[id] = data;
    _enforceSizeCap(_postsCache, kMaxPostsCache);
    try {
      await _postsBox?.put(id, data);
    } catch (e) {
      _debugLog('⚠️ Failed to persist post $id: $e');
    }
  }

  /// Put multiple posts
  Future<void> putPosts(List<Map<String, dynamic>> posts) async {
    if (!isAvailable) return;
    for (final post in posts) {
      final id = post['id'] as String?;
      if (id != null) {
        _postsCache[id] = post;
        try {
          await _postsBox?.put(id, post);
        } catch (e) {
          _debugLog('⚠️ Failed to persist post $id: $e');
        }
      }
    }
    _enforceSizeCap(_postsCache, kMaxPostsCache);
  }

  // ============================================
  // PROFILES
  // ============================================

  Map<String, dynamic>? getProfileSync(String uid) {
    if (!isAvailable) return null;
    return _profilesCache[uid];
  }

  Future<void> putProfile(String uid, Map<String, dynamic> data) async {
    if (!isAvailable) return;
    _profilesCache[uid] = data;
    await _profilesBox?.put(uid, data);
  }

  // ============================================
  // CONVERSATIONS
  // ============================================

  List<Map<String, dynamic>> getConversationsSync({int limit = 50}) {
    if (!isAvailable) return [];

    var convs = _conversationsCache.values.toList();

    // Sort by lastMessageAt descending
    convs.sort((a, b) {
      final aTime = _parseDateTime(a['lastMessageAt']);
      final bTime = _parseDateTime(b['lastMessageAt']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return convs.take(limit).toList();
  }

  Future<void> putConversation(String id, Map<String, dynamic> data) async {
    if (!isAvailable) return;
    _conversationsCache[id] = data;
    await _conversationsBox?.put(id, data);
  }

  Future<void> putConversations(List<Map<String, dynamic>> convs) async {
    if (!isAvailable) return;
    for (final conv in convs) {
      final id = conv['id'] as String?;
      if (id != null) {
        _conversationsCache[id] = conv;
        await _conversationsBox?.put(id, conv);
      }
    }
  }

  // ============================================
  // MESSAGES
  // ============================================

  List<Map<String, dynamic>> getMessagesSync(String conversationId, {int limit = 50}) {
    if (!isAvailable) return [];

    var msgs = _messagesCache.values
        .where((m) => m['conversationId'] == conversationId)
        .toList();

    // Sort by createdAt descending
    msgs.sort((a, b) {
      final aTime = _parseDateTime(a['createdAt']);
      final bTime = _parseDateTime(b['createdAt']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return msgs.take(limit).toList();
  }

  Future<void> putMessage(String id, Map<String, dynamic> data) async {
    if (!isAvailable) return;
    _messagesCache[id] = data;
    await _messagesBox?.put(id, data);
  }

  Future<void> putMessages(List<Map<String, dynamic>> msgs) async {
    if (!isAvailable) return;
    for (final msg in msgs) {
      final id = msg['id'] as String?;
      if (id != null) {
        _messagesCache[id] = msg;
        await _messagesBox?.put(id, msg);
      }
    }
  }

  // ============================================
  // PODCASTS
  // ============================================

  List<Map<String, dynamic>> getPodcastsSync({int limit = 50, String? category}) {
    if (!isAvailable) return [];

    var podcasts = _podcastsCache.values.toList();

    if (category != null) {
      podcasts = podcasts.where((p) => p['category'] == category).toList();
    }

    // Sort by createdAt descending
    podcasts.sort((a, b) {
      final aTime = _parseDateTime(a['createdAt']);
      final bTime = _parseDateTime(b['createdAt']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return podcasts.take(limit).toList();
  }

  Future<void> putPodcasts(List<Map<String, dynamic>> podcasts) async {
    if (!isAvailable) return;
    for (final podcast in podcasts) {
      final id = podcast['id'] as String?;
      if (id != null) {
        _podcastsCache[id] = podcast;
        await _podcastsBox?.put(id, podcast);
      }
    }
  }

  // ============================================
  // BOOKS
  // ============================================

  List<Map<String, dynamic>> getBooksSync({int limit = 50, String? category}) {
    if (!isAvailable) return [];

    var books = _booksCache.values.toList();

    if (category != null) {
      books = books.where((b) => b['category'] == category).toList();
    }

    // Sort by createdAt descending
    books.sort((a, b) {
      final aTime = _parseDateTime(a['createdAt']);
      final bTime = _parseDateTime(b['createdAt']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return books.take(limit).toList();
  }

  Future<void> putBooks(List<Map<String, dynamic>> books) async {
    if (!isAvailable) return;
    for (final book in books) {
      final id = book['id'] as String?;
      if (id != null) {
        _booksCache[id] = book;
        await _booksBox?.put(id, book);
      }
    }
  }

  // ============================================
  // STORIES
  // ============================================

  List<Map<String, dynamic>> getStoriesSync({int limit = 50}) {
    if (!isAvailable) return [];

    var stories = _storiesCache.values.toList();

    // Sort by createdAt descending
    stories.sort((a, b) {
      final aTime = _parseDateTime(a['createdAt']);
      final bTime = _parseDateTime(b['createdAt']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return stories.take(limit).toList();
  }

  Future<void> putStories(List<Map<String, dynamic>> stories) async {
    if (!isAvailable) return;
    for (final story in stories) {
      final id = story['id'] as String?;
      if (id != null) {
        _storiesCache[id] = story;
        await _storiesBox?.put(id, story);
      }
    }
  }

  // ============================================
  // MENTORSHIP MESSAGES
  // ============================================

  List<Map<String, dynamic>> getMentorshipMessagesSync({required String conversationId, int limit = 50}) {
    if (!isAvailable) return [];

    var msgs = _mentorshipMessagesCache.values
        .where((m) => m['conversationId'] == conversationId)
        .toList();

    // Sort by createdAt descending
    msgs.sort((a, b) {
      final aTime = _parseDateTime(a['createdAt']);
      final bTime = _parseDateTime(b['createdAt']);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return msgs.take(limit).toList();
  }

  Future<void> putMentorshipMessages(List<Map<String, dynamic>> msgs) async {
    if (!isAvailable) return;
    for (final msg in msgs) {
      final id = msg['id'] as String?;
      if (id != null) {
        _mentorshipMessagesCache[id] = msg;
        await _mentorshipMessagesBox?.put(id, msg);
      }
    }
  }

  // ============================================
  // UTILITIES
  // ============================================

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Get stats for debugging
  Map<String, int> getStats() {
    return {
      'posts': _postsCache.length,
      'profiles': _profilesCache.length,
      'conversations': _conversationsCache.length,
      'messages': _messagesCache.length,
      'podcasts': _podcastsCache.length,
      'books': _booksCache.length,
      'stories': _storiesCache.length,
      'mentorshipMessages': _mentorshipMessagesCache.length,
    };
  }

  /// Clear all data
  Future<void> clearAll() async {
    _postsCache.clear();
    _profilesCache.clear();
    _conversationsCache.clear();
    _messagesCache.clear();
    _podcastsCache.clear();
    _booksCache.clear();
    _storiesCache.clear();
    _mentorshipMessagesCache.clear();

    await _postsBox?.clear();
    await _profilesBox?.clear();
    await _conversationsBox?.clear();
    await _messagesBox?.clear();
    await _podcastsBox?.clear();
    await _booksBox?.clear();
    await _storiesBox?.clear();
    await _mentorshipMessagesBox?.clear();

    _debugLog('🗑️ WebLocalStore cleared');
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[WebLocalStore] $message');
    }
  }
}

/// Global accessor for WebLocalStore
final webLocalStore = WebLocalStore();
