import 'package:dio/dio.dart';

import '../../data/dto/file/file_item_dto.dart';
import '../../data/dto/file/user_group_dto.dart';
import '../../data/dto/file/file_share_dto.dart';
import '../../data/dto/file/file_favorite_dto.dart';

/// 文件管理仓库接口。
abstract class FileRepository {
  /// 搜索指定路径下的文件列表。
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
  });

  /// 获取文件内容。
  Future<FileItemDto> getFileContent({
    required String path,
    bool isDetail = false,
  });

  /// 保存文件内容。
  Future<void> saveFileContent({
    required String path,
    required String content,
  });

  /// 获取文件/目录大小。
  Future<int> getFileSize(String path);

  /// 获取回收站状态。
  Future<bool> getRecycleStatus();

  /// 删除文件/目录。
  Future<void> deleteFile({
    required String path,
    required bool isDir,
    bool forceDelete = false,
  });

  /// 获取网站根目录。
  Future<String> getWebsiteRootDir();

  /// 添加收藏。
  Future<int> favoriteFile(String path);

  /// 移除收藏。
  Future<void> deleteFavorite(int favoriteID);

  /// 查询收藏列表。
  Future<List<FileFavoriteDto>> searchFavorites();

  /// 获取用户和用户组。
  Future<UserGroupDto> getUserGroups();

  /// 更新文件/目录权限。
  Future<void> updatePermissions({
    required List<String> paths,
    required int mode,
    required String user,
    required String group,
    bool sub = true,
  });

  Future<String> wget({
    required String url,
    required String path,
    required String name,
    bool ignoreCertificate = false,
  });

  Future<void> wgetStop(String key);

  Future<List<String>> wgetProcessKeys();

  /// 压缩文件。
  Future<void> compressFiles({
    required List<String> files,
    required String type,
    required String dst,
    required String name,
    bool replace = false,
    String? secret,
  });

  /// 解压文件。
  Future<void> decompressFile({
    required String path,
    required String type,
    required String dst,
    String? secret,
  });

  /// 检查文件/目录是否存在。
  Future<bool> checkFileExists(String path);

  /// 批量检查文件/目录是否存在。
  Future<List<FileItemDto>> batchCheckFilesExists(List<String> paths);

  /// 移动或复制文件/目录。
  Future<void> moveCopyFiles({
    required List<String> oldPaths,
    required String newPath,
    required String type, // 'copy' 或 'cut'
    String name = '',
    bool cover = false,
    List<String> coverPaths = const [],
  });

  /// 上传单个文件，内部自动按大小选择普通上传或分片上传。
  Future<void> uploadFile({
    required String filePath,
    required String targetPath,
    bool overwrite = true,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  /// 创建文件或目录。
  Future<void> createFileOrDir({
    required String path,
    required bool isDir,
    int? mode,
    String? linkPath,
    bool isLink = false,
    bool isSymlink = true,
    String content = '',
    bool sub = false,
  });

  /// 创建或更新文件分享。
  Future<FileShareDto> createFileShare({
    required String path,
    required int expireMinutes,
    String? password,
  });

  /// 取消文件分享。
  Future<void> deleteFileShare(String path);

  /// 重命名文件或目录。
  Future<void> renameFile({
    required String oldPath,
    required String newPath,
  });

  /// 获取文件分享详情。
  Future<FileShareDto?> getFileShareDetail(String path);

  /// 分页查询分享列表。
  Future<Map<String, dynamic>> searchFileShares({
    int page = 1,
    int pageSize = 20,
  });

  /// 分页获取回收站列表。
  Future<Map<String, dynamic>> searchRecycleBin({
    int page = 1,
    int pageSize = 20,
  });

  /// 还原回收站项。
  Future<void> restoreRecycleItem({
    required String from,
    required String rName,
    String? name,
  });

  /// 清空回收站。
  Future<void> clearRecycleBin();

  /// 获取回收站开关状态。
  Future<String> getRecycleBinStatus();
}
