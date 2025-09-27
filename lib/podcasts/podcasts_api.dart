import 'package:dio/dio.dart';
import '../core/api_client.dart';

class PodcastsApi {
  final Dio _dio = ApiClient().dio;

  PodcastsApi();
  factory PodcastsApi.create() => PodcastsApi();

  Future<Map<String, dynamic>> list({
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
    final res = await _dio.get('/api/podcasts', queryParameters: query);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> categories() async {
    final res = await _dio.get('/api/podcasts/categories/list');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getPodcast(String id) async {
    final res = await _dio.get('/api/podcasts/$id');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createPodcast({
    required String title,
    String? author,
    String? description,
    String? coverUrl,
    String? audioUrl,
    int? durationSec,
    String? language,
    String? category,
    List<String>? tags,
    bool isPublished = false,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (durationSec != null) 'durationSec': durationSec,
      if (language != null) 'language': language,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      'isPublished': isPublished,
    };
    final res = await _dio.post('/api/podcasts', data: body);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> updatePodcast(
    String id, {
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? audioUrl,
    int? durationSec,
    String? language,
    String? category,
    List<String>? tags,
    bool? isPublished,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (durationSec != null) 'durationSec': durationSec,
      if (language != null) 'language': language,
      if (category != null) 'category': category,
      if (tags != null) 'tags': tags,
      if (isPublished != null) 'isPublished': isPublished,
    };
    final res = await _dio.put('/api/podcasts/$id', data: body);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> deletePodcast(String id) async {
    final res = await _dio.delete('/api/podcasts/$id');
    return Map<String, dynamic>.from(res.data);
  }

  // Likes
  Future<void> like(String id) async {
    await _dio.post('/api/podcasts/$id/like');
  }

  Future<void> unlike(String id) async {
    await _dio.delete('/api/podcasts/$id/like');
  }

  // Favorites
  Future<void> favorite(String id) async {
    await _dio.post('/api/podcasts/$id/favorite');
  }

  Future<void> unfavorite(String id) async {
    await _dio.delete('/api/podcasts/$id/favorite');
  }

  Future<Map<String, dynamic>> listMyFavorites() async {
    final res = await _dio.get('/api/podcasts/favorites/list/mine');
    return Map<String, dynamic>.from(res.data);
  }

  // Progress
  Future<Map<String, dynamic>> getProgress(String id) async {
    final res = await _dio.get('/api/podcasts/$id/progress');
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> updateAudioProgress({
    required String id,
    required int positionSec,
    int? durationSec,
  }) async {
    await _dio.put('/api/podcasts/$id/progress/audio', data: {
      'positionSec': positionSec,
      if (durationSec != null) 'durationSec': durationSec,
    });
  }

  // Playlists
  Future<Map<String, dynamic>> listMyPlaylists() async {
    final res = await _dio.get('/api/podcasts/playlists');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createPlaylist({
    required String name,
    bool isPrivate = false,
  }) async {
    final res = await _dio.post('/api/podcasts/playlists', data: {
      'name': name,
      'isPrivate': isPrivate,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getPlaylist(String playlistId) async {
    final res = await _dio.get('/api/podcasts/playlists/$playlistId');
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> updatePlaylist(String playlistId, {String? name, bool? isPrivate}) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (isPrivate != null) 'isPrivate': isPrivate,
    };
    await _dio.put('/api/podcasts/playlists/$playlistId', data: body);
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _dio.delete('/api/podcasts/playlists/$playlistId');
  }

  Future<void> addToPlaylist({required String playlistId, required String podcastId}) async {
    await _dio.post('/api/podcasts/playlists/$playlistId/items', data: {'podcastId': podcastId});
  }

  Future<void> removeFromPlaylist({required String playlistId, required String podcastId}) async {
    await _dio.delete('/api/podcasts/playlists/$playlistId/items/$podcastId');
  }

  // For add-to-playlist sheet
  Future<Map<String, dynamic>> playlistsForPodcast(String podcastId) async {
    final res = await _dio.get('/api/podcasts/playlists/for/$podcastId');
    return Map<String, dynamic>.from(res.data);
  }
}