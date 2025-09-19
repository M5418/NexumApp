import 'api_client.dart';

class AuthApi {
  final ApiClient _api;
  final TokenStore _store;

  AuthApi(this._api, this._store);

  Future<bool> login(String email, String password) async {
    final data = await _api.postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    final token = (data['accessToken'] as String?) ?? '';
    if (token.isEmpty) {
      return false;
    }
    await _store.save(token);
    return true;
  }

  Future<bool> register(String email, String name, String password) async {
    final data = await _api.postJson('/auth/register', {
      'email': email,
      'name': name,
      'password': password,
    });
    final token = (data['accessToken'] as String?) ?? '';
    if (token.isEmpty) {
      return false;
    }
    await _store.save(token);
    return true;
  }

  Future<Map<String, dynamic>> me() {
    return _api.getJson('/users/me');
  }

  Future<void> logout() {
    return _store.clear();
  }
}
