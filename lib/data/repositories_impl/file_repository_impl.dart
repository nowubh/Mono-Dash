import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_client_provider.dart';
import '../../core/storage/storage_service.dart';
import '../../core/utils/file_icon_path_cache.dart';
import '../../domain/repositories/file_repository.dart';
import '../../presentation/features/server_detail/providers/active_server_provider.dart';
import '../api/file_api.dart';
import '../dto/file/file_favorite_dto.dart';
import '../dto/file/file_item_dto.dart';
import '../dto/file/user_group_dto.dart';
import '../dto/file/file_share_dto.dart';

part 'file_repository_impl.g.dart';

/// [FileRepository] 的默认实现。
class FileRepositoryImpl implements FileRepository {
  FileRepositoryImpl(this._fileApi, this._storage, this._serverId);

  final FileApi _fileApi;
  final StorageService _storage;
  final String _serverId;

  @override
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
  }) => _fileApi.searchFiles(
    path: path,
    expand: expand,
    showHidden: showHidden,
    page: page,
    pageSize: pageSize,
    search: search,
    containSub: containSub,
    sortBy: sortBy,
    sortOrder: sortOrder,
  );

  @override
  Future<FileItemDto> getFileContent({
    required String path,
    bool isDetail = false,
  }) => _fileApi.getFileContent(path: path, isDetail: isDetail);

  @override
  Future<void> saveFileContent({
    required String path,
    required String content,
  }) => _fileApi.saveFileContent(path: path, content: content);

  @override
  Future<int> getFileSize(String path) => _fileApi.getFileSize(path);

  @override
  Future<bool> getRecycleStatus() => _fileApi.getRecycleStatus();

  @override
  Future<void> deleteFile({
    required String path,
    required bool isDir,
    bool forceDelete = false,
  }) => _fileApi.deleteFile(
    path: path,
    isDir: isDir,
    forceDelete: forceDelete,
  );

  @override
  Future<String> getWebsiteRootDir() async {
    final path = await _fileApi.getWebsiteRootDir();
    if (path.isNotEmpty) {
      FileIconPathCache.updatePaths(path);
      _storage.setString('website_path_$_serverId', path);
    }
    return path;
  }

  @override
  Future<int> favoriteFile(String path) => _fileApi.favoriteFile(path);

  @override
  Future<void> deleteFavorite(int favoriteID) =>
      _fileApi.deleteFavorite(favoriteID);

  @override
  Future<List<FileFavoriteDto>> searchFavorites() async {
    final result = await _fileApi.searchFavorites();
    return result.items;
  }

  @override
  Future<UserGroupDto> getUserGroups() => _fileApi.getUserGroups();

  @override
  Future<void> updatePermissions({
    required List<String> paths,
    required int mode,
    required String user,
    required String group,
    bool sub = true,
  }) =>
      _fileApi.updatePermissions(
        paths: paths,
        mode: mode,
        user: user,
        group: group,
        sub: sub,
      );

  @override
  Future<String> wget({
    required String url,
    required String path,
    required String name,
    bool ignoreCertificate = false,
  }) =>
      _fileApi.wget(
        url: url,
        path: path,
        name: name,
        ignoreCertificate: ignoreCertificate,
      );

  @override
  Future<void> wgetStop(String key) => _fileApi.wgetStop(key);

  @override
  Future<List<String>> wgetProcessKeys() => _fileApi.wgetProcessKeys();

  @override
  Future<void> compressFiles({
    required List<String> files,
    required String type,
    required String dst,
    required String name,
    bool replace = false,
    String? secret,
  }) =>
      _fileApi.compressFiles(
        files: files,
        type: type,
        dst: dst,
        name: name,
        replace: replace,
        secret: secret ?? '',
      );

  @override
  Future<void> decompressFile({
    required String path,
    required String type,
    required String dst,
    String? secret,
  }) =>
      _fileApi.decompressFile(
        path: path,
        type: type,
        dst: dst,
        secret: secret ?? '',
      );

  @override
  Future<bool> checkFileExists(String path) => _fileApi.checkFileExists(path);

  @override
  Future<List<FileItemDto>> batchCheckFilesExists(List<String> paths) =>
      _fileApi.batchCheckFilesExists(paths);

  @override
  Future<void> moveCopyFiles({
    required List<String> oldPaths,
    required String newPath,
    required String type,
    String name = '',
    bool cover = false,
    List<String> coverPaths = const [],
  }) =>
      _fileApi.moveCopyFiles(
        oldPaths: oldPaths,
        newPath: newPath,
        type: type,
        name: name,
        cover: cover,
        coverPaths: coverPaths,
      );

  static const _maxSingleFileSize = 10 * 1024 * 1024; // 10MB
  static const _chunkSize = 5 * 1024 * 1024; // 5MB

  @override
  Future<void> uploadFile({
    required String filePath,
    required String targetPath,
    bool overwrite = true,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final fileSize = await File(filePath).length();
    if (fileSize <= _maxSingleFileSize) {
      await _fileApi.uploadFiles(
        filePaths: [filePath],
        targetPath: targetPath,
        overwrite: overwrite,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
        cancelToken: cancelToken,
      );
    } else {
      await _uploadChunked(
        filePath: filePath,
        targetPath: targetPath,
        fileSize: fileSize,
        overwrite: overwrite,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
  }

  Future<void> _uploadChunked({
    required String filePath,
    required String targetPath,
    required int fileSize,
    bool overwrite = true,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final filename = filePath.split('/').last;
    final chunkCount = (fileSize / _chunkSize).ceil();
    for (int i = 0; i < chunkCount; i++) {
      if (cancelToken?.isCancelled == true) return;
      final start = i * _chunkSize;
      final end = min(start + _chunkSize, fileSize);
      await _fileApi.uploadChunk(
        filePath: filePath,
        filename: filename,
        targetPath: targetPath,
        chunkIndex: i,
        chunkCount: chunkCount,
        chunkStart: start,
        chunkEnd: end,
        overwrite: overwrite,
        cancelToken: cancelToken,
      );
      onProgress?.call((i + 1) / chunkCount);
    }
  }

  @override
  Future<void> createFileOrDir({
    required String path,
    required bool isDir,
    int? mode,
    String? linkPath,
    bool isLink = false,
    bool isSymlink = true,
    String content = '',
    bool sub = false,
  }) =>
      _fileApi.createFileOrDir(
        path: path,
        isDir: isDir,
        mode: mode,
        linkPath: linkPath,
        isLink: isLink,
        isSymlink: isSymlink,
        content: content,
        sub: sub,
      );

  @override
  Future<FileShareDto> createFileShare({
    required String path,
    required int expireMinutes,
    String? password,
  }) async {
    final data = await _fileApi.createFileShare(
      path: path,
      expireMinutes: expireMinutes,
      password: password,
    );
    return FileShareDto.fromJson(data);
  }

  @override
  Future<void> deleteFileShare(String path) => _fileApi.deleteFileShare(path);

  @override
  Future<void> renameFile({
    required String oldPath,
    required String newPath,
  }) =>
      _fileApi.renameFile(oldPath: oldPath, newPath: newPath);

  @override
  Future<FileShareDto?> getFileShareDetail(String path) =>
      _fileApi.getFileShareDetail(path);

  @override
  Future<Map<String, dynamic>> searchFileShares({
    int page = 1,
    int pageSize = 20,
  }) =>
      _fileApi.searchFileShares(page: page, pageSize: pageSize);

  @override
  Future<Map<String, dynamic>> searchRecycleBin({
    int page = 1,
    int pageSize = 20,
  }) =>
      _fileApi.searchRecycleBin(page: page, pageSize: pageSize);

  @override
  Future<void> restoreRecycleItem({
    required String from,
    required String rName,
    String? name,
  }) =>
      _fileApi.restoreRecycleItem(from: from, rName: rName, name: name);

  @override
  Future<void> clearRecycleBin() => _fileApi.clearRecycleBin();

  @override
  Future<String> getRecycleBinStatus() => _fileApi.getRecycleBinStatus();
}

/// 基于当前激活服务器的文件仓库 Provider。
@Riverpod(dependencies: [activeServerId, storageService])
Future<FileRepository> fileRepository(Ref ref) async {
  final serverId = ref.watch(activeServerIdProvider);
  final client = await ref.watch(dioClientProvider(serverId).future);
  final storage = ref.watch(storageServiceProvider);
  return FileRepositoryImpl(FileApi(client), storage, serverId.toString());
}
