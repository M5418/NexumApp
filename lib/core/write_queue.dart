import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Represents a pending write operation
class PendingWrite {
  final String id;
  final String collection;
  final String documentId;
  final WriteOperation operation;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastRetryAt;

  PendingWrite({
    required this.id,
    required this.collection,
    required this.documentId,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastRetryAt,
  });

  PendingWrite copyWith({
    int? retryCount,
    DateTime? lastRetryAt,
  }) {
    return PendingWrite(
      id: id,
      collection: collection,
      documentId: documentId,
      operation: operation,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'documentId': documentId,
    'operation': operation.name,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'lastRetryAt': lastRetryAt?.toIso8601String(),
  };

  factory PendingWrite.fromJson(Map<String, dynamic> json) {
    return PendingWrite(
      id: json['id'] as String,
      collection: json['collection'] as String,
      documentId: json['documentId'] as String,
      operation: WriteOperation.values.firstWhere(
        (e) => e.name == json['operation'],
        orElse: () => WriteOperation.create,
      ),
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastRetryAt: json['lastRetryAt'] != null 
          ? DateTime.parse(json['lastRetryAt'] as String)
          : null,
    );
  }
}

enum WriteOperation { create, update, delete }

/// Callback type for executing writes
typedef WriteExecutor = Future<void> Function(PendingWrite write);

/// Outbox queue for optimistic writes with retry and conflict resolution.
/// Writes are persisted locally and synced to Firestore in background.
class WriteQueue {
  static final WriteQueue _instance = WriteQueue._internal();
  factory WriteQueue() => _instance;
  WriteQueue._internal();

  final Queue<PendingWrite> _queue = Queue();
  final Map<String, WriteExecutor> _executors = {};
  bool _isProcessing = false;
  Timer? _retryTimer;
  SharedPreferences? _prefs;

  static const String _storageKey = 'pending_writes';
  static const int _maxRetries = 5;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  /// Stream of queue status updates
  final StreamController<WriteQueueStatus> _statusController = 
      StreamController<WriteQueueStatus>.broadcast();
  Stream<WriteQueueStatus> get statusStream => _statusController.stream;

  /// Initialize the queue and restore pending writes
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _restorePendingWrites();
    _startRetryTimer();
    _debugLog('✅ WriteQueue initialized with ${_queue.length} pending writes');
  }

  /// Register an executor for a collection
  void registerExecutor(String collection, WriteExecutor executor) {
    _executors[collection] = executor;
  }

  /// Add a write to the queue (optimistic - returns immediately)
  String enqueue({
    required String collection,
    required String documentId,
    required WriteOperation operation,
    required Map<String, dynamic> data,
  }) {
    final id = '${collection}_${documentId}_${DateTime.now().millisecondsSinceEpoch}';
    final write = PendingWrite(
      id: id,
      collection: collection,
      documentId: documentId,
      operation: operation,
      data: data,
      createdAt: DateTime.now(),
    );

    _queue.add(write);
    _persistQueue();
    _emitStatus();
    _processQueue();

    _debugLog('📝 Enqueued ${operation.name} for $collection/$documentId');
    return id;
  }

  /// Process the queue (non-blocking)
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final write = _queue.first;
      final executor = _executors[write.collection];

      if (executor == null) {
        _debugLog('⚠️ No executor for ${write.collection}, skipping');
        _queue.removeFirst();
        continue;
      }

      // Check if we should retry based on backoff
      if (write.retryCount > 0 && write.lastRetryAt != null) {
        final backoff = _calculateBackoff(write.retryCount);
        final lastRetry = write.lastRetryAt;
        if (lastRetry == null) continue;
        final nextRetry = lastRetry.add(backoff);
        if (DateTime.now().isBefore(nextRetry)) {
          // Not ready to retry yet, move to end of queue
          _queue.removeFirst();
          _queue.add(write);
          break;
        }
      }

      try {
        await executor(write);
        _queue.removeFirst();
        _persistQueue();
        _emitStatus();
        _debugLog('✅ Completed ${write.operation.name} for ${write.collection}/${write.documentId}');
      } catch (e) {
        _debugLog('❌ Failed ${write.operation.name} for ${write.collection}/${write.documentId}: $e');
        
        if (write.retryCount >= _maxRetries) {
          // Max retries exceeded, remove from queue
          _queue.removeFirst();
          _debugLog('🗑️ Dropped write after $_maxRetries retries');
        } else {
          // Update retry count and move to end
          _queue.removeFirst();
          _queue.add(write.copyWith(
            retryCount: write.retryCount + 1,
            lastRetryAt: DateTime.now(),
          ));
        }
        _persistQueue();
        _emitStatus();
        
        // Break to allow backoff
        break;
      }
    }

    _isProcessing = false;
  }

  Duration _calculateBackoff(int retryCount) {
    // Exponential backoff: 2s, 4s, 8s, 16s, 32s (capped at 5 min)
    final seconds = _initialRetryDelay.inSeconds * (1 << retryCount);
    return Duration(seconds: seconds.clamp(0, _maxRetryDelay.inSeconds));
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_queue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  Future<void> _persistQueue() async {
    if (_prefs == null) return;
    final jsonList = _queue.map((w) => w.toJson()).toList();
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  Future<void> _restorePendingWrites() async {
    if (_prefs == null) return;
    final prefs = _prefs;
    if (prefs == null) return;
    final stored = prefs.getString(_storageKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final jsonList = jsonDecode(stored) as List;
      for (final json in jsonList) {
        _queue.add(PendingWrite.fromJson(Map<String, dynamic>.from(json as Map)));
      }
    } catch (e) {
      _debugLog('⚠️ Failed to restore pending writes: $e');
    }
  }

  void _emitStatus() {
    _statusController.add(WriteQueueStatus(
      pendingCount: _queue.length,
      isProcessing: _isProcessing,
    ));
  }

  /// Get current queue status
  WriteQueueStatus get status => WriteQueueStatus(
    pendingCount: _queue.length,
    isProcessing: _isProcessing,
  );

  /// Clear all pending writes (use with caution)
  Future<void> clear() async {
    _queue.clear();
    await _persistQueue();
    _emitStatus();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[WriteQueue] $message');
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _statusController.close();
  }
}

class WriteQueueStatus {
  final int pendingCount;
  final bool isProcessing;

  WriteQueueStatus({
    required this.pendingCount,
    required this.isProcessing,
  });

  bool get hasPending => pendingCount > 0;
}
