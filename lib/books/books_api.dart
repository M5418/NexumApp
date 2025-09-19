import '../core/api_client.dart';

class BooksApi {
  final ApiClient _api;
  BooksApi(this._api);

  /// Convenience factory using default TokenStore+ApiClient
  factory BooksApi.create() => BooksApi(ApiClient(TokenStore()));

  Future<Map<String, dynamic>> listBooks({
    int page = 1,
    int limit = 20,
    String? authorId,
    String? category,
    String? q,
    bool? isPublished,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (authorId != null) 'authorId': authorId,
      if (category != null) 'category': category,
      if (q != null) 'q': q,
      if (isPublished != null) 'isPublished': isPublished,
    };
    return _api.getJson('/books', query: query);
  }

  Future<Map<String, dynamic>> getBook(int id) {
    return _api.getJson('/books/$id');
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
  }) {
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
    return _api.postJson('/books', body);
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
  }) {
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
    return _api.putJson('/books/$id', body);
  }

  Future<Map<String, dynamic>> deleteBook(int id) {
    return _api.deleteJson('/books/$id');
  }
}
