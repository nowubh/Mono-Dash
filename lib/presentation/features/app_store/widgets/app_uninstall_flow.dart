import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/app/app_installed_dto.dart';
import '../../../../data/dto/common/task_log_dto.dart';
import '../../../../data/repositories_impl/app_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/frosted_dialog.dart';
import '../../../common/components/task_log_sheet.dart';

Future<void> confirmUninstallApp(
  BuildContext context,
  WidgetRef ref,
  AppInstalledDto app,
) async {
  final l10n = context.l10n;
  bool forceDelete = false;
  bool deleteBackup = false;
  bool deleteImage = false;

  try {
    final repo = await ref.read(appRepositoryProvider.future);
    final config = await repo.getStoreConfig();
    deleteBackup = config.uninstallDeleteBackup;
    deleteImage = config.uninstallDeleteImage;
  } catch (_) {}

  if (!context.mounted) return;
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => FrostedDialog(
        title: l10n.appStore_uninstallApp,
        subtitle: l10n.appStore_uninstallConfirm(app.displayName),
        icon: TablerIcons.trash,
        confirmText: l10n.appStore_confirmUninstall,
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
        child: Column(
          children: [
            _UninstallOption(
              label: l10n.appStore_forceUninstall,
              description: l10n.appStore_forceUninstallDescription,
              value: forceDelete,
              onChanged: (v) => setDialogState(() => forceDelete = v),
            ),
            const _CardDivider(),
            _UninstallOption(
              label: l10n.appStore_deleteBackups,
              description: l10n.appStore_deleteBackupsDescription,
              value: deleteBackup,
              onChanged: (v) => setDialogState(() => deleteBackup = v),
            ),
            const _CardDivider(),
            _UninstallOption(
              label: l10n.appStore_deleteImages,
              description: l10n.appStore_deleteImagesDescription,
              value: deleteImage,
              onChanged: (v) => setDialogState(() => deleteImage = v),
            ),
          ],
        ),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final taskID = const Uuid().v4();
  try {
    final repo = await ref.read(appRepositoryProvider.future);
    await repo.uninstallApp(
      installId: app.id,
      detailId: app.appDetailId,
      taskID: taskID,
      forceDelete: forceDelete,
      deleteBackup: deleteBackup,
      deleteImage: deleteImage,
      deleteDB: true,
    );

    if (!context.mounted) return;
    Navigator.pop(context);
    showTaskLogSheet(
      context,
      title: l10n.appStore_uninstallingTitle(app.displayName),
      taskID: taskID,
      reader: (id) async {
        final log = await repo.readTaskLog(id);
        return TaskLogDto(
          end: log.end,
          path: log.path,
          total: log.total,
          taskStatus: log.taskStatus,
          lines: log.lines.reversed.toList(),
          scope: log.scope,
          totalLines: log.totalLines,
        );
      },
    );
  } catch (e) {
    showAppErrorToast(l10n.appStore_uninstallRequestFailed('$e'));
  }
}

class _UninstallOption extends StatelessWidget {
  const _UninstallOption({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 0.5,
        color: AppColors.separator(context).withValues(alpha: 0.1),
      ),
    );
  }
}
