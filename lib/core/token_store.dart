import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _k = FlutterSecureStorage();
  static const _key = 'auth_token';

  static Future<String?> read() => _k.read(key: _key);
  static Future<void> write(String token) => _k.write(key: _key, value: token);
  static Future<void> clear() => _k.delete(key: _key);
}
