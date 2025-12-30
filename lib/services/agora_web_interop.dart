// Agora Web SDK JavaScript Interop for Flutter Web
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';

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
);

/// Dart wrapper for Agora Web SDK JavaScript interop
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

  /// Initialize Agora Web SDK
  Future<bool> initialize({required bool isBroadcaster}) async {
    try {
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
    _isInitialized = false;
  }
}
