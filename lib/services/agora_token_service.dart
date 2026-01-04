import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service to generate Agora RTC tokens via Firebase Cloud Functions
class AgoraTokenService {
  static final AgoraTokenService _instance = AgoraTokenService._internal();
  factory AgoraTokenService() => _instance;
  AgoraTokenService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Generate an Agora token for the given channel
  /// Returns null if token generation fails (will use no-token mode)
  Future<AgoraTokenResult?> generateToken({
    required String channelName,
    required int uid,
    required bool isPublisher,
  }) async {
    try {
      debugPrint('AgoraTokenService: Generating token for channel: $channelName, uid: $uid, publisher: $isPublisher');
      
      final callable = _functions.httpsCallable('generateAgoraToken');
      final result = await callable.call<Map<String, dynamic>>({
        'channelName': channelName,
        'uid': uid,
        'role': isPublisher ? 'publisher' : 'subscriber',
      });

      final data = result.data;
      final token = data['token'] as String?;
      final appId = data['appId'] as String?;
      
      if (token != null && token.isNotEmpty) {
        debugPrint('AgoraTokenService: Token generated successfully');
        return AgoraTokenResult(
          token: token,
          uid: data['uid'] as int? ?? uid,
          channelName: data['channelName'] as String? ?? channelName,
          appId: appId ?? '',
        );
      } else {
        debugPrint('AgoraTokenService: Empty token returned - using no-token mode');
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('AgoraTokenService: Firebase Functions error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('AgoraTokenService: Error generating token: $e');
      return null;
    }
  }
}

class AgoraTokenResult {
  final String token;
  final int uid;
  final String channelName;
  final String appId;

  const AgoraTokenResult({
    required this.token,
    required this.uid,
    required this.channelName,
    required this.appId,
  });
}
