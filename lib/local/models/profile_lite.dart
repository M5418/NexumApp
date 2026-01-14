import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'profile_lite.g.dart';

/// Lightweight profile model for local Isar storage.
@collection
class ProfileLite {
  Id get isarId => fastHash(uid);

  @Index(unique: true)
  late String uid;

  String? displayName;
  String? firstName;
  String? lastName;
  String? username;
  String? photoUrl;
  String? bio;
  String? email;

  /// Connection counts
  int followersCount = 0;
  int followingCount = 0;
  int postsCount = 0;

  @Index()
  DateTime? updatedAt;

  @Index()
  late DateTime localUpdatedAt;

  String syncStatus = 'synced';

  ProfileLite();

  /// Create from Firestore document data
  factory ProfileLite.fromFirestore(String docId, Map<String, dynamic> data) {
    final profile = ProfileLite()
      ..uid = docId
      ..displayName = data['displayName'] as String?
      ..firstName = data['firstName'] as String?
      ..lastName = data['lastName'] as String?
      ..username = data['username'] as String?
      ..photoUrl = data['avatarUrl'] as String? ?? data['photoUrl'] as String?
      ..bio = data['bio'] as String?
      ..email = data['email'] as String?
      ..followersCount = _safeInt(data['followersCount'])
      ..followingCount = _safeInt(data['followingCount'])
      ..postsCount = _safeInt(data['postsCount'])
      ..updatedAt = _parseTimestamp(data['updatedAt'])
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'synced';

    return profile;
  }

  /// Get full display name
  String get fullName {
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isNotEmpty || ln.isNotEmpty) {
      return '$fn $ln'.trim();
    }
    return displayName ?? username ?? 'User';
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'photoUrl': photoUrl,
      'bio': bio,
      'email': email,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
    };
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value.toInt().clamp(0, 999999999);
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final seconds = (value as dynamic).seconds as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}

