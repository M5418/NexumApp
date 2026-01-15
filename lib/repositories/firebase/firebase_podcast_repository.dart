import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/podcast_repository.dart';

class FirebasePodcastRepository implements PodcastRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _podcasts => _db.collection('podcasts');
  CollectionReference<Map<String, dynamic>> get _podcastCategories => _db.collection('podcast_categories');
  CollectionReference<Map<String, dynamic>> get _podcastProgress => _db.collection('podcast_progress');

  PodcastModel _podcastFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final uid = _auth.currentUser?.uid;
    
    final likes = List<String>.from(d['likes'] ?? []);
    final bookmarks = List<String>.from(d['bookmarks'] ?? []);
    final subscriptions = List<String>.from(d['subscriptions'] ?? []);
    
    return PodcastModel(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      author: d['author']?.toString(),
      authorId: d['authorId']?.toString(),
      description: d['description']?.toString(),
      coverUrl: d['coverUrl']?.toString(),
      coverThumbUrl: d['coverThumbUrl']?.toString(),
      audioUrl: d['audioUrl']?.toString(),
      durationSec: d['durationSec']?.toInt(),
      language: d['language']?.toString(),
      category: d['category']?.toString(),
      tags: List<String>.from(d['tags'] ?? []),
      isPublished: d['isPublished'] == true,
      playCount: (d['playCount'] ?? 0).toInt(),
      likeCount: likes.length,
      rating: (d['rating'] ?? 0.0).toDouble(),
      reviewCount: (d['reviewCount'] ?? 0).toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLiked: uid != null && likes.contains(uid),
      isBookmarked: uid != null && bookmarks.contains(uid),
      isSubscribed: uid != null && subscriptions.contains(uid),
    );
  }

  @override
  Future<List<PodcastModel>> listPodcasts({
    int page = 1,
    int limit = 20,
    String? authorId,
    String? category,
    String? query,
    bool? isPublished,
    bool mine = false,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _podcasts;
      bool hasFilter = false;

      if (mine) {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return [];
        q = q.where('authorId', isEqualTo: uid);
        hasFilter = true;
      } else if (authorId != null) {
        q = q.where('authorId', isEqualTo: authorId);
        hasFilter = true;
      }

      if (category != null) {
        q = q.where('category', isEqualTo: category);
        hasFilter = true;
      }

      if (isPublished != null) {
        q = q.where('isPublished', isEqualTo: isPublished);
        hasFilter = true;
      }

      if (!hasFilter) {
        q = q.orderBy('createdAt', descending: true);
      }
      q = q.limit(limit);

      try {
        final snap = await q.get();
        return snap.docs.map(_podcastFromDoc).toList();
      } on FirebaseException catch (_) {
        final fallback = _podcasts.limit(limit);
        final snap = await fallback.get();
        return snap.docs.map(_podcastFromDoc).toList();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// FAST: Get podcasts from cache first (instant)
  Future<List<PodcastModel>> listPodcastsFromCache({
    int limit = 20,
    String? category,
    bool? isPublished,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _podcasts;
      
      if (category != null) {
        q = q.where('category', isEqualTo: category);
      }
      if (isPublished != null) {
        q = q.where('isPublished', isEqualTo: isPublished);
      }
      q = q.orderBy('createdAt', descending: true).limit(limit);

      try {
        final snap = await q.get(const GetOptions(source: Source.cache));
        return snap.docs.map(_podcastFromDoc).toList();
      } catch (_) {
        // Try without ordering if index missing
        final fallback = _podcasts.limit(limit);
        final snap = await fallback.get(const GetOptions(source: Source.cache));
        return snap.docs.map(_podcastFromDoc).toList();
      }
    } catch (_) {
      return []; // Cache miss
    }
  }

  @override
  Future<PodcastModel?> getPodcast(String podcastId) async {
    final doc = await _podcasts.doc(podcastId).get();
    if (!doc.exists) return null;
    return _podcastFromDoc(doc);
  }

  @override
  Future<String> createPodcast({
    required String title,
    String? author,
    String? description,
    String? coverUrl,
    String? coverThumbUrl,
    String? audioUrl,
    int? durationSec,
    String? language,
    String? category,
    List<String>? tags,
    bool isPublished = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    
    final data = {
      'title': title,
      'author': author,
      'authorId': uid,
      'description': description,
      'coverUrl': coverUrl,
      'coverThumbUrl': coverThumbUrl,
      'audioUrl': audioUrl,
      'durationSec': durationSec,
      'language': language ?? 'en',
      'category': category,
      'tags': tags ?? [],
      'isPublished': isPublished,
      'playCount': 0,
      'likes': [],
      'bookmarks': [],
      'subscriptions': [],
      'rating': 0.0,
      'reviewCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    final ref = await _podcasts.add(data);
    return ref.id;
  }

  @override
  Future<void> updatePodcast(
    String podcastId, {
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? coverThumbUrl,
    String? audioUrl,
    int? durationSec,
    String? language,
    String? category,
    List<String>? tags,
    bool? isPublished,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (title != null) updates['title'] = title;
    if (author != null) updates['author'] = author;
    if (description != null) updates['description'] = description;
    if (coverUrl != null) updates['coverUrl'] = coverUrl;
    if (coverThumbUrl != null) updates['coverThumbUrl'] = coverThumbUrl;
    if (audioUrl != null) updates['audioUrl'] = audioUrl;
    if (durationSec != null) updates['durationSec'] = durationSec;
    if (language != null) updates['language'] = language;
    if (category != null) updates['category'] = category;
    if (tags != null) updates['tags'] = tags;
    if (isPublished != null) updates['isPublished'] = isPublished;
    
    await _podcasts.doc(podcastId).update(updates);
  }

  @override
  Future<void> deletePodcast(String podcastId) async {
    await _podcasts.doc(podcastId).delete();
  }

  @override
  Future<void> likePodcast(String podcastId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _podcasts.doc(podcastId).update({
      'likes': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> unlikePodcast(String podcastId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _podcasts.doc(podcastId).update({
      'likes': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> bookmarkPodcast(String podcastId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _podcasts.doc(podcastId).update({
      'bookmarks': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> unbookmarkPodcast(String podcastId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _podcasts.doc(podcastId).update({
      'bookmarks': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> subscribeToPodcast(String podcastId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _podcasts.doc(podcastId).update({
      'subscriptions': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> unsubscribeFromPodcast(String podcastId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _podcasts.doc(podcastId).update({
      'subscriptions': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> recordPlay(String podcastId, {String? episodeId}) async {
    await _podcasts.doc(podcastId).update({
      'playCount': FieldValue.increment(1),
    });
  }

  @override
  Future<PodcastProgressModel?> getProgress(String podcastId, {String? episodeId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    final progressId = episodeId != null ? '${podcastId}_${episodeId}_$uid' : '${podcastId}_$uid';
    final doc = await _podcastProgress.doc(progressId).get();
    
    if (!doc.exists) return null;
    
    final d = doc.data()!;
    return PodcastProgressModel(
      podcastId: podcastId,
      episodeId: episodeId,
      userId: uid,
      currentPosition: Duration(seconds: (d['currentPositionSec'] ?? 0).toInt()),
      totalDuration: Duration(seconds: (d['totalDurationSec'] ?? 0).toInt()),
      progressPercent: (d['progressPercent'] ?? 0.0).toDouble(),
      lastPlayedAt: (d['lastPlayedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<void> updateProgress({
    required String podcastId,
    String? episodeId,
    required Duration currentPosition,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final progressId = episodeId != null ? '${podcastId}_${episodeId}_$uid' : '${podcastId}_$uid';
    
    // Get total duration from podcast
    final podcast = await getPodcast(podcastId);
    final totalDuration = podcast?.durationSec ?? 0;
    
    final data = {
      'podcastId': podcastId,
      'episodeId': episodeId,
      'userId': uid,
      'currentPositionSec': currentPosition.inSeconds,
      'totalDurationSec': totalDuration,
      'progressPercent': totalDuration > 0 ? (currentPosition.inSeconds / totalDuration * 100).clamp(0, 100) : 0,
      'lastPlayedAt': FieldValue.serverTimestamp(),
    };
    
    await _podcastProgress.doc(progressId).set(data, SetOptions(merge: true));
  }

  @override
  Future<List<PodcastCategoryModel>> getCategories() async {
    final snap = await _podcastCategories.orderBy('name').get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return PodcastCategoryModel(
        id: doc.id,
        name: (d['name'] ?? '').toString(),
        icon: d['icon']?.toString(),
        description: d['description']?.toString(),
        podcastCount: (d['podcastCount'] ?? 0).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<PodcastModel>> searchPodcasts(String query) async {
    return listPodcasts(query: query, limit: 50);
  }

  @override
  Future<List<PodcastModel>> getTrending() async {
    final snap = await _podcasts
        .where('isPublished', isEqualTo: true)
        .orderBy('playCount', descending: true)
        .limit(10)
        .get();
    
    return snap.docs.map(_podcastFromDoc).toList();
  }

  @override
  Future<List<PodcastModel>> getRecommendations() async {
    // Simplified - just return popular podcasts
    return getTrending();
  }

  @override
  Future<List<PodcastModel>> getBookmarkedPodcasts() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        
        return [];
      }
      
      final snap = await _podcasts
          .where('bookmarks', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();
      
      return snap.docs.map(_podcastFromDoc).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<PodcastModel>> getSubscribedPodcasts() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        
        return [];
      }
      
      final snap = await _podcasts
          .where('subscriptions', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(100)
          .get();
      
      return snap.docs.map(_podcastFromDoc).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<PodcastModel>> getRecentlyPlayed() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    // Get progress records for this user
    final progress = await _podcastProgress
        .where('userId', isEqualTo: uid)
        .orderBy('lastPlayedAt', descending: true)
        .limit(20)
        .get();
    
    final podcastIds = progress.docs.map((d) => d.data()['podcastId'].toString()).toSet();
    final podcasts = <PodcastModel>[];
    
    for (final id in podcastIds) {
      final podcast = await getPodcast(id);
      if (podcast != null) podcasts.add(podcast);
    }
    
    return podcasts;
  }

  // Simplified episode management
  @override
  Future<List<PodcastEpisodeModel>> getEpisodes(String podcastId) async {
    // Episodes would be in a subcollection
    return [];
  }

  @override
  Future<String> createEpisode({
    required String podcastId,
    required String title,
    String? description,
    required String audioUrl,
    required int durationSec,
  }) async {
    // Simplified implementation
    return '';
  }

  @override
  Future<void> deleteEpisode(String episodeId) async {
    // Simplified implementation
  }

  // Streams
  @override
  Stream<PodcastModel?> podcastStream(String podcastId) {
    if (podcastId.isEmpty) return Stream.value(null);
    return _podcasts.doc(podcastId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _podcastFromDoc(doc);
    });
  }

  @override
  Stream<PodcastProgressModel?> progressStream(String podcastId, {String? episodeId}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    
    final progressId = episodeId != null ? '${podcastId}_${episodeId}_$uid' : '${podcastId}_$uid';
    return _podcastProgress.doc(progressId).snapshots().map((doc) {
      if (!doc.exists) return null;
      
      final d = doc.data()!;
      return PodcastProgressModel(
        podcastId: podcastId,
        episodeId: episodeId,
        userId: uid,
        currentPosition: Duration(seconds: (d['currentPositionSec'] ?? 0).toInt()),
        totalDuration: Duration(seconds: (d['totalDurationSec'] ?? 0).toInt()),
        progressPercent: (d['progressPercent'] ?? 0.0).toDouble(),
        lastPlayedAt: (d['lastPlayedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    });
  }

  @override
  Stream<List<PodcastModel>> subscribedPodcastsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _podcasts
        .where('subscriptions', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(_podcastFromDoc).toList());
  }
}
