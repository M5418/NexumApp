// Stub file for IsarDB on web platform
// On web, we use Hive instead of Isar

import 'local_store.dart';

/// Stub IsarDB for web - does nothing, web uses WebLocalStore instead
class IsarDB implements LocalStore {
  static final IsarDB _instance = IsarDB._internal();
  factory IsarDB() => _instance;
  IsarDB._internal();

  dynamic get instance => null;

  @override
  bool get isAvailable => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}
}

/// Global accessor
final isarDB = IsarDB();
