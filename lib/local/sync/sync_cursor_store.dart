import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores sync cursors (last sync timestamps) per module.
/// Used for delta sync to fetch only updated documents.
class SyncCursorStore {
  static final SyncCursorStore _instance = SyncCursorStore._internal();
  factory SyncCursorStore() => _instance;
  SyncCursorStore._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  static const String _keyPrefix = 'sync_cursor_';
  static const String _keySeeded = 'sync_seeded_';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    _debugLog('✅ SyncCursorStore initialized');
  }

  /// Get last sync time for a module
  DateTime? getLastSyncTime(String module) {
    final prefs = _prefs;
    if (prefs == null) return null;
    
    final timestamp = prefs.getInt('$_keyPrefix$module');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Set last sync time for a module
  Future<void> setLastSyncTime(String module, DateTime time) async {
    final prefs = _prefs;
    if (prefs == null) return;
    
    await prefs.setInt('$_keyPrefix$module', time.millisecondsSinceEpoch);
    _debugLog('📍 Cursor updated for $module: $time');
  }

  /// Check if initial seeding has been done for a module
  bool isSeeded(String module) {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.getBool('$_keySeeded$module') ?? false;
  }

  /// Mark a module as seeded
  Future<void> markSeeded(String module) async {
    final prefs = _prefs;
    if (prefs == null) return;
    
    await prefs.setBool('$_keySeeded$module', true);
    _debugLog('✅ Module $module marked as seeded');
  }

  /// Clear all sync cursors (for logout/reset)
  Future<void> clearAll() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final keys = prefs.getKeys().where(
      (k) => k.startsWith(_keyPrefix) || k.startsWith(_keySeeded)
    ).toList();

    for (final key in keys) {
      await prefs.remove(key);
    }
    _debugLog('🗑️ All sync cursors cleared');
  }

  /// Get all module cursors for debugging
  Map<String, DateTime?> getAllCursors() {
    final prefs = _prefs;
    if (prefs == null) return {};

    final result = <String, DateTime?>{};
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    
    for (final key in keys) {
      final module = key.substring(_keyPrefix.length);
      final timestamp = prefs.getInt(key);
      if (timestamp != null) {
        result[module] = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    return result;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[SyncCursor] $message');
    }
  }
}
