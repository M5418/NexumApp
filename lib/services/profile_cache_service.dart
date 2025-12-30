import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import '../repositories/firebase/firebase_post_repository.dart';
import '../repositories/models/post_model.dart';
import '../repositories/interfaces/user_repository.dart';
import '../models/post.dart';

/// Global singleton cache for profile data
/// Preloaded during splash screen, instantly available on profile page
class ProfileCacheService extends ChangeNotifier {
  static final ProfileCacheService _instance = ProfileCacheService._internal();
  factory ProfileCacheService() => _instance;
  ProfileCacheService._internal();

  // Cached data
  UserProfile? _currentUserProfile;
  Map<String, dynamic>? _currentUserProfileMap;
  List<PostModel> _currentUserPosts = [];
  List<Post> _currentUserPostsUI = [];
  List<Map<String, String>> _mediaItems = [];
  
  // Loading states
  bool _isProfileLoaded = false;
  bool _isPostsLoaded = false;
  
  // Getters
  UserProfile? get currentUserProfile => _currentUserProfile;
  Map<String, dynamic>? get currentUserProfileMap => _currentUserProfileMap;
  List<PostModel> get currentUserPosts => _currentUserPosts;
  List<Post> get currentUserPostsUI => _currentUserPostsUI;
  List<Map<String, String>> get mediaItems => _mediaItems;
  bool get isProfileLoaded => _isProfileLoaded;
  bool get isPostsLoaded => _isPostsLoaded;
  bool get isFullyLoaded => _isProfileLoaded && _isPostsLoaded;
  
  /// Preload all profile data - call this during splash screen
  Future<void> preloadCurrentUserData(String userId) async {
    debugPrint('🚀 [ProfileCache] Preloading profile data for $userId...');
    
    final userRepo = FirebaseUserRepository();
    final postRepo = FirebasePostRepository();
    
    // Load profile and posts in parallel
    await Future.wait([
      _loadProfile(userRepo, userId),
      _loadPosts(postRepo, userId),
    ]);
    
    debugPrint('✅ [ProfileCache] Profile data preloaded');
    notifyListeners();
  }
  
  Future<void> _loadProfile(FirebaseUserRepository userRepo, String userId) async {
    try {
      final profile = await userRepo.getUserProfile(userId);
      if (profile != null) {
        _currentUserProfile = profile;
        
        // Fetch REAL-TIME connection counts from follows collection
        final db = FirebaseFirestore.instance;
        int followersCount = profile.followersCount ?? 0;
        int followingCount = profile.followingCount ?? 0;
        
        try {
          // Connections (inbound) = users who follow this user
          final followersSnap = await db.collection('follows')
              .where('followedId', isEqualTo: userId)
              .count()
              .get();
          followersCount = followersSnap.count ?? 0;
          
          // Connected (outbound) = users this user follows
          final followingSnap = await db.collection('follows')
              .where('followerId', isEqualTo: userId)
              .count()
              .get();
          followingCount = followingSnap.count ?? 0;
          
          debugPrint('👥 [ProfileCache] Real-time counts: Connections=$followersCount, Connected=$followingCount');
        } catch (e) {
          debugPrint('⚠️ [ProfileCache] Count fetch error, using stored values: $e');
        }
        
        // Create profile map with real-time counts
        _currentUserProfileMap = _toProfileMapWithCounts(profile, followersCount, followingCount);
        _isProfileLoaded = true;
        debugPrint('✅ [ProfileCache] Profile loaded: ${profile.firstName} ${profile.lastName}');
      }
    } catch (e) {
      debugPrint('⚠️ [ProfileCache] Profile load error: $e');
    }
  }
  
  Future<void> _loadPosts(FirebasePostRepository postRepo, String userId) async {
    try {
      // Cache-first for instant UI
      final cached = await postRepo.getUserPostsFromCache(uid: userId, limit: 50);
      if (cached.isNotEmpty) {
        _currentUserPosts = cached;
      }

      // Refresh from server (non-blocking for UI readiness)
      final fresh = await postRepo.getUserPosts(uid: userId, limit: 50);
      if (fresh.isNotEmpty) {
        _currentUserPosts = fresh;
      }
      _isPostsLoaded = true;
      debugPrint('✅ [ProfileCache] Posts loaded: ${_currentUserPosts.length} posts');
    } catch (e) {
      debugPrint('⚠️ [ProfileCache] Posts load error: $e');
    }
  }
  
  Map<String, dynamic> _toProfileMap(UserProfile profile) {
    return _toProfileMapWithCounts(
      profile,
      profile.followersCount ?? 0,
      profile.followingCount ?? 0,
    );
  }
  
  Map<String, dynamic> _toProfileMapWithCounts(UserProfile profile, int followersCount, int followingCount) {
    final fn = (profile.firstName ?? '').trim();
    final ln = (profile.lastName ?? '').trim();
    final fullName = (fn.isNotEmpty || ln.isNotEmpty)
        ? '$fn $ln'.trim()
        : (profile.displayName ?? profile.username ?? 'User');

    return {
      'id': profile.uid,
      'uid': profile.uid,
      'first_name': profile.firstName ?? '',
      'last_name': profile.lastName ?? '',
      'full_name': fullName,
      'displayName': profile.displayName ?? '',
      'username': profile.username ?? '',
      'bio': profile.bio ?? '',
      'profile_photo_url': profile.avatarUrl ?? '',
      'cover_photo_url': profile.coverUrl ?? '',
      // Stats used by ProfilePage UI - use real-time counts
      'connections_inbound_count': followersCount,
      'connections_outbound_count': followingCount,
      'connections_total_count': followersCount + followingCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'posts_count': profile.postsCount ?? 0,
      'postsCount': profile.postsCount ?? 0,
      // Lists used by ProfilePage UI
      'interest_domains': profile.interestDomains ?? const <String>[],
      'professional_experiences':
          profile.professionalExperiences ?? const <Map<String, dynamic>>[],
      'trainings': profile.trainings ?? const <Map<String, dynamic>>[],
    };
  }
  
  /// Update cached posts UI (after hydration)
  void setCachedPostsUI(List<Post> posts, List<Map<String, String>> media) {
    _currentUserPostsUI = posts;
    _mediaItems = media;
    notifyListeners();
  }
  
  /// Update profile after edit
  void updateProfile(UserProfile profile) {
    _currentUserProfile = profile;
    _currentUserProfileMap = _toProfileMap(profile);
    _isProfileLoaded = true;
    notifyListeners();
  }
  
  /// Clear cache (on logout)
  void clear() {
    _currentUserProfile = null;
    _currentUserProfileMap = null;
    _currentUserPosts = [];
    _currentUserPostsUI = [];
    _mediaItems = [];
    _isProfileLoaded = false;
    _isPostsLoaded = false;
    notifyListeners();
  }
  
  /// Refresh profile data
  Future<void> refresh(String userId) async {
    await preloadCurrentUserData(userId);
  }
}
