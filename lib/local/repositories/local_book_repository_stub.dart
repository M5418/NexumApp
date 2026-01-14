// Stub file for LocalBookRepository on web platform

class LocalBookRepository {
  static final LocalBookRepository _instance = LocalBookRepository._internal();
  factory LocalBookRepository() => _instance;
  LocalBookRepository._internal();

  Future<void> syncRemote() async {}
}
