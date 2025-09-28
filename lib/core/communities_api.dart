// lib/core/communities_api.dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'api_client.dart';

class ApiCommunity {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final String? coverUrl;
  final String friendsInCommon;
  final int unreadPosts;

  // Added stats
  final int postsCount;
  final int memberCount;

  ApiCommunity({
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

  factory ApiCommunity.fromJson(Map<String, dynamic> j) {
    return ApiCommunity(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      avatarUrl: (j['avatarUrl'] ?? '').toString(),
      bio: (j['bio'] ?? '').toString(),
      coverUrl: j['coverUrl']?.toString(),
      friendsInCommon: (j['friendsInCommon'] ?? '+0').toString(),
      unreadPosts: (j['unreadPosts'] is num) ? (j['unreadPosts'] as num).toInt() : 0,
      postsCount: (j['postsCount'] is num) ? (j['postsCount'] as num).toInt() : 0,
      memberCount: (j['memberCount'] is num) ? (j['memberCount'] as num).toInt() : 0,
    );
  }
}

class ApiCommunityMember {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? avatarLetter;

  ApiCommunityMember({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.avatarLetter,
  });

  factory ApiCommunityMember.fromJson(Map<String, dynamic> j) {
    return ApiCommunityMember(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      username: j['username']?.toString(),
      avatarUrl: j['avatarUrl']?.toString(),
      avatarLetter: j['avatarLetter']?.toString(),
    );
  }
}

class CommunitiesApi {
  final Dio _dio = ApiClient().dio;

  Future<List<ApiCommunity>> listAll() async {
    final resp = await _dio.get('/api/communities');
    if (resp.data is! Map || resp.data['ok'] != true) {
      throw Exception('Failed to load communities');
    }
    final raw = resp.data['data'] as List<dynamic>? ?? [];
    return raw
        .map((e) => ApiCommunity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ApiCommunity>> listMine() async {
    debugPrint('Loading my communities...');
    final resp = await _dio.get('/api/communities/my');
    if (resp.data is! Map || resp.data['ok'] != true) {
      throw Exception('Failed to load my communities');
    }
    final raw = resp.data['data'] as List<dynamic>? ?? [];
    final items = raw
        .map((e) => ApiCommunity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    debugPrint('Loaded ${items.length} communities');
    return items;
  }

  Future<ApiCommunity> details(String communityId) async {
    final resp = await _dio.get('/api/communities/$communityId');
    final data = resp.data;
    if (data is Map && data['ok'] == true) {
      final d = Map<String, dynamic>.from(data['data'] ?? {});
      return ApiCommunity.fromJson(d);
    }
    if (data is Map) {
      // sometimes backend might not wrap in ok/data in dev
      return ApiCommunity.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Failed to load community details');
  }

  Future<List<ApiCommunityMember>> members(String communityId) async {
    final resp = await _dio.get('/api/communities/$communityId/members');
    if (resp.data is! Map || resp.data['ok'] != true) {
      throw Exception('Failed to load community members');
    }
    final raw = resp.data['data'] as List<dynamic>? ?? [];
    return raw
        .map((e) => ApiCommunityMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}