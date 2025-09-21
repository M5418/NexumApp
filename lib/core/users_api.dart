import 'api_client.dart';

class UsersApi {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getAllUsers() async {
    final res = await _dio.get('/api/users/all');
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<Map<String, dynamic>>> list() async {
    final map = await getAllUsers();
    final data = map['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}
