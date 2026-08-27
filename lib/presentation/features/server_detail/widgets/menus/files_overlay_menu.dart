import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../../core/localization/l10n_x.dart';
import '../../../../common/components/frosted_overlay_menu.dart';
import '../../../../common/components/terminal/app_terminal.dart';
import '../../../files/models/files_view_state.dart';
import '../../../files/providers/files_provider.dart';
import '../../../files/screens/download_manager_page.dart';
import '../../../files/widgets/file_create_sheet.dart';
import '../../../files/widgets/file_display_options_sheet.dart';
import '../../../files/widgets/file_favorites_sheet.dart';
import '../../../files/widgets/file_upload_sheet.dart';
import '../../../files/widgets/remote_download_sheet.dart';
import '../../../files/widgets/file_share_list_sheet.dart';
import '../../../files/widgets/file_recycle_bin_sheet.dart';

class FilesOverlayMenu extends ConsumerWidget {
  const FilesOverlayMenu({
    super.key,
    required this.isDark,
    required this.isOverlapping,
    required this.onSearchModeEnter,
  });

  final bool isDark;
  final bool isOverlapping;
  final VoidCallback onSearchModeEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final providerContainer = ProviderScope.containerOf(context);
    final filesState = ref.watch(filesControllerProvider).valueOrNull;
    final showHidden = filesState?.showHidden ?? true;
    final isSelectionMode = filesState?.isSelectionMode ?? false;

    return FrostedOverlayMenuButton(
      label: l10n.serverDetail_menu,
      isDark: isDark,
      isOverlapping: isOverlapping,
      items: [
        // 1. 新建
        FrostedMenuItem(
          text: l10n.serverDetail_new,
          icon: TablerIcons.plus,
          action: () {},
          children: [
            FrostedMenuItem(
              text: l10n.files_createFileTitle,
              icon: TablerIcons.file_plus,
              action: () {
                final path =
                    ref
                        .read(filesControllerProvider)
                        .valueOrNull
                        ?.currentPath ??
                    '/';
                FileCreateSheet.show(
                  context,
                  type: FileCreateType.file,
                  currentPath: path,
                );
              },
            ),
            FrostedMenuItem(
              text: l10n.files_createDirectoryTitle,
              icon: TablerIcons.folder_plus,
              action: () {
                final path =
                    ref
                        .read(filesControllerProvider)
                        .valueOrNull
                        ?.currentPath ??
                    '/';
                FileCreateSheet.show(
                  context,
                  type: FileCreateType.directory,
                  currentPath: path,
                );
              },
            ),
          ],
        ),

        // 2. 刷新
        FrostedMenuItem(
          text: l10n.common_refresh,
          icon: TablerIcons.refresh,
          action: () => ref.read(filesControllerProvider.notifier).refresh(),
        ),

        // 3. 多选
        FrostedMenuItem(
          text: isSelectionMode
              ? l10n.serverDetail_exitSelection
              : l10n.serverDetail_selectMultiple,
          icon: isSelectionMode
              ? TablerIcons.square_rounded_x
              : TablerIcons.square_rounded_check,
          action: () =>
              ref.read(filesControllerProvider.notifier).toggleSelectionMode(),
        ),

        // 4. 搜索
        FrostedMenuItem(
          text: l10n.common_search,
          icon: TablerIcons.search,
          action: onSearchModeEnter,
        ),

        // 5. 收藏夹
        FrostedMenuItem(
          text: l10n.files_favoritesTitle,
          icon: TablerIcons.star,
          action: () => FileFavoritesSheet.show(
            context,
            providerContainer: providerContainer,
          ),
        ),

        // 5. 上传
        FrostedMenuItem(
          text: l10n.upload_title,
          icon: TablerIcons.cloud_upload,
          action: () {},
          children: [
            FrostedMenuItem(
              text: l10n.serverDetail_uploadFromPhotos,
              icon: TablerIcons.photo,
              action: () async {
                final path =
                    ref
                        .read(filesControllerProvider)
                        .valueOrNull
                        ?.currentPath ??
                    '/';
                final result = await FilePicker.pickFiles(
                  type: FileType.image,
                  allowMultiple: true,
                );
                if (result != null &&
                    result.files.isNotEmpty &&
                    context.mounted) {
                  await showFileUploadSheet(
                    context,
                    path,
                    initialFiles: result.files,
                  );
                }
              },
            ),
            FrostedMenuItem(
              text: l10n.serverDetail_uploadFromFiles,
              icon: TablerIcons.file_upload,
              action: () async {
                final path =
                    ref
                        .read(filesControllerProvider)
                        .valueOrNull
                        ?.currentPath ??
                    '/';
                final result = await FilePicker.pickFiles(
                  type: FileType.any,
                  allowMultiple: true,
                );
                if (result != null &&
                    result.files.isNotEmpty &&
                    context.mounted) {
                  await showFileUploadSheet(
                    context,
                    path,
                    initialFiles: result.files,
                  );
                }
              },
            ),
            FrostedMenuItem(
              text: l10n.serverDetail_uploadFromRemote,
              icon: TablerIcons.cloud_download,
              action: () async {
                final path =
                    ref
                        .read(filesControllerProvider)
                        .valueOrNull
                        ?.currentPath ??
                    '/';
                if (context.mounted) {
                  await showRemoteDownloadSheet(context, path);
                }
              },
            ),
          ],
        ),

        // 6. 分享管理
        FrostedMenuItem(
          text: l10n.serverDetail_shareManagement,
          icon: TablerIcons.table_share,
          action: () => FileShareListSheet.show(
            context,
            providerContainer: providerContainer,
          ),
        ),

        // 7. 回收站
        FrostedMenuItem(
          text: l10n.files_recycleTitle,
          icon: TablerIcons.trash,
          action: () => FileRecycleBinSheet.show(
            context,
            providerContainer: providerContainer,
          ),
        ),

        // 7. 下载管理
        FrostedMenuItem(
          text: l10n.download_managerTitle,
          icon: TablerIcons.download,
          action: () {
            final container = ProviderScope.containerOf(context);
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => UncontrolledProviderScope(
                  container: container,
                  child: const DownloadManagerPage(),
                ),
              ),
            );
          },
        ),

