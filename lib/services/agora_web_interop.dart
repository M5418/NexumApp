// Agora Web SDK JavaScript Interop for Flutter Web
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('agoraWebInit')
external JSPromise<JSBoolean> _agoraWebInit(JSBoolean isBroadcaster);

@JS('agoraWebCreateTracks')
external JSPromise<JSBoolean> _agoraWebCreateTracks();

@JS('agoraWebJoin')
external JSPromise<JSBoolean> _agoraWebJoin(JSString channelName, JSString? token, JSNumber uid);

@JS('agoraWebLeave')
external JSPromise<JSBoolean> _agoraWebLeave();

@JS('agoraWebPlayLocal')
external JSBoolean _agoraWebPlayLocal(JSString containerId);

@JS('agoraWebPlayRemote')
external JSBoolean _agoraWebPlayRemote(JSNumber uid, JSString containerId);

@JS('agoraWebMuteAudio')
external JSPromise<JSBoolean> _agoraWebMuteAudio(JSBoolean muted);

@JS('agoraWebMuteVideo')
external JSPromise<JSBoolean> _agoraWebMuteVideo(JSBoolean muted);

@JS('agoraWebSwitchCamera')
external JSPromise<JSBoolean> _agoraWebSwitchCamera();

@JS('agoraWebGetRemoteUsers')
external JSArray<JSNumber> _agoraWebGetRemoteUsers();

@JS('agoraWebDispose')
external void _agoraWebDispose();

@JS('agoraWebSetCallbacks')
external void _agoraWebSetCallbacks(
  JSFunction? onUserJoined,
  JSFunction? onUserLeft,
  JSFunction? onError,
  JSFunction? onConnectionStateChanged,
  JSFunction? onJoinSuccess,
  JSFunction? onLocalVideoStateChanged,
);

@JS('agoraWebIsRuntimeReady')
external JSObject? _agoraWebIsRuntimeReady();

@JS('agoraWebGetDiagnostics')
external JSObject? _agoraWebGetDiagnostics();

/// Result of checking Agora Web runtime status
class AgoraWebRuntimeStatus {
  final bool sdkLoaded;
  final bool secureContext;
  final bool webRTCSupported;

  const AgoraWebRuntimeStatus({
    required this.sdkLoaded,
    required this.secureContext,
    required this.webRTCSupported,
  });

  bool get isReady => sdkLoaded && secureContext && webRTCSupported;

  String? get errorMessage {
    if (!sdkLoaded) return 'Agora Web SDK not loaded. Check index.html script tags.';
    if (!secureContext) return 'WebRTC requires HTTPS or localhost. Current origin is not secure.';
    if (!webRTCSupported) return 'WebRTC is not supported in this browser.';
    return null;
  }
}

/// Web diagnostics data
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

