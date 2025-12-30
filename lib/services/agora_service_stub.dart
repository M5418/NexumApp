// Stub file for non-web platforms
// This is used when dart.library.io is available (iOS/Android)

import 'dart:async';

/// Stub class for AgoraWebService on non-web platforms
class AgoraWebService {
  bool _isInitialized = false;
  
  final _userJoinedController = StreamController<int>.broadcast();
  final _userLeftController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<String>.broadcast();
  
  Stream<int> get onUserJoined => _userJoinedController.stream;
  Stream<int> get onUserLeft => _userLeftController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<String> get onConnectionStateChanged => _connectionStateController.stream;
  
  bool get isInitialized => _isInitialized;

  Future<bool> initialize({required bool isBroadcaster}) async {
    // Not supported on native platforms
    return false;
  }

  Future<bool> joinChannel({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    return false;
  }

  Future<bool> leaveChannel() async {
    return false;
  }

  bool playLocalVideo(String containerId) {
    return false;
  }

  bool playRemoteVideo(int uid, String containerId) {
    return false;
  }

  Future<bool> muteLocalAudio(bool muted) async {
    return false;
  }

  Future<bool> muteLocalVideo(bool muted) async {
    return false;
  }

  Future<bool> switchCamera() async {
    return false;
  }

  List<int> getRemoteUserIds() {
    return [];
  }

  void dispose() {
    _userJoinedController.close();
    _userLeftController.close();
    _errorController.close();
    _connectionStateController.close();
  }
}
