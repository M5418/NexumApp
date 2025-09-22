import 'api_client.dart';

class ConnectionsStatus {
  final Set<String> inbound; // they connected to you
  final Set<String> outbound; // you connected to them

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
      inbound: inboundList.map((e) => e.toString()).toSet(),
      outbound: outboundList.map((e) => e.toString()).toSet(),
    );
  }

  Future<void> connect(String userId) async {
    await _dio.post('/api/connections/$userId');
  }

  Future<void> disconnect(String userId) async {
    await _dio.delete('/api/connections/$userId');
  }
}
