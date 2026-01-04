import 'dart:async';

class CommunityModel {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final String? coverUrl;
  final String friendsInCommon; // display label like "+3"
  final int unreadPosts;
  final int postsCount;
  final int memberCount;
  
  // Multilingual support - maps language code to translated name/bio
  final Map<String, String>? nameTranslations; // e.g., {'fr': 'Nom', 'es': 'Nombre'}
  final Map<String, String>? bioTranslations;  // e.g., {'fr': 'Description', 'es': 'Descripción'}

  CommunityModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    this.coverUrl,
    this.friendsInCommon = '+0',
    this.unreadPosts = 0,
    this.postsCount = 0,
    this.memberCount = 0,
    this.nameTranslations,
    this.bioTranslations,
  });
  
  /// Get localized name for the given language code, falls back to default name
  String getLocalizedName(String languageCode) {
    if (nameTranslations != null && nameTranslations!.containsKey(languageCode)) {
      final translated = nameTranslations![languageCode];
      if (translated != null && translated.isNotEmpty) {
        return translated;
      }
    }
    return name;
  }
  
  /// Get localized bio for the given language code, falls back to default bio
  String getLocalizedBio(String languageCode) {
    if (bioTranslations != null && bioTranslations!.containsKey(languageCode)) {
      final translated = bioTranslations![languageCode];
      if (translated != null && translated.isNotEmpty) {
        return translated;
      }
    }
    return bio;
  }
  
  /// Create a copy with updated fields
  CommunityModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? bio,
    String? coverUrl,
    String? friendsInCommon,
    int? unreadPosts,
    int? postsCount,
    int? memberCount,
    Map<String, String>? nameTranslations,
    Map<String, String>? bioTranslations,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      coverUrl: coverUrl ?? this.coverUrl,
      friendsInCommon: friendsInCommon ?? this.friendsInCommon,
      unreadPosts: unreadPosts ?? this.unreadPosts,
      postsCount: postsCount ?? this.postsCount,
      memberCount: memberCount ?? this.memberCount,
      nameTranslations: nameTranslations ?? this.nameTranslations,
      bioTranslations: bioTranslations ?? this.bioTranslations,
    );
  }
}

class CommunityMemberModel {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? avatarLetter;

  CommunityMemberModel({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.avatarLetter,
  });
}

abstract class CommunityRepository {
  Future<List<CommunityModel>> listAll({int limit = 100, String? lastCommunityId});
  Future<List<CommunityModel>> listMine({int limit = 100, String? lastCommunityId});
  Future<CommunityModel?> details(String communityId);
  Future<List<CommunityMemberModel>> members(String communityId, {int limit = 200});
  Future<void> updateCommunity({
    required String communityId,
    String? name,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    Map<String, String>? nameTranslations,
    Map<String, String>? bioTranslations,
  });
}
