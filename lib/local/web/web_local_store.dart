import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Web-specific local store using Hive for instant reads.
/// Provides in-memory cache + Hive persistence for web platform.
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

  // In-memory caches for sync reads
  final Map<String, Map<String, dynamic>> _postsCache = {};
  final Map<String, Map<String, dynamic>> _profilesCache = {};
  final Map<String, Map<String, dynamic>> _conversationsCache = {};
  final Map<String, Map<String, dynamic>> _messagesCache = {};
  final Map<String, Map<String, dynamic>> _podcastsCache = {};
  final Map<String, Map<String, dynamic>> _booksCache = {};

  bool get isAvailable => _initialized && !_initFailed;

  /// Initialize Hive and open all boxes
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();
      
      _postsBox = await Hive.openBox<Map>('posts_lite');
      _profilesBox = await Hive.openBox<Map>('profiles_lite');
      _conversationsBox = await Hive.openBox<Map>('conversations_lite');
      _messagesBox = await Hive.openBox<Map>('messages_lite');
      _podcastsBox = await Hive.openBox<Map>('podcasts_lite');
      _booksBox = await Hive.openBox<Map>('books_lite');

      // Load into memory for sync reads
      await _loadAllToMemory();

      _initialized = true;
      _debugLog('✅ WebLocalStore initialized with ${_postsCache.length} posts, ${_conversationsCache.length} conversations');
    } catch (e) {
      _initFailed = true;
      _debugLog('❌ WebLocalStore init failed: $e');
    }
  }

  /// Load all Hive data into memory caches
  Future<void> _loadAllToMemory() async {
    _loadBoxToCache(_postsBox, _postsCache);
    _loadBoxToCache(_profilesBox, _profilesCache);
    _loadBoxToCache(_conversationsBox, _conversationsCache);
    _loadBoxToCache(_messagesBox, _messagesCache);
    _loadBoxToCache(_podcastsBox, _podcastsCache);
    _loadBoxToCache(_booksBox, _booksCache);
  }

  void _loadBoxToCache(Box<Map>? box, Map<String, Map<String, dynamic>> cache) {
    if (box == null) return;
    cache.clear();
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        cache[key.toString()] = Map<String, dynamic>.from(value);
      }
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
    await _postsBox?.put(id, data);
  }

  /// Put multiple posts
  Future<void> putPosts(List<Map<String, dynamic>> posts) async {
    if (!isAvailable) return;
    for (final post in posts) {
      final id = post['id'] as String?;
      if (id != null) {
        _postsCache[id] = post;
        await _postsBox?.put(id, post);
      }
    }
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

    await _postsBox?.clear();
    await _profilesBox?.clear();
    await _conversationsBox?.clear();
    await _messagesBox?.clear();
    await _podcastsBox?.clear();
    await _booksBox?.clear();

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
