import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Multi-layer cache manager for app data
/// Layer 1: In-Memory (fastest - instant access)
/// Layer 2: SharedPreferences (fast - ~50ms)
/// Layer 3: Network/Firestore (slow - 200-500ms)
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // In-memory cache
  final Map<String, CacheEntry> _memoryCache = {};
  
  // Cache configuration
  static const Duration defaultTTL = Duration(minutes: 15);
  static const Duration longTTL = Duration(hours: 1);
  static const Duration shortTTL = Duration(minutes: 5);
  
  // Cache size limits
  static const int maxMemoryCacheSize = 100; // entries
  
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ CacheManager initialized');
  }

  /// Get data from cache (memory first, then disk)
  Future<T?> get<T>(String key, {T Function(Map<String, dynamic>)? fromJson}) async {
    // Check memory cache first
    final memEntry = _memoryCache[key];
    if (memEntry != null && !memEntry.isExpired) {
      debugPrint('🎯 Cache HIT (memory): $key');
      return memEntry.data as T?;
    }

    // Check disk cache
    if (_prefs != null) {
      final diskData = _prefs!.getString('cache_$key');
      if (diskData != null) {
        try {
          final json = jsonDecode(diskData);
          final timestamp = DateTime.parse(json['timestamp'] as String);
          final ttlMinutes = json['ttl'] as int? ?? 15;
          final expiry = timestamp.add(Duration(minutes: ttlMinutes));
          
          if (DateTime.now().isBefore(expiry)) {
            final data = json['data'];
            T? value;
            
            if (fromJson != null && data is Map<String, dynamic>) {
              value = fromJson(data);
            } else {
              value = data as T?;
            }
            
            // Promote to memory cache
            _setMemoryCache(key, value, Duration(minutes: ttlMinutes));
            debugPrint('🎯 Cache HIT (disk): $key');
            return value;
          }
        } catch (e) {
          debugPrint('⚠️ Cache read error for $key: $e');
        }
      }
    }

    debugPrint('❌ Cache MISS: $key');
    return null;
  }

  /// Set data in cache (both memory and disk)
  Future<void> set<T>(String key, T data, {Duration? ttl}) async {
    final duration = ttl ?? defaultTTL;
    
    // Set in memory
    _setMemoryCache(key, data, duration);
    
    // Set in disk
    if (_prefs != null && data != null) {
      try {
        final json = {
          'data': data is Map ? data : (data as dynamic).toJson?.call() ?? data.toString(),
          'timestamp': DateTime.now().toIso8601String(),
          'ttl': duration.inMinutes,
        };
        await _prefs!.setString('cache_$key', jsonEncode(json));
        debugPrint('💾 Cached: $key (TTL: ${duration.inMinutes}m)');
      } catch (e) {
        debugPrint('⚠️ Cache write error for $key: $e');
      }
    }
  }

  /// Set data only in memory (for frequently changing data)
  void setMemoryOnly<T>(String key, T data, {Duration? ttl}) {
    _setMemoryCache(key, data, ttl ?? shortTTL);
    debugPrint('🧠 Memory cached: $key');
  }

  /// Get data from memory only
  T? getMemoryOnly<T>(String key) {
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired) {
      return entry.data as T?;
    }
    return null;
  }

  void _setMemoryCache<T>(String key, T data, Duration ttl) {
    // Remove oldest if cache is full
    if (_memoryCache.length >= maxMemoryCacheSize) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    
    _memoryCache[key] = CacheEntry(
      data: data,
      expiry: DateTime.now().add(ttl),
    );
  }

  /// Clear specific key from all caches
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _prefs?.remove('cache_$key');
    debugPrint('🗑️ Removed cache: $key');
  }

  /// Clear cache by pattern (e.g., 'post_*')
  Future<void> removePattern(String pattern) async {
    final regex = RegExp(pattern.replaceAll('*', '.*'));
    
    // Clear memory
    _memoryCache.removeWhere((key, _) => regex.hasMatch(key));
    
    // Clear disk
    if (_prefs != null) {
      final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_'));
      for (final key in keys) {
        final cleanKey = key.substring(6); // Remove 'cache_' prefix
        if (regex.hasMatch(cleanKey)) {
          await _prefs!.remove(key);
        }
      }
    }
    
    debugPrint('🗑️ Removed cache pattern: $pattern');
  }

  /// Clear all cache
  Future<void> clearAll() async {
    _memoryCache.clear();
    
    if (_prefs != null) {
      final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_'));
      for (final key in keys) {
        await _prefs!.remove(key);
      }
    }
    
    debugPrint('🗑️ Cleared all cache');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final validEntries = _memoryCache.values.where((e) => !e.isExpired).length;
    
    return {
      'memory_entries': _memoryCache.length,
      'valid_entries': validEntries,
      'expired_entries': _memoryCache.length - validEntries,
      'max_size': maxMemoryCacheSize,
    };
  }

  /// Clean expired entries from memory
  void cleanExpired() {
    _memoryCache.removeWhere((_, entry) => entry.isExpired);
    debugPrint('🧹 Cleaned expired cache entries');
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime expiry;

  CacheEntry({
    required this.data,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);
}
