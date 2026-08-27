import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/api_compatibility.dart';
import '../../core/network/api_response_parser.dart';
import '../../core/network/dio_client.dart';
import '../dto/common/task_log_dto.dart';
import '../dto/common/page_result.dart';
import '../dto/file/file_favorite_dto.dart';
import '../dto/file/file_item_dto.dart';
import '../dto/file/user_group_dto.dart';
import '../dto/file/file_share_dto.dart';

/// 文件 API。
///
/// 对应 1Panel `/files` 相关接口。
class FileApi {
  FileApi(this._client);

  final DioClient _client;

  /// 下载文件到本地路径。
  /// GET /api/v2/files/download
  Future<void> downloadFile({
    required String path,
    required String savePath,
    String operateNode = 'local',
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    await _client.download(
      '/api/v2/files/download',
      savePath: savePath,
      query: {'path': path, 'operateNode': operateNode},
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 下载文件内容为字节数组。
  /// GET /api/v2/files/download
  Future<Uint8List> downloadBytes({
    required String path,
    String operateNode = 'local',
  }) async {
    final response = await _client.get<List<int>>(
      '/api/v2/files/download',
      query: {'path': path, 'operateNode': operateNode},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  /// 搜索指定目录下的文件列表。
  /// POST /api/v2/files/search
  Future<FileItemDto> searchFiles({
    required String path,
    bool expand = true,
    bool showHidden = true,
    int page = 1,
    int pageSize = 100,
    String search = '',
    bool containSub = false,
    String sortBy = 'name',
    String? sortOrder,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/search',
      data: {
        'path': path,
        'expand': expand,
        'showHidden': showHidden,
        'page': page,
        'pageSize': pageSize,
        'search': search,
        'containSub': containSub,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      },
    );
    return ApiResponseParser.object(resp, FileItemDto.fromJson);
  }

  /// 查询 OpenResty 网站根目录。
  Future<String> getWebsiteRootDir() async {
    final resp = await ApiCompatibility.tryVariants(
      [
        ApiEndpointVariant(
          name: 'settings.website.dir',
          call: () =>
              _client.get<Map<String, dynamic>>('/api/v2/settings/website/dir'),
        ),
        ApiEndpointVariant(
          name: 'files.path.websiteDir',
          call: () => _client.get<Map<String, dynamic>>(
            '/api/v2/files/path/websiteDir',
          ),
        ),
      ],
      cacheScope: _client,
      cacheKey: 'files.websiteRootDir',
    );
    final data = resp.data?['data'];
    return data is String ? data : '';
  }

  /// 读取文件内容。
  Future<T> readFile<T>({
    int id = 0,
    required String type,
    String name = '',
    required T Function(Map<String, dynamic>) fromJson,
    int page = 1,
    int pageSize = 500,
    bool latest = true,
    String taskID = '',
    String taskType = '',
    String taskOperate = '',
    int resourceID = 0,
  }) async {
    final data = _readFilePayload(
      id: id,
      type: type,
      name: name,
      page: page,
      pageSize: pageSize,
      latest: latest,
      taskID: taskID,
      taskType: taskType,
      taskOperate: taskOperate,
      resourceID: resourceID,
    );
    final resp = await ApiCompatibility.tryVariants(
      [
        ApiEndpointVariant(
          name: 'files.read.pathType',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/files/read/${Uri.encodeComponent(type)}',
            query: const {'operateNode': 'local'},
            data: data,
          ),
        ),
        ApiEndpointVariant(
          name: 'files.read.bodyType',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/files/read',
            query: const {'operateNode': 'local'},
            data: data,
          ),
        ),
      ],
      cacheScope: _client,
      cacheKey: 'files.read',
    );
    return ApiResponseParser.object(resp, fromJson);
  }

  /// 读取运行环境构建日志。
  Future<TaskLogDto> readRuntimeLog({
    required int id,
    required String type,
    int page = 1,
    int pageSize = 500,
    bool latest = false,
  }) async {
    final data = _readFilePayload(
      id: id,
      type: type,
      page: page,
      pageSize: pageSize,
      latest: latest,
    );
    final resp = await ApiCompatibility.tryVariants(
      [
        ApiEndpointVariant(
          name: 'files.readRuntime.pathType',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/files/read/${Uri.encodeComponent(type)}',
            data: data,
          ),
        ),
        ApiEndpointVariant(
          name: 'files.readRuntime.bodyType',
          call: () => _client.post<Map<String, dynamic>>(
            '/api/v2/files/read',
            data: data,
          ),
        ),
      ],
      cacheScope: _client,
      cacheKey: 'files.readRuntimeLog',
    );
    return ApiResponseParser.object(resp, TaskLogDto.fromJson);
  }

  Map<String, dynamic> _readFilePayload({
    required int id,
    required String type,
    String name = '',
    required int page,
    required int pageSize,
    required bool latest,
    String taskID = '',
    String taskType = '',
    String taskOperate = '',
    int resourceID = 0,
  }) {
    return {
      if (id != 0) ...{'id': id, 'ID': id},
      'type': type,
      if (name.isNotEmpty) 'name': name,
      'page': page,
      'pageSize': pageSize,
      'latest': latest,
      'taskID': taskID,
      if (taskType.isNotEmpty) 'taskType': taskType,
      if (taskOperate.isNotEmpty) 'taskOperate': taskOperate,
      if (resourceID != 0) 'resourceID': resourceID,
    };
  }

  /// 获取文件内容。
  /// POST /api/v2/files/content
  Future<FileItemDto> getFileContent({
    required String path,
    bool expand = true,
    int page = 1,
    int pageSize = 100,
    bool isDetail = false,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/content',
      data: {
        'path': path,
        'expand': expand,
        'page': page,
        'pageSize': pageSize,
        'isDetail': isDetail,
      },
    );
    return ApiResponseParser.object(resp, FileItemDto.fromJson);
  }

  /// 保存文件内容。
  /// POST /api/v2/files/save
  Future<void> saveFileContent({
    required String path,
    required String content,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/save',
      data: {'path': path, 'content': content},
    );
  }

  /// 获取文件/目录大小。
  /// POST /api/v2/files/size
  Future<int> getFileSize(String path) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/size',
      data: {'path': path},
    );
    final data = resp.data?['data'];
    return (data?['size'] as num?)?.toInt() ?? 0;
  }

