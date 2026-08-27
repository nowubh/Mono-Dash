import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../data/dto/backup/backup_record_dto.dart';
import '../../../../data/dto/container/container_search_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/backup_components.dart';
import '../../../common/components/frosted_dialog.dart';
import '../../../common/components/task_log_sheet.dart';
import '../providers/container_backup_provider.dart';

void showContainerBackupSheet(
  BuildContext context,
  ContainerItemDto containerItem,
) {
  showActionSheet<void>(
    context: context,
    builder: (_) => _ContainerBackupSheet(containerItem: containerItem),
  );
}

class _ContainerBackupSheet extends ConsumerStatefulWidget {
  const _ContainerBackupSheet({required this.containerItem});

  final ContainerItemDto containerItem;

  @override
  ConsumerState<_ContainerBackupSheet> createState() =>
      _ContainerBackupSheetState();
}

class _ContainerBackupSheetState extends ConsumerState<_ContainerBackupSheet> {
  final _scrollController = ScrollController();

  String get _containerName => widget.containerItem.name;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      ref
          .read(containerBackupControllerProvider(_containerName).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(
      containerBackupControllerProvider(_containerName),
    );

    return ActionSheetScaffold(
      maxHeightFactor: 0.82,
      minBodyHeightFactor: 0.6,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
        child: Row(
          children: [
            Icon(
              TablerIcons.archive,
              size: 22,
              color: CupertinoColors.systemTeal.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.containers_backupSheetTitle(
                  widget.containerItem.name,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: _createBackup,
              child: Icon(
                TablerIcons.plus,
                size: 22,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
      child: asyncState.when(
        data: (state) {
          if (state.records.isEmpty) {
            return const BackupEmptyState();
          }
          return ListView.builder(
            controller: _scrollController,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: state.records.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.records.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BackupRecordCard(
                  containerName: _containerName,
                  record: state.records[index],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => AppErrorState(
          title: context.l10n.containers_loadBackupsFailed,
          error: error,
          onRetry: () => ref
              .read(containerBackupControllerProvider(_containerName).notifier)
              .refresh(),
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    final input = await _showBackupInputDialog(context);
    if (input == null || !mounted) return;
    final taskTitle = context.l10n.containers_runBackup;
    final createFailed = context.l10n.containers_createBackupFailed;
    try {
      final notifier = ref.read(
        containerBackupControllerProvider(_containerName).notifier,
      );
      final taskID = await notifier.backup(
        secret: input.secret,
        description: input.description,
        stopBefore: input.stopBefore,
      );
      if (!mounted) return;
      await showTaskLogSheet(
        context,
        title: taskTitle,
        taskID: taskID,
        reader: (taskID) => notifier.readTaskLog(taskID, latest: false),
        onFinished: notifier.refresh,
      );
    } catch (error) {
      showAppErrorToast(createFailed, description: '$error');
    }
  }
}

class _BackupRecordCard extends ConsumerWidget {
  const _BackupRecordCard({required this.containerName, required this.record});

  final String containerName;
  final BackupRecordDto record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ok = record.status.toLowerCase() == 'success';
    final statusColor = ok
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.systemOrange.resolveFrom(context);
    final statusIcon = ok ? TablerIcons.circle_check : TablerIcons.alert_circle;
    final secondary = AppColors.secondaryLabel(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.16),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.fileName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.label(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(TablerIcons.note, size: 14, color: secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  record.description.trim().isEmpty
                      ? context.l10n.containers_noRemark
                      : record.description.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color: secondary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BackupInlineMeta(
                    icon: TablerIcons.file_zip,
                    text: formatBytes(record.size),
                    color: secondary,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: BackupInlineMeta(
                    icon: TablerIcons.clock,
                    text: formatTimeAgo(record.createdAt, context.l10n),
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BackupStatusMeta(
                    alignEnd: false,
                    statusIcon: statusIcon,
                    statusColor: statusColor,
                    statusText: record.status.isEmpty ? '--' : record.status,
                  ),
                ),
              ),
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => showAppToast(
                    context.l10n.containers_runDirectory,
                    description: record.fileDir,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: BackupInlineMeta(
                      icon: TablerIcons.folder,
                      text: record.fileDir,
                      color: secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: BackupTextAction(
                  icon: TablerIcons.restore,
                  label: context.l10n.containers_restore,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                  onTap: () => _recover(context, ref),
                ),
              ),
              Expanded(
                child: BackupTextAction(
                  icon: TablerIcons.trash,
                  label: context.l10n.common_delete,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                  onTap: () => _delete(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _recover(BuildContext context, WidgetRef ref) async {
    final taskTitle = context.l10n.containers_restoreBackupTask;
    final restoreFailed = context.l10n.containers_restoreBackupFailed;
    final notifier = ref.read(
      containerBackupControllerProvider(containerName).notifier,
    );
    final result = await _showRecoverDialog(context);
    if (result == null) return;
    try {
      final taskID = await notifier.recover(
        record,
        secret: result.secret,
        timeout: result.timeout,
      );
      if (!context.mounted) return;
      await showTaskLogSheet(
        context,
        title: taskTitle,
        taskID: taskID,
        reader: (taskID) => notifier.readTaskLog(taskID, latest: true),
        onFinished: notifier.refresh,
      );
    } catch (error) {
      if (!context.mounted) return;
      showAppErrorToast(restoreFailed, description: '$error');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = context.l10n.containers_backupDeleted;
    final deleteFailed = context.l10n.containers_deleteBackupFailed;
    final confirmed = await showFrostedConfirmDialog(
      context,
      title: context.l10n.containers_deleteBackup,
      content: context.l10n.containers_deleteBackupConfirm(record.fileName),
      confirmText: context.l10n.common_delete,
      isDestructive: true,
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(containerBackupControllerProvider(containerName).notifier)
          .delete(record);
      showAppSuccessToast(deleted);
    } catch (error) {
      if (!context.mounted) return;
      showAppErrorToast(deleteFailed, description: '$error');
    }
  }
}

class _BackupInput {
  const _BackupInput({
    required this.secret,
    required this.description,
    required this.stopBefore,
  });

  final String secret;
  final String description;
  final bool stopBefore;
}

Future<_BackupInput?> _showBackupInputDialog(BuildContext context) {
  final secretController = TextEditingController();
  final descController = TextEditingController();
  bool stopBefore = false;

  return showCupertinoDialog<_BackupInput>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => FrostedDialog(
        title: context.l10n.containers_runBackup,
        icon: TablerIcons.archive,
        confirmText: context.l10n.containers_startBackup,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(
          _BackupInput(
            secret: secretController.text.trim(),
            description: descController.text.trim(),
            stopBefore: stopBefore,
          ),
        ),
        child: Column(
          children: [
            CupertinoTextField(
              controller: secretController,
              placeholder: context.l10n.containers_compressionPasswordOptional,
              autocorrect: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: descController,
              placeholder: context.l10n.containers_descriptionOptional,
              autocorrect: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.containers_stopBeforeBackup,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
                AppToggleSwitch(
                  value: stopBefore,
                  onChanged: (v) => setState(() => stopBefore = v),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.containers_stopBeforeBackupHint,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(() {
    secretController.dispose();
    descController.dispose();
  });
}

class _RecoverInput {
  const _RecoverInput({required this.secret, required this.timeout});
  final String secret;
  final int timeout;
}

Future<_RecoverInput?> _showRecoverDialog(BuildContext context) {
  final secretController = TextEditingController();
  final timeoutController = TextEditingController(text: '30');

  return showCupertinoDialog<_RecoverInput>(
    context: context,
    builder: (context) => FrostedDialog(
      title: context.l10n.containers_restoreBackup,
      icon: TablerIcons.restore,
      confirmText: context.l10n.containers_startRestore,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        final timeoutMin = int.tryParse(timeoutController.text) ?? 30;
        final timeoutSec = timeoutMin == -1 ? -1 : timeoutMin * 60;
        Navigator.of(context).pop(
          _RecoverInput(
            secret: secretController.text.trim(),
            timeout: timeoutSec,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.containers_restorePasswordHint,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: secretController,
            placeholder: context.l10n.containers_restorePasswordOptional,
            autocorrect: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                context.l10n.containers_timeout,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoTextField(
                  controller: timeoutController,
                  placeholder: context.l10n.containers_minutes,
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground(
                      context,
                    ).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      context.l10n.containers_minutes,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.containers_restoreTimeoutHint,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    secretController.dispose();
    timeoutController.dispose();
  });
}
