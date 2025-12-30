// Agora Web SDK Wrapper for Flutter Web
// This provides JavaScript interop for the Agora RTC Web SDK

class AgoraWebClient {
  constructor() {
    this.client = null;
    this.localAudioTrack = null;
    this.localVideoTrack = null;
    this.remoteUsers = new Map();
    this.isJoined = false;
    this.isBroadcaster = false;
    
    // Event callbacks
    this.onUserJoined = null;
    this.onUserLeft = null;
    this.onError = null;
    this.onConnectionStateChanged = null;
  }

  async initialize(appId, isBroadcaster) {
    try {
      if (!window.AgoraRTC) {
        throw new Error('Agora Web SDK not loaded');
      }

      this.isBroadcaster = isBroadcaster;
      
      // Create client with live broadcasting profile
      this.client = AgoraRTC.createClient({ 
        mode: 'live', 
        codec: 'vp8' 
      });

      // Set client role
      await this.client.setClientRole(isBroadcaster ? 'host' : 'audience');

      // Set up event handlers
      this.client.on('user-published', async (user, mediaType) => {
        await this.client.subscribe(user, mediaType);
        console.log('Agora Web: Subscribed to user', user.uid, mediaType);
        
        if (mediaType === 'video') {
          this.remoteUsers.set(user.uid, user);
          if (this.onUserJoined) {
            this.onUserJoined(user.uid);
          }
        }
        if (mediaType === 'audio') {
          user.audioTrack?.play();
        }
      });

      this.client.on('user-unpublished', (user, mediaType) => {
        console.log('Agora Web: User unpublished', user.uid, mediaType);
        if (mediaType === 'video') {
          this.remoteUsers.delete(user.uid);
        }
      });

      this.client.on('user-left', (user) => {
        console.log('Agora Web: User left', user.uid);
        this.remoteUsers.delete(user.uid);
        if (this.onUserLeft) {
          this.onUserLeft(user.uid);
        }
      });

      this.client.on('connection-state-change', (curState, prevState) => {
        console.log('Agora Web: Connection state', prevState, '->', curState);
        if (this.onConnectionStateChanged) {
          this.onConnectionStateChanged(curState);
        }
      });

      this.client.on('exception', (event) => {
        console.error('Agora Web: Exception', event);
        if (this.onError) {
          this.onError(event.msg || 'Unknown error');
        }
      });

      console.log('Agora Web: Client initialized');
      return true;
    } catch (error) {
      console.error('Agora Web: Initialize error', error);
      if (this.onError) {
        this.onError(error.message);
      }
      return false;
    }
  }

  async createLocalTracks() {
    try {
      if (!this.isBroadcaster) {
        console.log('Agora Web: Not a broadcaster, skipping local tracks');
        return true;
      }

      // Create audio and video tracks
      [this.localAudioTrack, this.localVideoTrack] = await AgoraRTC.createMicrophoneAndCameraTracks(
        { encoderConfig: 'music_standard' },
        { 
          encoderConfig: '720p_2',
          facingMode: 'user'
        }
      );

      console.log('Agora Web: Local tracks created');
      return true;
    } catch (error) {
      console.error('Agora Web: Create tracks error', error);
      if (this.onError) {
        this.onError(error.message);
      }
      return false;
    }
  }

  async joinChannel(channelName, token, uid) {
    try {
      if (!this.client) {
        throw new Error('Client not initialized');
      }

      // Join the channel
      const appId = '371cf61b84c0427d84471c91e71435cd';
      await this.client.join(appId, channelName, token || null, uid);
      this.isJoined = true;
      console.log('Agora Web: Joined channel', channelName, 'as uid', uid);

      // Publish local tracks if broadcaster
      if (this.isBroadcaster && this.localAudioTrack && this.localVideoTrack) {
        await this.client.publish([this.localAudioTrack, this.localVideoTrack]);
        console.log('Agora Web: Published local tracks');
      }

      return true;
    } catch (error) {
      console.error('Agora Web: Join channel error', error);
      if (this.onError) {
        this.onError(error.message);
      }
      return false;
    }
  }

  async leaveChannel() {
    try {
      // Stop and close local tracks
      if (this.localAudioTrack) {
        this.localAudioTrack.stop();
        this.localAudioTrack.close();
        this.localAudioTrack = null;
      }
      if (this.localVideoTrack) {
        this.localVideoTrack.stop();
        this.localVideoTrack.close();
        this.localVideoTrack = null;
      }

      // Leave channel
      if (this.client && this.isJoined) {
        await this.client.leave();
        this.isJoined = false;
        console.log('Agora Web: Left channel');
      }

      this.remoteUsers.clear();
      return true;
    } catch (error) {
      console.error('Agora Web: Leave channel error', error);
      return false;
    }
  }

