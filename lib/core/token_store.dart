import 'token_store_stub.dart'
  if (dart.library.html) 'token_store_web.dart'
  if (dart.library.io) 'token_store_io.dart' as impl;

class TokenStore {
  static Future<String?> read() => impl.readToken();
  static Future<void> write(String token) => impl.writeToken(token);
  static Future<void> clear() => impl.clearToken();
}