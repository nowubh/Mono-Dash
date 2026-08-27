import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/database/database_instance_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../../data/repositories_impl/database_repository_impl.dart';

/// 显示删除数据库 Sheet。
///
/// 先做占用检查，无占用则展示输入库名确认删除的表单。
/// 删除成功后调用 [onDeleted]。
Future<void> showDatabaseDeleteSheet(
  BuildContext context, {
  required DatabaseSearchItemDto database,
  required String type,
  VoidCallback? onDeleted,
}) async {
  await showActionSheet<void>(
    context: context,
    builder: (_) => _DatabaseDeleteSheet(
      database: database,
      type: type,
      onDeleted: onDeleted,
    ),
  );
}

class _DatabaseDeleteSheet extends ConsumerStatefulWidget {
  const _DatabaseDeleteSheet({
    required this.database,
    required this.type,
    this.onDeleted,
  });

  final DatabaseSearchItemDto database;
  final String type;
  final VoidCallback? onDeleted;

  @override
  ConsumerState<_DatabaseDeleteSheet> createState() =>
      _DatabaseDeleteSheetState();
}

class _DatabaseDeleteSheetState extends ConsumerState<_DatabaseDeleteSheet> {
  List<DBResourceDto>? _resources;
  bool _checking = true;
  bool _deleting = false;
  bool _forceDelete = false;
  bool _deleteBackup = false;
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      final result = await repo.checkDelete(
        id: widget.database.id,
        type: widget.type,
        database: widget.database.instanceName,
      );
      if (mounted) {
        setState(() {
          _resources = result;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checking = false);
        showAppErrorToast(
          context.l10n.databases_checkFailed,
          description: '$e',
        );
      }
    }
  }

  bool get _canConfirm =>
      _confirmController.text.trim() == widget.database.name;

  Future<void> _submit() async {
    if (!_canConfirm) return;
    setState(() => _deleting = true);
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      await repo.deleteDatabase(
        id: widget.database.id,
        type: widget.type,
        database: widget.database.instanceName,
        forceDelete: _forceDelete,
        deleteBackup: _deleteBackup,
      );
      if (mounted) {
        showAppSuccessToast(context.l10n.databases_deleted);
        widget.onDeleted?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.databases_deleteFailed,
          description: '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
        child: Row(
          children: [
            Icon(
              TablerIcons.trash,
              size: 22,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.databases_deleteDatabase,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.l10n.common_cancel,
                style: TextStyle(
                  color: AppColors.secondaryLabel(context),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
      child: _checking
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : _resources != null && _resources!.isNotEmpty
          ? _buildBlocked()
          : _buildConfirm(),
    );
  }

  Widget _buildBlocked() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemOrange
                .resolveFrom(context)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CupertinoColors.systemOrange
                  .resolveFrom(context)
                  .withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                TablerIcons.alert_triangle,
                size: 18,
                color: CupertinoColors.systemOrange.resolveFrom(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.databases_deleteBlocked,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.label(context),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...(_resources!.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _resourceIcon(r.type),
                    size: 16,
                    color: AppColors.secondaryLabel(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.label(context),
                      ),
                    ),
                  ),
                  Text(
                    r.type,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildConfirm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 警告
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed
                .resolveFrom(context)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CupertinoColors.systemRed
                  .resolveFrom(context)
                  .withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                TablerIcons.alert_triangle,
                size: 18,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.databases_deleteWarning(widget.database.name),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.label(context),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 输入库名确认
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l10n.databases_deleteConfirmInput(widget.database.name),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
        CupertinoTextField(
          controller: _confirmController,
          placeholder: widget.database.name,
          onChanged: (_) => setState(() {}),
          autocorrect: false,
          enableSuggestions: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          style: TextStyle(fontSize: 16, color: AppColors.label(context)),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _confirmController.text.isNotEmpty && !_canConfirm
                  ? CupertinoColors.systemRed
                        .resolveFrom(context)
                        .withValues(alpha: 0.4)
                  : AppColors.separator(context).withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 选项
        _buildToggle(
          icon: TablerIcons.forbid,
          title: context.l10n.databases_forceDelete,
          subtitle: context.l10n.databases_forceDeleteSubtitle,
          value: _forceDelete,
          onChanged: (v) => setState(() => _forceDelete = v),
        ),
        const SizedBox(height: 10),
        _buildToggle(
          icon: TablerIcons.database_off,
          title: context.l10n.databases_deleteBackups,
          subtitle: context.l10n.databases_deleteBackupsSubtitle,
          value: _deleteBackup,
          onChanged: (v) => setState(() => _deleteBackup = v),
        ),
        const SizedBox(height: 32),
        // 删除按钮
        SizedBox(
          width: double.infinity,
          height: 50,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            color: _canConfirm
                ? CupertinoColors.systemRed.resolveFrom(context)
                : AppColors.separator(context).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            onPressed: (_canConfirm && !_deleting) ? _submit : null,
            child: _deleting
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : Text(
                    context.l10n.databases_confirmDelete,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _canConfirm
                          ? CupertinoColors.white
                          : AppColors.tertiaryLabel(context),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.secondaryLabel(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ),
                ],
              ),
            ),
            AppToggleSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  IconData _resourceIcon(String type) {
    return switch (type) {
      'website' => TablerIcons.world,
      'app' || 'application' => TablerIcons.app_window,
      _ => TablerIcons.link,
    };
  }
}
