// Stub file for sync infrastructure on web platform
// On web, sync is handled by WebCacheWarmer

/// Stub SyncCursorStore for web
class SyncCursorStore {
  static final SyncCursorStore _instance = SyncCursorStore._internal();
  factory SyncCursorStore() => _instance;
  SyncCursorStore._internal();

  Future<void> init() async {}
}

/// Stub SyncScheduler for web
class SyncScheduler {
  static final SyncScheduler _instance = SyncScheduler._internal();
  factory SyncScheduler() => _instance;
  SyncScheduler._internal();

  Future<void> init() async {}
  void registerModule(String name, Future<void> Function() callback) {}
  void triggerInitialSync() {}
}

/// Stub InitialSeeder for web
class InitialSeeder {
  static final InitialSeeder _instance = InitialSeeder._internal();
  factory InitialSeeder() => _instance;
  InitialSeeder._internal();

  Future<void> seedAllIfNeeded() async {}
}
