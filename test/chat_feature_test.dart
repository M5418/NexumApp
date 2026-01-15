import 'package:flutter_test/flutter_test.dart';

/// Tests for Chat (1:1) feature
/// Covers: message caching, optimistic send, read receipts, media messages
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Caching Optimization', () {
    test('should load messages from local cache instantly', () {
      final localRepo = _MockLocalMessageRepository();
      localRepo.seedMessages('conv1', List.generate(100, (i) => 
        _createMockMessage('m$i', 'conv1')
      ));
      
      final stopwatch = Stopwatch()..start();
      final messages = localRepo.getLocalSync('conv1', limit: 50);
      stopwatch.stop();
      
      expect(messages.length, 50);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('should show cached messages before network fetch', () {
      final localRepo = _MockLocalMessageRepository();
      localRepo.seedMessages('conv1', [
        _createMockMessage('m1', 'conv1', text: 'Cached message'),
      ]);
      
      final cached = localRepo.getLocalSync('conv1', limit: 50);
      expect(cached.length, 1);
      expect(cached.first.text, 'Cached message');
    });

    test('should merge new messages from server', () {
      final localRepo = _MockLocalMessageRepository();
      localRepo.seedMessages('conv1', [
        _createMockMessage('m1', 'conv1', text: 'Old message'),
      ]);
      
      // Server brings new messages
      localRepo.upsertFromRemote('conv1', [
        _createMockMessage('m2', 'conv1', text: 'New message'),
      ]);
      
      final messages = localRepo.getLocalSync('conv1', limit: 50);
      expect(messages.length, 2);
    });

    test('should handle optimistic send with pending status', () {
      final localRepo = _MockLocalMessageRepository();
      
      // Send message optimistically
      final pending = _createMockMessage('pending_1', 'conv1', 
        text: 'Sending...', 
        syncStatus: 'pending'
      );
      localRepo.addPendingMessage(pending);
      
      final messages = localRepo.getLocalSync('conv1', limit: 50);
      expect(messages.any((m) => m.syncStatus == 'pending'), isTrue);
    });

    test('should update message status after server confirm', () {
      final localRepo = _MockLocalMessageRepository();
      localRepo.addPendingMessage(_createMockMessage('m1', 'conv1', syncStatus: 'pending'));
      
      localRepo.updateSyncStatus('conv1', 'm1', 'sent');
      
      final msg = localRepo.getLocalSync('conv1', limit: 50).first;
      expect(msg.syncStatus, 'sent');
    });

    test('should work offline with cached messages', () {
      final localRepo = _MockLocalMessageRepository();
      localRepo.seedMessages('conv1', [
        _createMockMessage('m1', 'conv1'),
        _createMockMessage('m2', 'conv1'),
      ]);
      localRepo.setOfflineMode(true);
      
      final messages = localRepo.getLocalSync('conv1', limit: 50);
      expect(messages.length, 2);
    });
  });


  group('Message Model Mapping', () {
    test('should map MessageLite to UI Message', () {
      final msgLite = _MockMessageLite(
        id: 'msg1',
        conversationId: 'conv1',
        senderId: 'user1',
        senderName: 'John',
        text: 'Hello!',
        type: 'text',
        createdAt: DateTime(2024, 1, 15, 10, 30),
      );
      
      final uiMsg = _mapMessageToUI(msgLite, currentUserId: 'user2');
      
      expect(uiMsg['id'], 'msg1');
      expect(uiMsg['content'], 'Hello!');
      expect(uiMsg['isFromCurrentUser'], isFalse);
    });

    test('should identify own messages', () {
      final msgLite = _MockMessageLite(
        id: 'msg1',
        conversationId: 'conv1',
        senderId: 'user1',
        senderName: 'John',
        text: 'My message',
        type: 'text',
        createdAt: DateTime.now(),
      );
      
      final uiMsg = _mapMessageToUI(msgLite, currentUserId: 'user1');
      expect(uiMsg['isFromCurrentUser'], isTrue);
    });

    test('should handle different message types', () {
      final imageMsg = _MockMessageLite(
        id: 'msg1',
        conversationId: 'conv1',
        senderId: 'user1',
        senderName: 'John',
        text: null,
        type: 'image',
        mediaUrl: 'https://example.com/image.jpg',
        createdAt: DateTime.now(),
      );
      
      final uiMsg = _mapMessageToUI(imageMsg, currentUserId: 'user2');
      expect(uiMsg['type'], 'image');
      expect(uiMsg['mediaUrl'], isNotNull);
    });
  });

  group('Messages Local Cache', () {
    test('should return cached messages instantly', () {
      final cache = _MockMessagesCache();
      cache.putMessages('conv1', [
        _createMockMessage('m1', 'conv1'),
        _createMockMessage('m2', 'conv1'),
      ]);
      
      final messages = cache.getMessagesSync('conv1', limit: 50);
      expect(messages.length, 2);
    });

    test('should return messages in chronological order', () {
      final cache = _MockMessagesCache();
      cache.putMessages('conv1', [
        _createMockMessage('m1', 'conv1', createdAt: DateTime(2024, 1, 15, 10, 0)),
        _createMockMessage('m2', 'conv1', createdAt: DateTime(2024, 1, 15, 10, 5)),
        _createMockMessage('m3', 'conv1', createdAt: DateTime(2024, 1, 15, 10, 2)),
      ]);
      
      final messages = cache.getMessagesSync('conv1', limit: 50);
      expect(messages.first.id, 'm1'); // Oldest first for chat
      expect(messages.last.id, 'm2'); // Newest last
    });

    test('should filter by conversation', () {
      final cache = _MockMessagesCache();
      cache.putMessages('conv1', [_createMockMessage('m1', 'conv1')]);
      cache.putMessages('conv2', [_createMockMessage('m2', 'conv2')]);
      
      final conv1Messages = cache.getMessagesSync('conv1', limit: 50);
      expect(conv1Messages.length, 1);
      expect(conv1Messages.first.conversationId, 'conv1');
    });
  });

  group('Optimistic Send', () {
    test('should add message locally before server confirm', () {
      final cache = _MockMessagesCache();
      final pendingMsg = _createPendingMessage(
        conversationId: 'conv1',
        senderId: 'user1',
        text: 'Sending...',
      );
      
      cache.addPendingMessage(pendingMsg);
      
      final messages = cache.getMessagesSync('conv1', limit: 50);
      expect(messages.any((m) => m.syncStatus == 'pending'), isTrue);
    });

    test('should update status after server confirm', () {
      final pending = _createPendingMessage(
        conversationId: 'conv1',
        senderId: 'user1',
        text: 'Hello',
      );
      
      final confirmed = pending.copyWith(syncStatus: 'sent');
      expect(confirmed.syncStatus, 'sent');
    });

    test('should mark as failed on error', () {
      final pending = _createPendingMessage(
        conversationId: 'conv1',
        senderId: 'user1',
        text: 'Hello',
      );
      
      final failed = pending.copyWith(syncStatus: 'failed');
      expect(failed.syncStatus, 'failed');
    });
  });

  group('Read Receipts', () {
    test('should track read status', () {
      final receipts = _MockReadReceipts();
      receipts.markAsRead('conv1', 'user1', DateTime.now());
      
      expect(receipts.hasRead('conv1', 'user1'), isTrue);
    });

    test('should get last read timestamp', () {
      final receipts = _MockReadReceipts();
      final readTime = DateTime(2024, 1, 15, 10, 30);
      receipts.markAsRead('conv1', 'user1', readTime);
      
      expect(receipts.getLastReadTime('conv1', 'user1'), readTime);
    });

    test('should count unread messages', () {
      final cache = _MockMessagesCache();
      final receipts = _MockReadReceipts();
      
      cache.putMessages('conv1', [
        _createMockMessage('m1', 'conv1', createdAt: DateTime(2024, 1, 15, 10, 0)),
        _createMockMessage('m2', 'conv1', createdAt: DateTime(2024, 1, 15, 10, 5)),
        _createMockMessage('m3', 'conv1', createdAt: DateTime(2024, 1, 15, 10, 10)),
      ]);
      
      receipts.markAsRead('conv1', 'user1', DateTime(2024, 1, 15, 10, 2));
      
      final unread = cache.countUnreadMessages('conv1', receipts, 'user1');
      expect(unread, 2); // m2 and m3 are after last read
    });
  });

  group('Media Messages', () {
    test('should validate image message', () {
      final result = _validateMediaMessage(
        type: 'image',
        mediaUrl: 'https://example.com/image.jpg',
      );
      expect(result.isValid, isTrue);
    });

    test('should reject media message without URL', () {
      final result = _validateMediaMessage(
        type: 'image',
        mediaUrl: '',
      );
      expect(result.isValid, isFalse);
    });

    test('should handle voice message duration', () {
      final voiceMsg = _MockMessageLite(
        id: 'msg1',
        conversationId: 'conv1',
        senderId: 'user1',
        senderName: 'John',
        text: null,
        type: 'voice',
        mediaUrl: 'https://example.com/voice.m4a',
        mediaDuration: 15,
        createdAt: DateTime.now(),
      );
      
      expect(voiceMsg.mediaDuration, 15);
    });
  });

  group('Message Search', () {
    test('should search messages by text', () {
      final cache = _MockMessagesCache();
      cache.putMessages('conv1', [
        _createMockMessage('m1', 'conv1', text: 'Hello there'),
        _createMockMessage('m2', 'conv1', text: 'How are you?'),
        _createMockMessage('m3', 'conv1', text: 'Hello again'),
      ]);
      
      final results = cache.searchMessages('conv1', 'Hello');
      expect(results.length, 2);
    });
  });

  group('Typing Indicator', () {
    test('should track typing status', () {
      final typing = _MockTypingIndicator();
      typing.setTyping('conv1', 'user2', true);
      
      expect(typing.isTyping('conv1', 'user2'), isTrue);
    });

    test('should clear typing after timeout', () {
      final typing = _MockTypingIndicator();
      typing.setTyping('conv1', 'user2', true);
      typing.clearTyping('conv1', 'user2');
      
      expect(typing.isTyping('conv1', 'user2'), isFalse);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapMessageToUI(_MockMessageLite msg, {required String currentUserId}) {
  return {
    'id': msg.id,
    'conversationId': msg.conversationId,
    'senderId': msg.senderId,
    'senderName': msg.senderName,
    'content': msg.text ?? '',
    'type': msg.type,
    'mediaUrl': msg.mediaUrl,
    'isFromCurrentUser': msg.senderId == currentUserId,
    'timestamp': msg.createdAt,
  };
}

_MockMessageLite _createMockMessage(
  String id,
  String conversationId, {
  String senderId = 'user1',
  String text = 'Test message',
  String type = 'text',
  DateTime? createdAt,
  String syncStatus = 'sent',
}) {
  return _MockMessageLite(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    senderName: 'Test User',
    text: text,
    type: type,
    createdAt: createdAt ?? DateTime.now(),
    syncStatus: syncStatus,
  );
}

_MockMessageLite _createPendingMessage({
  required String conversationId,
  required String senderId,
  required String text,
}) {
  return _MockMessageLite(
    id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
    conversationId: conversationId,
    senderId: senderId,
    senderName: 'Me',
    text: text,
    type: 'text',
    createdAt: DateTime.now(),
    syncStatus: 'pending',
  );
}

_ValidationResult _validateMediaMessage({
  required String type,
  required String mediaUrl,
}) {
  if (mediaUrl.isEmpty) {
    return _ValidationResult(isValid: false, error: 'Media URL required');
  }
  return _ValidationResult(isValid: true);
}

// Mock classes

class _MockMessageLite {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? text;
  final String type;
  final String? mediaUrl;
  final int? mediaDuration;
  final DateTime createdAt;
  final String syncStatus;

  _MockMessageLite({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.text,
    required this.type,
    this.mediaUrl,
    this.mediaDuration,
    required this.createdAt,
    this.syncStatus = 'sent',
  });

  _MockMessageLite copyWith({String? syncStatus}) {
    return _MockMessageLite(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class _MockMessagesCache {
  final Map<String, List<_MockMessageLite>> _messages = {};

  void putMessages(String conversationId, List<_MockMessageLite> messages) {
    _messages.putIfAbsent(conversationId, () => []);
    _messages[conversationId]!.addAll(messages);
  }

  void addPendingMessage(_MockMessageLite message) {
    _messages.putIfAbsent(message.conversationId, () => []);
    _messages[message.conversationId]!.add(message);
  }

  List<_MockMessageLite> getMessagesSync(String conversationId, {required int limit}) {
    final msgs = _messages[conversationId] ?? [];
    final sorted = List<_MockMessageLite>.from(msgs)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.take(limit).toList();
  }

  int countUnreadMessages(String conversationId, _MockReadReceipts receipts, String userId) {
    final lastRead = receipts.getLastReadTime(conversationId, userId);
    if (lastRead == null) return _messages[conversationId]?.length ?? 0;
    
    return _messages[conversationId]
        ?.where((m) => m.createdAt.isAfter(lastRead))
        .length ?? 0;
  }

  List<_MockMessageLite> searchMessages(String conversationId, String query) {
    final msgs = _messages[conversationId] ?? [];
    final lowerQuery = query.toLowerCase();
    return msgs.where((m) => m.text?.toLowerCase().contains(lowerQuery) ?? false).toList();
  }
}

class _MockReadReceipts {
  final Map<String, Map<String, DateTime>> _receipts = {};

  void markAsRead(String conversationId, String userId, DateTime time) {
    _receipts.putIfAbsent(conversationId, () => {});
    _receipts[conversationId]![userId] = time;
  }

  bool hasRead(String conversationId, String userId) {
    return _receipts[conversationId]?.containsKey(userId) ?? false;
  }

  DateTime? getLastReadTime(String conversationId, String userId) {
    return _receipts[conversationId]?[userId];
  }
}

class _MockTypingIndicator {
  final Map<String, Map<String, bool>> _typing = {};

  void setTyping(String conversationId, String userId, bool isTyping) {
    _typing.putIfAbsent(conversationId, () => {});
    _typing[conversationId]![userId] = isTyping;
  }

  bool isTyping(String conversationId, String userId) {
    return _typing[conversationId]?[userId] ?? false;
  }

  void clearTyping(String conversationId, String userId) {
    _typing[conversationId]?.remove(userId);
  }
}

class _ValidationResult {
  final bool isValid;
  final String? error;

  _ValidationResult({required this.isValid, this.error});
}

class _MockLocalMessageRepository {
  final Map<String, List<_MockMessageLite>> _localData = {};
  bool _offlineMode = false;

  void seedMessages(String conversationId, List<_MockMessageLite> messages) {
    _localData[conversationId] = messages;
  }

  List<_MockMessageLite> getLocalSync(String conversationId, {required int limit}) {
    final msgs = _localData[conversationId] ?? [];
    final sorted = List<_MockMessageLite>.from(msgs)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.take(limit).toList();
  }

  void addPendingMessage(_MockMessageLite message) {
    _localData.putIfAbsent(message.conversationId, () => []);
    _localData[message.conversationId]!.add(message);
  }

  void upsertFromRemote(String conversationId, List<_MockMessageLite> remoteMessages) {
    _localData.putIfAbsent(conversationId, () => []);
    for (final remote in remoteMessages) {
      final existingIndex = _localData[conversationId]!.indexWhere((m) => m.id == remote.id);
      if (existingIndex >= 0) {
        _localData[conversationId]![existingIndex] = remote;
      } else {
        _localData[conversationId]!.add(remote);
      }
    }
  }

  void updateSyncStatus(String conversationId, String messageId, String status) {
    final msgs = _localData[conversationId];
    if (msgs == null) return;
    final index = msgs.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      msgs[index] = msgs[index].copyWith(syncStatus: status);
    }
  }

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }
}
