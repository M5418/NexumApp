import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/mentorship_message_lite_web.dart';

export '../models/mentorship_message_lite_web.dart';

/// Web-only local repository for Mentorship Messages.
class LocalMentorshipMessageRepository {
  static final LocalMentorshipMessageRepository _instance = LocalMentorshipMessageRepository._internal();
  factory LocalMentorshipMessageRepository() => _instance;
  LocalMentorshipMessageRepository._internal();

  List<MentorshipMessageLite> getLocalSync(String conversationId, {int limit = 50}) {
    if (!webLocalStore.isAvailable) return [];
    final maps = webLocalStore.getMentorshipMessagesSync(conversationId: conversationId, limit: limit);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} mentorship messages from Hive');
      return maps.map((m) => MentorshipMessageLite.fromMap(m)).toList();
    }
    return [];
  }

  Future<void> syncConversation(String conversationId) async {
    debugPrint('🌐 [Web] syncConversation called - handled by WebCacheWarmer');
  }

  int getLocalCount(String conversationId) {
    if (!webLocalStore.isAvailable) return 0;
    return getLocalSync(conversationId, limit: 1000).length;
  }
}
