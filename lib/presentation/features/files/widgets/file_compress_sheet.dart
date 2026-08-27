import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/file/file_item_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/file_browser_picker_sheet.dart';
import '../providers/files_provider.dart';

class FileCompressSheet extends ConsumerStatefulWidget {
  const FileCompressSheet({super.key, required this.items});

  final List<FileItemDto> items;

  static Future<void> show(
    BuildContext context,
    List<FileItemDto> items, {
    ProviderContainer? providerContainer,
  }) {
    return showActionSheet(
      context: context,
      providerContainer: providerContainer,
      builder: (context) => FileCompressSheet(items: items),
    );
  }

  @override
  ConsumerState<FileCompressSheet> createState() => _FileCompressSheetState();
}

class _FileCompressSheetState extends ConsumerState<FileCompressSheet> {
  String _type = 'zip';
  late TextEditingController _nameController;
  late TextEditingController _dstController;
  bool _replace = false;
  bool _isSubmitting = false;

  final List<String> _formats = [
    'zip',
    'gz',
    'bz2',
    'tar.bz2',
    'tar',
    'tgz',
    'tar.gz',
    'xz',
    'tar.xz',
    'rar',
    '7z',
  ];

  @override
  void initState() {
    super.initState();
    final firstItem = widget.items.first;

    // 如果是多个文件，随机生成一个名称；单个文件则默认用文件名
    final defaultName = widget.items.length > 1
        ? _generateRandomName()
        : firstItem.name;

    _nameController = TextEditingController(text: defaultName);

    // 默认路径为当前所在目录，如果没有则使用第一个文件的目录
    final itemDir = firstItem.path.contains('/')
        ? firstItem.path.substring(0, firstItem.path.lastIndexOf('/'))
        : '/';
    final currentPath =
        ref.read(filesControllerProvider).valueOrNull?.currentPath ?? itemDir;
    _dstController = TextEditingController(text: currentPath);
  }

  String _generateRandomName() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    String result = '';
    for (var i = 0; i < 6; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dstController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    final dst = _dstController.text.trim();

    if (name.isEmpty) {
      showAppErrorToast(l10n.files_compressNameRequired);
      return;
    }
    if (dst.isEmpty) {
      showAppErrorToast(l10n.files_compressPathRequired);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final fullName = '$name.$_type';
      await ref
          .read(filesControllerProvider.notifier)
          .compressFiles(
            files: widget.items.map((e) => e.path).toList(),
            type: _type,
            dst: dst,
            name: fullName,
            replace: _replace,
          );
      if (mounted) {
        showAppSuccessToast(l10n.files_compressStarted);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(l10n.files_compressFailed, description: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _formats
        .map((f) => AppPickerOption(value: f, label: f))
        .toList();

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
              context.l10n.files_compressTitle,
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
                      context.l10n.files_compressAction,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 格式选择
          _buildLabel(context.l10n.files_compressFormat),
          AppOverlayPicker<String>(
            options: options,
            value: _type,
            onChanged: (val) => setState(() => _type = val),
            backgroundColor: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),

          // 2. 名称
          _buildLabel(context.l10n.files_nameLabel),
          _buildNameInput(),
          const SizedBox(height: 20),

          // 3. 压缩路径
          _buildLabel(context.l10n.files_compressPath),
          _buildDestinationInput(),
          const SizedBox(height: 24),

          // 4. 覆盖开关
          _buildToggleOption(
            icon: TablerIcons.file_diff,
            title: context.l10n.files_overwriteExistingFile,
            value: _replace,
            onChanged: (val) => setState(() => _replace = val),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryLabel(context),
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _nameController,
              placeholder: context.l10n.files_fileNamePlaceholder,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border(
                  left: BorderSide(
                    color: AppColors.separator(context).withValues(alpha: 0.1),
                  ),
                  top: BorderSide(
                    color: AppColors.separator(context).withValues(alpha: 0.1),
                  ),
                  bottom: BorderSide(
                    color: AppColors.separator(context).withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
          ),
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(
                context,
              ).withValues(alpha: 0.3),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
              border: Border.all(
                color: AppColors.separator(context).withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              '.$_type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationInput() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _dstController,
              placeholder: context.l10n.files_targetDirectoryPlaceholder,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border(
                  left: BorderSide(
                    color: AppColors.separator(context).withValues(alpha: 0.1),
                  ),
                  top: BorderSide(
                    color: AppColors.separator(context).withValues(alpha: 0.1),
                  ),
                  bottom: BorderSide(
                    color: AppColors.separator(context).withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _pickDestinationPath,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.tertiaryBackground(
                  context,
                ).withValues(alpha: 0.3),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(12),
                ),
                border: Border.all(
                  color: AppColors.separator(context).withValues(alpha: 0.1),
                ),
              ),
              child: Icon(
                TablerIcons.folder_search,
                size: 20,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDestinationPath() async {
    final result = await FileBrowserPickerSheet.show(
      context,
      title: context.l10n.files_selectCompressPath,
      confirmText: context.l10n.common_use,
      initialPath: _dstController.text.trim().isEmpty
          ? '/'
          : _dstController.text.trim(),
      selectionMode: FilePickerSelectionMode.directories,
    );
    if (!mounted || result == null) return;
    _dstController.text = result.path;
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
