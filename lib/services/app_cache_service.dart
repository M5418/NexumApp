import 'package:flutter/foundation.dart';
import '../repositories/firebase/firebase_conversation_repository.dart';
import '../repositories/firebase/firebase_community_repository.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import '../repositories/interfaces/conversation_repository.dart';
import '../repositories/interfaces/community_repository.dart';
import '../repositories/interfaces/user_repository.dart';
import '../core/admin_config.dart';

/// Global singleton cache for app data (conversations, communities, connections)
/// Preloaded during app startup, instantly available on page navigation
class AppCacheService extends ChangeNotifier {
  static final AppCacheService _instance = AppCacheService._internal();
  factory AppCacheService() => _instance;
  AppCacheService._internal();

  // Cached data
  List<ConversationSummaryModel> _conversations = [];
  List<CommunityModel> _communities = [];
  List<UserProfile> _suggestedUsers = [];
  
  // Loading states
  bool _isConversationsLoaded = false;
  bool _isCommunitiesLoaded = false;
  bool _isSuggestedUsersLoaded = false;
  
  // Getters
  List<ConversationSummaryModel> get conversations => _conversations;
  List<CommunityModel> get communities => _communities;
  List<UserProfile> get suggestedUsers => _suggestedUsers;
  bool get isConversationsLoaded => _isConversationsLoaded;
  bool get isCommunitiesLoaded => _isCommunitiesLoaded;
  bool get isSuggestedUsersLoaded => _isSuggestedUsersLoaded;
  bool get isFullyLoaded => _isConversationsLoaded && _isCommunitiesLoaded && _isSuggestedUsersLoaded;
  
  /// Preload all app data - call this during splash screen
  Future<void> preloadAppData(String userId) async {
    debugPrint('🚀 [AppCache] Preloading conversations + communities + connections...');
    
    // Load in parallel
    await Future.wait([
      _loadConversations(),
      _loadCommunities(userId),
      _loadSuggestedUsers(userId),
    ]);
    
    debugPrint('✅ [AppCache] App data preloaded');
    notifyListeners();
  }
  
  Future<void> _loadConversations() async {
    try {
      final convRepo = FirebaseConversationRepository();
      
      // Try cache first
      final cached = await convRepo.listFromCache();
      if (cached.isNotEmpty) {
        _conversations = cached;
        _isConversationsLoaded = true;
        debugPrint('✅ [AppCache] Conversations from cache: ${cached.length}');
      }
      
      // Then fetch fresh
      final fresh = await convRepo.list();
      if (fresh.isNotEmpty) {
        _conversations = fresh;
      }
      _isConversationsLoaded = true;
      debugPrint('✅ [AppCache] Conversations loaded: ${_conversations.length}');
    } catch (e) {
      debugPrint('⚠️ [AppCache] Conversations load error: $e');
      _isConversationsLoaded = true; // Mark as loaded even on error to prevent blocking
    }
  }
  
  Future<void> _loadCommunities(String userId) async {
    try {
      final commRepo = FirebaseCommunityRepository();
      final isAdmin = AdminConfig.isAdmin(userId);
      
      // Load user's communities
      final list = isAdmin 
          ? await commRepo.listAll(limit: 20)
          : await commRepo.listMine(limit: 20);
      
      _communities = list;
      _isCommunitiesLoaded = true;
      debugPrint('✅ [AppCache] Communities loaded: ${list.length}');
    } catch (e) {
      debugPrint('⚠️ [AppCache] Communities load error: $e');
      _isCommunitiesLoaded = true; // Mark as loaded even on error
    }
  }
  
  Future<void> _loadSuggestedUsers(String userId) async {
    try {
      final userRepo = FirebaseUserRepository();
      
      // Try cache first for instant display
      final cached = await userRepo.getSuggestedUsersFromCache(limit: 20);
      if (cached.isNotEmpty) {
        _suggestedUsers = cached.where((p) => p.uid != userId).toList();
        _isSuggestedUsersLoaded = true;
        debugPrint('✅ [AppCache] Connections from cache: ${cached.length}');
      }
      
      // Then fetch fresh
      final fresh = await userRepo.getSuggestedUsers(limit: 100);
      if (fresh.isNotEmpty) {
        _suggestedUsers = fresh.where((p) => p.uid != userId).toList();
      }
      _isSuggestedUsersLoaded = true;
      debugPrint('✅ [AppCache] Connections loaded: ${_suggestedUsers.length}');
    } catch (e) {
      debugPrint('⚠️ [AppCache] Connections load error: $e');
      _isSuggestedUsersLoaded = true;
    }
  }
  
  /// Update suggested users cache
  void updateSuggestedUsers(List<UserProfile> users) {
    _suggestedUsers = users;
    _isSuggestedUsersLoaded = true;
    notifyListeners();
  }
  
  /// Update conversations cache (after new message)
  void updateConversations(List<ConversationSummaryModel> conversations) {
    _conversations = conversations;
    _isConversationsLoaded = true;
    notifyListeners();
  }
  
  /// Update communities cache
  void updateCommunities(List<CommunityModel> communities) {
    _communities = communities;
    _isCommunitiesLoaded = true;
    notifyListeners();
  }
  
  /// Clear cache (on logout)
  void clear() {
    _conversations = [];
    _communities = [];
    _suggestedUsers = [];
    _isConversationsLoaded = false;
    _isCommunitiesLoaded = false;
    _isSuggestedUsersLoaded = false;
    _safeNotifyListeners();
  }
  
  /// Safe notify that catches disposed listener errors
  void _safeNotifyListeners() {
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [AppCache] notifyListeners error (safe to ignore): $e');
    }
  }
  
  /// Refresh all data
  Future<void> refresh(String userId) async {
    await preloadAppData(userId);
  }
}
