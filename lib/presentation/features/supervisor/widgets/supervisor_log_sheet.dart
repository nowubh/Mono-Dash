import 'dart:async';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/api/file_api.dart';
import '../../../../data/api/host_tool_api.dart';
import '../../../../data/dto/common/task_log_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_confirm_sheet.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/app_picker.dart';

Future<void> showSupervisorLogSheet(
  BuildContext context, {
  required String title,
  required String processName,
  required Future<FileApi> Function() fileApiLoader,
  required Future<HostToolApi> Function() hostToolApiLoader,
  String type = 'supervisor',
  String file = 'out.log',
}) {
  return showActionSheet<void>(
    context: context,
    expand: true,
    builder: (_) => _SupervisorLogSheet(
      title: title,
      processName: processName,
      type: type,
      file: file,
      fileApiLoader: fileApiLoader,
      hostToolApiLoader: hostToolApiLoader,
    ),
  );
}

List<AppPickerOption<int>> _lineCountOptions() => const [
  AppPickerOption(value: 100, label: '100'),
  AppPickerOption(value: 200, label: '200'),
  AppPickerOption(value: 500, label: '500'),
  AppPickerOption(value: 1000, label: '1000'),
  AppPickerOption(value: 2000, label: '2000'),
];

class _SupervisorLogSheet extends StatefulWidget {
  const _SupervisorLogSheet({
    required this.title,
    required this.processName,
    required this.fileApiLoader,
    required this.hostToolApiLoader,
    required this.file,
    this.type = 'supervisor',
  });

  final String title;
  final String processName;
  final String type;
  final String file;
  final Future<FileApi> Function() fileApiLoader;
  final Future<HostToolApi> Function() hostToolApiLoader;

  @override
  State<_SupervisorLogSheet> createState() => _SupervisorLogSheetState();
}

class _SupervisorLogSheetState extends State<_SupervisorLogSheet> {
  Timer? _timer;
  TaskLogDto? _log;
  Object? _error;
  int _pageSize = 500;
  bool _loading = true;
  bool _actionLoading = false;
  bool _follow = false;

  bool get _isMainLog => widget.type == 'supervisord';
  String get _readName =>
      _isMainLog ? 'supervisor' : '${widget.processName}.${widget.file}';
  String get _content => _log?.lines.join('\n') ?? '';

