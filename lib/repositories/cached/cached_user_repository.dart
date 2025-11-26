import 'dart:typed_data';
import '../../core/cache_manager.dart';
import '../interfaces/user_repository.dart';

/// Cached wrapper for UserRepository
/// Implements cache-aside pattern: check cache first, then fetch from source
class CachedUserRepository implements UserRepository {
  final UserRepository _source;
  final CacheManager _cache = CacheManager();

  CachedUserRepository(this._source);

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    // Try memory cache first (in-memory only for complex objects)
    final cached = _cache.getMemoryOnly<UserProfile>('user_$uid');
    
    if (cached != null) {
      return cached;
    }

    // Cache miss - fetch from source
    final profile = await _source.getUserProfile(uid);
    
    if (profile != null) {
      // Cache in memory for 15 minutes
      _cache.setMemoryOnly('user_$uid', profile, ttl: CacheManager.defaultTTL);
    }
    
    return profile;
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    // Current user profile changes less frequently
    final cached = _cache.getMemoryOnly<UserProfile>('current_user');
    
    if (cached != null) {
      return cached;
    }

    final profile = await _source.getCurrentUserProfile();
    
    if (profile != null) {
      // Cache in memory only for 5 minutes (refreshes on app restart)
      _cache.setMemoryOnly('current_user', profile, ttl: CacheManager.shortTTL);
    }
    
    return profile;
  }

  @override
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _source.updateUserProfile(uid, data);
    
    // Invalidate cache after update
    await _cache.remove('user_$uid');
    await _cache.remove('current_user');
  }

  @override
  Future<List<UserProfile>> getSuggestedUsers({int limit = 12}) async {
    // Suggested users change frequently, cache for short time
    final cached = _cache.getMemoryOnly<List<UserProfile>>('suggested_users');
    
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final users = await _source.getSuggestedUsers(limit: limit);
    
    if (users.isNotEmpty) {
      // Cache for 5 minutes only
      _cache.setMemoryOnly('suggested_users', users, ttl: CacheManager.shortTTL);
    }
    
    return users;
  }

  @override
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List imageBytes,
    required String extension,
  }) async {
    final url = await _source.uploadProfilePhoto(
      uid: uid,
      imageBytes: imageBytes,
      extension: extension,
    );
    
    // Invalidate user cache after photo upload
    await _cache.remove('user_$uid');
    await _cache.remove('current_user');
    
    return url;
  }

  @override
  Future<String> uploadCoverPhoto({
    required String uid,
    required Uint8List imageBytes,
    required String extension,
  }) async {
    final url = await _source.uploadCoverPhoto(
      uid: uid,
      imageBytes: imageBytes,
      extension: extension,
    );
    
    // Invalidate user cache after cover upload
    await _cache.remove('user_$uid');
    await _cache.remove('current_user');
    
    return url;
  }

  @override
  Future<List<UserProfile>> searchUsers({required String query, int limit = 20}) async {
    // Search results change frequently, don't cache
    return await _source.searchUsers(query: query, limit: limit);
  }

  @override
  Future<List<UserProfile>> getUsers(List<String> uids) async {
    final List<UserProfile> results = [];
    final List<String> missingUids = [];
    
    // Check cache for each uid
    for (final uid in uids) {
      final cached = _cache.getMemoryOnly<UserProfile>('user_$uid');
      if (cached != null) {
        results.add(cached);
      } else {
        missingUids.add(uid);
      }
    }
    
    // Fetch missing ones
    if (missingUids.isNotEmpty) {
      final fetched = await _source.getUsers(missingUids);
      
      // Cache the fetched profiles
      for (final profile in fetched) {
        _cache.setMemoryOnly('user_${profile.uid}', profile, ttl: CacheManager.defaultTTL);
        results.add(profile);
      }
    }
    
    return results;
  }

  @override
  Future<void> updateFCMToken(String token) async {
    await _source.updateFCMToken(token);
    // Invalidate current user cache
    await _cache.remove('current_user');
  }

  @override
  Future<void> removeFCMToken(String token) async {
    await _source.removeFCMToken(token);
    // Invalidate current user cache
    await _cache.remove('current_user');
  }

  @override
  Stream<UserProfile?> userProfileStream(String uid) {
    // For streams, pass through without caching (real-time data)
    return _source.userProfileStream(uid);
  }

  /// Manually refresh user cache
  Future<void> refreshUserCache(String uid) async {
    await _cache.remove('user_$uid');
  }

  /// Preload user profiles (e.g., for feed authors)
  Future<void> preloadUsers(List<String> uids) async {
    for (final uid in uids) {
      final cached = _cache.getMemoryOnly<UserProfile>('user_$uid');
      if (cached == null) {
        // Fetch in background without blocking
        getUserProfile(uid).then((_) {
          // Profile will be cached automatically
        }).catchError((e) {
          // Ignore errors for background prefetch
        });
      }
    }
  }
}
