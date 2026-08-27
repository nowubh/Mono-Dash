import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/network/api_response_parser.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/one_panel_auth.dart';
import '../../core/network/web_socket_connector.dart';

/// 进程管理 API（对应 1Panel `/process` 相关接口）。
class ProcessApi {
  ProcessApi(this._client);

  final DioClient _client;

  /// POST /api/v2/process/stop
  Future<void> stopProcess(int pid) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/process/stop',
      data: {'PID': pid},
    );
  }

  /// GET /api/v2/process/:pid
  Future<Map<String, dynamic>> getProcessByPID(int pid) async {
    final resp = await _client.get<dynamic>('/api/v2/process/$pid');
    return ApiResponseParser.map(resp);
  }

  /// POST /api/v2/process/listening
  Future<List<Map<String, dynamic>>> getListeningProcesses() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/process/listening',
    );
    final data = ApiResponseParser.primitive<List<dynamic>>(resp);
    return data
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// WebSocket /api/v2/process/ws?operateNode=...
  static Future<WebSocketChannel> connectProcessWebSocket({
    required String baseUrl,
    required String apiKey,
    bool allowInsecureConnections = false,
    String? operateNode = 'local',
  }) async {
    final uri = Uri.parse(baseUrl);
    final wsUrl = Uri(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      host: uri.host,
      port: uri.port,
      path: '${uri.path}/api/v2/process/ws'.replaceAll('//', '/'),
      queryParameters: operateNode == null
          ? null
          : {'operateNode': operateNode},
    );
    final headers = await OnePanelAuth.signedHeaders(apiKey);

    await checkAppWebSocketAuth(
      wsUrl,
      headers: headers,
      allowInsecureConnections: allowInsecureConnections,
      currentNode: operateNode,
    );
    return connectAppWebSocket(
      wsUrl,
      headers: headers,
      allowInsecureConnections: allowInsecureConnections,
    );
  }
}
