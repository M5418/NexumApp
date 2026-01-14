import 'package:flutter/foundation.dart';
import '../web/web_local_store.dart';
import '../models/community_post_lite_web.dart';

export '../models/community_post_lite_web.dart';

/// Web-only local repository for Community Posts.
class LocalCommunityPostRepository {
  static final LocalCommunityPostRepository _instance = LocalCommunityPostRepository._internal();
  factory LocalCommunityPostRepository() => _instance;
  LocalCommunityPostRepository._internal();

  List<CommunityPostLite> getLocalSync(String communityId, {int limit = 20}) {
    if (!webLocalStore.isAvailable) return [];
    final maps = webLocalStore.getPostsSync(limit: limit, communityId: communityId);
    if (maps.isNotEmpty) {
      debugPrint('🌐 [Web] Loaded ${maps.length} community posts from Hive');
      return maps.map((m) => CommunityPostLite.fromMap(m)).toList();
    }
    return [];
  }

  Future<void> syncCommunity(String communityId) async {}
}
