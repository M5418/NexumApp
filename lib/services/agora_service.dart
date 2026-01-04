import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/agora_debug_panel.dart';
import 'agora_web_interop.dart' if (dart.library.io) 'agora_service_stub.dart';

/// Result of Agora initialization
class AgoraInitResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;

  const AgoraInitResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
  });
}

/// Result of joining a channel
class AgoraJoinResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;
  final DateTime? joinTimestamp;

  const AgoraJoinResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
    this.joinTimestamp,
  });
}

/// Permission check result
class AgoraPermissionResult {
  final bool granted;
  final PermissionState cameraState;
  final PermissionState microphoneState;

  const AgoraPermissionResult({
    required this.granted,
    required this.cameraState,
    required this.microphoneState,
  });
}

class AgoraService {
  static const String appId = '371cf61b84c0427d84471c91e71435cd';
  
  // Native engine (iOS/Android)
  RtcEngine? _engine;
  
  // Web service (browser)
  AgoraWebService? _webService;
  
  bool _isInitialized = false;
  bool _isWeb = false;
  bool _isBroadcaster = false;
  bool _joinedChannel = false;
  bool _previewStarted = false;
  DateTime? _joinTimestamp;
  String _currentChannelName = '';
  int _currentUid = 0;
  String? _currentToken;
  
  // Permission states
  PermissionState _cameraPermission = PermissionState.unknown;
  PermissionState _microphonePermission = PermissionState.unknown;
  
  // Connection and video state
  String _connectionState = 'Disconnected';
  String _localVideoState = 'Stopped';
  String _localVideoError = 'None';
  String _lastError = '';
  String _lastErrorCode = '';
  
  // Stream controllers for events
  final _userJoinedController = StreamController<int>.broadcast();
  final _userOfflineController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<ConnectionStateType>.broadcast();
  final _joinSuccessController = StreamController<int>.broadcast();
  final _localVideoStateController = StreamController<LocalVideoStreamState>.broadcast();
  final _diagnosticsController = StreamController<AgoraDiagnostics>.broadcast();
  
  Stream<int> get onUserJoined => _userJoinedController.stream;
  Stream<int> get onUserOffline => _userOfflineController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<ConnectionStateType> get onConnectionStateChanged => _connectionStateController.stream;
  Stream<int> get onJoinChannelSuccess => _joinSuccessController.stream;
  Stream<LocalVideoStreamState> get onLocalVideoStateChanged => _localVideoStateController.stream;
  Stream<AgoraDiagnostics> get onDiagnosticsChanged => _diagnosticsController.stream;
  
  RtcEngine? get engine => _engine;
  AgoraWebService? get webService => _webService;
  bool get isInitialized => _isInitialized;
  bool get isWeb => _isWeb;
  bool get joinedChannel => _joinedChannel;
  DateTime? get joinTimestamp => _joinTimestamp;
  
  /// Get current diagnostics snapshot
  AgoraDiagnostics get diagnostics => AgoraDiagnostics(
    appIdPresent: appId.isNotEmpty,
    appIdLength: appId.length,
    channelName: _currentChannelName,
    uid: _currentUid,
    tokenPresent: _currentToken != null && _currentToken!.isNotEmpty,
    cameraPermission: _cameraPermission,
    microphonePermission: _microphonePermission,
    engineInitialized: _isInitialized,
    connectionState: _connectionState,
    joinedChannel: _joinedChannel,
    joinTimestamp: _joinTimestamp,
    clientRole: _isBroadcaster ? 'Broadcaster' : 'Audience',
    channelProfile: 'Live Broadcasting',
    localVideoState: _localVideoState,
    localVideoError: _localVideoError,
    previewStarted: _previewStarted,
    lastError: _lastError,
    lastErrorCode: _lastErrorCode,
    isBroadcasterRoleCorrect: !_isBroadcaster || (_isBroadcaster && _previewStarted),
  );

  void _emitDiagnostics() {
    if (!_diagnosticsController.isClosed) {
      _diagnosticsController.add(diagnostics);
    }
  }