  @override
  void initState() {
    super.initState();
    _load(showLoading: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = await widget.fileApiLoader();
      final log = await api.readFile<TaskLogDto>(
        type: widget.type,
        name: _readName,
        page: 1,
        pageSize: _pageSize,
        latest: true,
        fromJson: TaskLogDto.fromJson,
      );
      if (!mounted) return;
      setState(() {
        _log = log;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _setFollow(bool value) {
    setState(() => _follow = value);
    _timer?.cancel();
    if (value) {
      _timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _load(showLoading: false),
      );
    }
    _load(showLoading: !value);
  }

  Future<void> _clear() async {
    if (_isMainLog || _actionLoading) return;
    final clearedText = context.l10n.supervisor_logCleared;
    final clearFailedText = context.l10n.supervisor_clearFailed;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (_) => AppConfirmSheet(
        title: context.l10n.supervisor_clearLog,
        content: context.l10n.supervisor_clearLogConfirm,
        confirmText: context.l10n.supervisor_clearLog,
        confirmColor: CupertinoColors.destructiveRed,
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _actionLoading = true);
    try {
      await (await widget.hostToolApiLoader()).operateSupervisorProcessFile(
        name: widget.processName,
        file: widget.file,
        operate: 'clear',
      );
      showAppSuccessToast(clearedText);
      await _load(showLoading: false);
    } catch (e) {
      showAppErrorToast(clearFailedText, description: '$e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _exportLog() async {
    final content = _content;
    if (content.trim().isEmpty) {
      showAppWarningToast(context.l10n.taskLog_noExportableLogs);
      return;
    }
    final sharePluginMissingText = context.l10n.taskLog_sharePluginMissing;
    final sharePluginMissingDescriptionText =
        context.l10n.taskLog_sharePluginMissingDescription;
    final exportFailedText = context.l10n.taskLog_exportFailed;
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final safeName = widget.processName.isEmpty
          ? 'supervisor'
          : widget.processName;
      final filename =
          '${safeName}_${_isMainLog ? 'main' : widget.file}_$timestamp.log';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);
      await SharePlus.instance.share(
        ShareParams(
          title: filename,
          subject: filename,
          files: [XFile(file.path, mimeType: 'text/plain')],
          fileNameOverrides: [filename],
        ),
      );
    } on MissingPluginException {
      showAppErrorToast(
        sharePluginMissingText,
        description: sharePluginMissingDescriptionText,
      );
    } catch (error) {
      showAppErrorToast(exportFailedText, description: '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    return ActionSheetScaffold(
      isAdaptive: false,
      showHandle: false,
      maxHeightFactor: 0.9,
      panelHeader: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Icon(
                  _isMainLog || widget.file == 'out.log'
                      ? TablerIcons.logs
                      : TablerIcons.alert_triangle,
                  size: 22,
                  color:
                      (_isMainLog || widget.file == 'out.log'
                              ? CupertinoColors.systemBrown
                              : CupertinoColors.systemOrange)
                          .resolveFrom(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
                if (_loading || _follow)
                  const CupertinoActivityIndicator()
                else ...[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 34),
                    onPressed: _exportLog,
                    child: Icon(
                      TablerIcons.share_3,
                      size: 21,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 34),
                    onPressed: _load,
                    child: Icon(
                      TablerIcons.refresh,
                      size: 21,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _SupervisorLogControls(
            pageSize: _pageSize,
            follow: _follow,
            showClear: !_isMainLog,
            actionLoading: _actionLoading,
            onPageSizeChanged: (value) {
              setState(() => _pageSize = value);
              _load();
            },
            onFollowChanged: _setFollow,
            onClear: _clear,
          ),
          if (log != null && log.path.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                log.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : _error != null
          ? AppEmptyState(
              icon: TablerIcons.alert_triangle,
              title: context.l10n.supervisor_readLogFailed,
              subtitle: '$_error',
              actionLabel: context.l10n.common_retry,
              onAction: _load,
            )
          : log == null || _content.isEmpty
          ? AppEmptyState(
              icon: TablerIcons.file_text,
              title: context.l10n.supervisor_emptyLogTitle,
              subtitle: context.l10n.supervisor_emptyLogSubtitle,
            )
          : Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    _content,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.42,
                      color: AppColors.label(context),
                      fontFamilyFallback: const [
                        'SF Mono',
                        'Menlo',
                        'Consolas',
                        'monospace',
                      ],
                    ),
                  ),
                ),
                if (_actionLoading)
                  const Center(child: CupertinoActivityIndicator()),
              ],
            ),
    );
  }
}

class _SupervisorLogControls extends StatelessWidget {
  const _SupervisorLogControls({
    required this.pageSize,
    required this.follow,
    required this.showClear,
    required this.actionLoading,
    required this.onPageSizeChanged,
    required this.onFollowChanged,
    required this.onClear,
  });

  final int pageSize;
  final bool follow;
  final bool showClear;
  final bool actionLoading;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<bool> onFollowChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  context.l10n.supervisor_lineCount,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppOverlayPicker<int>(
                    options: _lineCountOptions(),
                    value: pageSize,
                    onChanged: onPageSizeChanged,
                    height: 38,
                    maxListHeight: 200,
                    backgroundColor: AppColors.secondaryBackground(
                      context,
                    ).withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SwitchTile(
              title: context.l10n.supervisor_follow,
              value: follow,
              onChanged: onFollowChanged,
            ),
          ),
          if (showClear) ...[
            const SizedBox(width: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: actionLoading ? null : onClear,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed
                      .resolveFrom(context)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      TablerIcons.trash,
                      size: 16,
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      context.l10n.supervisor_clear,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.systemRed.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.label(context),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.72,
            child: AppToggleSwitch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
