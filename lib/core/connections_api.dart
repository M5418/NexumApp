import 'api_client.dart';

class ConnectionsStatus {
  final Set<int> inbound; // they connected to you
  final Set<int> outbound; // you connected to them

  ConnectionsStatus({required this.inbound, required this.outbound});
}

class ConnectionsApi {
  final _dio = ApiClient().dio;

  Future<ConnectionsStatus> status() async {
    final res = await _dio.get('/api/connections');
    final data = res.data is Map ? res.data['data'] : res.data;
    final inboundList = (data['inbound'] as List? ?? const []).cast<dynamic>();
    final outboundList = (data['outbound'] as List? ?? const [])
        .cast<dynamic>();
    return ConnectionsStatus(
      inbound: inboundList.map((e) => (e as num).toInt()).toSet(),
      outbound: outboundList.map((e) => (e as num).toInt()).toSet(),
    );
  }

  Future<void> connect(int userId) async {
    await _dio.post('/api/connections/$userId');
  }

  Future<void> disconnect(int userId) async {
    await _dio.delete('/api/connections/$userId');
  }
}
