import 'dart:convert';

import '../../core/network/api_compatibility.dart';
import '../../core/network/api_response_parser.dart';
import '../../core/network/dio_client.dart';

/// 设置相关 API。
class SettingApi {
  SettingApi(this._client);

  final DioClient _client;

  /// 获取面板安装根目录。
  /// GET /api/v2/settings/basedir
  Future<String> getBaseDir() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/settings/basedir',
    );
    return ApiResponseParser.primitive<String>(resp);
  }

  /// 更新系统设置。
  /// POST /api/v2/settings/update
  Future<void> updateSetting({
    required String key,
    required String value,
  }) async {
    await _client.post(
      '/api/v2/settings/update',
      data: {'key': key, 'value': value},
    );
  }

  /// 保存描述与置顶状态。
  /// POST /api/v2/settings/description/save
  Future<void> saveDescription({
    required String id,
    required String type,
    String detailType = '',
    required bool isPinned,
    required String description,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/settings/description/save',
      data: {
        'id': id,
        'type': type,
        'detailType': detailType,
        'isPinned': isPinned,
        'description': description,
      },
    );
    ApiResponseParser.ok(resp);
  }

  /// 搜索系统设置。
  /// POST /api/v2/settings/search
  Future<Map<String, dynamic>> searchSettings() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/settings/search',
      data: {},
    );
    return resp.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// 获取系统 IP 地址（宿主机地址）。
  ///
  /// 从系统设置中提取 `systemIP` 字段。
  Future<String> getSystemIP() async {
    final settings = await searchSettings();
    return (settings['systemIP'] as String?) ?? '';
  }

  /// 搜索 Core 侧面板配置（用户名、主题、语言、会话超时等）。
  /// POST /api/v2/core/settings/search
  Future<Map<String, dynamic>> searchCoreSettings() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/core/settings/search',
      data: {},
    );
    final raw = resp.data?['data'];
    final settings = raw is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    try {
      final current = await loadCurrentUser();
      for (final key in const [
        'apiInterfaceStatus',
        'apiKey',
        'ipWhiteList',
        'apiKeyValidityTime',
      ]) {
        if (current.containsKey(key)) settings[key] = current[key];
      }
      final currentName = current['name']?.toString();
      if ((settings['userName']?.toString().isEmpty ?? true) &&
          currentName != null &&
          currentName.isNotEmpty) {
        settings['userName'] = currentName;
      }
    } catch (_) {
      // Older 1Panel versions do not expose /core/auth/current.
    }

    return settings;
  }

  /// 更新 Core 侧面板配置。
  /// POST /api/v2/core/settings/update
  Future<void> updateCoreSetting({
    required String key,
    required String value,
  }) async {
    await _client.post(
      '/api/v2/core/settings/update',
      data: {'key': key, 'value': value},
    );
  }

  /// 获取 Core 侧备忘录。
  /// GET /api/v2/core/settings/memo
  Future<String> getMemo() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/settings/memo',
    );
    return ApiResponseParser.primitive<String>(resp);
  }

  /// 保存 Core 侧备忘录。
  /// POST /api/v2/core/settings/memo
  Future<void> saveMemo(String content) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/core/settings/memo',
      data: {'content': content},
    );
    ApiResponseParser.ok(resp);
  }

  /// 更新面板登录密码。
  /// POST /api/v2/core/settings/password/update
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await ApiCompatibility.tryVariants<void>(
      [
        ApiEndpointVariant(
          name: 'core.auth.current.updatePassword',
          call: () async {
            final user = await loadCurrentUser();
            final name = user['name']?.toString() ?? '';
            await _client.post(
              '/api/v2/core/auth/current/update',
              data: {
                'name': name,
                'oldPassword': base64Encode(utf8.encode(oldPassword)),
                'password': base64Encode(utf8.encode(newPassword)),
              },
            );
          },
        ),
        ApiEndpointVariant(
          name: 'core.settings.password.update',
          call: () async {
            await _client.post(
              '/api/v2/core/settings/password/update',
              data: {'oldPassword': oldPassword, 'newPassword': newPassword},
            );
          },
        ),
      ],
      cacheScope: _client,
      cacheKey: 'core.password.update',
    );
  }

  Future<Map<String, dynamic>> loadCurrentUser() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/auth/current',
    );
    return ApiResponseParser.map(resp);
  }

  // ── 安全设置 ──

  /// 更新面板端口。
  /// POST /api/v2/core/settings/port/update
  Future<void> updatePort(int serverPort) async {
    await _client.post(
      '/api/v2/core/settings/port/update',
      data: {'serverPort': serverPort},
    );
  }

  /// 获取网络接口地址列表。
  /// GET /api/v2/core/settings/interface
  Future<List<String>> loadInterfaceAddr() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/settings/interface',
    );
    final data = resp.data?['data'];
    if (data is List) return data.whereType<String>().toList();
    return [];
  }

  /// 更新绑定地址。
  /// POST /api/v2/core/settings/bind/update
  Future<void> updateBindInfo({
    required String ipv6,
    required String bindAddress,
  }) async {
    await _client.post(
      '/api/v2/core/settings/bind/update',
      data: {'ipv6': ipv6, 'bindAddress': bindAddress},
    );
  }

  /// 更新 SSL 配置。
  /// POST /api/v2/core/settings/ssl/update
  Future<void> updateSSL(Map<String, dynamic> data) async {
    await _client.post('/api/v2/core/settings/ssl/update', data: data);
  }

  /// 获取 SSL 信息。
  /// GET /api/v2/core/settings/ssl/info
  Future<Map<String, dynamic>> loadSSLInfo() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/core/settings/ssl/info',
    );
    return ApiResponseParser.map(resp);
  }

  /// 加载 MFA 信息。
  /// POST /api/v2/core/settings/mfa
  Future<Map<String, dynamic>> loadMFA({
    required String title,
    required int interval,
  }) async {
    final data = {'title': title, 'interval': interval};
    final resp = await ApiCompatibility.tryVariants(
      [
        ApiEndpointVariant(
          name: 'core.auth.mfa',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/core/auth/mfa',
            data: data,
          ),
        ),
        ApiEndpointVariant(
          name: 'core.settings.mfa',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/core/settings/mfa',
            data: data,
          ),
        ),
      ],
      cacheScope: _client,
      cacheKey: 'core.mfa.load',
    );
    return ApiResponseParser.map(resp);
  }

  /// 绑定 MFA。
  /// POST /api/v2/core/settings/mfa/bind
  Future<void> bindMFA({
    required String secret,
    required String code,
    required String interval,
  }) async {
    final data = {'secret': secret, 'code': code, 'interval': interval};
    await ApiCompatibility.tryVariants<void>(
      [
        ApiEndpointVariant(
          name: 'core.auth.mfa.bind',
          call: () async {
            await _client.post('/api/v2/core/auth/mfa/bind', data: data);
          },
        ),
        ApiEndpointVariant(
          name: 'core.settings.mfa.bind',
          call: () async {
            await _client.post('/api/v2/core/settings/mfa/bind', data: data);
          },
        ),
      ],
      cacheScope: _client,
      cacheKey: 'core.mfa.bind',
    );
  }

  /// 获取 Passkey 列表。
  /// GET /api/v2/core/settings/passkey/list
  Future<List<Map<String, dynamic>>> listPasskeys() async {
    final resp = await ApiCompatibility.tryVariants(
      [
        ApiEndpointVariant(
          name: 'core.auth.passkey.list',
          call: () => _client.get<Map<String, dynamic>>(
            '/api/v2/core/auth/passkey/list',
          ),
        ),
        ApiEndpointVariant(
          name: 'core.settings.passkey.list',
          call: () => _client.get<Map<String, dynamic>>(
            '/api/v2/core/settings/passkey/list',
          ),
        ),
      ],
      cacheScope: _client,
      cacheKey: 'core.passkey.list',
    );
    final data = resp.data?['data'];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  /// 删除 Passkey。
  /// DELETE /api/v2/core/settings/passkey/:id
  Future<void> deletePasskey(int id) async {
    await ApiCompatibility.tryVariants<void>(
      [
        ApiEndpointVariant(
          name: 'core.auth.passkey.del',
          call: () async {
            await _client.post(
              '/api/v2/core/auth/passkey/del',
              data: {'id': '$id'},
            );
          },
        ),
        ApiEndpointVariant(
          name: 'core.settings.passkey.delete',
          call: () async {
            await _client.delete('/api/v2/core/settings/passkey/$id');
          },
        ),
      ],
      cacheScope: _client,
      cacheKey: 'core.passkey.delete',
    );
  }

  // ── API 接口配置 ──

  /// 生成 API 密钥。
  /// POST /api/v2/core/settings/api/config/generate/key
  Future<String> generateApiKey() async {
    final resp = await ApiCompatibility.tryVariants(
      [
        ApiEndpointVariant(
          name: 'core.auth.api.generate',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/core/auth/api/generate',
            data: {},
          ),
        ),
        ApiEndpointVariant(
          name: 'core.settings.api.config.generate.key',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/core/settings/api/config/generate/key',
            data: {},
          ),
        ),
      ],
      cacheScope: _client,
      cacheKey: 'core.api.generate',
    );
    return ApiResponseParser.primitive<String>(resp);
  }

  /// 更新 API 接口配置。
  /// POST /api/v2/core/settings/api/config/update
  Future<void> updateApiConfig(Map<String, dynamic> config) async {
    await ApiCompatibility.tryVariants<void>(
      [
        ApiEndpointVariant(
          name: 'core.auth.api.update',
          call: () async {
            await _client.post('/api/v2/core/auth/api/update', data: config);
          },
        ),
        ApiEndpointVariant(
          name: 'core.settings.api.config.update',
          call: () async {
            await _client.post(
              '/api/v2/core/settings/api/config/update',
              data: config,
            );
          },
        ),
      ],
      cacheScope: _client,
      cacheKey: 'core.api.update',
    );
  }

  // ── 快照 ──

  /// 创建快照。
  /// POST /api/v2/settings/snapshot
  Future<void> createSnapshot(Map<String, dynamic> data) async {
    await _client.post('/api/v2/settings/snapshot', data: data);
  }

  /// 导入/同步快照。
  /// POST /api/v2/settings/snapshot/import
  Future<void> importSnapshot(Map<String, dynamic> data) async {
    await _client.post('/api/v2/settings/snapshot/import', data: data);
  }

  /// 搜索快照列表。
  /// POST /api/v2/settings/snapshot/search
  Future<Map<String, dynamic>> searchSnapshots({
    required int page,
    required int pageSize,
    String info = '',
    String orderBy = 'createdAt',
    String order = 'null',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/settings/snapshot/search',
      data: {
        'page': page,
        'pageSize': pageSize,
        'info': info,
        'orderBy': orderBy,
        'order': order,
      },
    );
    return ApiResponseParser.map(resp);
  }

  /// 加载快照树数据。
  /// GET /api/v2/settings/snapshot/load
  Future<Map<String, dynamic>> loadSnapshotData() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/settings/snapshot/load',
    );
    return ApiResponseParser.map(resp);
  }

  /// 删除快照。
  /// POST /api/v2/settings/snapshot/del
  Future<void> deleteSnapshots({
    required List<int> ids,
    bool deleteWithFile = false,
  }) async {
    await _client.post(
      '/api/v2/settings/snapshot/del',
      data: {'ids': ids, 'deleteWithFile': deleteWithFile},
    );
  }

  /// 恢复快照。
  /// POST /api/v2/settings/snapshot/recover
  Future<void> recoverSnapshot({
    required int id,
    bool isNew = false,
    bool reDownload = false,
    String taskID = '',
    String secret = '',
  }) async {
    await _client.post(
      '/api/v2/settings/snapshot/recover',
      data: {
        'id': id,
        'isNew': isNew,
        'reDownload': reDownload,
        'taskID': taskID,
        'secret': secret,
      },
    );
  }

  /// 回滚快照。
  /// POST /api/v2/settings/snapshot/rollback
  Future<void> rollbackSnapshot({
    required int id,
    String taskID = '',
    String secret = '',
  }) async {
    await _client.post(
      '/api/v2/settings/snapshot/rollback',
      data: {'id': id, 'taskID': taskID, 'secret': secret},
    );
  }

  /// 重新创建快照。
  /// POST /api/v2/settings/snapshot/recreate
  Future<void> recreateSnapshot(int id) async {
    await _client.post('/api/v2/settings/snapshot/recreate', data: {'id': id});
  }

  /// 更新快照描述。
  /// POST /api/v2/settings/snapshot/description/update
  Future<void> updateSnapshotDescription(int id, String description) async {
    await _client.post(
      '/api/v2/settings/snapshot/description/update',
      data: {'id': id, 'description': description},
    );
  }
}
