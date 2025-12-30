import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'agora_web_interop.dart' if (dart.library.io) 'agora_service_stub.dart';

class AgoraService {
  static const String appId = '371cf61b84c0427d84471c91e71435cd';
  
  // Native engine (iOS/Android)
  RtcEngine? _engine;
  
  // Web service (browser)
  AgoraWebService? _webService;
  
  bool _isInitialized = false;
  bool _isWeb = false;
  
  // Stream controllers for events
  final _userJoinedController = StreamController<int>.broadcast();
  final _userOfflineController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionStateController = StreamController<ConnectionStateType>.broadcast();
  
  Stream<int> get onUserJoined => _userJoinedController.stream;
  Stream<int> get onUserOffline => _userOfflineController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<ConnectionStateType> get onConnectionStateChanged => _connectionStateController.stream;
  
  RtcEngine? get engine => _engine;
  AgoraWebService? get webService => _webService;
  bool get isInitialized => _isInitialized;
  bool get isWeb => _isWeb;

  Future<bool> requestPermissions() async {
    // On web, browser handles permissions via getUserMedia
    if (kIsWeb) {
      debugPrint('Agora: Web platform - browser will request permissions');
      return true;
    }
    
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      
      debugPrint('Agora: Camera permission: $cameraStatus');
      debugPrint('Agora: Microphone permission: $micStatus');
      
      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      debugPrint('Agora: Permission request error: $e');
      return false;
    }
  }

  Future<void> initialize({required bool isBroadcaster}) async {
    if (_isInitialized) return;
    
    _isWeb = kIsWeb;
    
    // Use web SDK on web platform
    if (kIsWeb) {
      try {
        debugPrint('Agora: Initializing Web SDK...');
        _webService = AgoraWebService();
        
        // Forward web service events to our controllers
        _webService!.onUserJoined.listen((uid) {
          debugPrint('Agora Web: Remote user $uid joined');
          _userJoinedController.add(uid);
        });
        _webService!.onUserLeft.listen((uid) {
          debugPrint('Agora Web: Remote user $uid left');
          _userOfflineController.add(uid);
        });
        _webService!.onError.listen((error) {
          debugPrint('Agora Web Error: $error');
          _errorController.add(error);
        });
        
        final success = await _webService!.initialize(isBroadcaster: isBroadcaster);
        if (!success) {
          throw Exception('Web SDK initialization failed');
        }
        
        _isInitialized = true;
        debugPrint('Agora: Web SDK initialized successfully');
        return;
      } catch (e, stack) {
        debugPrint('Agora: Web initialization error: $e');
        debugPrint('Agora: Stack trace: $stack');
        _isInitialized = false;
        rethrow;
      }
    }
    
    // Use native SDK on iOS/Android
    try {
      debugPrint('Agora: Creating native RTC engine...');
      _engine = createAgoraRtcEngine();
      
      debugPrint('Agora: Initializing with appId...');
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        areaCode: AreaCode.areaCodeGlob.value(),
      ));
      
      // Register event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('Agora: Joined channel ${connection.channelId}');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Agora: Remote user $remoteUid joined');
          _userJoinedController.add(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('Agora: Remote user $remoteUid left');
          _userOfflineController.add(remoteUid);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora Error: $err - $msg');
          _errorController.add('$err: $msg');
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('Agora: Connection state changed to $state');
          _connectionStateController.add(state);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('Agora: Token will expire soon');
        },
      ));
      
      // Set role based on broadcaster or audience
      debugPrint('Agora: Setting client role (broadcaster: $isBroadcaster)...');
      if (isBroadcaster) {
        await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await _engine!.enableVideo();
        await _engine!.enableAudio();
        await _engine!.startPreview();
      } else {
        await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
        await _engine!.enableVideo();
      }
      
      _isInitialized = true;
      debugPrint('Agora: Native SDK initialized successfully');
    } catch (e, stack) {
      debugPrint('Agora: Initialization error: $e');
      debugPrint('Agora: Stack trace: $stack');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> joinChannel({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora not initialized');
    }
    
    // Web platform
    if (_isWeb && _webService != null) {
      await _webService!.joinChannel(
        channelName: channelName,
        uid: uid,
        token: token,
      );
      return;
    }
    
    // Native platform
    if (_engine == null) {
      throw Exception('Agora engine not initialized');
    }
    
    await _engine!.joinChannel(
      token: token ?? '',
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> joinChannelAsViewer({
    required String channelName,
    required int uid,
    String? token,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora not initialized');
    }
    
    // Web platform
    if (_isWeb && _webService != null) {
      await _webService!.joinChannel(
        channelName: channelName,
        uid: uid,
        token: token,
      );
      return;
    }
    
    // Native platform
    if (_engine == null) {
      throw Exception('Agora engine not initialized');
    }
    
    await _engine!.joinChannel(
      token: token ?? '',
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        clientRoleType: ClientRoleType.clientRoleAudience,
      ),
    );
  }

  Future<void> leaveChannel() async {
    if (_isWeb && _webService != null) {
      await _webService!.leaveChannel();
      return;
    }
    if (_engine != null) {
      await _engine!.leaveChannel();
    }
  }

  Future<void> muteLocalAudio(bool muted) async {
    if (_isWeb && _webService != null) {
      await _webService!.muteLocalAudio(muted);
      return;
    }
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> muteLocalVideo(bool muted) async {
    if (_isWeb && _webService != null) {
      await _webService!.muteLocalVideo(muted);
      return;
    }
    await _engine?.muteLocalVideoStream(muted);
  }

  Future<void> switchCamera() async {
    if (_isWeb && _webService != null) {
      await _webService!.switchCamera();
      return;
    }
    await _engine?.switchCamera();
  }

  /// Play local video in a web container (web only)
  bool playLocalVideoWeb(String containerId) {
    if (_isWeb && _webService != null) {
      return _webService!.playLocalVideo(containerId);
    }
    return false;
  }

  /// Play remote video in a web container (web only)
  bool playRemoteVideoWeb(int uid, String containerId) {
    if (_isWeb && _webService != null) {
      return _webService!.playRemoteVideo(uid, containerId);
    }
    return false;
  }

  Future<void> dispose() async {
    if (_isWeb && _webService != null) {
      _webService!.dispose();
      _webService = null;
    }
    
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }
    
    _userJoinedController.close();
    _userOfflineController.close();
    _errorController.close();
    _connectionStateController.close();
    _isInitialized = false;
  }
}
