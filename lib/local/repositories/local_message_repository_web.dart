import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/message_lite_web.dart';

export '../models/message_lite_web.dart';

/// Web-only local repository for Messages.
class LocalMessageRepository {
  static final LocalMessageRepository _instance = LocalMessageRepository._internal();
  factory LocalMessageRepository() => _instance;
  LocalMessageRepository._internal();

  List<MessageLite> getLocalSync(String conversationId, {int limit = 50}) {
    if (!webLocalStore.isAvailable) return [];
    final maps = webLocalStore.getMessagesSync(conversationId, limit: limit);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} messages from Hive');
      return maps.map((m) => MessageLite.fromMap(m)).toList();
    }
    return [];
  }

  Future<void> syncConversation(String conversationId) async {
    // Web sync is handled by WebCacheWarmer
    debugPrint('🌐 [Web] syncConversation called - handled by WebCacheWarmer');
  }

  int getLocalCount(String conversationId) {
    if (!webLocalStore.isAvailable) return 0;
    return getLocalSync(conversationId, limit: 1000).length;
  }
}
