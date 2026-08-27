import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../utils/file_icon_utils.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../data/dto/file/recycle_bin_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_notice_sheet.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../providers/file_recycle_bin_provider.dart';

class FileRecycleBinSheet extends ConsumerStatefulWidget {
  const FileRecycleBinSheet({super.key, required this.serverId});

  final int serverId;

  static Future<void> show(
    BuildContext context, {
    ProviderContainer? providerContainer,
  }) {
    final container = providerContainer ?? ProviderScope.containerOf(context);
    final serverId = container.read(activeServerIdProvider);
    return showActionSheet(
      context: context,
      providerContainer: container,
      builder: (context) => FileRecycleBinSheet(serverId: serverId),
    );
  }

  @override
  ConsumerState<FileRecycleBinSheet> createState() =>
      _FileRecycleBinSheetState();
}

class _FileRecycleBinSheetState extends ConsumerState<FileRecycleBinSheet> {
  String? _activeRName;
  String? _confirmAction;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(widget.serverId)],
      child: Consumer(
        builder: (context, ref, child) {
          final itemsAsync = ref.watch(fileRecycleBinControllerProvider);

          return itemsAsync.when(
            data: (items) => NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 200) {
                    ref
                        .read(fileRecycleBinControllerProvider.notifier)
                        .loadMore();
                  }
                }
                return false;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_activeRName != null) {
                    setState(() {
                      _activeRName = null;
                      _confirmAction = null;
                    });
                  }
                },
                child: ActionSheetScaffold(
                  isAdaptive: true,
                  showHandle: false,
                  panelHeader: _buildHeader(context, ref),
                  child: items.isEmpty
                      ? _buildEmptyState(context)
                      : Column(
                          children: [
                            ...items.map(
                              (item) => _RecycleBinItem(
                                item: item,
                                isActive: _activeRName == item.rName,
                                confirmAction: _activeRName == item.rName
                                    ? _confirmAction
                                    : null,
                                onActionTap: (action) {
                                  final notifier = ref.read(
                                    fileRecycleBinControllerProvider.notifier,
                                  );
                                  if (action == 'card') {
                                    if (_activeRName != null) {
                                      setState(() {
                                        _activeRName = null;
                                        _confirmAction = null;
                                      });
                                    }
                                    return;
                                  }

                                  if (_activeRName == item.rName) {
                                    if (_confirmAction == action) {
                                      // 执行操作
                                      if (action == 'restore') {
                                        notifier.restoreItem(item);
                                      } else {
                                        notifier.deleteItem(item);
                                      }
                                      setState(() {
                                        _activeRName = null;
                                        _confirmAction = null;
                                      });
                                    } else {
                                      // 进入确认状态
                                      setState(() => _confirmAction = action);
                                    }
                                  } else {
                                    // 展开菜单
                                    setState(() {
                                      _activeRName = item.rName;
                                      _confirmAction = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            if (ref
                                .watch(
                                  fileRecycleBinControllerProvider.notifier,
                                )
                                .isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: CupertinoActivityIndicator(),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                ),
              ),
            ),
            loading: () => ActionSheetScaffold(
              isAdaptive: true,
              showHandle: false,
              child: const SizedBox(
                height: 200,
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
            error: (err, stack) {
              if (err is AppNetworkException && err.statusCode == 404) {
                return AppNoticeSheet(
                  title: context.l10n.files_shareUnsupportedTitle,
                  content: context.l10n.files_recycleUnsupportedContent,
                  icon: TablerIcons.puzzle_off,
                  iconColor: CupertinoColors.systemBlue,
                );
              }
              return AppNoticeSheet(
                title: context.l10n.common_loadingFailed,
                content: err.toString(),
                icon: TablerIcons.alert_triangle,
                iconColor: CupertinoColors.systemRed,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final status = ref.watch(fileRecycleBinControllerProvider.notifier).status;
    final isEnabled = status == 'Enable';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          const Icon(
            TablerIcons.trash,
            size: 26,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.files_recycleTitle,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.label(context),
                ),
              ),
              Text(
                isEnabled
                    ? context.l10n.files_recycleEnabled
                    : context.l10n.files_recycleDisabled,
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled
                      ? CupertinoColors.systemGreen
                      : AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => _showClearConfirm(context, ref),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                TablerIcons.trash_x,
                size: 20,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppToggleSwitch(
            value: isEnabled,
            onChanged: (value) => ref
                .read(fileRecycleBinControllerProvider.notifier)
                .toggleStatus(value),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.files_recycleClearTitle),
        content: Text(context.l10n.files_recycleClearContent),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.common_cancel),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ref.read(fileRecycleBinControllerProvider.notifier).clearAll();
            },
            child: Text(context.l10n.files_recycleClearAction),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              TablerIcons.trash_off,
              size: 64,
              color: AppColors.tertiaryLabel(context),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.files_recycleEmpty,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecycleBinItem extends StatelessWidget {
  const _RecycleBinItem({
    required this.item,
    required this.isActive,
    this.confirmAction,
    required this.onActionTap,
  });

  final RecycleBinDto item;
  final bool isActive;
  final String? confirmAction;
  final Function(String) onActionTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onActionTap('card'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? (confirmAction == 'restore'
                      ? CupertinoColors.systemGreen.withValues(alpha: 0.3)
                      : confirmAction == 'delete'
                      ? CupertinoColors.systemRed.withValues(alpha: 0.3)
                      : AppColors.separator(context).withValues(alpha: 0.1))
                : AppColors.separator(context).withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.label(context).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Builder(
                builder: (context) {
                  if (item.isDir) {
                    return Image.asset(
                      FileIconUtils.getFolderAssetPath(
                        item.name,
                        item.sourcePath,
                      ),
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    );
                  }
                  final extIndex = item.name.lastIndexOf('.');
                  final ext = extIndex != -1
                      ? item.name.substring(extIndex)
                      : '';
                  final (icon, color) = FileIconUtils.getFileIconInfo(
                    context,
                    ext,
                    item.name,
                  );
                  return Icon(
                    icon,
                    color: isActive
                        ? (confirmAction == 'restore'
                              ? CupertinoColors.systemGreen
                              : confirmAction == 'delete'
                              ? CupertinoColors.systemRed
                              : color)
                        : color,
                    size: 24,
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? (confirmAction == 'restore'
                                ? CupertinoColors.systemGreen
                                : confirmAction == 'delete'
                                ? CupertinoColors.systemRed
                                : AppColors.label(context))
                          : AppColors.label(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? (confirmAction == 'restore'
                              ? context.l10n.files_recycleConfirmRestore
                              : confirmAction == 'delete'
                              ? context.l10n.files_recycleConfirmDelete
                              : context.l10n.files_recycleSelectAction)
                        : '${formatBytes(item.size)}  •  ${DateFormat('MM/dd HH:mm').format(item.deleteTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? (confirmAction == 'restore'
                                ? CupertinoColors.systemGreen.withValues(
                                    alpha: 0.7,
                                  )
                                : confirmAction == 'delete'
                                ? CupertinoColors.systemRed.withValues(
                                    alpha: 0.7,
                                  )
                                : AppColors.secondaryLabel(context))
                          : AppColors.secondaryLabel(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 操作区
            if (!isActive)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => onActionTap('menu'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.label(context).withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    TablerIcons.dots,
                    size: 18,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: TablerIcons.restore,
                    color: confirmAction == 'restore'
                        ? CupertinoColors.systemGreen
                        : AppColors.secondaryLabel(
                            context,
                          ).withValues(alpha: 0.5),
                    bgColor: confirmAction == 'restore'
                        ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                        : AppColors.label(context).withValues(alpha: 0.03),
                    onTap: () => onActionTap('restore'),
                  ),
                  const SizedBox(width: 10),
                  _buildActionButton(
                    icon: TablerIcons.trash,
                    color: confirmAction == 'delete'
                        ? CupertinoColors.systemRed
                        : AppColors.secondaryLabel(
                            context,
                          ).withValues(alpha: 0.5),
                    bgColor: confirmAction == 'delete'
                        ? CupertinoColors.systemRed.withValues(alpha: 0.1)
                        : AppColors.label(context).withValues(alpha: 0.03),
                    onTap: () => onActionTap('delete'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