  playLocalVideo(containerId) {
    try {
      if (this.localVideoTrack) {
        this.localVideoTrack.play(containerId, { fit: 'cover' });
        console.log('Agora Web: Playing local video in', containerId);
        return true;
      }
      return false;
    } catch (error) {
      console.error('Agora Web: Play local video error', error);
      return false;
    }
  }

  playRemoteVideo(uid, containerId) {
    try {
      const user = this.remoteUsers.get(uid);
      if (user && user.videoTrack) {
        user.videoTrack.play(containerId, { fit: 'cover' });
        console.log('Agora Web: Playing remote video for uid', uid, 'in', containerId);
        return true;
      }
      return false;
    } catch (error) {
      console.error('Agora Web: Play remote video error', error);
      return false;
    }
  }

  async muteLocalAudio(muted) {
    try {
      if (this.localAudioTrack) {
        await this.localAudioTrack.setEnabled(!muted);
        console.log('Agora Web: Audio muted:', muted);
        return true;
      }
      return false;
    } catch (error) {
      console.error('Agora Web: Mute audio error', error);
      return false;
    }
  }

  async muteLocalVideo(muted) {
    try {
      if (this.localVideoTrack) {
        await this.localVideoTrack.setEnabled(!muted);
        console.log('Agora Web: Video muted:', muted);
        return true;
      }
      return false;
    } catch (error) {
      console.error('Agora Web: Mute video error', error);
      return false;
    }
  }

  async switchCamera() {
    try {
      if (this.localVideoTrack) {
        const devices = await AgoraRTC.getCameras();
        if (devices.length > 1) {
          const currentDevice = this.localVideoTrack.getTrackLabel();
          const currentIndex = devices.findIndex(d => d.label === currentDevice);
          const nextIndex = (currentIndex + 1) % devices.length;
          await this.localVideoTrack.setDevice(devices[nextIndex].deviceId);
          console.log('Agora Web: Switched camera to', devices[nextIndex].label);
          return true;
        }
      }
      return false;
    } catch (error) {
      console.error('Agora Web: Switch camera error', error);
      return false;
    }
  }

  getRemoteUserIds() {
    return Array.from(this.remoteUsers.keys());
  }

  dispose() {
    this.leaveChannel();
    this.client = null;
    console.log('Agora Web: Disposed');
  }
}

// Global instance for Flutter interop
window.agoraWebClient = null;

// Interop functions called from Dart
window.agoraWebInit = async function(isBroadcaster) {
  window.agoraWebClient = new AgoraWebClient();
  return await window.agoraWebClient.initialize('371cf61b84c0427d84471c91e71435cd', isBroadcaster);
};

window.agoraWebCreateTracks = async function() {
  if (window.agoraWebClient) {
    return await window.agoraWebClient.createLocalTracks();
  }
  return false;
};

window.agoraWebJoin = async function(channelName, token, uid) {
  if (window.agoraWebClient) {
    return await window.agoraWebClient.joinChannel(channelName, token, uid);
  }
  return false;
};

window.agoraWebLeave = async function() {
  if (window.agoraWebClient) {
    return await window.agoraWebClient.leaveChannel();
  }
  return false;
};

window.agoraWebPlayLocal = function(containerId) {
  if (window.agoraWebClient) {
    return window.agoraWebClient.playLocalVideo(containerId);
  }
  return false;
};

window.agoraWebPlayRemote = function(uid, containerId) {
  if (window.agoraWebClient) {
    return window.agoraWebClient.playRemoteVideo(uid, containerId);
  }
  return false;
};

window.agoraWebMuteAudio = async function(muted) {
  if (window.agoraWebClient) {
    return await window.agoraWebClient.muteLocalAudio(muted);
  }
  return false;
};

window.agoraWebMuteVideo = async function(muted) {
  if (window.agoraWebClient) {
    return await window.agoraWebClient.muteLocalVideo(muted);
  }
  return false;
};

window.agoraWebSwitchCamera = async function() {
  if (window.agoraWebClient) {
    return await window.agoraWebClient.switchCamera();
  }
  return false;
};

window.agoraWebGetRemoteUsers = function() {
  if (window.agoraWebClient) {
    return window.agoraWebClient.getRemoteUserIds();
  }
  return [];
};

window.agoraWebDispose = function() {
  if (window.agoraWebClient) {
    window.agoraWebClient.dispose();
    window.agoraWebClient = null;
  }
};

window.agoraWebSetCallbacks = function(onUserJoined, onUserLeft, onError, onConnectionStateChanged) {
  if (window.agoraWebClient) {
    window.agoraWebClient.onUserJoined = onUserJoined;
    window.agoraWebClient.onUserLeft = onUserLeft;
    window.agoraWebClient.onError = onError;
    window.agoraWebClient.onConnectionStateChanged = onConnectionStateChanged;
  }
};

console.log('Agora Web SDK wrapper loaded');