  /// 获取回收站状态。
  /// GET /api/v2/files/recycle/status
  Future<bool> getRecycleStatus() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/files/recycle/status',
    );
    final data = resp.data?['data'];
    return data == 'Enable';
  }

  /// 删除文件/目录。
  /// POST /api/v2/files/del
  Future<void> deleteFile({
    required String path,
    required bool isDir,
    bool forceDelete = false,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/del',
      data: {'path': path, 'isDir': isDir, 'forceDelete': forceDelete},
    );
  }

  /// 添加收藏。
  /// POST /api/v2/files/favorite
  Future<int> favoriteFile(String path) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/favorite',
      data: {'path': path},
    );
    final data = resp.data?['data'];
    return (data?['id'] as num?)?.toInt() ?? 0;
  }

  /// 移除收藏。
  /// POST /api/v2/files/favorite/del
  Future<void> deleteFavorite(int favoriteID) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/favorite/del',
      data: {'id': favoriteID},
    );
  }

  /// 查询收藏列表。
  /// POST /api/v2/files/favorite/search
  Future<PageResult<FileFavoriteDto>> searchFavorites({
    int page = 1,
    int pageSize = 1000,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/favorite/search',
      data: {'page': page, 'pageSize': pageSize},
    );
    final data =
        resp.data?['data'] as Map<String, dynamic>? ??
        {'total': 0, 'items': []};
    return PageResult.fromJson(data, FileFavoriteDto.fromJson);
  }

  /// 获取用户和用户组。
  /// POST /api/v2/files/user/group
  Future<UserGroupDto> getUserGroups() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/user/group',
    );
    return ApiResponseParser.object(resp, UserGroupDto.fromJson);
  }

  /// 压缩文件。
  /// POST /api/v2/files/compress
  Future<void> compressFiles({
    required List<String> files,
    required String type,
    required String dst,
    required String name,
    bool replace = false,
    String secret = '',
  }) async {
    await _client.post(
      '/api/v2/files/compress',
      data: {
        'files': files,
        'type': type,
        'dst': dst,
        'name': name,
        'replace': replace,
        'secret': secret,
      },
    );
  }

  /// 解压文件。
  /// POST /api/v2/files/decompress
  Future<void> decompressFile({
    required String path,
    required String type,
    required String dst,
    String secret = '',
  }) async {
    await _client.post(
      '/api/v2/files/decompress',
      data: {'path': path, 'type': type, 'dst': dst, 'secret': secret},
    );
  }

  /// 更新文件/目录权限。
  /// POST /api/v2/files/batch/role
  Future<void> updatePermissions({
    required List<String> paths,
    required int mode,
    required String user,
    required String group,
    bool sub = true,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/batch/role',
      data: {
        'paths': paths,
        'mode': mode,
        'user': user,
        'group': group,
        'sub': sub,
      },
    );
  }

  /// 检查文件/目录是否存在。
  /// POST /api/v2/files/check
  Future<bool> checkFileExists(String path) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/check',
      data: {'path': path, 'withInit': false},
    );
    return resp.data?['data'] == true;
  }

  /// 批量检查文件/目录是否存在。
  /// POST /api/v2/files/batch/check
  Future<List<FileItemDto>> batchCheckFilesExists(List<String> paths) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/batch/check',
      data: {'paths': paths},
    );
    final data = resp.data?['data'] as List<dynamic>?;
    return data?.map((e) => FileItemDto.fromJson(e)).toList() ?? [];
  }

  /// 移动或复制文件/目录。
  /// POST /api/v2/files/move
  Future<void> moveCopyFiles({
    required List<String> oldPaths,
    required String newPath,
    required String type, // 'copy' 或 'cut'
    String name = '',
    bool cover = false,
    List<String> coverPaths = const [],
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/move',
      data: {
        'oldPaths': oldPaths,
        'newPath': newPath,
        'type': type,
        'name': name,
        'cover': cover,
        'coverPaths': coverPaths,
      },
    );
  }

  /// 普通上传（文件大小 <= 10MB）。
  /// POST /api/v2/files/upload
  Future<void> uploadFiles({
    required List<String> filePaths,
    required String targetPath,
    bool overwrite = true,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('path', targetPath));
    formData.fields.add(MapEntry('overwrite', overwrite.toString()));
    for (final filePath in filePaths) {
      final fileName = filePath.split('/').last;
      formData.files.add(
        MapEntry(
          'file',
          await MultipartFile.fromFile(filePath, filename: fileName),
        ),
      );
    }
    await _client.postMultipart<Map<String, dynamic>>(
      '/api/v2/files/upload',
      formData: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  /// 分片上传单个分片。
  /// POST /api/v2/files/chunkupload
  Future<void> uploadChunk({
    required String filePath,
    required String filename,
    required String targetPath,
    required int chunkIndex,
    required int chunkCount,
    required int chunkStart,
    required int chunkEnd,
    bool overwrite = true,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);
    final raf = await file.open();
    try {
      await raf.setPosition(chunkStart);
      final chunkBytes = await raf.read(chunkEnd - chunkStart);
      final formData = FormData.fromMap({
        'path': targetPath,
        'filename': filename,
        'chunkIndex': chunkIndex.toString(),
        'chunkCount': chunkCount.toString(),
        'overwrite': overwrite.toString(),
        'chunk': MultipartFile.fromBytes(chunkBytes, filename: filename),
      });
      await _client.postMultipart<Map<String, dynamic>>(
        '/api/v2/files/chunkupload',
        formData: formData,
        cancelToken: cancelToken,
      );
    } finally {
      await raf.close();
    }
  }

  /// 远程下载。
  /// POST /api/v2/files/wget
  Future<String> wget({
    required String url,
    required String path,
    required String name,
    bool ignoreCertificate = false,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/wget',
      data: {
        'url': url,
        'path': path,
        'name': name,
        'ignoreCertificate': ignoreCertificate,
      },
    );
    final data = resp.data?['data'];
    return data is Map ? (data['key'] ?? '') : '';
  }

  /// 停止远程下载。
  /// POST /api/v2/files/wget/stop
  Future<void> wgetStop(String key) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/wget/stop',
      data: {'key': key},
    );
  }

  /// 获取远程下载任务 keys。
  /// GET /api/v2/files/wget/process/keys
  Future<List<String>> wgetProcessKeys() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/files/wget/process/keys',
    );
    final data = resp.data?['data'];
    if (data is Map && data['keys'] is List) {
      return (data['keys'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  /// 创建文件或目录
  /// POST /api/v2/files
  Future<void> createFileOrDir({
    required String path,
    required bool isDir,
    int? mode,
    String? linkPath,
    bool isLink = false,
    bool isSymlink = true,
    String content = '',
    bool sub = false,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files',
      data: {
        'path': path,
        'isDir': isDir,
        'mode': mode,
        'linkPath': linkPath,
        'isLink': isLink,
        'isSymlink': isSymlink,
        'content': content,
        'sub': sub,
      },
    );
  }

  /// 创建或更新文件分享
  /// POST /api/v2/files/share/create
  Future<Map<String, dynamic>> createFileShare({
    required String path,
    required int expireMinutes,
    String? password,
  }) async {
    final data = <String, dynamic>{
      'path': path,
      'expireMinutes': expireMinutes,
    };
    if (password != null) data['password'] = password;

    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/share/create',
      data: data,
    );
    return resp.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// 取消文件分享
  /// POST /api/v2/files/share/del
  Future<void> deleteFileShare(String path) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/share/del',
      data: {'path': path},
    );
  }

  /// 重命名文件或目录。
  /// POST /api/v2/files/rename
  Future<void> renameFile({
    required String oldPath,
    required String newPath,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/files/rename',
      data: {'oldName': oldPath, 'newName': newPath},
    );
  }

  /// 获取文件分享详情。
  /// POST /api/v2/files/share/detail
  Future<FileShareDto?> getFileShareDetail(String path) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/share/detail',
      data: {'path': path},
    );
    final data = resp.data?['data'];
    if (data == null) return null;
    return FileShareDto.fromJson(data);
  }

  /// 分页查询分享列表。
  /// POST /api/v2/files/share/search
  Future<Map<String, dynamic>> searchFileShares({
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/share/search',
      data: {'page': page, 'pageSize': pageSize},
    );
    return resp.data?['data'] as Map<String, dynamic>? ??
        {'total': 0, 'items': []};
  }

  /// 分页获取回收站列表。
  /// POST /api/v2/files/recycle/search
  Future<Map<String, dynamic>> searchRecycleBin({
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/files/recycle/search',
      data: {'page': page, 'pageSize': pageSize},
    );
    return resp.data?['data'] as Map<String, dynamic>? ??
        {'total': 0, 'items': []};
  }

  /// 还原回收站项。
  /// POST /api/v2/files/recycle/reduce
  Future<void> restoreRecycleItem({
    required String from,
    required String rName,
    String? name,
  }) async {
    final data = <String, dynamic>{'from': from, 'rName': rName};
    if (name != null) data['name'] = name;

    await _client.post('/api/v2/files/recycle/reduce', data: data);
  }

  /// 清空回收站。
  /// POST /api/v2/files/recycle/clear
  Future<void> clearRecycleBin() async {
    await _client.post('/api/v2/files/recycle/clear');
  }

  /// 获取回收站开关状态。
  /// GET /api/v2/files/recycle/status
  Future<String> getRecycleBinStatus() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/files/recycle/status',
    );
    return resp.data?['data'] as String? ?? 'Disable';
  }
}
