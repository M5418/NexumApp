import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/profile_lite.dart';

/// Local-first repository for Profiles.
/// Reads from Isar instantly, syncs with Firestore in background.
class LocalProfileRepository {
  static final LocalProfileRepository _instance = LocalProfileRepository._internal();
  factory LocalProfileRepository() => _instance;
  LocalProfileRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;

  /// Get profile from local cache (instant)
  ProfileLite? getProfileSync(String uid) {
    final db = isarDB.instance;
    if (db == null) return null;

    return db.profileLites.filter().uidEqualTo(uid).findFirstSync();
  }

  /// Watch a profile for changes
  Stream<ProfileLite?> watchProfile(String uid) {
    final db = isarDB.instance;
    if (db == null) {
      return Stream.value(null);
    }

    return db.profileLites
        .filter()
        .uidEqualTo(uid)
        .watch(fireImmediately: true)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  /// Sync a specific profile from Firestore
  Future<ProfileLite?> syncProfile(String uid) async {
    if (!isIsarSupported) return null;

    final db = isarDB.instance;
    if (db == null) return null;

    try {
      _debugLog('🔄 Syncing profile: $uid');

      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        _debugLog('⚠️ Profile not found: $uid');
        return null;
      }

      final data = doc.data();
      if (data == null) return null;

      final profile = ProfileLite.fromFirestore(doc.id, data);

      await db.writeTxn(() async {
        await db.profileLites.put(profile);
      });

      _debugLog('✅ Synced profile: $uid');
      return profile;
    } catch (e) {
      _debugLog('❌ Profile sync failed: $e');
      return null;
    }
  }

  /// Batch sync multiple profiles (for feed author data)
  Future<void> syncProfiles(List<String> uids) async {
    if (!isIsarSupported || uids.isEmpty) return;

    final db = isarDB.instance;
    if (db == null) return;

    // Filter out already cached profiles
    final toFetch = <String>[];
    for (final uid in uids) {
      final cached = db.profileLites.filter().uidEqualTo(uid).findFirstSync();
      if (cached == null) {
        toFetch.add(uid);
      }
    }

    if (toFetch.isEmpty) return;

    try {
      _debugLog('🔄 Batch syncing ${toFetch.length} profiles');

      // Firestore limits 'in' queries to 30 items
      final batches = <List<String>>[];
      for (var i = 0; i < toFetch.length; i += 30) {
        batches.add(toFetch.sublist(
          i,
          i + 30 > toFetch.length ? toFetch.length : i + 30,
        ));
      }

      final profiles = <ProfileLite>[];

      for (final batch in batches) {
        final snapshot = await _db.collection('users')
            .where(firestore.FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          profiles.add(ProfileLite.fromFirestore(doc.id, data));
        }
      }

      if (profiles.isNotEmpty) {
        await db.writeTxn(() async {
          await db.profileLites.putAll(profiles);
        });
        _debugLog('✅ Batch synced ${profiles.length} profiles');
      }
    } catch (e) {
      _debugLog('❌ Batch profile sync failed: $e');
    }
  }

  /// Update profile locally (optimistic)
  Future<void> updateProfileOptimistic(ProfileLite profile) async {
    final db = isarDB.instance;
    if (db == null) return;

    profile.localUpdatedAt = DateTime.now();
    profile.syncStatus = 'pending';

    await db.writeTxn(() async {
      await db.profileLites.put(profile);
    });

    _debugLog('📝 Updated profile optimistically: ${profile.uid}');
  }

  /// Update sync status after Firestore write
  Future<void> updateSyncStatus(String uid, String status) async {
    final db = isarDB.instance;
    if (db == null) return;

    final profile = db.profileLites.filter().uidEqualTo(uid).findFirstSync();
    if (profile == null) return;

    profile.syncStatus = status;
    profile.localUpdatedAt = DateTime.now();

    await db.writeTxn(() async {
      await db.profileLites.put(profile);
    });
  }

  /// Get all cached profiles
  List<ProfileLite> getAllCachedProfiles() {
    final db = isarDB.instance;
    if (db == null) return [];

    return db.profileLites.where().findAllSync();
  }

  /// Get profile count
  int getLocalCount() {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.profileLites.countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalProfileRepo] $message');
    }
  }
}
