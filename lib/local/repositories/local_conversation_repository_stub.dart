// Stub file for LocalConversationRepository on web platform

class LocalConversationRepository {
  static final LocalConversationRepository _instance = LocalConversationRepository._internal();
  factory LocalConversationRepository() => _instance;
  LocalConversationRepository._internal();

  Future<void> syncRemote() async {}
}
