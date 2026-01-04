import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Debug panel for Agora diagnostics - only visible in debug builds
class AgoraDebugPanel extends StatefulWidget {
  final AgoraDiagnostics diagnostics;
  final VoidCallback? onClose;

  const AgoraDebugPanel({
    super.key,
    required this.diagnostics,
    this.onClose,
  });

  @override
  State<AgoraDebugPanel> createState() => _AgoraDebugPanelState();
}

class _AgoraDebugPanelState extends State<AgoraDebugPanel> {
  String _logContent = '';
  bool _showLogs = false;

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Configuration', [
                      _buildRow('App ID Present', widget.diagnostics.appIdPresent ? '✅ Yes' : '❌ No'),
                      _buildRow('App ID Length', '${widget.diagnostics.appIdLength}'),
                      _buildRow('Channel Name', widget.diagnostics.channelName.isNotEmpty ? widget.diagnostics.channelName : '(empty)'),
                      _buildRow('UID', '${widget.diagnostics.uid}'),
                      _buildRow('Token Present', widget.diagnostics.tokenPresent ? '✅ Yes' : '⚠️ No (using empty)'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Permissions', [
                      _buildRow('Camera', _permissionIcon(widget.diagnostics.cameraPermission)),
                      _buildRow('Microphone', _permissionIcon(widget.diagnostics.microphonePermission)),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Connection State', [
                      _buildRow('Engine Initialized', widget.diagnostics.engineInitialized ? '✅ Yes' : '❌ No'),
                      _buildRow('Connection State', widget.diagnostics.connectionState),
                      _buildRow('Join Status', widget.diagnostics.joinedChannel ? '✅ Joined' : '❌ Not joined'),
                      if (widget.diagnostics.joinTimestamp != null)
                        _buildRow('Joined At', _formatTime(widget.diagnostics.joinTimestamp)),
                      _buildRow('Client Role', widget.diagnostics.clientRole),
                      _buildRow('Channel Profile', widget.diagnostics.channelProfile),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Video State', [
                      _buildRow('Local Video State', widget.diagnostics.localVideoState),
                      _buildRow('Local Video Error', widget.diagnostics.localVideoError),
                      _buildRow('Preview Started', widget.diagnostics.previewStarted ? '✅ Yes' : '❌ No'),
                    ]),
                    if (widget.diagnostics.lastError.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSection('Last Error', [
                        _buildRow('Code', widget.diagnostics.lastErrorCode),
                        _buildRow('Message', widget.diagnostics.lastError),
                      ], isError: true),
                    ],
                    const SizedBox(height: 16),
                    _buildSection('Role Assertion', [
                      _buildRow(
                        'Host is Broadcaster',
                        widget.diagnostics.isBroadcasterRoleCorrect
                            ? '✅ Correct'
                            : '⚠️ WARNING: Host should be broadcaster!',
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildLogSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Color(0xFFBFAE01), size: 20),
          const SizedBox(width: 8),
          const Text(
            'Agora Debug Panel',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {bool isError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isError ? Colors.red : const Color(0xFFBFAE01),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isError ? Colors.red.withOpacity(0.1) : Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
            border: isError ? Border.all(color: Colors.red.withOpacity(0.5)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _permissionIcon(PermissionState state) {
    switch (state) {
      case PermissionState.granted:
        return '✅ Granted';
      case PermissionState.denied:
        return '❌ Denied';
      case PermissionState.permanentlyDenied:
        return '🚫 Permanently Denied';
      case PermissionState.restricted:
        return '⚠️ Restricted';
      case PermissionState.unknown:
        return '❓ Unknown';
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'N/A';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SDK Logs',
              style: TextStyle(
                color: const Color(0xFFBFAE01),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _loadLogs,
              child: Text(
                _showLogs ? 'Refresh' : 'Load Logs',
                style: const TextStyle(color: Color(0xFFBFAE01), fontSize: 12),
              ),
            ),
            if (_showLogs)
              TextButton(
                onPressed: _copyLogPath,
                child: const Text(
                  'Copy Path',
                  style: TextStyle(color: Color(0xFFBFAE01), fontSize: 12),
                ),
              ),
          ],
        ),
        if (_showLogs) ...[
          const SizedBox(height: 8),
          Container(
            height: 200,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(
                _logContent.isEmpty ? 'No logs available' : _logContent,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadLogs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logFile = File('${dir.path}/agora_sdk.log');
      
      if (await logFile.exists()) {
        final content = await logFile.readAsString();
        final lines = content.split('\n');
        final last50 = lines.length > 50 ? lines.sublist(lines.length - 50) : lines;
        setState(() {
          _logContent = last50.join('\n');
          _showLogs = true;
        });
      } else {
        setState(() {
          _logContent = 'Log file not found at: ${logFile.path}';
          _showLogs = true;
        });
      }
    } catch (e) {
      setState(() {
        _logContent = 'Error loading logs: $e';
        _showLogs = true;
      });
    }
  }

  Future<void> _copyLogPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logPath = '${dir.path}/agora_sdk.log';
      debugPrint('Agora log path: $logPath');
      // Show snackbar with path
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Log path: $logPath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting log path: $e');
    }
  }
}

/// Diagnostics data class for Agora state
class AgoraDiagnostics {
  final bool appIdPresent;
  final int appIdLength;
  final String channelName;
  final int uid;
  final bool tokenPresent;
  final PermissionState cameraPermission;
  final PermissionState microphonePermission;
  final bool engineInitialized;
  final String connectionState;
  final bool joinedChannel;
  final DateTime? joinTimestamp;
  final String clientRole;
  final String channelProfile;
  final String localVideoState;
  final String localVideoError;
  final bool previewStarted;
  final String lastError;
  final String lastErrorCode;
  final bool isBroadcasterRoleCorrect;

  const AgoraDiagnostics({
    this.appIdPresent = false,
    this.appIdLength = 0,
    this.channelName = '',
    this.uid = 0,
    this.tokenPresent = false,
    this.cameraPermission = PermissionState.unknown,
    this.microphonePermission = PermissionState.unknown,
    this.engineInitialized = false,
    this.connectionState = 'Disconnected',
    this.joinedChannel = false,
    this.joinTimestamp,
    this.clientRole = 'Unknown',
    this.channelProfile = 'Unknown',
    this.localVideoState = 'Unknown',
    this.localVideoError = 'None',
    this.previewStarted = false,
    this.lastError = '',
    this.lastErrorCode = '',
    this.isBroadcasterRoleCorrect = true,
  });

  AgoraDiagnostics copyWith({
    bool? appIdPresent,
    int? appIdLength,
    String? channelName,
    int? uid,
    bool? tokenPresent,
    PermissionState? cameraPermission,
    PermissionState? microphonePermission,
    bool? engineInitialized,
    String? connectionState,
    bool? joinedChannel,
    DateTime? joinTimestamp,
    String? clientRole,
    String? channelProfile,
    String? localVideoState,
    String? localVideoError,
    bool? previewStarted,
    String? lastError,
    String? lastErrorCode,
    bool? isBroadcasterRoleCorrect,
  }) {
    return AgoraDiagnostics(
      appIdPresent: appIdPresent ?? this.appIdPresent,
      appIdLength: appIdLength ?? this.appIdLength,
      channelName: channelName ?? this.channelName,
      uid: uid ?? this.uid,
      tokenPresent: tokenPresent ?? this.tokenPresent,
      cameraPermission: cameraPermission ?? this.cameraPermission,
      microphonePermission: microphonePermission ?? this.microphonePermission,
      engineInitialized: engineInitialized ?? this.engineInitialized,
      connectionState: connectionState ?? this.connectionState,
      joinedChannel: joinedChannel ?? this.joinedChannel,
      joinTimestamp: joinTimestamp ?? this.joinTimestamp,
      clientRole: clientRole ?? this.clientRole,
      channelProfile: channelProfile ?? this.channelProfile,
      localVideoState: localVideoState ?? this.localVideoState,
      localVideoError: localVideoError ?? this.localVideoError,
      previewStarted: previewStarted ?? this.previewStarted,
      lastError: lastError ?? this.lastError,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      isBroadcasterRoleCorrect: isBroadcasterRoleCorrect ?? this.isBroadcasterRoleCorrect,
    );
  }
}

enum PermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  restricted,
}
