// Stub file for non-web platforms
// This is used when dart.library.io is available (iOS/Android)

import 'dart:async';

/// Result of checking Agora Web runtime status (stub)
class AgoraWebRuntimeStatus {
  final bool sdkLoaded;
  final bool secureContext;
  final bool webRTCSupported;

  const AgoraWebRuntimeStatus({
    required this.sdkLoaded,
    required this.secureContext,
    required this.webRTCSupported,
  });

  bool get isReady => false; // Never ready on native
  String? get errorMessage => 'Web SDK not available on native platforms';
}

/// Web diagnostics data (stub)
class AgoraWebDiagnostics {
  final bool isJoined;
  final bool isBroadcaster;
  final String connectionState;
  final int? joinTimestamp;
  final String? lastError;
  final String? lastErrorCode;
  final int remoteUserCount;
  final bool hasLocalVideo;
  final bool hasLocalAudio;

  const AgoraWebDiagnostics({
    this.isJoined = false,
    this.isBroadcaster = false,
    this.connectionState = 'DISCONNECTED',
    this.joinTimestamp,
    this.lastError,
    this.lastErrorCode,
    this.remoteUserCount = 0,
    this.hasLocalVideo = false,
    this.hasLocalAudio = false,
  });
}

/// Stub class for AgoraWebService on non-web platforms
class AgoraWebService {
  bool _isInitialized = false;
  bool _isJoined = false;
  DateTime? _joinTimestamp;
  
  final _userJoinedController = StreamController<int>.broadcast();
  final _userLeftController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<String>.broadcast();
  final _joinSuccessController = StreamController<int>.broadcast();
  final _localVideoStateController = StreamController<String>.broadcast();
  
  Stream<int> get onUserJoined => _userJoinedController.stream;
  Stream<int> get onUserLeft => _userLeftController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<String> get onConnectionStateChanged => _connectionStateController.stream;
  Stream<int> get onJoinSuccess => _joinSuccessController.stream;
  Stream<String> get onLocalVideoStateChanged => _localVideoStateController.stream;
  
  bool get isInitialized => _isInitialized;
  bool get isJoined => _isJoined;
  DateTime? get joinTimestamp => _joinTimestamp;

  static AgoraWebRuntimeStatus checkRuntimeStatus() {
    return const AgoraWebRuntimeStatus(
      sdkLoaded: false,
      secureContext: false,
      webRTCSupported: false,
    );
  }

  AgoraWebDiagnostics getDiagnostics() {
    return const AgoraWebDiagnostics();
  }

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
    _joinSuccessController.close();
    _localVideoStateController.close();
    _isInitialized = false;
    _isJoined = false;
  }
}
