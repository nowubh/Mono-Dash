import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/file/file_item_dto.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';

class FileDeleteSheet extends StatefulWidget {
  const FileDeleteSheet({
    super.key,
    required this.items,
    required this.recycleEnabled,
  });

  final List<FileItemDto> items;
  final bool recycleEnabled;

  static Future<({bool confirmed, bool forceDelete})?> show(
    BuildContext context, {
    required FileItemDto item,
    required bool recycleEnabled,
  }) {
    return showActionSheet<({bool confirmed, bool forceDelete})>(
      context: context,
      builder: (context) =>
          FileDeleteSheet(items: [item], recycleEnabled: recycleEnabled),
    );
  }

  static Future<({bool confirmed, bool forceDelete})?> showBatch(
    BuildContext context, {
    required List<FileItemDto> items,
    required bool recycleEnabled,
  }) {
    return showActionSheet<({bool confirmed, bool forceDelete})>(
      context: context,
      builder: (context) =>
          FileDeleteSheet(items: items, recycleEnabled: recycleEnabled),
    );
  }

  @override
  State<FileDeleteSheet> createState() => _FileDeleteSheetState();
}

class _FileDeleteSheetState extends State<FileDeleteSheet> {
  bool _forceDelete = false;

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      isFloating: true,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // 顶部图标与标题
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              TablerIcons.trash_x,
              color: CupertinoColors.systemRed,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.items.length > 1
                ? context.l10n.files_deleteBatchTitle(widget.items.length)
                : context.l10n.files_deleteSingleTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.label(context),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.recycleEnabled
                  ? context.l10n.files_deleteToRecycleBinHint
                  : context.l10n.files_deletePermanentHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryLabel(context),
                height: 1.4,
              ),
            ),
          ),

          if (widget.recycleEnabled) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.separator(context).withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      TablerIcons.alert_triangle,
                      color: CupertinoColors.systemOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.files_deleteForceTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.label(context),
                          ),
                        ),
                        Text(
                          context.l10n.files_deleteForceSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppToggleSwitch(
                    value: _forceDelete,
                    onChanged: (val) => setState(() => _forceDelete = val),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: AppColors.secondaryBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.l10n.common_cancel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((confirmed: true, forceDelete: _forceDelete)),
                  child: Text(
                    context.l10n.common_delete,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
