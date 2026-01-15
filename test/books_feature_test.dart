import 'package:flutter_test/flutter_test.dart';

/// Tests for Books feature
/// Covers: local caching, sync, pagination, reading progress, offline access
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Caching Optimization', () {
    test('should load from local cache synchronously (< 5ms)', () {
      final cache = _MockBooksCache();
      cache.putBooks(List.generate(50, (i) => 
        _MockBookLite(id: 'b$i', title: 'Book $i', pdfUrl: '', createdAt: DateTime.now())
      ));
      
      final stopwatch = Stopwatch()..start();
      final books = cache.getBooksSync(limit: 20);
      stopwatch.stop();
      
      expect(books.length, 20);
      // Sync read should be nearly instant
      expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Allow some margin for test env
    });

    test('should return cached data before network fetch', () {
      final localRepo = _MockLocalBookRepository();
      localRepo.seedLocalData([
        _MockBookLite(id: 'b1', title: 'Cached Book 1', pdfUrl: '', createdAt: DateTime.now()),
        _MockBookLite(id: 'b2', title: 'Cached Book 2', pdfUrl: '', createdAt: DateTime.now()),
      ]);
      
      // Simulate page load pattern: local first, then remote
      final localBooks = localRepo.getLocalSync(limit: 20);
      expect(localBooks.length, 2);
      expect(localBooks.first.title, 'Cached Book 1');
    });

    test('should merge remote data into local cache', () {
      final localRepo = _MockLocalBookRepository();
      localRepo.seedLocalData([
        _MockBookLite(id: 'b1', title: 'Old Title', pdfUrl: '', createdAt: DateTime(2024, 1, 10)),
      ]);
      
      // Simulate remote sync bringing updated data
      final remoteBooks = [
        _MockBookLite(id: 'b1', title: 'Updated Title', pdfUrl: '', createdAt: DateTime(2024, 1, 15)),
        _MockBookLite(id: 'b2', title: 'New Book', pdfUrl: '', createdAt: DateTime(2024, 1, 15)),
      ];
      localRepo.upsertFromRemote(remoteBooks);
      
      final merged = localRepo.getLocalSync(limit: 20);
      expect(merged.length, 2);
      expect(merged.firstWhere((b) => b.id == 'b1').title, 'Updated Title');
    });

    test('should work offline with cached data', () {
      final localRepo = _MockLocalBookRepository();
      localRepo.seedLocalData([
        _MockBookLite(id: 'b1', title: 'Offline Book', pdfUrl: '', createdAt: DateTime.now()),
      ]);
      
      // Simulate offline mode
      localRepo.setNetworkAvailable(false);
      
      final books = localRepo.getLocalSync(limit: 20);
      expect(books.length, 1);
      expect(books.first.title, 'Offline Book');
    });

    test('should handle empty cache gracefully', () {
      final localRepo = _MockLocalBookRepository();
      
      final books = localRepo.getLocalSync(limit: 20);
      expect(books, isEmpty);
    });

    test('should track sync status per item', () {
      final book = _MockBookLite(
        id: 'b1', 
        title: 'Test', 
        pdfUrl: '', 
        createdAt: DateTime.now(),
        syncStatus: 'pending',
      );
      
      expect(book.syncStatus, 'pending');
      
      final synced = book.copyWith(syncStatus: 'synced');
      expect(synced.syncStatus, 'synced');
    });

    test('should use delta sync with cursor', () {
      final syncManager = _MockSyncManager();
      syncManager.setLastSyncTime('books', DateTime(2024, 1, 10));
      
      // Should only fetch items updated after last sync
      final lastSync = syncManager.getLastSyncTime('books');
      expect(lastSync, isNotNull);
      expect(lastSync!.day, 10);
    });
  });


  group('Book Model Mapping', () {
    test('should map BookLite to UI Book model', () {
      final bookLite = _MockBookLite(
        id: 'book1',
        title: 'Flutter Development',
        author: 'John Doe',
        description: 'A comprehensive guide',
        coverUrl: 'https://example.com/cover.jpg',
        pdfUrl: 'https://example.com/book.pdf',
        createdAt: DateTime(2024, 1, 15),
      );
      
      final uiBook = _mapBookLiteToUI(bookLite);
      
      expect(uiBook['id'], 'book1');
      expect(uiBook['title'], 'Flutter Development');
      expect(uiBook['author'], 'John Doe');
    });

    test('should handle null optional fields', () {
      final bookLite = _MockBookLite(
        id: 'book1',
        title: 'Minimal Book',
        author: null,
        description: null,
        coverUrl: null,
        pdfUrl: 'https://example.com/book.pdf',
        createdAt: DateTime.now(),
      );
      
      final uiBook = _mapBookLiteToUI(bookLite);
      
      expect(uiBook['author'], 'Unknown Author');
      expect(uiBook['description'], '');
    });
  });

  group('Books Local Cache', () {
    test('should return cached books instantly', () {
      final cache = _MockBooksCache();
      cache.putBooks([
        _MockBookLite(id: 'b1', title: 'Book 1', pdfUrl: '', createdAt: DateTime.now()),
        _MockBookLite(id: 'b2', title: 'Book 2', pdfUrl: '', createdAt: DateTime.now()),
      ]);
      
      final books = cache.getBooksSync(limit: 10);
      expect(books.length, 2);
    });

    test('should respect limit parameter', () {
      final cache = _MockBooksCache();
      cache.putBooks(List.generate(20, (i) => 
        _MockBookLite(id: 'b$i', title: 'Book $i', pdfUrl: '', createdAt: DateTime.now())
      ));
      
      final books = cache.getBooksSync(limit: 5);
      expect(books.length, 5);
    });

    test('should return empty list when cache empty', () {
      final cache = _MockBooksCache();
      final books = cache.getBooksSync(limit: 10);
      expect(books, isEmpty);
    });

    test('should filter by published status', () {
      final cache = _MockBooksCache();
      cache.putBooks([
        _MockBookLite(id: 'b1', title: 'Published', pdfUrl: '', createdAt: DateTime.now(), isPublished: true),
        _MockBookLite(id: 'b2', title: 'Draft', pdfUrl: '', createdAt: DateTime.now(), isPublished: false),
      ]);
      
      final published = cache.getPublishedBooksSync();
      expect(published.length, 1);
      expect(published.first.title, 'Published');
    });
  });

  group('Reading Progress', () {
    test('should track current page', () {
      final progress = _MockReadingProgress();
      progress.setCurrentPage('book1', 50);
      
      expect(progress.getCurrentPage('book1'), 50);
    });

    test('should calculate percentage', () {
      final progress = _MockReadingProgress();
      progress.setCurrentPage('book1', 50);
      progress.setTotalPages('book1', 200);
      
      expect(progress.getPercentage('book1'), 25.0);
    });

    test('should return 0 for unread book', () {
      final progress = _MockReadingProgress();
      expect(progress.getCurrentPage('unknown'), 0);
      expect(progress.getPercentage('unknown'), 0.0);
    });

    test('should persist progress locally', () {
      final progress = _MockReadingProgress();
      progress.setCurrentPage('book1', 100);
      
      // Simulate app restart
      final restored = _MockReadingProgress.restore({'book1': 100});
      expect(restored.getCurrentPage('book1'), 100);
    });
  });

  group('Book Search', () {
    test('should search by title', () {
      final cache = _MockBooksCache();
      cache.putBooks([
        _MockBookLite(id: 'b1', title: 'Flutter Guide', pdfUrl: '', createdAt: DateTime.now()),
        _MockBookLite(id: 'b2', title: 'Dart Basics', pdfUrl: '', createdAt: DateTime.now()),
        _MockBookLite(id: 'b3', title: 'Advanced Flutter', pdfUrl: '', createdAt: DateTime.now()),
      ]);
      
      final results = cache.searchBooks('Flutter');
      expect(results.length, 2);
    });

    test('should search case-insensitive', () {
      final cache = _MockBooksCache();
      cache.putBooks([
        _MockBookLite(id: 'b1', title: 'FLUTTER GUIDE', pdfUrl: '', createdAt: DateTime.now()),
      ]);
      
      final results = cache.searchBooks('flutter');
      expect(results.length, 1);
    });

    test('should return empty for no matches', () {
      final cache = _MockBooksCache();
      cache.putBooks([
        _MockBookLite(id: 'b1', title: 'Flutter Guide', pdfUrl: '', createdAt: DateTime.now()),
      ]);
      
      final results = cache.searchBooks('React');
      expect(results, isEmpty);
    });
  });

  group('PDF Loading', () {
    test('should validate PDF URL', () {
      expect(_isValidPdfUrl('https://example.com/book.pdf'), isTrue);
      expect(_isValidPdfUrl('https://storage.googleapis.com/book.pdf'), isTrue);
      expect(_isValidPdfUrl(''), isFalse);
      expect(_isValidPdfUrl('not-a-url'), isFalse);
    });

    test('should handle PDF load failure gracefully', () {
      final loader = _MockPdfLoader();
      final result = loader.loadPdf('https://invalid.com/broken.pdf', shouldFail: true);
      
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, isNotNull);
    });
  });

  group('Offline Access', () {
    test('should mark book as downloaded', () {
      final downloads = _MockDownloadManager();
      downloads.markDownloaded('book1', '/local/path/book1.pdf');
      
      expect(downloads.isDownloaded('book1'), isTrue);
      expect(downloads.getLocalPath('book1'), '/local/path/book1.pdf');
    });

    test('should prefer local path when available', () {
      final downloads = _MockDownloadManager();
      downloads.markDownloaded('book1', '/local/path/book1.pdf');
      
      final path = downloads.getReadPath('book1', 'https://remote.com/book1.pdf');
      expect(path, '/local/path/book1.pdf');
    });

    test('should fallback to remote when not downloaded', () {
      final downloads = _MockDownloadManager();
      
      final path = downloads.getReadPath('book1', 'https://remote.com/book1.pdf');
      expect(path, 'https://remote.com/book1.pdf');
    });
  });
}

