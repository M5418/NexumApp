import '../../models/post.dart';

abstract class SearchRepository {
  Future<SearchResult> search({
    required String query,
    int limit = 10,
    SearchType? type,
  });
  
  Future<List<SearchUser>> searchUsers(String query, {int limit = 10});
  Future<List<SearchCommunity>> searchCommunities(String query, {int limit = 10});
  Future<List<Post>> searchPosts(String query, {int limit = 10});
}

enum SearchType { users, communities, posts, all }

class SearchResult {
  final List<SearchUser> users;
  final List<Post> posts;
  final List<SearchCommunity> communities;

  SearchResult({
    required this.users,
    required this.posts,
    required this.communities,
  });
}

class SearchUser {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  SearchUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });
}

class SearchCommunity {
  final String id;
  final String name;
  final String bio;
  final String avatarUrl;
  final String? coverUrl;

  SearchCommunity({
    required this.id,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    this.coverUrl,
  });
}