/// Dart wrapper for Agora Web SDK JavaScript interop
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

  /// Check if Agora Web runtime is ready
  static AgoraWebRuntimeStatus checkRuntimeStatus() {
    try {
      final result = _agoraWebIsRuntimeReady();
      if (result == null) {
        return const AgoraWebRuntimeStatus(
          sdkLoaded: false,
          secureContext: false,
          webRTCSupported: false,
        );
      }
      
      final sdkLoaded = _getBoolProperty(result, 'sdkLoaded');
      final secureContext = _getBoolProperty(result, 'secureContext');
      final webRTCSupported = _getBoolProperty(result, 'webRTCSupported');
      
      return AgoraWebRuntimeStatus(
        sdkLoaded: sdkLoaded,
        secureContext: secureContext,
        webRTCSupported: webRTCSupported,
      );
    } catch (e) {
      return const AgoraWebRuntimeStatus(
        sdkLoaded: false,
        secureContext: false,
        webRTCSupported: false,
      );
    }
  }

  static bool _getBoolProperty(JSObject obj, String key) {
    final value = obj[key];
    if (value == null) return false;
    if (value.isA<JSBoolean>()) return (value as JSBoolean).toDart;
    return false;
  }

  static String _getStringProperty(JSObject obj, String key, String defaultValue) {
    final value = obj[key];
    if (value == null) return defaultValue;
    if (value.isA<JSString>()) return (value as JSString).toDart;
    return defaultValue;
  }

  static String? _getStringPropertyNullable(JSObject obj, String key) {
    final value = obj[key];
    if (value == null || value.isUndefinedOrNull) return null;
    if (value.isA<JSString>()) return (value as JSString).toDart;
    return null;
  }

  static int _getIntProperty(JSObject obj, String key, int defaultValue) {
    final value = obj[key];
    if (value == null) return defaultValue;
    if (value.isA<JSNumber>()) return (value as JSNumber).toDartInt;
    return defaultValue;
  }

  static int? _getIntPropertyNullable(JSObject obj, String key) {
    final value = obj[key];
    if (value == null || value.isUndefinedOrNull) return null;
    if (value.isA<JSNumber>()) return (value as JSNumber).toDartInt;
    return null;
  }

  /// Get current diagnostics
  AgoraWebDiagnostics getDiagnostics() {
    try {
      final result = _agoraWebGetDiagnostics();
      if (result == null) {
        return const AgoraWebDiagnostics();
      }
      
      return AgoraWebDiagnostics(
        isJoined: _getBoolProperty(result, 'isJoined'),
        isBroadcaster: _getBoolProperty(result, 'isBroadcaster'),
        connectionState: _getStringProperty(result, 'connectionState', 'DISCONNECTED'),
        joinTimestamp: _getIntPropertyNullable(result, 'joinTimestamp'),
        lastError: _getStringPropertyNullable(result, 'lastError'),
        lastErrorCode: _getStringPropertyNullable(result, 'lastErrorCode'),
        remoteUserCount: _getIntProperty(result, 'remoteUserCount', 0),
        hasLocalVideo: _getBoolProperty(result, 'hasLocalVideo'),
        hasLocalAudio: _getBoolProperty(result, 'hasLocalAudio'),
      );
    } catch (e) {
      return const AgoraWebDiagnostics();
    }
  }

  /// Initialize Agora Web SDK
  Future<bool> initialize({required bool isBroadcaster}) async {
    try {
      // Check runtime first
      final runtimeStatus = checkRuntimeStatus();
      if (!runtimeStatus.isReady) {
        _errorController.add(runtimeStatus.errorMessage ?? 'Runtime not ready');
        return false;
      }
      
      // Set up callbacks
      _agoraWebSetCallbacks(
        ((JSNumber uid) {
          _userJoinedController.add(uid.toDartInt);
        }).toJS,
        ((JSNumber uid) {
          _userLeftController.add(uid.toDartInt);
        }).toJS,
        ((JSString error) {
          _errorController.add(error.toDart);
        }).toJS,
        ((JSString state) {
          _connectionStateController.add(state.toDart);
        }).toJS,
        ((JSNumber uid, JSString channel) {
          _isJoined = true;
          _joinTimestamp = DateTime.now();
          _joinSuccessController.add(uid.toDartInt);
        }).toJS,
        ((JSString state) {
          _localVideoStateController.add(state.toDart);
        }).toJS,
      );
      
      final result = await _agoraWebInit(isBroadcaster.toJS).toDart;
      if (!result.toDart) {
        return false;
      }
      
      // Create local tracks for broadcaster
      if (isBroadcaster) {
        final tracksResult = await _agoraWebCreateTracks().toDart;
        if (!tracksResult.toDart) {
          return false;
        }
      }
      
      _isInitialized = true;
      return true;
    } catch (e) {
      _errorController.add('Initialize error: $e');
      return false;
    }
  }

  /// Join a channel
  Future<bool> joinChannel({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    try {
      final result = await _agoraWebJoin(
        channelName.toJS,
        token?.toJS,
        uid.toJS,
      ).toDart;
      return result.toDart;
    } catch (e) {
      _errorController.add('Join error: $e');
      return false;
    }
  }

  /// Leave the channel
  Future<bool> leaveChannel() async {
    try {
      final result = await _agoraWebLeave().toDart;
      return result.toDart;
    } catch (e) {
      _errorController.add('Leave error: $e');
      return false;
    }
  }

  /// Play local video in a container element
  bool playLocalVideo(String containerId) {
    try {
      return _agoraWebPlayLocal(containerId.toJS).toDart;
    } catch (e) {
      _errorController.add('Play local video error: $e');
      return false;
    }
  }

  /// Play remote user's video in a container element
  bool playRemoteVideo(int uid, String containerId) {
    try {
      return _agoraWebPlayRemote(uid.toJS, containerId.toJS).toDart;
    } catch (e) {
      _errorController.add('Play remote video error: $e');
      return false;
    }
  }

  /// Mute/unmute local audio
  Future<bool> muteLocalAudio(bool muted) async {
    try {
      final result = await _agoraWebMuteAudio(muted.toJS).toDart;
      return result.toDart;
    } catch (e) {
      _errorController.add('Mute audio error: $e');
      return false;
    }
  }

  /// Mute/unmute local video
  Future<bool> muteLocalVideo(bool muted) async {
    try {
      final result = await _agoraWebMuteVideo(muted.toJS).toDart;
      return result.toDart;
    } catch (e) {
      _errorController.add('Mute video error: $e');
      return false;
    }
  }

  /// Switch camera (if multiple cameras available)
  Future<bool> switchCamera() async {
    try {
      final result = await _agoraWebSwitchCamera().toDart;
      return result.toDart;
    } catch (e) {
      _errorController.add('Switch camera error: $e');
      return false;
    }
  }

  /// Get list of remote user IDs
  List<int> getRemoteUserIds() {
    try {
      final jsArray = _agoraWebGetRemoteUsers();
      return jsArray.toDart.map((e) => e.toDartInt).toList();
    } catch (e) {
      return [];
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _agoraWebDispose();
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