  /// Validate inputs before joining
  String? validateInputs({
    required String channelName,
    required int uid,
    String? token,
  }) {
    if (appId.isEmpty) {
      return 'App ID is empty - check build configuration';
    }
    if (channelName.isEmpty) {
      return 'Channel name is empty';
    }
    if (uid <= 0) {
      return 'Invalid UID: $uid';
    }
    // Token can be empty for testing mode
    return null;
  }

  /// Request camera and microphone permissions
  Future<AgoraPermissionResult> requestPermissions() async {
    // On web, browser handles permissions via getUserMedia
    if (kIsWeb) {
      debugPrint('Agora: Web platform - browser will request permissions');
      _cameraPermission = PermissionState.granted;
      _microphonePermission = PermissionState.granted;
      _emitDiagnostics();
      return const AgoraPermissionResult(
        granted: true,
        cameraState: PermissionState.granted,
        microphoneState: PermissionState.granted,
      );
    }
    
    try {
      debugPrint('Agora: Requesting camera permission...');
      final cameraStatus = await Permission.camera.request();
      debugPrint('Agora: Camera permission: $cameraStatus');
      
      debugPrint('Agora: Requesting microphone permission...');
      final micStatus = await Permission.microphone.request();
      debugPrint('Agora: Microphone permission: $micStatus');
      
      _cameraPermission = _mapPermissionStatus(cameraStatus);
      _microphonePermission = _mapPermissionStatus(micStatus);
      
      final granted = cameraStatus.isGranted && micStatus.isGranted;
      
      if (!granted) {
        _lastError = 'Permissions not granted - Camera: $cameraStatus, Mic: $micStatus';
        _lastErrorCode = 'PERMISSION_DENIED';
      }
      
      _emitDiagnostics();
      
      return AgoraPermissionResult(
        granted: granted,
        cameraState: _cameraPermission,
        microphoneState: _microphonePermission,
      );
    } catch (e) {
      debugPrint('Agora: Permission request error: $e');
      _lastError = 'Permission request failed: $e';
      _lastErrorCode = 'PERMISSION_ERROR';
      _emitDiagnostics();
      return const AgoraPermissionResult(
        granted: false,
        cameraState: PermissionState.unknown,
        microphoneState: PermissionState.unknown,
      );
    }
  }

