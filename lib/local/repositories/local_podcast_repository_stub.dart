// Stub file for LocalPodcastRepository on web platform

class LocalPodcastRepository {
  static final LocalPodcastRepository _instance = LocalPodcastRepository._internal();
  factory LocalPodcastRepository() => _instance;
  LocalPodcastRepository._internal();

  Future<void> syncRemote() async {}
}