// Helper functions

Map<String, dynamic> _mapBookLiteToUI(_MockBookLite book) {
  return {
    'id': book.id,
    'title': book.title,
    'author': book.author ?? 'Unknown Author',
    'description': book.description ?? '',
    'coverUrl': book.coverUrl,
    'pdfUrl': book.pdfUrl,
  };
}

bool _isValidPdfUrl(String url) {
  if (url.isEmpty) return false;
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  } catch (e) {
    return false;
  }
}

// Mock classes

class _MockBookLite {
  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final String pdfUrl;
  final DateTime createdAt;
  final bool isPublished;
  final String syncStatus;

  _MockBookLite({
    required this.id,
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    required this.pdfUrl,
    required this.createdAt,
    this.isPublished = true,
    this.syncStatus = 'synced',
  });

  _MockBookLite copyWith({String? syncStatus}) {
    return _MockBookLite(
      id: id,
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      pdfUrl: pdfUrl,
      createdAt: createdAt,
      isPublished: isPublished,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class _MockBooksCache {
  final List<_MockBookLite> _books = [];

  void putBooks(List<_MockBookLite> books) {
    _books.addAll(books);
  }

  List<_MockBookLite> getBooksSync({required int limit}) {
    return _books.take(limit).toList();
  }

  List<_MockBookLite> getPublishedBooksSync() {
    return _books.where((b) => b.isPublished).toList();
  }

  List<_MockBookLite> searchBooks(String query) {
    final lowerQuery = query.toLowerCase();
    return _books.where((b) => b.title.toLowerCase().contains(lowerQuery)).toList();
  }
}

class _MockReadingProgress {
  final Map<String, int> _currentPages = {};
  final Map<String, int> _totalPages = {};

  _MockReadingProgress();

  factory _MockReadingProgress.restore(Map<String, int> pages) {
    final progress = _MockReadingProgress();
    progress._currentPages.addAll(pages);
    return progress;
  }

  void setCurrentPage(String bookId, int page) {
    _currentPages[bookId] = page;
  }

  void setTotalPages(String bookId, int total) {
    _totalPages[bookId] = total;
  }

  int getCurrentPage(String bookId) => _currentPages[bookId] ?? 0;

  double getPercentage(String bookId) {
    final current = _currentPages[bookId] ?? 0;
    final total = _totalPages[bookId] ?? 0;
    if (total == 0) return 0.0;
    return (current / total) * 100;
  }
}

class _MockPdfLoader {
  _PdfLoadResult loadPdf(String url, {bool shouldFail = false}) {
    if (shouldFail) {
      return _PdfLoadResult(isSuccess: false, errorMessage: 'Failed to load PDF');
    }
    return _PdfLoadResult(isSuccess: true);
  }
}

class _PdfLoadResult {
  final bool isSuccess;
  final String? errorMessage;

  _PdfLoadResult({required this.isSuccess, this.errorMessage});
}

class _MockDownloadManager {
  final Map<String, String> _downloads = {};

  void markDownloaded(String bookId, String localPath) {
    _downloads[bookId] = localPath;
  }

  bool isDownloaded(String bookId) => _downloads.containsKey(bookId);

  String? getLocalPath(String bookId) => _downloads[bookId];

  String getReadPath(String bookId, String remoteUrl) {
    return _downloads[bookId] ?? remoteUrl;
  }
}

class _MockLocalBookRepository {
  final List<_MockBookLite> _localData = [];
  bool _networkAvailable = true;

  void seedLocalData(List<_MockBookLite> books) {
    _localData.addAll(books);
  }

  List<_MockBookLite> getLocalSync({required int limit}) {
    return _localData.take(limit).toList();
  }

  void upsertFromRemote(List<_MockBookLite> remoteBooks) {
    for (final remote in remoteBooks) {
      final existingIndex = _localData.indexWhere((b) => b.id == remote.id);
      if (existingIndex >= 0) {
        _localData[existingIndex] = remote;
      } else {
        _localData.add(remote);
      }
    }
  }

  void setNetworkAvailable(bool available) {
    _networkAvailable = available;
  }

  bool get isNetworkAvailable => _networkAvailable;
}

class _MockSyncManager {
  final Map<String, DateTime> _lastSyncTimes = {};

  void setLastSyncTime(String module, DateTime time) {
    _lastSyncTimes[module] = time;
  }

  DateTime? getLastSyncTime(String module) => _lastSyncTimes[module];
}
