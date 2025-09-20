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
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (authorId != null) 'authorId': authorId,
      if (category != null) 'category': category,
      if (q != null) 'q': q,
      if (isPublished != null) 'isPublished': isPublished,
    };
    final response = await _dio.get('/books', queryParameters: query);
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getBook(int id) async {
    final response = await _dio.get('/books/$id');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> createBook({
    required String title,
    String? description,
    String? coverUrl,
    String? contentUrl,
    String? category,
    List<String>? tags,
    double? price,
    bool isPublished = false,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (contentUrl != null) 'contentUrl': contentUrl,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      if (price != null) 'price': price,
      'isPublished': isPublished,
    };
    final response = await _dio.post('/books', data: body);
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> updateBook(
    int id, {
    String? title,
    String? description,
    String? coverUrl,
    String? contentUrl,
    String? category,
    List<String>? tags,
    double? price,
    bool? isPublished,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (contentUrl != null) 'contentUrl': contentUrl,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      if (price != null) 'price': price,
      if (isPublished != null) 'isPublished': isPublished,
    };
    final response = await _dio.put('/books/$id', data: body);
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> deleteBook(int id) async {
    final response = await _dio.delete('/books/$id');
    return Map<String, dynamic>.from(response.data);
  }
}
