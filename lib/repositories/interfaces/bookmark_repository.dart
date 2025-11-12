import '../models/bookmark_model.dart';

abstract class BookmarkRepository {
  // Add bookmarks
  Future<String> bookmarkPost({
    required String postId,
    String? title,
    String? coverUrl,
    String? authorName,
    String? description,
  });

  Future<String> bookmarkPodcast({
    required String podcastId,
    String? title,
    String? coverUrl,
    String? authorName,
    String? description,
  });

  Future<String> bookmarkBook({
    required String bookId,
    String? title,
    String? coverUrl,
    String? authorName,
    String? description,
  });

  // Remove bookmarks
  Future<void> removeBookmark(String bookmarkId);
  Future<void> removeBookmarkByItem(String itemId, BookmarkType type);

  // Get bookmarks
  Future<List<BookmarkModel>> getPostBookmarks();
  Future<List<BookmarkModel>> getPodcastBookmarks();
  Future<List<BookmarkModel>> getBookBookmarks();
  Future<List<BookmarkModel>> getAllBookmarks();

  // Check if bookmarked
  Future<bool> isBookmarked(String itemId, BookmarkType type);
  Future<String?> getBookmarkId(String itemId, BookmarkType type);
}
