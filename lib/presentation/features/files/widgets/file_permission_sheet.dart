import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../data/dto/file/file_item_dto.dart';
import '../../../../data/dto/file/user_group_dto.dart';
import '../../../../data/repositories_impl/file_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../providers/files_provider.dart';

class FilePermissionSheet extends ConsumerStatefulWidget {
  const FilePermissionSheet({super.key, required this.items});

  final List<FileItemDto> items;

  static Future<void> show(
    BuildContext context,
    FileItemDto item, {
    ProviderContainer? providerContainer,
  }) {
    return showActionSheet(
      context: context,
      providerContainer: providerContainer,
      builder: (context) => FilePermissionSheet(items: [item]),
    );
  }

  static Future<void> showBatch(
    BuildContext context,
    List<FileItemDto> items, {
    ProviderContainer? providerContainer,
  }) {
    return showActionSheet(
      context: context,
      providerContainer: providerContainer,
      builder: (context) => FilePermissionSheet(items: items),
    );
  }

  @override
  ConsumerState<FilePermissionSheet> createState() =>
      _FilePermissionSheetState();
}

class _FilePermissionSheetState extends ConsumerState<FilePermissionSheet> {
  // 权限位状态 [Owner, Group, Others] [Read, Write, Execute]
  late List<List<bool>> _permissions;
  late TextEditingController _modeController;

  String _selectedUser = '';
  String _selectedGroup = '';
  bool _applyToSub = true;

  UserGroupDto? _userGroupData;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    final firstItem = widget.items.first;
    _permissions = parseOctalMode(firstItem.mode);
    _modeController = TextEditingController(
      text: octalModeToString(_permissions),
    );
    _selectedUser = firstItem.user;
    _selectedGroup = firstItem.group;
    _loadUserGroups();
  }

  @override
  void dispose() {
    _modeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserGroups() async {
    if (!mounted) return;
    try {
      // 稍微等待确保 context 和 provider 状态稳定
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;

      final repo = await ref.read(fileRepositoryProvider.future);
      final data = await repo.getUserGroups();
      if (mounted) {
        setState(() {
          _userGroupData = data;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('FilePermissionSheet: Load user groups failed: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
        showAppErrorToast(context.l10n.files_permissionLoadUserGroupsFailed);
      }
    }
  }

  void _updateFromModeString(String val) {
    // 允许输入 3 位或 4 位数字
    final clean = val.startsWith('0') ? val.substring(1) : val;
    if (clean.length == 3 && RegExp(r'^[0-7]+$').hasMatch(clean)) {
      setState(() {
        _permissions = parseOctalMode(clean);
      });
    }
  }

  void _onToggle(int roleIndex, int permIndex, bool? value) {
    setState(() {
      _permissions[roleIndex][permIndex] = value ?? false;
      _modeController.text = octalModeToString(_permissions);
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    try {
      final mode = int.parse(_modeController.text, radix: 8);
      final controller = ref.read(filesControllerProvider.notifier);

      await controller.updatePermissions(
        paths: widget.items.map((e) => e.path).toList(),
        mode: mode,
        user: _selectedUser,
        group: _selectedGroup,
        sub: _applyToSub,
      );

      if (mounted) {
        showAppSuccessToast(l10n.files_permissionUpdateSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      showAppErrorToast(
        l10n.files_permissionSubmitFailed,
        description: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      showHandle: false,
      isAdaptive: true,
      hasHorizontalPadding: true,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.items.length > 1
                      ? context.l10n.files_permissionBatchTitle
                      : context.l10n.files_permissionSingleTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.label(context),
                  ),
                ),
                Text(
                  widget.items.length > 1
                      ? context.l10n.files_selectedCount(widget.items.length)
                      : widget.items.first.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: _submit,
              child: Text(
                context.l10n.common_save,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 权限矩阵
          _buildPermissionMatrix(),
          const SizedBox(height: 20),

          // 2. 权限数值输入
          _buildModeInput(),
          const SizedBox(height: 24),

          // 3. 所有者和用户组
          _buildOwnershipSection(),
          const SizedBox(height: 20),

          // 4. 子文件选项
          _buildSubfilesOption(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPermissionMatrix() {
    final labels = [
      context.l10n.files_permissionRead,
      context.l10n.files_permissionWrite,
      context.l10n.files_permissionExecute,
    ];
    final roles = [
      context.l10n.files_permissionOwner,
      context.l10n.files_permissionGroup,
      context.l10n.files_permissionPublic,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // 表头
          Row(
            children: [
              const SizedBox(width: 80),
              for (final label in labels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 行数据
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  height: 0.5,
                  color: AppColors.separator(context).withValues(alpha: 0.1),
                ),
              ),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    roles[i],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                for (var j = 0; j < 3; j++)
                  Expanded(
                    child: Center(
                      child: CupertinoCheckbox(
                        value: _permissions[i][j],
                        onChanged: (val) => _onToggle(i, j, val),
                        activeColor: CupertinoColors.activeBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeInput() {
    return Row(
      children: [
        Text(
          context.l10n.files_permissionModeValue,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CupertinoTextField(
            controller: _modeController,
            placeholder: context.l10n.files_permissionModePlaceholder,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.separator(context).withValues(alpha: 0.1),
              ),
            ),
            onChanged: _updateFromModeString,
          ),
        ),
      ],
    );
  }

  Widget _buildOwnershipSection() {
    if (_isLoadingData) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final users =
        _userGroupData?.users
            .map((u) => AppPickerOption(value: u.username, label: u.username))
            .toList() ??
        [];
    final groups =
        _userGroupData?.groups
            .map((g) => AppPickerOption(value: g, label: g))
            .toList() ??
        [];

    return Column(
      children: [
        _buildPickerRow(
          context.l10n.files_permissionOwner,
          users,
          _selectedUser,
          (val) => setState(() => _selectedUser = val),
        ),
        const SizedBox(height: 12),
        _buildPickerRow(
          context.l10n.files_permissionGroup,
          groups,
          _selectedGroup,
          (val) => setState(() => _selectedGroup = val),
        ),
      ],
    );
  }

  Widget _buildPickerRow(
    String label,
    List<AppPickerOption<String>> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
        Expanded(
          child: AppOverlayPicker<String>(
            options: options,
            value: value,
            onChanged: onChanged,
            backgroundColor: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSubfilesOption() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            TablerIcons.folders,
            size: 20,
            color: AppColors.secondaryLabel(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.files_permissionApplyToSubfiles,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          AppToggleSwitch(
            value: _applyToSub,
            onChanged: (val) => setState(() => _applyToSub = val),
          ),
        ],
      ),
    );
  }
}
