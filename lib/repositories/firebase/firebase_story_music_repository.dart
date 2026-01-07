import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/story_music_model.dart';

class FirebaseStoryMusicRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _musicCollection =>
      _db.collection('story_music');

  // Admin UID - Only this account can upload music
  static const String nexumAdminUid = 'NEXUM_ADMIN_UID'; // Replace with actual admin UID

  /// Check if current user is admin
  bool get isAdmin {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid == nexumAdminUid;
  }

  /// Get all active music tracks for story selection
  Future<List<StoryMusicModel>> getStoryMusic({int limit = 50}) async {
    try {
      final snap = await _musicCollection
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) => StoryMusicModel.fromFirestore(doc)).toList();
    } catch (e) {
      // Fallback without ordering if index not ready
      try {
        final snap = await _musicCollection
            .where('isActive', isEqualTo: true)
            .limit(limit)
            .get();
        return snap.docs.map((doc) => StoryMusicModel.fromFirestore(doc)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Get music from cache first (instant)
  Future<List<StoryMusicModel>> getStoryMusicFromCache({int limit = 50}) async {
    try {
      final snap = await _musicCollection
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));

      return snap.docs.map((doc) => StoryMusicModel.fromFirestore(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Upload music (admin only)
  Future<StoryMusicModel?> uploadMusic({
    required String title,
    required String artist,
    required Uint8List audioBytes,
    required String audioFileName,
    Uint8List? coverBytes,
    String? coverFileName,
    int? durationSec,
    String? genre,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    
    // Note: In production, you'd check admin status server-side
    // For now, any authenticated user can upload (you can restrict in Firestore rules)

    try {
      // Upload audio file
      final audioRef = _storage.ref('story_music/audio/${DateTime.now().millisecondsSinceEpoch}_$audioFileName');
      await audioRef.putData(audioBytes, SettableMetadata(contentType: 'audio/mpeg'));
      final audioUrl = await audioRef.getDownloadURL();

      // Upload cover if provided
      String? coverUrl;
      if (coverBytes != null && coverFileName != null) {
        final coverRef = _storage.ref('story_music/covers/${DateTime.now().millisecondsSinceEpoch}_$coverFileName');
        await coverRef.putData(coverBytes, SettableMetadata(contentType: 'image/jpeg'));
        coverUrl = await coverRef.getDownloadURL();
      }

      // Create document
      final docRef = await _musicCollection.add({
        'title': title,
        'artist': artist,
        'audioUrl': audioUrl,
        'coverUrl': coverUrl,
        'durationSec': durationSec ?? 0,
        'genre': genre,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': uid,
      });

      // Return the created model
      final doc = await docRef.get();
      return StoryMusicModel.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete music (admin only)
  Future<void> deleteMusic(String musicId) async {
    await _musicCollection.doc(musicId).delete();
  }

  /// Toggle music active status (admin only)
  Future<void> toggleMusicActive(String musicId, bool isActive) async {
    await _musicCollection.doc(musicId).update({'isActive': isActive});
  }

  /// Get single music track by ID
  Future<StoryMusicModel?> getMusicById(String musicId) async {
    try {
      final doc = await _musicCollection.doc(musicId).get();
      if (!doc.exists) return null;
      return StoryMusicModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }
}
