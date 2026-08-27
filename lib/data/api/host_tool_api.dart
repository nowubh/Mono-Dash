import 'package:dio/dio.dart';

import '../../core/network/api_compatibility.dart';
import '../../core/network/api_response_parser.dart';
import '../../core/network/dio_client.dart';
import '../dto/host_tool/supervisor_dto.dart';

/// 主机工具 API（对应 1Panel `/hosts/tool` 相关接口）。
class HostToolApi {
  HostToolApi(this._client);

  final DioClient _client;

  Future<SupervisorToolStatus> getSupervisorStatus() async {
    final resp = await ApiCompatibility.tryVariants(
      [
        ApiEndpointVariant(
          name: 'hosts.tool.status',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/hosts/tool/status',
            data: const {'type': 'supervisord'},
          ),
        ),
        ApiEndpointVariant(
          name: 'hosts.tool.legacyStatus',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/hosts/tool',
            data: const {'type': 'supervisord', 'operate': 'status'},
          ),
        ),
      ],
      cacheScope: _client,
      cacheKey: 'hosts.tool.status',
    );
    return ApiResponseParser.object(resp, SupervisorToolStatus.fromJson);
  }

  Future<void> operateSupervisor(String operate) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/operate',
      data: {'type': 'supervisord', 'operate': operate},
    );
  }

  Future<void> initSupervisor({
    required String configPath,
    required String serviceName,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/init',
      data: {
        'type': 'supervisord',
        'configPath': configPath,
        'serviceName': serviceName,
      },
    );
  }

  Future<String> operateSupervisorConfig({
    required String operate,
    String content = '',
  }) async {
    final resp = await ApiCompatibility.tryVariants(
      _supervisorConfigVariants(operate: operate, content: content),
      cacheScope: _client,
      cacheKey: 'hosts.tool.config.$operate',
    );
    final data = ApiResponseParser.map(resp);
    return data['content'] as String? ?? '';
  }

  List<ApiEndpointVariant<Response<Map<String, dynamic>>>>
  _supervisorConfigVariants({
    required String operate,
    required String content,
  }) {
    final legacyData = {
      'type': 'supervisord',
      'operate': operate,
      if (content.isNotEmpty || operate == 'set') 'content': content,
    };

    if (operate == 'get') {
      return [
        ApiEndpointVariant(
          name: 'hosts.tool.config.get',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/hosts/tool/config/get',
            data: const {'type': 'supervisord'},
          ),
        ),
        ApiEndpointVariant(
          name: 'hosts.tool.config.legacyGet',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/hosts/tool/config',
            data: legacyData,
          ),
        ),
      ];
    }

    if (operate == 'set') {
      return [
        ApiEndpointVariant(
          name: 'hosts.tool.config.set',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/hosts/tool/config/set',
            data: {'type': 'supervisord', 'content': content},
          ),
        ),
        ApiEndpointVariant(
          name: 'hosts.tool.config.legacySet',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/hosts/tool/config',
            data: legacyData,
          ),
        ),
      ];
    }

    return [
      ApiEndpointVariant(
        name: 'hosts.tool.config.legacy',
        call: () => _client.post<Map<String, dynamic>>(
          '/api/v2/hosts/tool/config',
          data: legacyData,
        ),
      ),
    ];
  }

  Future<List<SupervisorProcessConfig>> getSupervisorProcesses() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/hosts/tool/supervisor/process',
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    return ApiResponseParser.list(resp, SupervisorProcessConfig.fromJson);
  }

  Future<void> submitSupervisorProcess(
    SupervisorProcessConfig config, {
    required String operate,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/supervisor/process',
      data: config.toSubmitJson(operate),
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<void> operateSupervisorProcess({
    required String name,
    required String operate,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/supervisor/process',
      data: {'name': name, 'operate': operate},
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<String> operateSupervisorProcessFile({
    required String name,
    required String file,
    required String operate,
    String content = '',
  }) async {
    final options = Options(
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    );
    final legacyData = {
      'name': name,
      'file': file,
      'operate': operate,
      if (content.isNotEmpty || operate == 'update') 'content': content,
    };

    final resp = await ApiCompatibility.tryVariants(
      operate == 'get'
          ? [
              ApiEndpointVariant(
                name: 'hosts.tool.supervisor.process.file.get',
                call: () => _client.post<Map<String, dynamic>>(
                  '/api/v2/hosts/tool/supervisor/process/file/get',
                  data: {'name': name, 'file': file},
                  options: options,
                ),
              ),
              ApiEndpointVariant(
                name: 'hosts.tool.supervisor.process.file.legacyGet',
                call: () => _client.post<Map<String, dynamic>>(
                  '/api/v2/hosts/tool/supervisor/process/file',
                  data: legacyData,
                  options: options,
                ),
              ),
            ]
          : [
              ApiEndpointVariant(
                name: 'hosts.tool.supervisor.process.file.operate',
                call: () => _client.post<Map<String, dynamic>>(
                  '/api/v2/hosts/tool/supervisor/process/file',
                  data: legacyData,
                  options: options,
                ),
              ),
            ],
      cacheScope: _client,
      cacheKey: 'hosts.tool.supervisor.process.file.$operate',
    );
    final data = resp.data?['data'];
    return data is String ? data : '';
  }
}
