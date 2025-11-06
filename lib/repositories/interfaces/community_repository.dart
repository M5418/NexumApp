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
  });
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
  Future<List<CommunityModel>> listAll({int limit = 100});
  Future<List<CommunityModel>> listMine({int limit = 100});
  Future<CommunityModel?> details(String communityId);
  Future<List<CommunityMemberModel>> members(String communityId, {int limit = 200});
}
