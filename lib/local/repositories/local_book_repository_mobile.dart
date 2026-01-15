import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/book_lite.dart';
import '../sync/sync_cursor_store.dart';
import '../web/web_local_store.dart';

export '../models/book_lite.dart';

/// Local-first repository for Books.
class LocalBookRepository {
  static final LocalBookRepository _instance = LocalBookRepository._internal();
  factory LocalBookRepository() => _instance;
  LocalBookRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const String _module = 'books';
  static const int _syncBatchSize = 50;

  /// Watch local books (instant UI binding)
  Stream<List<BookLite>> watchLocal({int limit = 50, String? category}) {
    final db = isarDB.instance;
    if (db == null) return Stream.value([]);

    if (category != null) {
      return db.bookLites
          .filter()
          .categoryEqualTo(category)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return db.bookLites
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local books synchronously
  /// Uses Isar on mobile, Hive on web
  List<BookLite> getLocalSync({int limit = 50, String? category}) {
    // WEB: Use Hive via WebLocalStore
    if (isHiveSupported && webLocalStore.isAvailable) {
      final maps = webLocalStore.getBooksSync(limit: limit, category: category);
      if (maps.isNotEmpty) {
        _debugLog('🌐 [Web] Loaded ${maps.length} books from Hive');
        return maps.map((m) => BookLite.fromMap(m)).toList();
      }
    }
    
    // MOBILE: Use Isar
    final db = isarDB.instance;
    if (db == null) return [];

    if (category != null) {
      return db.bookLites
          .filter()
          .categoryEqualTo(category)
          .sortByCreatedAtDesc()
          .limit(limit)
          .findAllSync();
    }

    return db.bookLites
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Get a single book by ID
  BookLite? getBookSync(String bookId) {
    final db = isarDB.instance;
    if (db == null) return null;
    return db.bookLites.filter().idEqualTo(bookId).findFirstSync();
  }

  /// Sync remote books (delta sync)
  Future<void> syncRemote() async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    await _cursorStore.init();

    try {
      final lastSync = _cursorStore.getLastSyncTime(_module);
      _debugLog('🔄 Syncing books since: $lastSync');

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;

      if (lastSync != null) {
        snapshot = await _db.collection('books')
            .where('updatedAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('updatedAt')
            .limit(_syncBatchSize)
            .get();
      } else {
        snapshot = await _db.collection('books')
            .where('isPublished', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Books already up to date');
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
        await _cursorStore.setLastSyncTime(_module, latestUpdate);
      }

      _debugLog('✅ Synced ${books.length} books');
    } catch (e) {
      _debugLog('❌ Book sync failed: $e');
    }
  }

  /// Get book count
  int getLocalCount() {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.bookLites.countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalBookRepo] $message');
    }
  }
}