  PermissionState _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return PermissionState.granted;
      case PermissionStatus.denied:
        return PermissionState.denied;
      case PermissionStatus.permanentlyDenied:
        return PermissionState.permanentlyDenied;
      case PermissionStatus.restricted:
        return PermissionState.restricted;
      default:
        return PermissionState.unknown;
    }
  }

  /// Configure SDK logging to file
  Future<void> _configureLogging() async {
    if (kIsWeb || _engine == null) return;
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logPath = '${dir.path}/agora_sdk.log';
      debugPrint('Agora: Configuring SDK logging to: $logPath');
      
      await _engine!.setLogFile(logPath);
      await _engine!.setLogFileSize(1024); // 1MB max
      await _engine!.setLogLevel(LogLevel.logLevelInfo);
      
      debugPrint('Agora: SDK logging configured successfully');
    } catch (e) {
      debugPrint('Agora: Failed to configure logging: $e');
    }
  }

  /// Initialize Agora SDK
  Future<AgoraInitResult> initialize({required bool isBroadcaster}) async {
    if (_isInitialized) {
      return const AgoraInitResult(success: true);
    }
    
    _isBroadcaster = isBroadcaster;
    _isWeb = kIsWeb;
    
    // Validate app ID
    if (appId.isEmpty) {
      _lastError = 'App ID is empty - check --dart-define or build configuration';
      _lastErrorCode = 'INVALID_APP_ID';
      _emitDiagnostics();
      return AgoraInitResult(
        success: false,
        errorMessage: _lastError,
        errorCode: _lastErrorCode,
      );
    }
    
    debugPrint('Agora: App ID present, length: ${appId.length}');
    
    // Use web SDK on web platform
    if (kIsWeb) {
      try {
        debugPrint('Agora: Initializing Web SDK...');
        
        // Check web runtime status first
        final runtimeStatus = AgoraWebService.checkRuntimeStatus();
        if (!runtimeStatus.isReady) {
          _lastError = runtimeStatus.errorMessage ?? 'Web runtime not ready';
          _lastErrorCode = 'WEB_RUNTIME_NOT_READY';
          _emitDiagnostics();
          return AgoraInitResult(
            success: false,
            errorMessage: _lastError,
            errorCode: _lastErrorCode,
          );
        }
        
        _webService = AgoraWebService();
        
        final webSvc = _webService;
        if (webSvc == null) {
          throw Exception('Failed to create web service');
        }
        
        // Forward web service events to our controllers
        webSvc.onUserJoined.listen((uid) {
          debugPrint('Agora Web: Remote user $uid joined');
          _userJoinedController.add(uid);
        });
        webSvc.onUserLeft.listen((uid) {
          debugPrint('Agora Web: Remote user $uid left');
          _userOfflineController.add(uid);
        });
        webSvc.onError.listen((error) {
          debugPrint('Agora Web Error: $error');
          _lastError = error;
          _lastErrorCode = 'WEB_ERROR';
          _errorController.add(error);
          _emitDiagnostics();
        });
        webSvc.onConnectionStateChanged.listen((state) {
          debugPrint('Agora Web: Connection state changed to $state');
          _connectionState = state;
          _emitDiagnostics();
        });
        // Forward join success from web service
        webSvc.onJoinSuccess.listen((uid) {
          debugPrint('Agora Web: ✅ Join success, uid: $uid');
          _joinedChannel = true;
          _joinTimestamp = DateTime.now();
          _connectionState = 'CONNECTED';
          _joinSuccessController.add(uid);
          _emitDiagnostics();
        });
        webSvc.onLocalVideoStateChanged.listen((state) {
          debugPrint('Agora Web: Local video state: $state');
          _localVideoState = state;
          _emitDiagnostics();
        });
        
        final success = await webSvc.initialize(isBroadcaster: isBroadcaster);
        if (!success) {
          throw Exception('Web SDK initialization failed');
        }
        
        _isInitialized = true;
        _previewStarted = isBroadcaster; // Web creates tracks during init for broadcaster
        debugPrint('Agora: ✅ Web SDK initialized successfully');
        _emitDiagnostics();
        return const AgoraInitResult(success: true);
      } catch (e, stack) {
        debugPrint('Agora: ❌ Web initialization error: $e');
        debugPrint('Agora: Stack trace: $stack');
        _isInitialized = false;
        _lastError = 'Web initialization failed: $e';
        _lastErrorCode = 'WEB_INIT_FAILED';
        _emitDiagnostics();
        return AgoraInitResult(
          success: false,
          errorMessage: _lastError,
          errorCode: _lastErrorCode,
        );
      }
    }
    
    // Use native SDK on iOS/Android
    try {
      debugPrint('Agora: Creating native RTC engine...');
      _engine = createAgoraRtcEngine();
      
      final eng = _engine;
      if (eng == null) {
        throw Exception('Failed to create RTC engine');
      }
      
      debugPrint('Agora: Initializing with appId (length: ${appId.length})...');
      await eng.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        areaCode: AreaCode.areaCodeGlob.value(),
      ));
      
      // Configure logging
      await _configureLogging();
      
      // Register event handlers with comprehensive callbacks
      eng.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('Agora: ✅ onJoinChannelSuccess - channel: ${connection.channelId}, elapsed: ${elapsed}ms');
          _joinedChannel = true;
          _joinTimestamp = DateTime.now();
          _connectionState = 'Connected';
          _joinSuccessController.add(elapsed);
          _emitDiagnostics();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Agora: Remote user $remoteUid joined');
          _userJoinedController.add(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('Agora: Remote user $remoteUid left, reason: $reason');
          _userOfflineController.add(remoteUid);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora: ❌ onError - code: $err, message: $msg');
          _lastError = msg;
          _lastErrorCode = err.toString();
          _errorController.add('$err: $msg');
          _emitDiagnostics();
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('Agora: 🔄 onConnectionStateChanged - state: $state, reason: $reason');
          _connectionState = _mapConnectionState(state);
          _connectionStateController.add(state);
          
          if (state == ConnectionStateType.connectionStateFailed) {
            _joinedChannel = false;
            _lastError = 'Connection failed: $reason';
            _lastErrorCode = reason.toString();
          }
          _emitDiagnostics();
        },
        onLocalVideoStateChanged: (VideoSourceType source, LocalVideoStreamState state, LocalVideoStreamReason reason) {
          debugPrint('Agora: 📹 onLocalVideoStateChanged - source: $source, state: $state, reason: $reason');
          _localVideoState = _mapLocalVideoState(state);
          _localVideoError = _mapLocalVideoReason(reason);
          _localVideoStateController.add(state);
          _emitDiagnostics();
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('Agora: ⚠️ Token will expire soon');
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('Agora: Left channel - duration: ${stats.duration}s');
          _joinedChannel = false;
          _connectionState = 'Disconnected';
          _emitDiagnostics();
        },
      ));
      
      // Set role based on broadcaster or audience
      debugPrint('Agora: Setting client role (broadcaster: $isBroadcaster)...');
      if (isBroadcaster) {
        await eng.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        debugPrint('Agora: Enabling video...');
        await eng.enableVideo();
        debugPrint('Agora: Enabling audio...');
        await eng.enableAudio();
        debugPrint('Agora: Starting preview...');
        await eng.startPreview();
        _previewStarted = true;
        debugPrint('Agora: ✅ Preview started successfully');
      } else {
        await eng.setClientRole(role: ClientRoleType.clientRoleAudience);
        await eng.enableVideo();
      }
      
      _isInitialized = true;
      debugPrint('Agora: ✅ Native SDK initialized successfully');
      _emitDiagnostics();
      return const AgoraInitResult(success: true);
    } catch (e, stack) {
      debugPrint('Agora: ❌ Initialization error: $e');
      debugPrint('Agora: Stack trace: $stack');
      _isInitialized = false;
      _lastError = 'Initialization failed: $e';
      _lastErrorCode = 'INIT_FAILED';
      _emitDiagnostics();
      return AgoraInitResult(
        success: false,
        errorMessage: _lastError,
        errorCode: _lastErrorCode,
      );
    }
  }

  String _mapConnectionState(ConnectionStateType state) {
    switch (state) {
      case ConnectionStateType.connectionStateDisconnected:
        return 'Disconnected';
      case ConnectionStateType.connectionStateConnecting:
        return 'Connecting';
      case ConnectionStateType.connectionStateConnected:
        return 'Connected';
      case ConnectionStateType.connectionStateReconnecting:
        return 'Reconnecting';
      case ConnectionStateType.connectionStateFailed:
        return 'Failed';
    }
  }

  String _mapLocalVideoState(LocalVideoStreamState state) {
    switch (state) {
      case LocalVideoStreamState.localVideoStreamStateStopped:
        return 'Stopped';
      case LocalVideoStreamState.localVideoStreamStateCapturing:
        return 'Capturing';
      case LocalVideoStreamState.localVideoStreamStateEncoding:
        return 'Encoding';
      case LocalVideoStreamState.localVideoStreamStateFailed:
        return 'Failed';
    }
  }

  String _mapLocalVideoReason(LocalVideoStreamReason reason) {
    switch (reason) {
      case LocalVideoStreamReason.localVideoStreamReasonOk:
        return 'None';
      case LocalVideoStreamReason.localVideoStreamReasonFailure:
        return 'General failure';
      case LocalVideoStreamReason.localVideoStreamReasonDeviceNoPermission:
        return 'No camera permission';
      case LocalVideoStreamReason.localVideoStreamReasonDeviceBusy:
        return 'Camera busy';
      case LocalVideoStreamReason.localVideoStreamReasonCaptureFailure:
        return 'Capture failure';
      case LocalVideoStreamReason.localVideoStreamReasonCodecNotSupport:
        return 'Codec not supported';
      default:
        return reason.toString();
    }
  }

  /// Join channel as broadcaster (host)
  Future<AgoraJoinResult> joinChannel({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    // Validate inputs
    final validationError = validateInputs(
      channelName: channelName,
      uid: uid,
      token: token,
    );
    if (validationError != null) {
      _lastError = validationError;
      _lastErrorCode = 'VALIDATION_ERROR';
      _emitDiagnostics();
      return AgoraJoinResult(
        success: false,
        errorMessage: validationError,
        errorCode: 'VALIDATION_ERROR',
      );
    }
    
    if (!_isInitialized) {
      _lastError = 'Agora not initialized';
      _lastErrorCode = 'NOT_INITIALIZED';
      _emitDiagnostics();
      return const AgoraJoinResult(
        success: false,
        errorMessage: 'Agora not initialized',
        errorCode: 'NOT_INITIALIZED',
      );
    }
    
    _currentChannelName = channelName;
    _currentUid = uid;
    _currentToken = token;
    _emitDiagnostics();
    
    debugPrint('Agora: Joining channel "$channelName" with uid: $uid, token present: ${token != null && token.isNotEmpty}');
    
    // Web platform
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        try {
          await webSvc.joinChannel(
            channelName: channelName,
            uid: uid,
            token: token,
          );
          _joinedChannel = true;
          _joinTimestamp = DateTime.now();
          _emitDiagnostics();
          return AgoraJoinResult(
            success: true,
            joinTimestamp: _joinTimestamp,
          );
        } catch (e) {
          _lastError = 'Web join failed: $e';
          _lastErrorCode = 'WEB_JOIN_FAILED';
          _emitDiagnostics();
          return AgoraJoinResult(
            success: false,
            errorMessage: _lastError,
            errorCode: _lastErrorCode,
          );
        }
      }
      return const AgoraJoinResult(
        success: false,
        errorMessage: 'Web service not available',
        errorCode: 'NO_WEB_SERVICE',
      );
    }
    
    // Native platform
    final eng = _engine;
    if (eng == null) {
      _lastError = 'Agora engine not initialized';
      _lastErrorCode = 'NO_ENGINE';
      _emitDiagnostics();
      return const AgoraJoinResult(
        success: false,
        errorMessage: 'Agora engine not initialized',
        errorCode: 'NO_ENGINE',
      );
    }
    
    try {
      debugPrint('Agora: Calling joinChannel...');
      await eng.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          // Set ultra low latency for live broadcasting
          audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );
      debugPrint('Agora: joinChannel call completed, waiting for onJoinChannelSuccess callback...');
      // Note: _joinedChannel will be set to true in onJoinChannelSuccess callback
      return const AgoraJoinResult(success: true);
    } catch (e) {
      debugPrint('Agora: ❌ joinChannel error: $e');
      _lastError = 'Join failed: $e';
      _lastErrorCode = 'JOIN_EXCEPTION';
      _emitDiagnostics();
      return AgoraJoinResult(
        success: false,
        errorMessage: _lastError,
        errorCode: _lastErrorCode,
      );
    }
  }

  /// Join channel as viewer (audience)
  Future<AgoraJoinResult> joinChannelAsViewer({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    // Validate inputs
    final validationError = validateInputs(
      channelName: channelName,
      uid: uid,
      token: token,
    );
    if (validationError != null) {
      _lastError = validationError;
      _lastErrorCode = 'VALIDATION_ERROR';
      _emitDiagnostics();
      return AgoraJoinResult(
        success: false,
        errorMessage: validationError,
        errorCode: 'VALIDATION_ERROR',
      );
    }
    
    if (!_isInitialized) {
      _lastError = 'Agora not initialized';
      _lastErrorCode = 'NOT_INITIALIZED';
      _emitDiagnostics();
      return const AgoraJoinResult(
        success: false,
        errorMessage: 'Agora not initialized',
        errorCode: 'NOT_INITIALIZED',
      );
    }
    
    _currentChannelName = channelName;
    _currentUid = uid;
    _currentToken = token;
    _emitDiagnostics();
    
    // Web platform
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        try {
          await webSvc.joinChannel(
            channelName: channelName,
            uid: uid,
            token: token,
          );
          _joinedChannel = true;
          _joinTimestamp = DateTime.now();
          _emitDiagnostics();
          return AgoraJoinResult(
            success: true,
            joinTimestamp: _joinTimestamp,
          );
        } catch (e) {
          _lastError = 'Web join failed: $e';
          _lastErrorCode = 'WEB_JOIN_FAILED';
          _emitDiagnostics();
          return AgoraJoinResult(
            success: false,
            errorMessage: _lastError,
            errorCode: _lastErrorCode,
          );
        }
      }
      return const AgoraJoinResult(
        success: false,
        errorMessage: 'Web service not available',
        errorCode: 'NO_WEB_SERVICE',
      );
    }
    
    // Native platform
    final eng = _engine;
    if (eng == null) {
      _lastError = 'Agora engine not initialized';
      _lastErrorCode = 'NO_ENGINE';
      _emitDiagnostics();
      return const AgoraJoinResult(
        success: false,
        errorMessage: 'Agora engine not initialized',
        errorCode: 'NO_ENGINE',
      );
    }
    
    try {
      await eng.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          clientRoleType: ClientRoleType.clientRoleAudience,
          // Set ultra low latency for audience as per Agora documentation
          audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );
      return const AgoraJoinResult(success: true);
    } catch (e) {
      _lastError = 'Join failed: $e';
      _lastErrorCode = 'JOIN_EXCEPTION';
      _emitDiagnostics();
      return AgoraJoinResult(
        success: false,
        errorMessage: _lastError,
        errorCode: _lastErrorCode,
      );
    }
  }

  Future<void> leaveChannel() async {
    debugPrint('Agora: Leaving channel...');
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        await webSvc.leaveChannel();
      }
      _joinedChannel = false;
      _emitDiagnostics();
      return;
    }
    final eng = _engine;
    if (eng != null) {
      await eng.leaveChannel();
    }
    _joinedChannel = false;
    _emitDiagnostics();
  }

  Future<void> muteLocalAudio(bool muted) async {
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        await webSvc.muteLocalAudio(muted);
      }
      return;
    }
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> muteLocalVideo(bool muted) async {
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        await webSvc.muteLocalVideo(muted);
      }
      return;
    }
    await _engine?.muteLocalVideoStream(muted);
  }

  Future<void> switchCamera() async {
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        await webSvc.switchCamera();
      }
      return;
    }
    await _engine?.switchCamera();
  }

  /// Play local video in a web container (web only)
  bool playLocalVideoWeb(String containerId) {
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        return webSvc.playLocalVideo(containerId);
      }
    }
    return false;
  }

  /// Play remote video in a web container (web only)
  bool playRemoteVideoWeb(int uid, String containerId) {
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        return webSvc.playRemoteVideo(uid, containerId);
      }
    }
    return false;
  }

  Future<void> dispose() async {
    debugPrint('Agora: Disposing service...');
    
    if (_isWeb) {
      final webSvc = _webService;
      if (webSvc != null) {
        webSvc.dispose();
        _webService = null;
      }
    }
    
    final eng = _engine;
    if (eng != null) {
      try {
        await eng.leaveChannel();
        await eng.release();
      } catch (e) {
        debugPrint('Agora: Error during dispose: $e');
      }
      _engine = null;
    }
    
    _userJoinedController.close();
    _userOfflineController.close();
    _errorController.close();
    _connectionStateController.close();
    _joinSuccessController.close();
    _localVideoStateController.close();
    _diagnosticsController.close();
    
    _isInitialized = false;
    _joinedChannel = false;
    _previewStarted = false;
    debugPrint('Agora: Service disposed');
  }
}
