import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/book_lite_web.dart';

export '../models/book_lite_web.dart';

/// Web-only local repository for Books.
class LocalBookRepository {
  static final LocalBookRepository _instance = LocalBookRepository._internal();
  factory LocalBookRepository() => _instance;
  LocalBookRepository._internal();

  List<BookLite> getLocalSync({int limit = 50, String? category}) {
    if (!webLocalStore.isAvailable) return [];
    final maps = webLocalStore.getBooksSync(limit: limit, category: category);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} books from Hive');
      return maps.map((m) => BookLite.fromMap(m)).toList();
    }
    return [];
  }

  Future<void> syncRemote() async {}
}
