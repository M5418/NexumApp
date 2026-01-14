import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/post_lite_web.dart';

export '../models/post_lite_web.dart';

/// Web-only local repository for Posts.
/// Uses Hive via WebLocalStore for instant reads.
class LocalPostRepository {
  static final LocalPostRepository _instance = LocalPostRepository._internal();
  factory LocalPostRepository() => _instance;
  LocalPostRepository._internal();

  /// Get local posts synchronously from Hive
  List<PostLite> getLocalSync({int limit = 20, String? communityId}) {
    if (!webLocalStore.isAvailable) return [];
    
    final maps = webLocalStore.getPostsSync(limit: limit, communityId: communityId);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} posts from Hive');
      return maps.map((m) => PostLite.fromMap(m)).toList();
    }
    return [];
  }

  /// Sync remote posts - on web, this is handled by WebCacheWarmer
  Future<void> syncRemote() async {
    // Web sync is handled by WebCacheWarmer at app start
    debugPrint('🌐 [Web] syncRemote called - handled by WebCacheWarmer');
  }

  /// Get local post count
  int getLocalCount() {
    if (!webLocalStore.isAvailable) return 0;
    return webLocalStore.getPostsSync(limit: 1000).length;
  }

}
