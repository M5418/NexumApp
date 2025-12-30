import 'dart:async';
import '../models/livestream_model.dart';

abstract class LiveStreamRepository {
  // Create a new live stream
  Future<String> createLiveStream({
    required String title,
    required String description,
    String? thumbnailUrl,
    String? thumbUrl,
    DateTime? scheduledAt,
    bool isPrivate = false,
    List<String>? invitedUserIds,
  });

  // Get a single live stream
  Future<LiveStreamModel?> getLiveStream(String streamId);

  // Update live stream details
  Future<void> updateLiveStream({
    required String streamId,
    String? title,
    String? description,
    String? thumbnailUrl,
    bool? isPrivate,
  });

  // Delete a live stream
  Future<void> deleteLiveStream(String streamId);

  // Start broadcasting (go live)
  Future<void> startLiveStream(String streamId);

  // End broadcasting
  Future<void> endLiveStream(String streamId);

  // Get active live streams (paginated)
  Future<List<LiveStreamModel>> getActiveLiveStreams({
    int limit = 20,
    LiveStreamModel? lastStream,
  });

  // Get active live streams from cache (instant load)
  Future<List<LiveStreamModel>> getActiveLiveStreamsFromCache({
    int limit = 20,
  });

  // Get upcoming/scheduled live streams
  Future<List<LiveStreamModel>> getUpcomingLiveStreams({
    int limit = 20,
    LiveStreamModel? lastStream,
  });

  // Get upcoming live streams from cache (instant load)
  Future<List<LiveStreamModel>> getUpcomingLiveStreamsFromCache({
    int limit = 20,
  });

  // Get past live streams (recordings)
  Future<List<LiveStreamModel>> getPastLiveStreams({
    int limit = 20,
    LiveStreamModel? lastStream,
  });

  // Get past live streams from cache (instant load)
  Future<List<LiveStreamModel>> getPastLiveStreamsFromCache({
    int limit = 20,
  });

  // Get user's live streams (as host)
  Future<List<LiveStreamModel>> getUserLiveStreams({
    required String uid,
    int limit = 20,
    LiveStreamModel? lastStream,
  });

  // Join a live stream as viewer
  Future<void> joinLiveStream(String streamId);

  // Leave a live stream as viewer
  Future<void> leaveLiveStream(String streamId);

  // Send a chat message
  Future<String> sendChatMessage({
    required String streamId,
    required String message,
  });

  // Send an emoji reaction
  Future<void> sendReaction({
    required String streamId,
    required String emoji,
  });

  // Get chat messages stream
  Stream<List<LiveStreamChatMessage>> chatMessagesStream({
    required String streamId,
    int limit = 100,
  });

  // Get reactions stream (for floating emoji animations)
  Stream<LiveStreamReaction> reactionsStream(String streamId);

  // Get live stream details stream (viewer count, status, etc.)
  Stream<LiveStreamModel?> liveStreamStream(String streamId);

  // Get active live streams stream
  Stream<List<LiveStreamModel>> activeLiveStreamsStream({int limit = 20});

  // Get viewer count
  Future<int> getViewerCount(String streamId);

  // Get viewers list
  Future<List<LiveStreamViewer>> getViewers({
    required String streamId,
    int limit = 50,
  });

  // Host controls
  Future<void> muteViewer({
    required String streamId,
    required String viewerId,
  });

  Future<void> unmuteViewer({
    required String streamId,
    required String viewerId,
  });

  Future<void> kickViewer({
    required String streamId,
    required String viewerId,
  });

  Future<void> banViewer({
    required String streamId,
    required String viewerId,
  });

  // Check if user is banned from stream
  Future<bool> isUserBanned({
    required String streamId,
    required String userId,
  });

  // Toggle recording
  Future<void> toggleRecording({
    required String streamId,
    required bool enabled,
  });

  // Get recording URL (for past streams)
  Future<String?> getRecordingUrl(String streamId);
}
