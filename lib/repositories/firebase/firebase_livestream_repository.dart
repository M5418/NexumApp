import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/livestream_repository.dart';
import '../models/livestream_model.dart';

class FirebaseLiveStreamRepository implements LiveStreamRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _streams => _firestore.collection('livestreams');
  
  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference _chatMessages(String streamId) =>
      _streams.doc(streamId).collection('messages');

  CollectionReference _reactions(String streamId) =>
      _streams.doc(streamId).collection('reactions');

  CollectionReference _viewers(String streamId) =>
      _streams.doc(streamId).collection('viewers');

  @override
  Future<String> createLiveStream({
    required String title,
    required String description,
    String? thumbnailUrl,
    String? thumbUrl,
    DateTime? scheduledAt,
    bool isPrivate = false,
    List<String>? invitedUserIds,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final streamKey = _generateStreamKey();
    
    final docRef = await _streams.add({
      'hostId': uid,
      'hostName': userData['displayName'] ?? userData['firstName'] ?? 'Host',
      'hostAvatarUrl': userData['avatarUrl'] ?? '',
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'thumbUrl': thumbUrl,
      'status': scheduledAt != null ? 'scheduled' : 'scheduled',
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt) : null,
      'startedAt': null,
      'endedAt': null,
      'viewerCount': 0,
      'peakViewerCount': 0,
      'totalViews': 0,
      'reactionCount': 0,
      'messageCount': 0,
      'isPrivate': isPrivate,
      'isRecording': false,
      'recordingUrl': null,
      'invitedUserIds': invitedUserIds ?? [],
      'bannedUserIds': [],
      'streamKey': streamKey,
      'streamUrl': null,
    });

    return docRef.id;
  }

  String _generateStreamKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < 24; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  @override
  Future<LiveStreamModel?> getLiveStream(String streamId) async {
    final doc = await _streams.doc(streamId).get();
    if (!doc.exists) return null;
    return LiveStreamModel.fromDoc(doc);
  }

  @override
  Future<void> updateLiveStream({
    required String streamId,
    String? title,
    String? description,
    String? thumbnailUrl,
    bool? isPrivate,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (thumbnailUrl != null) updates['thumbnailUrl'] = thumbnailUrl;
    if (isPrivate != null) updates['isPrivate'] = isPrivate;
    
    if (updates.isNotEmpty) {
      await _streams.doc(streamId).update(updates);
    }
  }

  @override
  Future<void> deleteLiveStream(String streamId) async {
    await _streams.doc(streamId).delete();
  }

  @override
  Future<void> startLiveStream(String streamId) async {
    await _streams.doc(streamId).update({
      'status': 'live',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> endLiveStream(String streamId) async {
    await _streams.doc(streamId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<LiveStreamModel>> getActiveLiveStreams({
    int limit = 20,
    LiveStreamModel? lastStream,
  }) async {
    Query query = _streams
        .where('status', isEqualTo: 'live')
        .orderBy('viewerCount', descending: true)
        .limit(limit);

    if (lastStream != null) {
      query = query.startAfterDocument(
          await _streams.doc(lastStream.id).get());
    }

    final snap = await query.get();
    return snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList();
  }

  @override
  Future<List<LiveStreamModel>> getActiveLiveStreamsFromCache({
    int limit = 20,
  }) async {
    try {
      final snap = await _streams
          .where('status', isEqualTo: 'live')
          .orderBy('viewerCount', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));
      return snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<LiveStreamModel>> getUpcomingLiveStreams({
    int limit = 20,
    LiveStreamModel? lastStream,
  }) async {
    Query query = _streams
        .where('status', isEqualTo: 'scheduled')
        .where('scheduledAt', isGreaterThan: Timestamp.now())
        .orderBy('scheduledAt')
        .limit(limit);

    if (lastStream != null) {
      query = query.startAfterDocument(
          await _streams.doc(lastStream.id).get());
    }

    final snap = await query.get();
    return snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList();
  }

  @override
  Future<List<LiveStreamModel>> getUpcomingLiveStreamsFromCache({
    int limit = 20,
  }) async {
    try {
      final snap = await _streams
          .where('status', isEqualTo: 'scheduled')
          .orderBy('scheduledAt')
          .limit(limit)
          .get(const GetOptions(source: Source.cache));
      return snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<LiveStreamModel>> getPastLiveStreams({
    int limit = 20,
    LiveStreamModel? lastStream,
  }) async {
    Query query = _streams
        .where('status', isEqualTo: 'ended')
        .orderBy('endedAt', descending: true)
        .limit(limit);

    if (lastStream != null) {
      query = query.startAfterDocument(
          await _streams.doc(lastStream.id).get());
    }

    final snap = await query.get();
    return snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList();
  }

  @override
  Future<List<LiveStreamModel>> getPastLiveStreamsFromCache({
    int limit = 20,
  }) async {
    try {
      final snap = await _streams
          .where('status', isEqualTo: 'ended')
          .orderBy('endedAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));
      return snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<LiveStreamModel>> getUserLiveStreams({
    required String uid,
    int limit = 20,
    LiveStreamModel? lastStream,
  }) async {
    Query query = _streams
        .where('hostId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastStream != null) {
      query = query.startAfterDocument(
          await _streams.doc(lastStream.id).get());
    }

    final snap = await query.get();
    return snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList();
  }

  @override
  Future<void> joinLiveStream(String streamId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final viewerRef = _viewers(streamId).doc(uid);
    final viewerDoc = await viewerRef.get();

    if (!viewerDoc.exists) {
      await viewerRef.set({
        'streamId': streamId,
        'userId': uid,
        'userName': userData['displayName'] ?? userData['firstName'] ?? 'Viewer',
        'userAvatarUrl': userData['avatarUrl'] ?? '',
        'joinedAt': FieldValue.serverTimestamp(),
        'isMuted': false,
        'isModerator': false,
      });

      await _streams.doc(streamId).update({
        'viewerCount': FieldValue.increment(1),
        'totalViews': FieldValue.increment(1),
      });

      // Update peak viewer count if needed
      final streamDoc = await _streams.doc(streamId).get();
      final streamData = streamDoc.data() as Map<String, dynamic>?;
      if (streamData != null) {
        final currentCount = (streamData['viewerCount'] ?? 0) + 1;
        final peakCount = streamData['peakViewerCount'] ?? 0;
        if (currentCount > peakCount) {
          await _streams.doc(streamId).update({
            'peakViewerCount': currentCount,
          });
        }
      }
    }
  }

  @override
  Future<void> leaveLiveStream(String streamId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final viewerRef = _viewers(streamId).doc(uid);
    final viewerDoc = await viewerRef.get();

    if (viewerDoc.exists) {
      await viewerRef.delete();
      await _streams.doc(streamId).update({
        'viewerCount': FieldValue.increment(-1),
      });
    }
  }

  @override
  Future<String> sendChatMessage({
    required String streamId,
    required String message,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    // Check if user is host
    final streamDoc = await _streams.doc(streamId).get();
    final streamData = streamDoc.data() as Map<String, dynamic>?;
    final isHost = streamData?['hostId'] == uid;

    final docRef = await _chatMessages(streamId).add({
      'streamId': streamId,
      'senderId': uid,
      'senderName': userData['displayName'] ?? userData['firstName'] ?? 'User',
      'senderAvatarUrl': userData['avatarUrl'] ?? '',
      'message': message,
      'sentAt': FieldValue.serverTimestamp(),
      'isHost': isHost,
      'isModerator': false,
      'isPinned': false,
    });

    await _streams.doc(streamId).update({
      'messageCount': FieldValue.increment(1),
    });

    return docRef.id;
  }

  @override
  Future<void> sendReaction({
    required String streamId,
    required String emoji,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _reactions(streamId).add({
      'streamId': streamId,
      'userId': uid,
      'emoji': emoji,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _streams.doc(streamId).update({
      'reactionCount': FieldValue.increment(1),
    });
  }

  @override
  Stream<List<LiveStreamChatMessage>> chatMessagesStream({
    required String streamId,
    int limit = 100,
  }) {
    return _chatMessages(streamId)
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LiveStreamChatMessage.fromDoc(d))
            .toList()
            .reversed
            .toList());
  }

  @override
  Stream<LiveStreamReaction> reactionsStream(String streamId) {
    return _reactions(streamId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .where((snap) => snap.docs.isNotEmpty)
        .map((snap) => LiveStreamReaction.fromDoc(snap.docs.first));
  }

  @override
  Stream<LiveStreamModel?> liveStreamStream(String streamId) {
    return _streams.doc(streamId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LiveStreamModel.fromDoc(doc);
    });
  }

  @override
  Stream<List<LiveStreamModel>> activeLiveStreamsStream({int limit = 20}) {
    return _streams
        .where('status', isEqualTo: 'live')
        .orderBy('viewerCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LiveStreamModel.fromDoc(d)).toList());
  }

  @override
  Future<int> getViewerCount(String streamId) async {
    final doc = await _streams.doc(streamId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['viewerCount'] ?? 0;
  }

  @override
  Future<List<LiveStreamViewer>> getViewers({
    required String streamId,
    int limit = 50,
  }) async {
    final snap = await _viewers(streamId)
        .orderBy('joinedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => LiveStreamViewer.fromDoc(d)).toList();
  }

  @override
  Future<void> muteViewer({
    required String streamId,
    required String viewerId,
  }) async {
    await _viewers(streamId).doc(viewerId).update({'isMuted': true});
  }

  @override
  Future<void> unmuteViewer({
    required String streamId,
    required String viewerId,
  }) async {
    await _viewers(streamId).doc(viewerId).update({'isMuted': false});
  }

  @override
  Future<void> kickViewer({
    required String streamId,
    required String viewerId,
  }) async {
    await _viewers(streamId).doc(viewerId).delete();
    await _streams.doc(streamId).update({
      'viewerCount': FieldValue.increment(-1),
    });
  }

  @override
  Future<void> banViewer({
    required String streamId,
    required String viewerId,
  }) async {
    await kickViewer(streamId: streamId, viewerId: viewerId);
    await _streams.doc(streamId).update({
      'bannedUserIds': FieldValue.arrayUnion([viewerId]),
    });
  }

  @override
  Future<bool> isUserBanned({
    required String streamId,
    required String userId,
  }) async {
    final doc = await _streams.doc(streamId).get();
    final data = doc.data() as Map<String, dynamic>?;
    final bannedIds = List<String>.from(data?['bannedUserIds'] ?? []);
    return bannedIds.contains(userId);
  }

  @override
  Future<void> toggleRecording({
    required String streamId,
    required bool enabled,
  }) async {
    await _streams.doc(streamId).update({'isRecording': enabled});
  }

  @override
  Future<String?> getRecordingUrl(String streamId) async {
    final doc = await _streams.doc(streamId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['recordingUrl'];
  }
}
