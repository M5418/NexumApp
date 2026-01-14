import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/conversation_lite_web.dart';

export '../models/conversation_lite_web.dart';

/// Web-only local repository for Conversations.
class LocalConversationRepository {
  static final LocalConversationRepository _instance = LocalConversationRepository._internal();
  factory LocalConversationRepository() => _instance;
  LocalConversationRepository._internal();

  List<ConversationLite> getLocalSync({int limit = 50}) {
    if (!webLocalStore.isAvailable) return [];
    final maps = webLocalStore.getConversationsSync(limit: limit);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} conversations from Hive');
      return maps.map((m) => ConversationLite.fromMap(m)).toList();
    }
    return [];
  }

  Future<void> syncRemote() async {}
}
