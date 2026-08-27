import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/file_repository_impl.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/file_browser_picker_sheet.dart';
import '../providers/files_provider.dart';
import 'wget_task_tracker.dart';

Future<bool> showRemoteDownloadSheet(
  BuildContext context,
  String currentPath,
) async {
  final result = await showActionSheet<bool>(
    context: context,
    builder: (context) => RemoteDownloadSheet(initialPath: currentPath),
  );
  return result ?? false;
}

class RemoteDownloadSheet extends ConsumerStatefulWidget {
  const RemoteDownloadSheet({super.key, required this.initialPath});

  final String initialPath;

  @override
  ConsumerState<RemoteDownloadSheet> createState() =>
      _RemoteDownloadSheetState();
}

class _RemoteDownloadSheetState extends ConsumerState<RemoteDownloadSheet> {
  late final TextEditingController _urlController;
  late final TextEditingController _pathController;
  late final TextEditingController _nameController;
  bool _ignoreCertificate = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _pathController = TextEditingController(text: widget.initialPath);
    _nameController = TextEditingController();

    // 当 URL 变化时，尝试从 URL 中提取文件名
    _urlController.addListener(() {
      if (_nameController.text.isEmpty) {
        try {
          final uri = Uri.parse(_urlController.text);
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            _nameController.text = segments.last;
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _pathController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  final _trackerKey = GlobalKey<WgetTaskTrackerState>();

  Future<void> _startDownload() async {
    final l10n = context.l10n;
    final url = _urlController.text.trim();
    final path = _pathController.text.trim();
    final name = _nameController.text.trim();

    if (url.isEmpty || path.isEmpty || name.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = await ref.read(fileRepositoryProvider.future);
      await repo.wget(
        url: url,
        path: path,
        name: name,
        ignoreCertificate: _ignoreCertificate,
      );

      if (mounted) {
        // 清空输入框方便下一次任务
        _urlController.clear();
        _nameController.clear();

        // 通知进度中心刷新任务列表
        _trackerKey.currentState?.refreshKeys();

        // 刷新列表
        ref.read(filesControllerProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.remoteDownload_createFailedTitle),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: Text(l10n.common_ok),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickPath() async {
    final result = await showActionSheet<FilePickerResult>(
      context: context,
      builder: (context) => FileBrowserPickerSheet(
        initialPath: _pathController.text,
        title: context.l10n.remoteDownload_selectSaveDirectory,
        selectionMode: FilePickerSelectionMode.directories,
      ),
    );

    if (result != null) {
      setState(() => _pathController.text = result.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _urlController.text.isNotEmpty &&
        _pathController.text.isNotEmpty &&
        _nameController.text.isNotEmpty &&
        !_isSubmitting;

    return ActionSheetScaffold(
      showHandle: false,
      isAdaptive: true,
      isFloating: false,
      hasHorizontalPadding: true,
      backgroundColor: AppColors.secondaryBackground(context),
      backgroundAlpha: 1.0,
      contentPadding: const EdgeInsets.only(bottom: 30),
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              TablerIcons.cloud_download,
              size: 32,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.remoteDownload_title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.label(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.remoteDownload_subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: canSubmit ? _startDownload : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: canSubmit
                      ? CupertinoColors.activeBlue.resolveFrom(context)
                      : AppColors.tertiaryLabel(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(
                        radius: 8,
                        color: CupertinoColors.white,
                      )
                    : Text(
                        context.l10n.remoteDownload_startAction,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: canSubmit
                              ? CupertinoColors.white
                              : AppColors.tertiaryLabel(context),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInputGroup([
              _buildTextField(
                controller: _urlController,
                placeholder: context.l10n.remoteDownload_urlPlaceholder,
                prefixIcon: TablerIcons.world,
                onChanged: (_) => setState(() {}),
              ),
              _buildTextField(
                controller: _nameController,
                placeholder: context.l10n.remoteDownload_namePlaceholder,
                prefixIcon: TablerIcons.file_text,
                onChanged: (_) => setState(() {}),
              ),
              _buildTextField(
                controller: _pathController,
                placeholder: context.l10n.remoteDownload_pathPlaceholder,
                prefixIcon: TablerIcons.folder,
                readOnly: true,
                onTap: _pickPath,
                suffix: const Icon(
                  TablerIcons.chevron_right,
                  size: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSettingItem(
              title: context.l10n.remoteDownload_ignoreCertificateTitle,
              subtitle: context.l10n.remoteDownload_ignoreCertificateSubtitle,
              value: _ignoreCertificate,
              onChanged: (v) => setState(() => _ignoreCertificate = v),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                context.l10n.remoteDownload_description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryLabel(context),
                  height: 1.5,
                ),
              ),
            ),
            WgetTaskTracker(
              key: _trackerKey,
              onActiveTasksChanged: (hasActiveTasks) {
                // 如果需要因为任务数变化而调整 UI 可以写在这里
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: 50),
                  color: AppColors.separator(context).withValues(alpha: 0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData prefixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: null,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(
          prefixIcon,
          size: 20,
          color: AppColors.secondaryLabel(context),
        ),
      ),
      suffix: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 16), child: suffix)
          : null,
      style: TextStyle(color: AppColors.label(context), fontSize: 15),
      placeholderStyle: TextStyle(
        color: AppColors.tertiaryLabel(context),
        fontSize: 15,
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
