import 'package:web/web.dart' as web;

const _key = 'auth_token';

Future<String?> readToken() async {
  // Storage#getItem returns String?; null if not present
  return web.window.localStorage.getItem(_key);
}

Future<void> writeToken(String token) async {
  web.window.localStorage.setItem(_key, token);
}

Future<void> clearToken() async {
  web.window.localStorage.removeItem(_key);
}