abstract class PlaylistRepository {
  Future<List<PlaylistModel>> getUserPlaylists();
  Future<PlaylistModel?> getPlaylist(String playlistId);
  Future<String> createPlaylist(String name, {bool isPrivate = false});
  Future<void> deletePlaylist(String playlistId);
  Future<void> addPodcastToPlaylist(String playlistId, String podcastId);
  Future<void> removePodcastFromPlaylist(String playlistId, String podcastId);
  Future<bool> playlistContainsPodcast(String playlistId, String podcastId);
  Future<List<String>> getPlaylistPodcastIds(String playlistId);
}

class PlaylistModel {
  final String id;
  final String name;
  final String userId;
  final bool isPrivate;
  final List<String> podcastIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.userId,
    required this.isPrivate,
    required this.podcastIds,
    required this.createdAt,
    required this.updatedAt,
  });
}