        // 7. 视图设置
        FrostedMenuItem(
          text: l10n.serverDetail_viewSettings,
          icon: TablerIcons.adjustments_horizontal,
          action: () {},
          children: [
            FrostedMenuItem(
              text: l10n.serverDetail_listView,
              icon: TablerIcons.list,
              action: () => ref
                  .read(filesControllerProvider.notifier)
                  .updateViewMode(FileViewMode.list),
            ),
            FrostedMenuItem(
              text: l10n.serverDetail_iconView,
              icon: TablerIcons.layout_grid,
              action: () => ref
                  .read(filesControllerProvider.notifier)
                  .updateViewMode(FileViewMode.icon),
            ),
            FrostedMenuItem(
              text: showHidden
                  ? l10n.serverDetail_hideHiddenFiles
                  : l10n.serverDetail_showAllFiles,
              icon: showHidden ? TablerIcons.eye_off : TablerIcons.eye,
              action: () =>
                  ref.read(filesControllerProvider.notifier).toggleShowHidden(),
            ),
            FrostedMenuItem(
              text: l10n.serverDetail_sortSettings,
              icon: TablerIcons.layout_grid,
              action: () => FileDisplayOptionsSheet.show(context),
            ),
          ],
        ),

        // 8. 运行终端
        FrostedMenuItem(
          text: l10n.serverDetail_openTerminal,
          icon: TablerIcons.terminal_2,
          action: () async {
            final path =
                ref.read(filesControllerProvider).valueOrNull?.currentPath ??
                '/';
            await showAppTerminal(
              context,
              containerId: '',
              source: 'host',
              command: 'clear && cd "$path"',
            );
            if (context.mounted) {
              ref.read(filesControllerProvider.notifier).refresh();
            }
          },
        ),
      ],
    );
  }
}
