import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/story_lite_web.dart';

export '../models/story_lite_web.dart';

/// Web-only local repository for Stories.
class LocalStoryRepository {
  static final LocalStoryRepository _instance = LocalStoryRepository._internal();
  factory LocalStoryRepository() => _instance;
  LocalStoryRepository._internal();

  List<StoryLite> getLocalSync({int limit = 50}) {
    if (!webLocalStore.isAvailable) return [];
    final maps = webLocalStore.getStoriesSync(limit: limit);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} stories from Hive');
      // Filter out expired stories
      return maps
          .map((m) => StoryLite.fromMap(m))
          .where((s) => !s.isExpired)
          .toList();
    }
    return [];
  }

  List<StoryLite> getByAuthorSync(String authorId, {int limit = 20}) {
    final all = getLocalSync(limit: 100);
    return all.where((s) => s.authorId == authorId).take(limit).toList();
  }

  Future<void> syncRemote() async {
    debugPrint('🌐 [Web] syncRemote called - handled by WebCacheWarmer');
  }

  Future<void> markViewed(String storyId) async {
    // Web: handled by Firestore directly
  }

  int getLocalCount() {
    if (!webLocalStore.isAvailable) return 0;
    return getLocalSync(limit: 1000).length;
  }
}
