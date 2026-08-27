import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/file_browser_picker_sheet.dart';
import '../providers/files_provider.dart';

enum FileCreateType { file, directory }

class FileCreateSheet extends ConsumerStatefulWidget {
  const FileCreateSheet({
    super.key,
    required this.type,
    required this.currentPath,
  });

  final FileCreateType type;
  final String currentPath;

  static Future<void> show(
    BuildContext context, {
    required FileCreateType type,
    required String currentPath,
    ProviderContainer? providerContainer,
  }) {
    return showActionSheet(
      context: context,
      providerContainer: providerContainer,
      builder: (context) =>
          FileCreateSheet(type: type, currentPath: currentPath),
    );
  }

  @override
  ConsumerState<FileCreateSheet> createState() => _FileCreateSheetState();
}

class _FileCreateSheetState extends ConsumerState<FileCreateSheet> {
  final _nameController = TextEditingController();
  final _modeController = TextEditingController();
  final _linkPathController = TextEditingController();

  bool _isLink = false;
  String _linkType = 'soft'; // 'soft' or 'hard'
  bool _isSubmitting = false;

  // 权限状态 [Owner, Group, Others] [Read, Write, Execute]
  late List<List<bool>> _permissions;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 设置默认权限位
    final defaultMode = widget.type == FileCreateType.file ? '0644' : '0755';
    _permissions = parseOctalMode(defaultMode);
    _modeController.text = defaultMode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modeController.dispose();
    _linkPathController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTogglePermission(int roleIndex, int permIndex, bool? value) {
    setState(() {
      _permissions[roleIndex][permIndex] = value ?? false;
      _modeController.text = octalModeToString(_permissions);
    });
  }

  void _updateFromModeString(String val) {
    if (val.length >= 3 && RegExp(r'^[0-7]+$').hasMatch(val)) {
      setState(() {
        _permissions = parseOctalMode(val);
      });
    }
  }

  String _titleOf(BuildContext context) => widget.type == FileCreateType.file
      ? context.l10n.files_createFileTitle
      : context.l10n.files_createDirectoryTitle;

  IconData get _icon => widget.type == FileCreateType.file
      ? TablerIcons.file_plus
      : TablerIcons.folder_plus;

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppErrorToast(l10n.files_createNameRequired);
      return;
    }

    final modeStr = _modeController.text.trim();
    final mode = int.tryParse(modeStr, radix: 8);

    if (mode == null) {
      showAppErrorToast(l10n.files_permissionModeInvalid);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final fullPath = widget.currentPath == '/'
          ? '/$name'
          : '${widget.currentPath}/$name';

      if (widget.type == FileCreateType.file) {
        await ref
            .read(filesControllerProvider.notifier)
            .createFile(
              fullPath,
              mode: mode,
              isLink: _isLink,
              isSymlink: _isLink ? (_linkType == 'soft') : true,
              linkPath: _isLink ? _linkPathController.text.trim() : null,
            );
      } else {
        await ref
            .read(filesControllerProvider.notifier)
            .createFolder(fullPath, mode: mode, isSymlink: true);
      }

      if (mounted) {
        showAppSuccessToast(l10n.files_createSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(l10n.files_createFailed, description: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
            Text(
              _titleOf(context),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.label(context),
              ),
            ),
            _isSubmitting
                ? const CupertinoActivityIndicator(radius: 8)
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _submit,
                    child: Text(
                      context.l10n.common_create,
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
          // _buildPathInfo(),
          const SizedBox(height: 20),

          _buildLabel(context.l10n.files_nameLabel),
          _buildInput(
            controller: _nameController,
            focusNode: _focusNode,
            placeholder: widget.type == FileCreateType.file
                ? context.l10n.files_createFileNamePlaceholder
                : context.l10n.files_createDirectoryNamePlaceholder,
            icon: _icon,
          ),

          const SizedBox(height: 24),

          _buildLabel(
            context.l10n.files_permissionSettings,
            trailing: SizedBox(
              height: 22,
              width: 64,
              child: CupertinoTextField(
                controller: _modeController,
                placeholder: '0755',
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: _updateFromModeString,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                  height: 1.1,
                ),
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground(
                    context,
                  ).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          _buildPermissionMatrix(),

          if (widget.type == FileCreateType.file) ...[
            const SizedBox(height: 24),
            _buildLabel(
              context.l10n.files_linkSettings,
              trailing: SizedBox(
                height: 22,
                child: Transform.scale(
                  scale: 0.75,
                  alignment: Alignment.centerRight,
                  child: AppToggleSwitch(
                    value: _isLink,
                    onChanged: (val) => setState(() => _isLink = val),
                  ),
                ),
              ),
            ),
            _buildLinkSettings(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Widget _buildPathInfo() {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: AppColors.secondaryBackground(context).withValues(alpha: 0.3),
  //       borderRadius: BorderRadius.circular(10),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(
  //           TablerIcons.folder,
  //           size: 16,
  //           color: AppColors.secondaryLabel(context),
  //         ),
  //         const SizedBox(width: 8),
  //         Expanded(
  //           child: Text(
  //             widget.currentPath,
  //             style: TextStyle(
  //               fontSize: 13,
  //               color: AppColors.secondaryLabel(context),
  //             ),
  //             maxLines: 1,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildLabel(String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.label(context),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String placeholder,
    required IconData icon,
    VoidCallback? onIconTap,
    TextInputType? keyboardType,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      keyboardType: keyboardType,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Icon(icon, size: 18, color: AppColors.secondaryLabel(context)),
      ),
      suffix: onIconTap != null
          ? CupertinoButton(
              padding: const EdgeInsets.only(right: 8),
              onPressed: onIconTap,
              child: Icon(
                TablerIcons.folder_search,
                size: 18,
                color: AppColors.secondaryLabel(context),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
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
          Row(
            children: [
              const SizedBox(width: 70),
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
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  height: 0.5,
                  color: AppColors.separator(context).withValues(alpha: 0.1),
                ),
              ),
            Row(
              children: [
                SizedBox(
                  width: 70,
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
                        onChanged: (val) => _onTogglePermission(i, j, val),
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

  Widget _buildLinkSettings() {
    if (!_isLink) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                context.l10n.files_linkType,
                style: const TextStyle(fontSize: 13),
              ),
              const Spacer(),
              SizedBox(
                width: 140,
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _linkType,
                  children: {
                    'soft': Text(
                      context.l10n.files_softLink,
                      style: const TextStyle(fontSize: 12),
                    ),
                    'hard': Text(
                      context.l10n.files_hardLink,
                      style: const TextStyle(fontSize: 12),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) setState(() => _linkType = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput(
            controller: _linkPathController,
            placeholder: context.l10n.files_linkTargetPlaceholder,
            icon: TablerIcons.link,
            onIconTap: _pickLinkTarget,
          ),
        ],
      ),
    );
  }

  Future<void> _pickLinkTarget() async {
    final result = await FileBrowserPickerSheet.show(
      context,
      title: context.l10n.files_selectLinkTarget,
      confirmText: context.l10n.common_use,
      selectionMode: FilePickerSelectionMode.files,
    );
    if (!mounted || result == null) return;
    setState(() => _linkPathController.text = result.path);
  }
}
