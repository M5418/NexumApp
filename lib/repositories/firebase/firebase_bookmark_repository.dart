import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/bookmark_repository.dart';
import '../models/bookmark_model.dart';

class FirebaseBookmarkRepository implements BookmarkRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _bookmarks => _db.collection('bookmarks');

  @override
  Future<String> bookmarkPost({
    required String postId,
    String? title,
    String? coverUrl,
    String? authorName,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if already bookmarked
    final existing = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'post')
        .where('itemId', isEqualTo: postId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id; // Already bookmarked
    }

    final bookmark = BookmarkModel(
      id: '',
      userId: user.uid,
      type: BookmarkType.post,
      itemId: postId,
      createdAt: DateTime.now(),
      title: title,
      coverUrl: coverUrl,
      authorName: authorName,
      description: description,
    );

    final ref = await _bookmarks.add(bookmark.toMap());
    return ref.id;
  }

  @override
  Future<String> bookmarkPodcast({
    required String podcastId,
    String? title,
    String? coverUrl,
    String? authorName,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if already bookmarked
    final existing = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'podcast')
        .where('itemId', isEqualTo: podcastId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final bookmark = BookmarkModel(
      id: '',
      userId: user.uid,
      type: BookmarkType.podcast,
      itemId: podcastId,
      createdAt: DateTime.now(),
      title: title,
      coverUrl: coverUrl,
      authorName: authorName,
      description: description,
    );

    final ref = await _bookmarks.add(bookmark.toMap());
    return ref.id;
  }

  @override
  Future<String> bookmarkBook({
    required String bookId,
    String? title,
    String? coverUrl,
    String? authorName,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if already bookmarked
    final existing = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'book')
        .where('itemId', isEqualTo: bookId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final bookmark = BookmarkModel(
      id: '',
      userId: user.uid,
      type: BookmarkType.book,
      itemId: bookId,
      createdAt: DateTime.now(),
      title: title,
      coverUrl: coverUrl,
      authorName: authorName,
      description: description,
    );

    final ref = await _bookmarks.add(bookmark.toMap());
    return ref.id;
  }

  @override
  Future<void> removeBookmark(String bookmarkId) async {
    await _bookmarks.doc(bookmarkId).delete();
  }

  @override
  Future<void> removeBookmarkByItem(String itemId, BookmarkType type) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final query = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: type.name)
        .where('itemId', isEqualTo: itemId)
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Future<List<BookmarkModel>> getPostBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final query = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'post')
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs.map((doc) => BookmarkModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<BookmarkModel>> getPodcastBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final query = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'podcast')
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs.map((doc) => BookmarkModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<BookmarkModel>> getBookBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final query = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'book')
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs.map((doc) => BookmarkModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<BookmarkModel>> getAllBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final query = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs.map((doc) => BookmarkModel.fromFirestore(doc)).toList();
  }

  @override
  Future<bool> isBookmarked(String itemId, BookmarkType type) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final query = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: type.name)
        .where('itemId', isEqualTo: itemId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  @override
  Future<String?> getBookmarkId(String itemId, BookmarkType type) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final query = await _bookmarks
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: type.name)
        .where('itemId', isEqualTo: itemId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }
}
