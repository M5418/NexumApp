import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/book_repository.dart';

class FirebaseBookRepository implements BookRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _books => _db.collection('books');
  CollectionReference<Map<String, dynamic>> get _bookCategories => _db.collection('book_categories');
  CollectionReference<Map<String, dynamic>> get _bookProgress => _db.collection('book_progress');

  BookModel _bookFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final uid = _auth.currentUser?.uid;
    
    // Check user-specific data
    final likes = List<String>.from(d['likes'] ?? []);
    final bookmarks = List<String>.from(d['bookmarks'] ?? []);
    final purchases = List<String>.from(d['purchases'] ?? []);
    
    return BookModel(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      author: d['author']?.toString(),
      authorId: d['authorId']?.toString(),
      description: d['description']?.toString(),
      coverUrl: d['coverUrl']?.toString(),
      coverThumbUrl: d['coverThumbUrl']?.toString(),
      epubUrl: d['epubUrl']?.toString(),
      pdfUrl: d['pdfUrl']?.toString(),
      audioUrl: d['audioUrl']?.toString(),
      language: d['language']?.toString(),
      category: d['category']?.toString(),
      tags: List<String>.from(d['tags'] ?? []),
      price: (d['price'] ?? 0.0).toDouble(),
      isPublished: d['isPublished'] == true,
      readingMinutes: (d['readingMinutes'] ?? 0).toInt(),
      audioDurationSec: d['audioDurationSec']?.toInt(),
      viewCount: (d['viewCount'] ?? 0).toInt(),
      likeCount: likes.length,
      rating: (d['rating'] ?? 0.0).toDouble(),
      reviewCount: (d['reviewCount'] ?? 0).toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLiked: uid != null && likes.contains(uid),
      isBookmarked: uid != null && bookmarks.contains(uid),
      isPurchased: uid != null && purchases.contains(uid),
    );
  }

  @override
  Future<List<BookModel>> listBooks({
    int page = 1,
    int limit = 20,
    String? authorId,
    String? category,
    String? query,
    bool? isPublished,
    bool mine = false,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _books;
      
      if (mine) {
        final uid = _auth.currentUser?.uid;
        if (uid == null) {
          return [];
        }
        q = q.where('authorId', isEqualTo: uid);
      } else if (authorId != null) {
        q = q.where('authorId', isEqualTo: authorId);
      }
      
      if (category != null) {
        q = q.where('category', isEqualTo: category);
      }
      
      if (isPublished != null) {
        q = q.where('isPublished', isEqualTo: isPublished);
      }
      
      if (query != null && query.isNotEmpty) {
        q = q.where('titleLower', isGreaterThanOrEqualTo: query.toLowerCase())
             .where('titleLower', isLessThan: '${query.toLowerCase()}\uf8ff');
      }
      
      final offset = (page - 1) * limit;
      if (offset > 0) {
        // Note: Firestore doesn't have offset, so we use limit for now
      }
      
      q = q.orderBy('createdAt', descending: true).limit(limit);
      
      final snap = await q.get();
      return snap.docs.map(_bookFromDoc).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// FAST: Get books from cache first (instant)
  Future<List<BookModel>> listBooksFromCache({
    int limit = 20,
    String? category,
    bool? isPublished,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _books;
      
      if (category != null) {
        q = q.where('category', isEqualTo: category);
      }
      if (isPublished != null) {
        q = q.where('isPublished', isEqualTo: isPublished);
      }
      q = q.orderBy('createdAt', descending: true).limit(limit);

      try {
        final snap = await q.get(const GetOptions(source: Source.cache));
        return snap.docs.map(_bookFromDoc).toList();
      } catch (_) {
        // Try without ordering if index missing
        final fallback = _books.limit(limit);
        final snap = await fallback.get(const GetOptions(source: Source.cache));
        return snap.docs.map(_bookFromDoc).toList();
      }
    } catch (_) {
      return []; // Cache miss
    }
  }

  @override
  Future<BookModel?> getBook(String bookId) async {
    final doc = await _books.doc(bookId).get();
    if (!doc.exists) return null;
    
    // Increment view count
    await doc.reference.update({
      'viewCount': FieldValue.increment(1),
    });
    
    return _bookFromDoc(doc);
  }

  @override
  Future<String> createBook({
    required String title,
    String? author,
    String? description,
    String? coverUrl,
    String? coverThumbUrl,
    String? epubUrl,
    String? pdfUrl,
    String? audioUrl,
    String? language,
    String? category,
    List<String>? tags,
    double? price,
    bool isPublished = false,
    int? readingMinutes,
    int? audioDurationSec,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    
    final data = {
      'title': title,
      'titleLower': title.toLowerCase(),
      'author': author,
      'authorId': uid,
      'description': description,
      'coverUrl': coverUrl,
      'coverThumbUrl': coverThumbUrl,
      'epubUrl': epubUrl,
      'pdfUrl': pdfUrl,
      'audioUrl': audioUrl,
      'language': language ?? 'en',
      'category': category,
      'tags': tags ?? [],
      'price': price ?? 0.0,
      'isPublished': isPublished,
      'readingMinutes': readingMinutes ?? 0,
      'audioDurationSec': audioDurationSec,
      'viewCount': 0,
      'likes': [],
      'bookmarks': [],
      'purchases': [],
      'rating': 0.0,
      'reviewCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    final ref = await _books.add(data);
    return ref.id;
  }

  @override
  Future<void> updateBook(
    String bookId, {
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? epubUrl,
    String? pdfUrl,
    String? audioUrl,
    String? language,
    String? category,
    List<String>? tags,
    double? price,
    bool? isPublished,
    int? readingMinutes,
    int? audioDurationSec,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (title != null) {
      updates['title'] = title;
      updates['titleLower'] = title.toLowerCase();
    }
    if (author != null) updates['author'] = author;
    if (description != null) updates['description'] = description;
    if (coverUrl != null) updates['coverUrl'] = coverUrl;
    if (epubUrl != null) updates['epubUrl'] = epubUrl;
    if (pdfUrl != null) updates['pdfUrl'] = pdfUrl;
    if (audioUrl != null) updates['audioUrl'] = audioUrl;
    if (language != null) updates['language'] = language;
    if (category != null) updates['category'] = category;
    if (tags != null) updates['tags'] = tags;
    if (price != null) updates['price'] = price;
    if (isPublished != null) updates['isPublished'] = isPublished;
    if (readingMinutes != null) updates['readingMinutes'] = readingMinutes;
    if (audioDurationSec != null) updates['audioDurationSec'] = audioDurationSec;
    
    await _books.doc(bookId).update(updates);
  }

  @override
  Future<void> deleteBook(String bookId) async {
    await _books.doc(bookId).delete();
    
    // Also delete related progress
    final progressDocs = await _bookProgress
        .where('bookId', isEqualTo: bookId)
        .get();
    
    final batch = _db.batch();
    for (final doc in progressDocs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> likeBook(String bookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _books.doc(bookId).update({
      'likes': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> unlikeBook(String bookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _books.doc(bookId).update({
      'likes': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> bookmarkBook(String bookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _books.doc(bookId).update({
      'bookmarks': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> unbookmarkBook(String bookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _books.doc(bookId).update({
      'bookmarks': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> purchaseBook(String bookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _books.doc(bookId).update({
      'purchases': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<BookProgressModel?> getProgress(String bookId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    final progressId = '${bookId}_$uid';
    final doc = await _bookProgress.doc(progressId).get();
    
    if (!doc.exists) return null;
    
    final d = doc.data()!;
    return BookProgressModel(
      bookId: bookId,
      userId: uid,
      currentPage: (d['currentPage'] ?? 0).toInt(),
      totalPages: (d['totalPages'] ?? 0).toInt(),
      progressPercent: (d['progressPercent'] ?? 0.0).toDouble(),
      audioProgress: d['audioProgressSec'] != null 
          ? Duration(seconds: d['audioProgressSec']) 
          : null,
      lastReadAt: (d['lastReadAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<void> updateProgress({
    required String bookId,
    int? currentPage,
    Duration? audioProgress,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final progressId = '${bookId}_$uid';
    final updates = <String, dynamic>{
      'bookId': bookId,
      'userId': uid,
      'lastReadAt': FieldValue.serverTimestamp(),
    };
    
    if (currentPage != null) {
      updates['currentPage'] = currentPage;
      // Calculate progress percent if we know total pages
      final book = await getBook(bookId);
      if (book != null && book.readingMinutes > 0) {
        // Estimate pages from reading minutes (1 page per minute)
        final totalPages = book.readingMinutes;
        updates['totalPages'] = totalPages;
        updates['progressPercent'] = (currentPage / totalPages * 100).clamp(0, 100);
      }
    }
    
    if (audioProgress != null) {
      updates['audioProgressSec'] = audioProgress.inSeconds;
    }
    
    await _bookProgress.doc(progressId).set(updates, SetOptions(merge: true));
  }

  // Simplified implementations for other methods
  @override
  Future<List<BookReviewModel>> getReviews(String bookId, {int limit = 20}) async {
    // Simplified - reviews would be in a subcollection
    return [];
  }

  @override
  Future<void> addReview({
    required String bookId,
    required double rating,
    String? comment,
  }) async {
    // Simplified implementation
  }

  @override
  Future<void> markReviewHelpful(String reviewId) async {
    // Simplified implementation
  }

  @override
  Future<List<BookCategoryModel>> getCategories() async {
    final snap = await _bookCategories.orderBy('name').get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return BookCategoryModel(
        id: doc.id,
        name: (d['name'] ?? '').toString(),
        icon: d['icon']?.toString(),
        description: d['description']?.toString(),
        bookCount: (d['bookCount'] ?? 0).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<BookModel>> searchBooks(String query) async {
    return listBooks(query: query, limit: 50);
  }

  @override
  Future<List<BookModel>> getRecommendations() async {
    // Simplified - just return popular books
    return listBooks(limit: 10);
  }

  @override
  Future<List<BookModel>> getBookmarkedBooks() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return [];
      }
      
      final snap = await _books
          .where('bookmarks', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();
      
      return snap.docs.map(_bookFromDoc).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<BookModel>> getPurchasedBooks() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return [];
      }
      
      final snap = await _books
          .where('purchases', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .get();
      
      return snap.docs.map(_bookFromDoc).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<BookModel?> bookStream(String bookId) {
    return _books.doc(bookId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _bookFromDoc(doc);
    });
  }

  @override
  Stream<BookProgressModel?> progressStream(String bookId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    
    final progressId = '${bookId}_$uid';
    return _bookProgress.doc(progressId).snapshots().map((doc) {
      if (!doc.exists) return null;
      
      final d = doc.data()!;
      return BookProgressModel(
        bookId: bookId,
        userId: uid,
        currentPage: (d['currentPage'] ?? 0).toInt(),
        totalPages: (d['totalPages'] ?? 0).toInt(),
        progressPercent: (d['progressPercent'] ?? 0.0).toDouble(),
        audioProgress: d['audioProgressSec'] != null 
            ? Duration(seconds: d['audioProgressSec']) 
            : null,
        lastReadAt: (d['lastReadAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    });
  }
}
