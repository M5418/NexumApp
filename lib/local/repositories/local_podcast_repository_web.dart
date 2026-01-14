import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/podcast_lite_web.dart';

export '../models/podcast_lite_web.dart';

/// Web-only local repository for Podcasts.
class LocalPodcastRepository {
  static final LocalPodcastRepository _instance = LocalPodcastRepository._internal();
  factory LocalPodcastRepository() => _instance;
  LocalPodcastRepository._internal();

  List<PodcastLite> getLocalSync({int limit = 50, String? category}) {
    if (!webLocalStore.isAvailable) return [];
    final maps = webLocalStore.getPodcastsSync(limit: limit, category: category);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} podcasts from Hive');
      return maps.map((m) => PodcastLite.fromMap(m)).toList();
    }
    return [];
  }

  Future<void> syncRemote() async {}
}
