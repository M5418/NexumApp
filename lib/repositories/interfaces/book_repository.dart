import 'dart:async';

// Model classes
class BookModel {
  final String id;
  final String title;
  final String? author;
  final String? authorId;
  final String? description;
  final String? coverUrl;
  final String? epubUrl;
  final String? pdfUrl;
  final String? audioUrl;
  final String? language;
  final String? category;
  final List<String> tags;
  final double? price;
  final bool isPublished;
  final int readingMinutes;
  final int? audioDurationSec;
  final int viewCount;
  final int likeCount;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLiked;
  final bool isBookmarked;
  final bool isPurchased;
  
  BookModel({
    required this.id,
    required this.title,
    this.author,
    this.authorId,
    this.description,
    this.coverUrl,
    this.epubUrl,
    this.pdfUrl,
    this.audioUrl,
    this.language,
    this.category,
    required this.tags,
    this.price,
    required this.isPublished,
    required this.readingMinutes,
    this.audioDurationSec,
    required this.viewCount,
    required this.likeCount,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
    required this.isLiked,
    required this.isBookmarked,
    required this.isPurchased,
  });
}

class BookCategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? description;
  final int bookCount;
  
  BookCategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.description,
    required this.bookCount,
  });
}

class BookReviewModel {
  final String id;
  final String bookId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final int helpfulCount;
  final bool isHelpful;
  
  BookReviewModel({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.helpfulCount,
    required this.isHelpful,
  });
}

class BookProgressModel {
  final String bookId;
  final String userId;
  final int currentPage;
  final int totalPages;
  final double progressPercent;
  final Duration? audioProgress;
  final DateTime lastReadAt;
  
  BookProgressModel({
    required this.bookId,
    required this.userId,
    required this.currentPage,
    required this.totalPages,
    required this.progressPercent,
    this.audioProgress,
    required this.lastReadAt,
  });
}

// Repository interface
abstract class BookRepository {
  // Book CRUD
  Future<List<BookModel>> listBooks({
    int page = 1,
    int limit = 20,
    String? authorId,
    String? category,
    String? query,
    bool? isPublished,
    bool mine = false,
  });
  
  Future<BookModel?> getBook(String bookId);
  
  Future<String> createBook({
    required String title,
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
    bool isPublished = false,
    int? readingMinutes,
    int? audioDurationSec,
  });
  
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
  });
  
  Future<void> deleteBook(String bookId);
  
  // Book interactions
  Future<void> likeBook(String bookId);
  Future<void> unlikeBook(String bookId);
  Future<void> bookmarkBook(String bookId);
  Future<void> unbookmarkBook(String bookId);
  Future<void> purchaseBook(String bookId);
  
  // Reading progress
  Future<BookProgressModel?> getProgress(String bookId);
  Future<void> updateProgress({
    required String bookId,
    int? currentPage,
    Duration? audioProgress,
  });
  
  // Reviews
  Future<List<BookReviewModel>> getReviews(String bookId, {int limit = 20});
  Future<void> addReview({
    required String bookId,
    required double rating,
    String? comment,
  });
  Future<void> markReviewHelpful(String reviewId);
  
  // Categories
  Future<List<BookCategoryModel>> getCategories();
  
  // Search and recommendations
  Future<List<BookModel>> searchBooks(String query);
  Future<List<BookModel>> getRecommendations();
  Future<List<BookModel>> getBookmarkedBooks();
  Future<List<BookModel>> getPurchasedBooks();
  
  // Real-time streams
  Stream<BookModel?> bookStream(String bookId);
  Stream<BookProgressModel?> progressStream(String bookId);
}
