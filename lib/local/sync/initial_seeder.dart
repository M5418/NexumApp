import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../isar_db.dart';
import '../local_store.dart';
import '../models/post_lite.dart';
import '../models/profile_lite.dart';
import '../models/conversation_lite.dart';
import '../models/podcast_lite.dart';
import '../models/book_lite.dart';
import 'sync_cursor_store.dart';

/// Seeds Isar database from existing Firestore data on first run.
/// Runs AFTER first frame to avoid blocking UI.
class InitialSeeder {
  static final InitialSeeder _instance = InitialSeeder._internal();
  factory InitialSeeder() => _instance;
  InitialSeeder._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();
  
  bool _isSeeding = false;

  /// Seed limits (fetch newest N items first)
  static const int _postsLimit = 200;
  static const int _conversationsLimit = 100;
  static const int _podcastsLimit = 100;
  static const int _booksLimit = 100;

  /// Run initial seeding for all modules (non-blocking)
  Future<void> seedAllIfNeeded() async {
    if (!isIsarSupported) {
      _debugLog('⏭️ Skipping seed - Isar not supported on this platform');
      return;
    }

    if (_isSeeding) {
      _debugLog('⏭️ Seeding already in progress');
      return;
    }

    _isSeeding = true;
    _debugLog('🌱 Starting initial seed check...');

    try {
      await _cursorStore.init();
      
      // Seed each module if not already seeded
      await Future.wait([
        _seedPostsIfNeeded(),
        _seedProfileIfNeeded(),
        _seedConversationsIfNeeded(),
        _seedPodcastsIfNeeded(),
        _seedBooksIfNeeded(),
      ]);

      _debugLog('✅ Initial seeding complete');
    } catch (e) {
      _debugLog('❌ Initial seeding failed: $e');
    } finally {
      _isSeeding = false;
    }
  }

  Future<void> _seedPostsIfNeeded() async {
    if (_cursorStore.isSeeded('posts')) {
      _debugLog('⏭️ Posts already seeded');
      return;
    }

    final db = isarDB.instance;
    if (db == null) return;

    try {
      _debugLog('🌱 Seeding posts from Firestore...');
      
      // Fetch newest posts, ordered by createdAt (backward compatible)
      final snapshot = await _db.collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_postsLimit)
          .get();

      if (snapshot.docs.isEmpty) {
        _debugLog('📭 No posts to seed');
        await _cursorStore.markSeeded('posts');
        return;
      }

      // Convert to PostLite and batch write
      final posts = <PostLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final post = PostLite.fromFirestore(doc.id, data);
        posts.add(post);

        // Track latest timestamp for cursor
        final updatedAt = post.updatedAt ?? post.createdAt;
        if (latestUpdate == null || updatedAt.isAfter(latestUpdate)) {
          latestUpdate = updatedAt;
        }
      }

      // Batch write to Isar
      await db.writeTxn(() async {
        await db.postLites.putAll(posts);
      });

