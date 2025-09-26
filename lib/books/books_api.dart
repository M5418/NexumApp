import '../core/api_client.dart';

class BooksApi {
  final _dio = ApiClient().dio;

  // Default constructor required for factory BooksApi.create()
  BooksApi();

  /// Convenience factory
  factory BooksApi.create() => BooksApi();

  Future<Map<String, dynamic>> listBooks({
    int page = 1,
    int limit = 20,
    String? authorId,
    String? category,
    String? q,
    bool? isPublished,
    bool mine = false,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (authorId != null) 'authorId': authorId,
      if (category != null) 'category': category,
      if (q != null) 'q': q,
      if (isPublished != null) 'isPublished': isPublished,
      if (mine) 'mine': true,
    };
    final response = await _dio.get('/api/books', queryParameters: query);
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getBook(String id) async {
    final response = await _dio.get('/api/books/$id');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> createBook({
    required String title,
    String? author,
    String? description,
    String? coverUrl,
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
    final body = <String, dynamic>{
      'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (language != null) 'language': language,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      if (price != null) 'price': price,
      'isPublished': isPublished,
      if (readingMinutes != null) 'readingMinutes': readingMinutes,
      if (audioDurationSec != null) 'audioDurationSec': audioDurationSec,
    };
    final response = await _dio.post('/api/books', data: body);
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> updateBook(
    String id, {
    String? title,
    String? author,
    String? description,
    String? coverUrl,
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
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (language != null) 'language': language,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      if (price != null) 'price': price,
      if (isPublished != null) 'isPublished': isPublished,
      if (readingMinutes != null) 'readingMinutes': readingMinutes,
      if (audioDurationSec != null) 'audioDurationSec': audioDurationSec,
    };
    final response = await _dio.put('/api/books/$id', data: body);
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> deleteBook(String id) async {
    final response = await _dio.delete('/api/books/$id');
    return Map<String, dynamic>.from(response.data);
  }

  // Likes
  Future<void> like(String id) async {
    await _dio.post('/api/books/$id/like');
  }

  Future<void> unlike(String id) async {
    await _dio.delete('/api/books/$id/like');
  }

  // Favorites
  Future<void> favorite(String id) async {
    await _dio.post('/api/books/$id/favorite');
  }

  Future<void> unfavorite(String id) async {
    await _dio.delete('/api/books/$id/favorite');
  }

  // Progress
  Future<Map<String, dynamic>> getProgress(String id) async {
    final response = await _dio.get('/api/books/$id/progress');
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> updateReadProgress({
    required String id,
    required int page,
    int? totalPages,
  }) async {
    await _dio.put('/api/books/$id/progress/read', data: {
      'page': page,
      if (totalPages != null) 'totalPages': totalPages,
    });
  }

  Future<void> updateAudioProgress({
    required String id,
    required int positionSec,
    int? durationSec,
  }) async {
    await _dio.put('/api/books/$id/progress/audio', data: {
      'positionSec': positionSec,
      if (durationSec != null) 'durationSec': durationSec,
    });
  }
}