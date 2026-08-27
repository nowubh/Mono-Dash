import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/network/api_response_parser.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_exceptions.dart';
import '../dto/container/docker_status_dto.dart';
import '../dto/container/container_limit_dto.dart';
import '../dto/container/container_status_dto.dart';
import '../dto/container/container_item_stats_dto.dart';
import '../dto/container/container_daemon_config_dto.dart';
import '../dto/container/container_search_dto.dart';
import '../dto/container/container_resource_stats_dto.dart';
import '../dto/container/container_stats_dto.dart';
import '../dto/container/container_by_image_dto.dart';
import '../dto/container/container_info_dto.dart';
import '../dto/container/container_option_dto.dart';
import '../dto/container/container_compose_dto.dart';
import '../dto/container/compose_template_dto.dart';
import '../dto/container/image_dtos.dart';
import '../dto/container/network_dtos.dart';
import '../dto/common/page_result.dart';

/// 容器 API。
///
/// 对应 1Panel `/containers` 相关接口。
class ContainerApi {
  ContainerApi(this._client);

  final DioClient _client;

  /// 查询 Docker 服务状态。
  Future<DockerStatusDto> getDockerStatus() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/docker/status',
    );
    return ApiResponseParser.object(resp, DockerStatusDto.fromJson);
  }

  /// 获取容器资源限制信息。
  /// GET /api/v2/containers/limit
  Future<ContainerLimitDto> getContainerLimit() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/limit',
    );
    return ApiResponseParser.object(resp, ContainerLimitDto.fromJson);
  }

  /// 获取容器运行状态统计。
  /// GET /api/v2/containers/status
  Future<ContainerStatusDto> getStatus() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/status',
    );
    return ApiResponseParser.object(resp, ContainerStatusDto.fromJson);
  }

  /// 获取容器资源占用与可释放空间统计。
  /// POST /api/v2/containers/item/stats
  Future<ContainerItemStatsDto> getItemStats() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/item/stats',
      data: const {'name': 'system'},
    );
    return ApiResponseParser.object(resp, ContainerItemStatsDto.fromJson);
  }

  /// 获取 Docker daemon 配置。
  /// GET /api/v2/containers/daemonjson
  Future<ContainerDaemonConfigDto> getDaemonConfig() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/daemonjson',
    );
    return ApiResponseParser.object(resp, ContainerDaemonConfigDto.fromJson);
  }

  /// 搜索容器。
  /// POST /api/v2/containers/search
  Future<ContainerSearchDto> searchContainers({
    String state = 'all',
    int page = 1,
    int pageSize = 20,
    String filters = '',
    String orderBy = 'createdAt',
    String order = 'null',
    bool excludeAppStore = false,
    String name = '',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/search',
      data: {
        'state': state,
        'page': page,
        'pageSize': pageSize,
        'filters': filters,
        'orderBy': orderBy,
        'order': order,
        'excludeAppStore': excludeAppStore,
        'name': name,
      },
    );
    return ApiResponseParser.object(resp, ContainerSearchDto.fromJson);
  }

  /// 获取容器资源统计列表信息。
  /// GET /api/v2/containers/list/stats
  Future<List<ContainerResourceStatsDto>> getContainerResourceStats() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/list/stats',
    );
    return ApiResponseParser.list(resp, ContainerResourceStatsDto.fromJson);
  }

  /// 获取单个容器实时监控数据。
  /// GET /api/v2/containers/stats/{containerId}
  Future<ContainerStatsDto> getContainerStats(String containerId) async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/stats/$containerId',
    );
    return ApiResponseParser.object(resp, ContainerStatsDto.fromJson);
  }

  /// 获取 Docker Compose 运行日志。
  Future<String> getComposeLog({
    required String composePath,
    required String since,
    required String tail,
    required bool follow,
    required bool timestamp,
  }) async {
    final resp = await _client.raw.get<ResponseBody>(
      '/api/v2/containers/search/log',
      queryParameters: {
        'compose': composePath,
        'since': since,
        'tail': tail,
        'follow': follow,
        'timestamp': timestamp,
        'operateNode': 'local',
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: const {'Accept': 'text/event-stream'},
      ),
    );

    final body = resp.data;
    if (body == null) return '';

    final chunks = <int>[];
    await for (final chunk in body.stream.timeout(
      const Duration(seconds: 2),
      onTimeout: (sink) => sink.close(),
    )) {
      chunks.addAll(chunk);
    }
    return _normalizeEventStream(utf8.decode(chunks, allowMalformed: true));
  }

  /// 获取单个容器运行日志。
  Future<String> getContainerLog({
    required String containerName,
    required String since,
    required String tail,
    required bool follow,
    required bool timestamp,
  }) async {
    final resp = await _client.raw.get<ResponseBody>(
      '/api/v2/containers/search/log',
      queryParameters: {
        'container': containerName,
        'since': since,
        'tail': tail,
        'follow': follow,
        'timestamp': timestamp,
        'operateNode': 'local',
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: const {'Accept': 'text/event-stream'},
      ),
    );

    final body = resp.data;
    if (body == null) return '';

    final chunks = <int>[];
    await for (final chunk in body.stream.timeout(
      const Duration(seconds: 2),
      onTimeout: (sink) => sink.close(),
    )) {
      chunks.addAll(chunk);
    }
    return _normalizeEventStream(utf8.decode(chunks, allowMalformed: true));
  }

  /// 清空 Docker Compose 日志。
  Future<void> cleanComposeLog({
    required String name,
    required String composePath,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/compose/clean/log',
      query: const {'operateNode': 'local'},
      data: {'name': name, 'path': composePath},
    );
  }

  /// 清空单个容器日志。
  Future<void> cleanContainerLog({required String containerName}) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/clean/log',
      query: const {'operateNode': 'local'},
      data: {'name': containerName},
    );
  }

  /// 根据镜像获取容器状态。
  /// POST /api/v2/containers/list/byimage
  Future<List<ContainerByImageDto>> getContainersByImage(
    String imageName,
  ) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/list/byimage',
      data: {'name': imageName},
    );
    return ApiResponseParser.list(resp, ContainerByImageDto.fromJson);
  }

  /// 升级容器。
  /// POST /api/v2/containers/upgrade
  Future<void> upgradeContainer({
    required String taskID,
    required List<String> names,
    required String image,
    required bool forcePull,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/upgrade',
      data: {
        'taskID': taskID,
        'names': names,
        'image': image,
        'forcePull': forcePull,
      },
    );
    ApiResponseParser.ok(resp);
  }

  /// 制作容器镜像。
  /// POST /api/v2/containers/commit
  Future<void> commitContainer({
    required String containerID,
    required String containerName,
    required String newImageName,
    required String comment,
    required String author,
    required bool pause,
    required String taskID,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/commit',
      data: {
        'containerID': containerID,
        'containerName': containerName,
        'newImageName': newImageName,
        'comment': comment,
        'author': author,
        'pause': pause,
        'taskID': taskID,
      },
    );
    ApiResponseParser.ok(resp);
  }

  /// 获取容器详细信息。
  /// POST /api/v2/containers/info
  Future<ContainerInfoDto> getContainerInfo(String name) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/info',
      data: {'name': name},
    );
    return ApiResponseParser.object(resp, ContainerInfoDto.fromJson);
  }

  /// 获取所有网络信息。
  /// GET /api/v2/containers/network
  Future<List<ContainerOptionDto>> getNetworks() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/network',
    );
    return ApiResponseParser.list(resp, ContainerOptionDto.fromJson);
  }

  /// 分页搜索网络。
  /// POST /api/v2/containers/network/search
  Future<NetworkSearchDto> searchNetworks({
    String info = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/network/search',
      data: {'info': info, 'page': page, 'pageSize': pageSize},
    );
    return ApiResponseParser.object(resp, NetworkSearchDto.fromJson);
  }

  /// 创建网络。
  /// POST /api/v2/containers/network
  Future<void> createNetwork(NetworkCreateReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/network',
      data: req.toJson(),
    );
    ApiResponseParser.ok(resp);
  }

  /// 批量删除网络。
  /// POST /api/v2/containers/network/del
  Future<void> deleteNetworks(List<String> names) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/network/del',
      data: {'names': names},
    );
    ApiResponseParser.ok(resp);
  }

  /// 获取所有挂载卷信息。
  /// GET /api/v2/containers/volume
  Future<List<ContainerOptionDto>> getVolumes() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/volume',
    );
    return ApiResponseParser.list(resp, ContainerOptionDto.fromJson);
  }

  /// 获取全部镜像信息。
  /// GET /api/v2/containers/image
  Future<List<ContainerOptionDto>> getImages() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/image',
    );
    return ApiResponseParser.list(resp, ContainerOptionDto.fromJson);
  }

  /// 更新容器。
  /// POST /api/v2/containers/update
  Future<void> updateContainer(Map<String, dynamic> data) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/update',
      data: data,
    );
    ApiResponseParser.ok(resp);
  }

  /// 容器操作。
  /// POST /api/v2/containers/operate
  Future<void> operateContainer({
    required List<String> names,
    required String operation,
    required String taskID,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/operate',
      data: {'names': names, 'operation': operation, 'taskID': taskID},
    );
    ApiResponseParser.ok(resp);
  }

  /// 清理容器。
  /// POST /api/v2/containers/prune
  Future<void> pruneContainers({
    required String taskID,
    String pruneType = 'container',
    bool withTagAll = false,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/prune',
      data: {
        'taskID': taskID,
        'pruneType': pruneType,
        'withTagAll': withTagAll,
      },
    );
    ApiResponseParser.ok(resp);
  }

  static String _normalizeEventStream(String raw) {
    if (!raw.contains('data:')) return raw.trimRight();
    final lines = <String>[];
    for (final line in const LineSplitter().convert(raw)) {
      if (line.startsWith('data:')) {
        lines.add(line.substring(5).trimLeft());
      } else if (line.isNotEmpty &&
          !line.startsWith('event:') &&
          !line.startsWith('id:') &&
          !line.startsWith('retry:')) {
        lines.add(line);
      }
    }
    return lines.join('\n').trimRight();
  }

  /// 搜索编排 (Compose)。
  /// POST /api/v2/containers/compose/search
  Future<ContainerComposeSearchDto> searchCompose({
    String info = '',
    int page = 1,
    int pageSize = 100,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/compose/search',
      data: {'info': info, 'page': page, 'pageSize': pageSize},
    );
    return ApiResponseParser.object(resp, ContainerComposeSearchDto.fromJson);
  }

  /// 容器编排操作。
  /// POST /api/v2/containers/compose/operate
  Future<void> operateCompose({
    required String name,
    required String path,
    required String operation,
    bool withFile = false,
    bool force = false,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/compose/operate',
      data: {
        'name': name,
        'path': path,
        'operation': operation,
        'withFile': withFile,
        'force': force,
      },
    );
    ApiResponseParser.ok(resp);
  }

  /// 检查容器/编排信息（获取 YAML 或配置）。
  /// POST /api/v2/containers/inspect
  Future<String> inspect({
    required String id,
    required String type,
    required String detail,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/inspect',
      data: {'id': id, 'type': type, 'detail': detail},
    );
    return ApiResponseParser.primitive<String>(resp);
  }

  /// 更新编排。
  /// POST /api/v2/containers/compose/update
  Future<String> updateCompose(Map<String, dynamic> data) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/compose/update',
      data: data,
    );
    ApiResponseParser.ok(resp);
    return data['taskID'] as String;
  }

  /// 测试/校验编排。
  /// POST /api/v2/containers/compose/test
  Future<bool> testCompose(Map<String, dynamic> data) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/compose/test',
      data: data,
    );
    return ApiResponseParser.primitive<bool>(resp);
  }

  /// 创建并启动编排。
  /// POST /api/v2/containers/compose
  Future<String> createCompose(Map<String, dynamic> data) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/compose',
      data: data,
    );
    ApiResponseParser.ok(resp);
    return data['taskID'] as String;
  }

  /// 获取镜像仓库列表。
  /// GET /api/v2/containers/repo
  Future<List<ImageRepoDto>> listImageRepos() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/repo',
    );
    return ApiResponseParser.list(resp, ImageRepoDto.fromJson);
  }

  /// 分页搜索镜像仓库。
  /// POST /api/v2/containers/repo/search
  Future<ImageRepoSearchDto> searchImageRepos({
    String info = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/repo/search',
      data: {'info': info, 'page': page, 'pageSize': pageSize},
    );
    return ApiResponseParser.object(resp, ImageRepoSearchDto.fromJson);
  }

  /// 新增镜像仓库。
  /// POST /api/v2/containers/repo
  Future<void> createImageRepo({
    required String name,
    required String downloadUrl,
    required String protocol,
    bool auth = false,
    String username = '',
    String password = '',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/repo',
      data: {
        'name': name,
        'downloadUrl': downloadUrl,
        'protocol': protocol,
        'auth': auth,
        'username': username,
        'password': password,
      },
    );
    ApiResponseParser.ok(resp);
  }

  /// 编辑镜像仓库。
  /// POST /api/v2/containers/repo/update
  Future<void> updateImageRepo({
    required int id,
    required String downloadUrl,
    required String protocol,
    bool auth = false,
    String username = '',
    String password = '',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/repo/update',
      data: {
        'id': id,
        'downloadUrl': downloadUrl,
        'protocol': protocol,
        'auth': auth,
        'username': username,
        'password': password,
      },
    );
    ApiResponseParser.ok(resp);
  }

  /// 删除镜像仓库。
  /// POST /api/v2/containers/repo/del
  Future<void> deleteImageRepo(int id) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/repo/del',
      data: {'id': id},
    );
    ApiResponseParser.ok(resp);
  }

  /// 同步/检测镜像仓库连接。
  /// POST /api/v2/containers/repo/status
  Future<void> syncImageRepo(int id) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/repo/status',
      data: {'id': id},
      options: Options(receiveTimeout: const Duration(seconds: 40)),
    );
    ApiResponseParser.ok(resp);
  }

  // ==========================================
  // Image API
  // ==========================================

  /// 获取所有镜像列表（不分页）。
  /// GET /api/v2/containers/image/all
  Future<List<DockerImageInfo>> getAllImages() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/containers/image/all',
    );
    return ApiResponseParser.list(resp, DockerImageInfo.fromJson);
  }

  /// 分页搜索镜像。
  /// POST /api/v2/containers/image/search
  Future<PageResult<DockerImageInfo>> searchImages(PageImageReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/image/search',
      data: req.toJson(),
    );
    return ApiResponseParser.object(
      resp,
      (json) =>
          PageResult<DockerImageInfo>.fromJson(json, DockerImageInfo.fromJson),
    );
  }

  /// 构建镜像。
  /// POST /api/v2/containers/image/build
  Future<void> buildImage(ImageBuildReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/image/build',
      data: req.toJson(),
    );
    ApiResponseParser.ok(resp);
  }

  /// 拉取镜像。
  /// POST /api/v2/containers/image/pull
  Future<void> pullImage(ImagePullReq req) async {
    try {
      final resp = await _client.post<Map<String, dynamic>>(
        '/api/v2/containers/image/pull',
        data: req.toJson(),
      );
      ApiResponseParser.ok(resp);
    } on ApiBusinessException catch (e) {
      // Compatibility: 1Panel v2.0.0 expects string instead of array for imageName
      if (e.statusCode == 400 &&
          e.message.contains(
            'unmarshal array into Go struct field ImagePull.imageName of type string',
          )) {
        final data = req.toJson();
        final names = data['imageName'];
        if (names is List && names.isNotEmpty) {
          // If it was an array with one element, send that element as a string
          // If multiple elements, this version of 1Panel likely doesn't support batch pull
          data['imageName'] = names.first;
          final retryResp = await _client.post<Map<String, dynamic>>(
            '/api/v2/containers/image/pull',
            data: data,
          );
          ApiResponseParser.ok(retryResp);
          return;
        }
      }
      rethrow;
    }
  }

  /// 推送镜像。
  /// POST /api/v2/containers/image/push
  Future<void> pushImage(ImagePushReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/image/push',
      data: req.toJson(),
    );
    ApiResponseParser.ok(resp);
  }

  /// 删除镜像。
  /// POST /api/v2/containers/image/remove
  Future<void> removeImage(BatchDeleteReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/image/remove',
      data: req.toJson(),
    );
    ApiResponseParser.ok(resp);
  }

  /// 导出镜像。
  /// POST /api/v2/containers/image/save
  Future<void> saveImage(ImageSaveReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/image/save',
      data: req.toJson(),
    );
    ApiResponseParser.ok(resp);
  }

  /// 重设镜像标签。
  /// POST /api/v2/containers/image/tag
  Future<void> tagImage(ImageTagReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/image/tag',
      data: req.toJson(),
    );
    ApiResponseParser.ok(resp);
  }

  /// 导入镜像。
  /// POST /api/v2/containers/image/load
  Future<void> loadImage(ImageLoadReq req) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/image/load',
      data: req.toJson(),
    );
    ApiResponseParser.ok(resp);
  }

  // ==========================================
  // Compose Template API
  // ==========================================

  /// 搜索编排模板。
  /// POST /api/v2/containers/template/search
  Future<ComposeTemplateSearchDto> searchTemplates({
    String info = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/template/search',
      data: {'info': info, 'page': page, 'pageSize': pageSize},
    );
    return ApiResponseParser.object(resp, ComposeTemplateSearchDto.fromJson);
  }

  /// 创建编排模板。
  /// POST /api/v2/containers/template
  Future<void> createTemplate({
    required String name,
    String description = '',
    required String content,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/template',
      data: {'name': name, 'description': description, 'content': content},
    );
    ApiResponseParser.ok(resp);
  }

  /// 更新编排模板。
  /// POST /api/v2/containers/template/update
  Future<void> updateTemplate({
    required int id,
    String description = '',
    required String content,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/template/update',
      data: {'id': id, 'description': description, 'content': content},
    );
    ApiResponseParser.ok(resp);
  }

  /// 删除编排模板。
  /// POST /api/v2/containers/template/del
  Future<void> deleteTemplates(List<int> ids) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/template/del',
      data: {'ids': ids},
    );
    ApiResponseParser.ok(resp);
  }

  /// 批量导入编排模板。
  /// POST /api/v2/containers/template/batch
  Future<void> batchImportTemplates(
    List<Map<String, dynamic>> templates,
  ) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/template/batch',
      data: {'templates': templates},
    );
    ApiResponseParser.ok(resp);
  }

  // ==========================================
  // Daemon Settings API
  // ==========================================

  /// Docker 服务操作（启动/停止/重启）。
  /// POST /api/v2/containers/docker/operate
  Future<void> dockerOperate(String operation) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/docker/operate',
      data: {'operation': operation},
    );
    ApiResponseParser.ok(resp);
  }

  /// 按 key 更新 daemon.json 配置。
  /// POST /api/v2/containers/daemonjson/update
  Future<void> updateDaemonByKey(String key, String value) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/daemonjson/update',
      data: {'key': key, 'value': value},
    );
    ApiResponseParser.ok(resp);
  }

  /// 更新 IPv6 选项。
  /// POST /api/v2/containers/ipv6option/update
  Future<void> updateIpv6Option({
    required String fixedCidrV6,
    required bool ip6Tables,
    required bool experimental,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/ipv6option/update',
      data: {
        'fixedCidrV6': fixedCidrV6,
        'ip6Tables': ip6Tables,
        'experimental': experimental,
      },
    );
    ApiResponseParser.ok(resp);
  }

  /// 更新日志切割选项。
  /// POST /api/v2/containers/logoption/update
  Future<void> updateLogOption({
    required String logMaxSize,
    required String logMaxFile,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/logoption/update',
      data: {'logMaxSize': logMaxSize, 'logMaxFile': logMaxFile},
    );
    ApiResponseParser.ok(resp);
  }

  /// 读取 daemon.json 原始文本。
  /// GET /api/v2/containers/daemonjson/file
  Future<String> getDaemonJsonFile() async {
    final resp = await _client.get<dynamic>(
      '/api/v2/containers/daemonjson/file',
    );
    return ApiResponseParser.primitive<String>(resp);
  }

  /// 按文件更新 daemon.json。
  /// POST /api/v2/containers/daemonjson/update/byfile
  Future<void> updateDaemonJsonByFile(String file) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/daemonjson/update/byfile',
      data: {'file': file},
    );
    ApiResponseParser.ok(resp);
  }

  /// 获取容器内用户列表。
  Future<List<String>> loadContainerUsers(String containerName) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/containers/users',
      data: {'name': containerName},
    );
    return ApiResponseParser.primitiveList<String>(resp);
  }
}
