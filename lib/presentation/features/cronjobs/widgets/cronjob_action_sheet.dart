import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../data/dto/cronjob/cronjob_dto.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_confirm_sheet.dart';
import '../providers/cronjob_provider.dart';

Future<void> showCronjobActionSheet(
  BuildContext context, {
  required CronjobDto item,
  required VoidCallback onEdit,
  required VoidCallback onToggleStatus,
  required VoidCallback onHandleOnce,
  required VoidCallback onDelete,
  required VoidCallback onViewRecords,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (ctx) => _CronjobActionSheet(
      item: item,
      onEdit: onEdit,
      onToggleStatus: onToggleStatus,
      onHandleOnce: onHandleOnce,
      onDelete: onDelete,
      onViewRecords: onViewRecords,
    ),
  );
}

class _CronjobActionSheet extends ConsumerWidget {
  const _CronjobActionSheet({
    required this.item,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onHandleOnce,
    required this.onDelete,
    required this.onViewRecords,
  });

  final CronjobDto item;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onHandleOnce;
  final VoidCallback onDelete;
  final VoidCallback onViewRecords;

  bool get _isEnabled => cronjobStatusIsEnabled(item.status);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: true,
      maxHeightFactor: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: l10n.cronjobs_management,
            icon: TablerIcons.settings,
          ),
          AppActionGroup(
            children: [
              AppActionRow(
                icon: _isEnabled
                    ? TablerIcons.player_stop
                    : TablerIcons.player_play,
                iconColor: _isEnabled
                    ? CupertinoColors.systemRed
                    : CupertinoColors.systemGreen,
                title: _isEnabled
                    ? l10n.cronjobs_disable
                    : l10n.cronjobs_enable,
                subtitle: Text(
                  _isEnabled
                      ? l10n.cronjobs_disableSubtitle
                      : l10n.cronjobs_enableSubtitle,
                ),
                onTap: () {
                  Navigator.pop(context);
                  onToggleStatus();
                },
              ),
              AppActionRow(
                icon: TablerIcons.player_play,
                iconColor: CupertinoColors.activeBlue,
                title: l10n.cronjobs_runOnce,
                subtitle: Text(l10n.cronjobs_runOnceSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  onHandleOnce();
                },
              ),
              AppActionRow(
                icon: TablerIcons.edit,
                iconColor: CupertinoColors.systemOrange,
                title: l10n.common_edit,
                subtitle: Text(l10n.cronjobs_editSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppSectionHeader(
            title: l10n.cronjobs_records,
            icon: TablerIcons.notes,
          ),
          AppActionGroup(
            children: [
              AppActionRow(
                icon: TablerIcons.history,
                iconColor: CupertinoColors.systemTeal,
                title: l10n.cronjobs_records,
                subtitle: Text(l10n.cronjobs_recordsSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  onViewRecords();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppSectionHeader(
            title: l10n.cronjobs_dangerZone,
            icon: TablerIcons.alert_triangle,
          ),
          AppActionGroup(
            children: [
              AppActionRow(
                icon: TablerIcons.trash,
                iconColor: CupertinoColors.destructiveRed,
                title: l10n.common_delete,
                subtitle: Text(l10n.cronjobs_deleteSubtitle),
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  showActionSheet(
                    context: context,
                    builder: (context) => AppConfirmSheet(
                      title: l10n.cronjobs_deleteTitle,
                      content: l10n.cronjobs_deleteConfirm(item.name),
                      confirmText: l10n.common_delete,
                      confirmColor: CupertinoColors.destructiveRed,
                      onConfirm: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
