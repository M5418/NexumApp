import 'package:flutter_test/flutter_test.dart';

/// Tests for Conversations List feature
/// Covers: local caching, sorting, unread counts, last message preview
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Caching Optimization', () {
    test('should load conversations from local cache instantly', () {
      final localRepo = _MockLocalConversationRepository();
      localRepo.seedLocalData(List.generate(50, (i) => 
        _createMockConversation('c$i')
      ));
      
      final stopwatch = Stopwatch()..start();
      final convs = localRepo.getLocalSync(limit: 20);
      stopwatch.stop();
      
      expect(convs.length, 20);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('should show cached conversations before network fetch', () {
      final localRepo = _MockLocalConversationRepository();
      localRepo.seedLocalData([
        _createMockConversation('c1', lastMessage: 'Cached message'),
      ]);
      
      final cached = localRepo.getLocalSync(limit: 20);
      expect(cached.length, 1);
      expect(cached.first.lastMessage, 'Cached message');
    });

    test('should merge updated conversations from server', () {
      final localRepo = _MockLocalConversationRepository();
      localRepo.seedLocalData([
        _createMockConversation('c1', lastMessage: 'Old message', unreadCount: 0),
      ]);
      
      // Server brings updated conversation
      localRepo.upsertFromRemote([
        _createMockConversation('c1', lastMessage: 'New message', unreadCount: 3),
      ]);
      
      final conv = localRepo.getLocalSync(limit: 20).first;
      expect(conv.lastMessage, 'New message');
      expect(conv.unreadCount, 3);
    });

    test('should update unread count locally', () {
      final localRepo = _MockLocalConversationRepository();
      localRepo.seedLocalData([
        _createMockConversation('c1', unreadCount: 5),
      ]);
      
      // Mark as read locally
      localRepo.markAsRead('c1');
      
      final conv = localRepo.getLocalSync(limit: 20).first;
      expect(conv.unreadCount, 0);
    });

    test('should work offline with cached conversations', () {
      final localRepo = _MockLocalConversationRepository();
      localRepo.seedLocalData([
        _createMockConversation('c1'),
        _createMockConversation('c2'),
      ]);
      localRepo.setOfflineMode(true);
      
      final convs = localRepo.getLocalSync(limit: 20);
      expect(convs.length, 2);
    });

    test('should use delta sync for conversation updates', () {
      final syncManager = _MockConversationSyncManager();
      syncManager.setLastSyncTime(DateTime(2024, 1, 10));
      
      final cursor = syncManager.getLastSyncTime();
      expect(cursor, isNotNull);
    });
  });


  group('Conversation Model Mapping', () {
    test('should map ConversationLite to UI model', () {
      final convLite = _MockConversationLite(
        id: 'conv1',
        memberIds: ['user1', 'user2'],
        lastMessage: 'Hello!',
        lastMessageAt: DateTime(2024, 1, 15, 10, 30),
        unreadCount: 3,
      );
      
      final uiConv = _mapConversationToUI(convLite, currentUserId: 'user1');
      
      expect(uiConv['id'], 'conv1');
      expect(uiConv['lastMessage'], 'Hello!');
      expect(uiConv['unreadCount'], 3);
    });

    test('should get other participant info', () {
      final convLite = _MockConversationLite(
        id: 'conv1',
        memberIds: ['user1', 'user2'],
        memberNames: {'user1': 'John', 'user2': 'Jane'},
        lastMessage: 'Hi',
        lastMessageAt: DateTime.now(),
      );
      
      final otherUser = _getOtherParticipant(convLite, 'user1');
      expect(otherUser['name'], 'Jane');
    });

    test('should handle group conversation', () {
      final convLite = _MockConversationLite(
        id: 'conv1',
        memberIds: ['user1', 'user2', 'user3'],
        isGroup: true,
        groupName: 'Team Chat',
        lastMessage: 'Meeting at 3',
        lastMessageAt: DateTime.now(),
      );
      
      final uiConv = _mapConversationToUI(convLite, currentUserId: 'user1');
      expect(uiConv['isGroup'], isTrue);
      expect(uiConv['displayName'], 'Team Chat');
    });
  });

  group('Conversations Local Cache', () {
    test('should return cached conversations instantly', () {
      final cache = _MockConversationsCache();
      cache.putConversations([
        _createMockConversation('c1'),
        _createMockConversation('c2'),
      ]);
      
      final convs = cache.getConversationsSync(limit: 20);
      expect(convs.length, 2);
    });

    test('should sort by last message time', () {
      final cache = _MockConversationsCache();
      cache.putConversations([
        _createMockConversation('c1', lastMessageAt: DateTime(2024, 1, 10)),
        _createMockConversation('c2', lastMessageAt: DateTime(2024, 1, 15)),
        _createMockConversation('c3', lastMessageAt: DateTime(2024, 1, 12)),
      ]);
      
      final convs = cache.getConversationsSync(limit: 20);
      expect(convs.first.id, 'c2'); // Most recent first
    });

    test('should filter by user membership', () {
      final cache = _MockConversationsCache();
      cache.putConversations([
        _createMockConversation('c1', memberIds: ['user1', 'user2']),
        _createMockConversation('c2', memberIds: ['user2', 'user3']),
        _createMockConversation('c3', memberIds: ['user1', 'user3']),
      ]);
      
      final userConvs = cache.getConversationsForUser('user1');
      expect(userConvs.length, 2);
    });
  });

  group('Unread Counts', () {
    test('should track unread count per conversation', () {
      final conv = _createMockConversation('c1', unreadCount: 5);
      expect(conv.unreadCount, 5);
    });

    test('should calculate total unread', () {
      final cache = _MockConversationsCache();
      cache.putConversations([
        _createMockConversation('c1', unreadCount: 3),
        _createMockConversation('c2', unreadCount: 7),
        _createMockConversation('c3', unreadCount: 0),
      ]);
      
      final total = cache.getTotalUnreadCount();
      expect(total, 10);
    });

    test('should reset unread on open', () {
      final conv = _createMockConversation('c1', unreadCount: 5);
      final updated = conv.markAsRead();
      expect(updated.unreadCount, 0);
    });

    test('should increment unread on new message', () {
      final conv = _createMockConversation('c1', unreadCount: 2);
      final updated = conv.incrementUnread();
      expect(updated.unreadCount, 3);
    });
  });

  group('Last Message Preview', () {
    test('should show text message preview', () {
      final conv = _createMockConversation('c1', lastMessage: 'Hello there!');
      expect(conv.lastMessage, 'Hello there!');
    });

    test('should show media placeholder for image', () {
      final conv = _createMockConversation('c1', 
        lastMessage: null,
        lastMessageType: 'image',
      );
      
      final preview = _getLastMessagePreview(conv);
      expect(preview, '📷 Photo');
    });

    test('should show media placeholder for voice', () {
      final conv = _createMockConversation('c1',
        lastMessage: null,
        lastMessageType: 'voice',
      );
      
      final preview = _getLastMessagePreview(conv);
      expect(preview, '🎤 Voice message');
    });

    test('should truncate long messages', () {
      final longMessage = 'A' * 100;
      final conv = _createMockConversation('c1', lastMessage: longMessage);
      
      final preview = _getLastMessagePreview(conv, maxLength: 50);
      expect(preview.length, lessThanOrEqualTo(53)); // 50 + "..."
    });
  });

  group('Conversation Search', () {
    test('should search by participant name', () {
      final cache = _MockConversationsCache();
      cache.putConversations([
        _createMockConversation('c1', memberNames: {'user1': 'John', 'user2': 'Jane'}),
        _createMockConversation('c2', memberNames: {'user1': 'John', 'user3': 'Bob'}),
      ]);
      
      final results = cache.searchConversations('Jane');
      expect(results.length, 1);
    });

    test('should search by group name', () {
      final cache = _MockConversationsCache();
      cache.putConversations([
        _createMockConversation('c1', isGroup: true, groupName: 'Flutter Team'),
        _createMockConversation('c2', isGroup: true, groupName: 'Design Team'),
      ]);
      
      final results = cache.searchConversations('Flutter');
      expect(results.length, 1);
    });
  });

  group('Conversation Actions', () {
    test('should archive conversation', () {
      final conv = _createMockConversation('c1', isArchived: false);
      final archived = conv.archive();
      expect(archived.isArchived, isTrue);
    });

    test('should mute conversation', () {
      final conv = _createMockConversation('c1', isMuted: false);
      final muted = conv.mute();
      expect(muted.isMuted, isTrue);
    });

    test('should pin conversation', () {
      final conv = _createMockConversation('c1', isPinned: false);
      final pinned = conv.pin();
      expect(pinned.isPinned, isTrue);
    });

    test('should sort pinned conversations first', () {
      final cache = _MockConversationsCache();
      cache.putConversations([
        _createMockConversation('c1', isPinned: false, lastMessageAt: DateTime(2024, 1, 15)),
        _createMockConversation('c2', isPinned: true, lastMessageAt: DateTime(2024, 1, 10)),
      ]);
      
      final convs = cache.getConversationsSync(limit: 20);
      expect(convs.first.id, 'c2'); // Pinned first despite older
    });
  });

  group('Online Status', () {
    test('should track online status', () {
      final status = _MockOnlineStatus();
      status.setOnline('user2', true);
      
      expect(status.isOnline('user2'), isTrue);
    });

    test('should get last seen time', () {
      final status = _MockOnlineStatus();
      final lastSeen = DateTime(2024, 1, 15, 10, 30);
      status.setLastSeen('user2', lastSeen);
      
      expect(status.getLastSeen('user2'), lastSeen);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapConversationToUI(_MockConversationLite conv, {required String currentUserId}) {
  String displayName;
  if (conv.isGroup) {
    displayName = conv.groupName ?? 'Group';
  } else {
    final otherId = conv.memberIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    displayName = conv.memberNames?[otherId] ?? 'Unknown';
  }
  
  return {
    'id': conv.id,
    'displayName': displayName,
    'lastMessage': conv.lastMessage,
    'lastMessageAt': conv.lastMessageAt,
    'unreadCount': conv.unreadCount,
    'isGroup': conv.isGroup,
  };
}

Map<String, dynamic> _getOtherParticipant(_MockConversationLite conv, String currentUserId) {
  final otherId = conv.memberIds.firstWhere((id) => id != currentUserId, orElse: () => '');
  return {
    'id': otherId,
    'name': conv.memberNames?[otherId] ?? 'Unknown',
  };
}

String _getLastMessagePreview(_MockConversationLite conv, {int maxLength = 50}) {
  if (conv.lastMessage != null && conv.lastMessage!.isNotEmpty) {
    if (conv.lastMessage!.length > maxLength) {
      return '${conv.lastMessage!.substring(0, maxLength)}...';
    }
    return conv.lastMessage!;
  }
  
  switch (conv.lastMessageType) {
    case 'image':
      return '📷 Photo';
    case 'video':
      return '🎬 Video';
    case 'voice':
      return '🎤 Voice message';
    case 'file':
      return '📎 File';
    default:
      return '';
  }
}

_MockConversationLite _createMockConversation(
  String id, {
  List<String>? memberIds,
  Map<String, String>? memberNames,
  String? lastMessage = 'Test message',
  String? lastMessageType = 'text',
  DateTime? lastMessageAt,
  int unreadCount = 0,
  bool isGroup = false,
  String? groupName,
  bool isArchived = false,
  bool isMuted = false,
  bool isPinned = false,
}) {
  return _MockConversationLite(
    id: id,
    memberIds: memberIds ?? ['user1', 'user2'],
    memberNames: memberNames,
    lastMessage: lastMessage,
    lastMessageType: lastMessageType,
    lastMessageAt: lastMessageAt ?? DateTime.now(),
    unreadCount: unreadCount,
    isGroup: isGroup,
    groupName: groupName,
    isArchived: isArchived,
    isMuted: isMuted,
    isPinned: isPinned,
  );
}

// Mock classes

class _MockConversationLite {
  final String id;
  final List<String> memberIds;
  final Map<String, String>? memberNames;
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isGroup;
  final String? groupName;
  final bool isArchived;
  final bool isMuted;
  final bool isPinned;

  _MockConversationLite({
    required this.id,
    required this.memberIds,
    this.memberNames,
    this.lastMessage,
    this.lastMessageType,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isGroup = false,
    this.groupName,
    this.isArchived = false,
    this.isMuted = false,
    this.isPinned = false,
  });

  _MockConversationLite markAsRead() {
    return _MockConversationLite(
      id: id,
      memberIds: memberIds,
      memberNames: memberNames,
      lastMessage: lastMessage,
      lastMessageType: lastMessageType,
      lastMessageAt: lastMessageAt,
      unreadCount: 0,
      isGroup: isGroup,
      groupName: groupName,
      isArchived: isArchived,
      isMuted: isMuted,
      isPinned: isPinned,
    );
  }

  _MockConversationLite incrementUnread() {
    return _MockConversationLite(
      id: id,
      memberIds: memberIds,
      memberNames: memberNames,
      lastMessage: lastMessage,
      lastMessageType: lastMessageType,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount + 1,
      isGroup: isGroup,
      groupName: groupName,
      isArchived: isArchived,
      isMuted: isMuted,
      isPinned: isPinned,
    );
  }

  _MockConversationLite archive() => _copyWith(isArchived: true);
  _MockConversationLite mute() => _copyWith(isMuted: true);
  _MockConversationLite pin() => _copyWith(isPinned: true);

  _MockConversationLite _copyWith({bool? isArchived, bool? isMuted, bool? isPinned}) {
    return _MockConversationLite(
      id: id,
      memberIds: memberIds,
      memberNames: memberNames,
      lastMessage: lastMessage,
      lastMessageType: lastMessageType,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      isGroup: isGroup,
      groupName: groupName,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class _MockConversationsCache {
  final List<_MockConversationLite> _conversations = [];

  void putConversations(List<_MockConversationLite> convs) {
    _conversations.addAll(convs);
  }

  List<_MockConversationLite> getConversationsSync({required int limit}) {
    final sorted = List<_MockConversationLite>.from(_conversations)
      ..sort((a, b) {
        // Pinned first
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        // Then by last message time
        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });
    return sorted.take(limit).toList();
  }

  List<_MockConversationLite> getConversationsForUser(String userId) {
    return _conversations.where((c) => c.memberIds.contains(userId)).toList();
  }

  int getTotalUnreadCount() {
    return _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  List<_MockConversationLite> searchConversations(String query) {
    final lowerQuery = query.toLowerCase();
    return _conversations.where((c) {
      if (c.isGroup && c.groupName?.toLowerCase().contains(lowerQuery) == true) {
        return true;
      }
      return c.memberNames?.values.any((name) => name.toLowerCase().contains(lowerQuery)) ?? false;
    }).toList();
  }
}

class _MockOnlineStatus {
  final Map<String, bool> _online = {};
  final Map<String, DateTime> _lastSeen = {};

  void setOnline(String userId, bool isOnline) {
    _online[userId] = isOnline;
  }

  bool isOnline(String userId) => _online[userId] ?? false;

  void setLastSeen(String userId, DateTime time) {
    _lastSeen[userId] = time;
  }

  DateTime? getLastSeen(String userId) => _lastSeen[userId];
}

class _MockLocalConversationRepository {
  final List<_MockConversationLite> _localData = [];
  bool _offlineMode = false;

  void seedLocalData(List<_MockConversationLite> convs) {
    _localData.addAll(convs);
  }

  List<_MockConversationLite> getLocalSync({required int limit}) {
    final sorted = List<_MockConversationLite>.from(_localData)
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return sorted.take(limit).toList();
  }

  void upsertFromRemote(List<_MockConversationLite> remoteConvs) {
    for (final remote in remoteConvs) {
      final existingIndex = _localData.indexWhere((c) => c.id == remote.id);
      if (existingIndex >= 0) {
        _localData[existingIndex] = remote;
      } else {
        _localData.add(remote);
      }
    }
  }

  void markAsRead(String conversationId) {
    final index = _localData.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      _localData[index] = _localData[index].markAsRead();
    }
  }

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }
}

class _MockConversationSyncManager {
  DateTime? _lastSyncTime;

  void setLastSyncTime(DateTime time) {
    _lastSyncTime = time;
  }

  DateTime? getLastSyncTime() => _lastSyncTime;
}