      // Update cursor and mark seeded
      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime('posts', latestUpdate);
      }
      await _cursorStore.markSeeded('posts');

      _debugLog('✅ Seeded ${posts.length} posts');
    } catch (e) {
      _debugLog('❌ Failed to seed posts: $e');
    }
  }

  Future<void> _seedProfileIfNeeded() async {
    if (_cursorStore.isSeeded('profile')) {
      _debugLog('⏭️ Profile already seeded');
      return;
    }

    final db = isarDB.instance;
    if (db == null) return;

    final userId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _debugLog('⏭️ No user logged in, skipping profile seed');
      return;
    }

    try {
      _debugLog('🌱 Seeding current user profile...');

      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) {
        _debugLog('📭 User profile not found');
        await _cursorStore.markSeeded('profile');
        return;
      }

      final data = doc.data();
      if (data == null) {
        await _cursorStore.markSeeded('profile');
        return;
      }

      final profile = ProfileLite.fromFirestore(doc.id, data);

      await db.writeTxn(() async {
        await db.profileLites.put(profile);
      });

      await _cursorStore.markSeeded('profile');
      _debugLog('✅ Seeded user profile');
    } catch (e) {
      _debugLog('❌ Failed to seed profile: $e');
    }
  }

  Future<void> _seedConversationsIfNeeded() async {
    if (_cursorStore.isSeeded('conversations')) {
      _debugLog('⏭️ Conversations already seeded');
      return;
    }

    final db = isarDB.instance;
    if (db == null) return;

    final userId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _debugLog('⏭️ No user logged in, skipping conversations seed');
      return;
    }

    try {
      _debugLog('🌱 Seeding conversations from Firestore...');

      // Query conversations where user is a member
      final snapshot = await _db.collection('conversations')
          .where('memberIds', arrayContains: userId)
          .orderBy('lastMessageAt', descending: true)
          .limit(_conversationsLimit)
          .get();

      if (snapshot.docs.isEmpty) {
        _debugLog('📭 No conversations to seed');
        await _cursorStore.markSeeded('conversations');
        return;
      }

      final conversations = <ConversationLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final conv = ConversationLite.fromFirestore(doc.id, data);
        conversations.add(conv);

        final updatedAt = conv.updatedAt ?? conv.lastMessageAt;
        if (updatedAt != null && (latestUpdate == null || updatedAt.isAfter(latestUpdate))) {
          latestUpdate = updatedAt;
        }
      }

      await db.writeTxn(() async {
        await db.conversationLites.putAll(conversations);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime('conversations', latestUpdate);
      }
      await _cursorStore.markSeeded('conversations');

      _debugLog('✅ Seeded ${conversations.length} conversations');
    } catch (e) {
      _debugLog('❌ Failed to seed conversations: $e');
    }
  }

  Future<void> _seedPodcastsIfNeeded() async {
    if (_cursorStore.isSeeded('podcasts')) {
      _debugLog('⏭️ Podcasts already seeded');
      return;
    }

    final db = isarDB.instance;
    if (db == null) return;

    try {
      _debugLog('🌱 Seeding podcasts from Firestore...');

      final snapshot = await _db.collection('podcasts')
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_podcastsLimit)
          .get();

      if (snapshot.docs.isEmpty) {
        _debugLog('📭 No podcasts to seed');
        await _cursorStore.markSeeded('podcasts');
        return;
      }

      final podcasts = <PodcastLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final podcast = PodcastLite.fromFirestore(doc.id, data);
        podcasts.add(podcast);

        final updatedAt = podcast.updatedAt ?? podcast.createdAt;
        if (updatedAt != null && (latestUpdate == null || updatedAt.isAfter(latestUpdate))) {
          latestUpdate = updatedAt;
        }
      }

      await db.writeTxn(() async {
        await db.podcastLites.putAll(podcasts);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime('podcasts', latestUpdate);
      }
      await _cursorStore.markSeeded('podcasts');

      _debugLog('✅ Seeded ${podcasts.length} podcasts');
    } catch (e) {
      _debugLog('❌ Failed to seed podcasts: $e');
    }
  }

  Future<void> _seedBooksIfNeeded() async {
    if (_cursorStore.isSeeded('books')) {
      _debugLog('⏭️ Books already seeded');
      return;
    }

    final db = isarDB.instance;
    if (db == null) return;

    try {
      _debugLog('🌱 Seeding books from Firestore...');

      final snapshot = await _db.collection('books')
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_booksLimit)
          .get();

      if (snapshot.docs.isEmpty) {
        _debugLog('📭 No books to seed');
        await _cursorStore.markSeeded('books');
        return;
      }

      final books = <BookLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final book = BookLite.fromFirestore(doc.id, data);
        books.add(book);

        final updatedAt = book.updatedAt ?? book.createdAt;
        if (updatedAt != null && (latestUpdate == null || updatedAt.isAfter(latestUpdate))) {
          latestUpdate = updatedAt;
        }
      }

      await db.writeTxn(() async {
        await db.bookLites.putAll(books);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime('books', latestUpdate);
      }
      await _cursorStore.markSeeded('books');

      _debugLog('✅ Seeded ${books.length} books');
    } catch (e) {
      _debugLog('❌ Failed to seed books: $e');
    }
  }

  /// Force re-seed all modules (for debugging/reset)
  Future<void> forceReseedAll() async {
    await _cursorStore.clearAll();
    await seedAllIfNeeded();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[InitialSeeder] $message');
    }
  }
}
