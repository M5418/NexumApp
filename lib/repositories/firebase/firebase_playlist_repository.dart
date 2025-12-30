import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/playlist_repository.dart';

class FirebasePlaylistRepository implements PlaylistRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _playlists =>
      _db.collection('podcast_playlists');

  PlaylistModel _playlistFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PlaylistModel(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      userId: (d['userId'] ?? '').toString(),
      isPrivate: d['isPrivate'] == true,
      podcastIds: List<String>.from(d['podcastIds'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<List<PlaylistModel>> getUserPlaylists() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _playlists
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(_playlistFromDoc).toList();
  }

  /// FAST: Get playlists from cache first (instant)
  Future<List<PlaylistModel>> getUserPlaylistsFromCache() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final snapshot = await _playlists
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.cache));

      return snapshot.docs.map(_playlistFromDoc).toList();
    } catch (_) {
      return []; // Cache miss
    }
  }

  @override
  Future<PlaylistModel?> getPlaylist(String playlistId) async {
    final doc = await _playlists.doc(playlistId).get();
    if (!doc.exists) return null;
    return _playlistFromDoc(doc);
  }

  @override
  Future<String> createPlaylist(String name, {bool isPrivate = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final data = {
      'name': name,
      'userId': uid,
      'isPrivate': isPrivate,
      'podcastIds': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final ref = await _playlists.add(data);
    return ref.id;
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await _playlists.doc(playlistId).delete();
  }

  @override
  Future<void> addPodcastToPlaylist(String playlistId, String podcastId) async {
    await _playlists.doc(playlistId).update({
      'podcastIds': FieldValue.arrayUnion([podcastId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removePodcastFromPlaylist(
      String playlistId, String podcastId) async {
    await _playlists.doc(playlistId).update({
      'podcastIds': FieldValue.arrayRemove([podcastId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> playlistContainsPodcast(
      String playlistId, String podcastId) async {
    final playlist = await getPlaylist(playlistId);
    return playlist?.podcastIds.contains(podcastId) ?? false;
  }

  @override
  Future<List<String>> getPlaylistPodcastIds(String playlistId) async {
    final playlist = await getPlaylist(playlistId);
    return playlist?.podcastIds ?? [];
  }
}
