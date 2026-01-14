import 'package:flutter/foundation.dart';

/// Abstract interface for local data storage.
/// Mobile uses Isar, Web uses Hive.
abstract class LocalStore {
  /// Initialize the local store
  Future<void> init();
  
  /// Check if the store is available and initialized
  bool get isAvailable;
  
  /// Close the store and release resources
  Future<void> close();
}

/// Check if Isar is supported on current platform (mobile only)
bool get isIsarSupported => !kIsWeb;

/// Check if Hive is supported on current platform (web only)
bool get isHiveSupported => kIsWeb;

/// Check if any local store is available
bool get isLocalStoreSupported => true; // Both platforms now have local stores
