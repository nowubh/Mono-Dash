import 'dart:async';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/app/app_installed_dto.dart';
import '../../../../data/dto/container/container_compose_dto.dart';
import '../../../../data/dto/container/container_search_dto.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/frosted_dialog.dart';

void showContainerLogSheet(
  BuildContext context, {
  AppInstalledDto? app,
  ContainerItemDto? containerItem,
  ContainerComposeDto? composeItem,
  String? containerName,
  String? displayName,
  bool initialFollow = false,
}) {
  showActionSheet<void>(
    context: context,
    builder: (_) => _ContainerLogSheet(
      app: app,
      containerItem: containerItem,
      composeItem: composeItem,
      containerName: containerName,
      displayName: displayName,
      initialFollow: initialFollow,
    ),
  );
}

List<AppPickerOption<String>> _sincePickerOptions(BuildContext context) => [
  AppPickerOption(value: 'all', label: context.l10n.containers_all),
  AppPickerOption(value: '1d', label: context.l10n.containers_lastDay),
  AppPickerOption(value: '4h', label: context.l10n.containers_lastHours(4)),
  AppPickerOption(value: '1h', label: context.l10n.containers_lastHours(1)),
  AppPickerOption(value: '10m', label: context.l10n.containers_lastMinutes(10)),
];

List<AppPickerOption<String>> _tailPickerOptions(BuildContext context) => [
  AppPickerOption(value: 'all', label: context.l10n.containers_all),
  const AppPickerOption(value: '100', label: '100'),
  const AppPickerOption(value: '200', label: '200'),
  const AppPickerOption(value: '500', label: '500'),
  const AppPickerOption(value: '1000', label: '1000'),
];

class _ContainerLogSheet extends ConsumerStatefulWidget {
  const _ContainerLogSheet({
    this.app,
    this.containerItem,
    this.composeItem,
    this.containerName,
    this.initialFollow = false,
    String? displayName,
  }) : assert(
         app != null ||
             containerItem != null ||
             composeItem != null ||
             containerName != null,
       ),
       displayTitle = displayName;

  final AppInstalledDto? app;
  final ContainerItemDto? containerItem;
  final ContainerComposeDto? composeItem;
  final String? containerName;
  final bool initialFollow;
  final String? displayTitle;

  String get displayName =>
      displayTitle ??
      app?.displayName ??
      containerItem?.name ??
      composeItem?.name ??
      '';
  String get name =>
      containerName ??
      app?.name ??
      containerItem?.name ??
      composeItem?.name ??
      '';

  @override
  ConsumerState<_ContainerLogSheet> createState() => _ContainerLogSheetState();
}

class _ContainerLogSheetState extends ConsumerState<_ContainerLogSheet>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  AnimationController? _newLogFxController;
  int _highlightNewTopLines = 0;
  String _since = 'all';
  String _tail = '100';
  bool _timestamp = false;
  bool _follow = false;
  bool _loading = true;
  bool _actionLoading = false;
  String _log = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _follow = widget.initialFollow;
    if (_follow) {
      _timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _loadLog(showLoading: false),
      );
    }
    _loadInfoAndLog();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _newLogFxController?.dispose();
    super.dispose();
  }

  AnimationController _ensureNewLogFxController() {
    return _newLogFxController ??=
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1300),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _highlightNewTopLines = 0);
          }
        });
  }

  Future<void> _loadInfoAndLog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadLog(showLoading: false);
  }

  Future<void> _loadLog({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      final String log;

      if (widget.app != null) {
        // Compatibility: 1Panel v2.0.0 app logs are read through container
        // logs using the installed app `container` field instead of
        // /api/v2/apps/installed/info/{id}.
        log = await repo.getContainerLog(
          containerName: _appContainerName,
          since: _since,
          tail: _tail,
          follow: _follow,
          timestamp: _timestamp,
        );
      } else if (widget.composeItem != null) {
        log = await repo.getComposeLog(
          composePath: widget.composeItem!.path,
          since: _since,
          tail: _tail,
          follow: _follow,
          timestamp: _timestamp,
        );
      } else {
        log = await repo.getContainerLog(
          containerName: widget.name,
          since: _since,
          tail: _tail,
          follow: _follow,
          timestamp: _timestamp,
        );
      }

      if (!mounted) return;
      final shouldFx = _log.isNotEmpty && log != _log;
      final newTopLines = shouldFx ? _countNewTopLines(_log, log) : 0;
      setState(() {
        _log = log;
        _highlightNewTopLines = newTopLines;
        _error = null;
        _loading = false;
      });
      if (newTopLines > 0) {
        _ensureNewLogFxController()
          ..stop()
          ..forward(from: 0);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
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
        (_) => _loadLog(showLoading: false),
      );
    }
    _loadLog();
  }

  String get _appContainerName {
    final app = widget.app;
    if (app == null) return '';
    final container = app.container.trim();
    if (container.isNotEmpty) return container;
    final serviceName = app.serviceName.trim();
    if (serviceName.isNotEmpty) return serviceName;
    return app.name;
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      maxHeightFactor: 0.86,
      panelHeader: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Icon(
                  TablerIcons.logs,
                  size: 22,
                  color: CupertinoColors.systemBrown.resolveFrom(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.containers_logSheetTitle(widget.displayName),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
                if (_loading || _follow)
                  const CupertinoActivityIndicator()
                else
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _exportLog,
                    child: Icon(
                      TablerIcons.share_3,
                      size: 22,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                  ),
              ],
            ),
          ),
          _Controls(
            since: _since,
            tail: _tail,
            timestamp: _timestamp,
            follow: _follow,
            onSinceChanged: (value) {
              setState(() => _since = value);
              _loadLog();
            },
            onTailChanged: (value) {
              setState(() => _tail = value);
              _loadLog();
            },
            onTimestampChanged: (value) {
              setState(() => _timestamp = value);
              _loadLog();
            },
            onFollowChanged: _setFollow,
            onClean: _cleanLog,
          ),
        ],
      ),
      child: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.containers_loadLogsFailed('$_error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryLabel(context)),
                ),
              ),
            )
          : Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedBuilder(
                      animation: _ensureNewLogFxController(),
                      builder: (context, _) {
                        if (_log.isEmpty) {
                          if (_loading) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 64),
                                child: CupertinoActivityIndicator(),
                              ),
                            );
                          }
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 64),
                              child: Text(
                                context.l10n.containers_noLogs,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryLabel(context),
                                ),
                              ),
                            ),
                          );
                        }
                        return SelectableText.rich(_buildLogTextSpan(context));
                      },
                    ),
                  ],
                ),
                if (_actionLoading)
                  const Center(child: CupertinoActivityIndicator()),
              ],
            ),
    );
  }

  Future<void> _cleanLog() async {
    final confirmed = await showFrostedConfirmDialog(
      context,
      title: context.l10n.containers_clearLogs,
      content: context.l10n.containers_clearLogsConfirm,
      confirmText: context.l10n.containers_clear,
      isDestructive: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final logsClearedText = context.l10n.containers_logsCleared;
    final clearLogsFailedText = context.l10n.containers_clearLogsFailed;
    setState(() => _actionLoading = true);
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      if (widget.app != null) {
        await repo.cleanContainerLog(containerName: _appContainerName);
      } else if (widget.composeItem != null) {
        await repo.cleanComposeLog(
          name: widget.name,
          composePath: widget.composeItem!.path,
        );
      } else {
        await repo.cleanContainerLog(containerName: widget.name);
      }
      showAppSuccessToast(logsClearedText);
      await _loadLog(showLoading: false);
    } catch (error) {
      showAppErrorToast(clearLogsFailedText, description: '$error');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _exportLog() async {
    if (_log.trim().isEmpty) {
      showAppWarningToast(context.l10n.containers_noExportableLogs);
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
      final safeName = widget.name.isEmpty ? 'container' : widget.name;
      final filename = '${safeName}_$timestamp.log';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(_log);
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

  List<String> _reversedLines(String raw) {
    final lines = raw.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return lines.reversed.toList(growable: false);
  }

  int _countNewTopLines(String oldRaw, String newRaw) {
    if (oldRaw.isEmpty || newRaw == oldRaw) return 0;
    final oldRev = _reversedLines(oldRaw);
    final newRev = _reversedLines(newRaw);
    if (oldRev.isEmpty || newRev.isEmpty) return 0;

    // 在新日志前部寻找“旧日志头部”的对齐点，兼容 tail 窗口滑动。
    final maxShift = math.min(newRev.length, 60);
    final probeLen = math.min(oldRev.length, 8);
    for (var shift = 0; shift < maxShift; shift++) {
      if (shift + probeLen > newRev.length) break;
      var matched = true;
      for (var i = 0; i < probeLen; i++) {
        if (newRev[shift + i] != oldRev[i]) {
          matched = false;
          break;
        }
      }
      if (matched) return shift;
    }

    // 兜底：只要内容变化，至少高亮顶部 3 行，让用户有感知。
    return math.min(3, newRev.length);
  }

  TextSpan _buildLogTextSpan(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 12,
      height: 1.35,
      fontFamily: 'monospace',
      color: AppColors.label(context),
    );
    final lines = _reversedLines(_log);
    final t = _newLogFxController?.value ?? 1;
    final pulse = ((1 + math.sin(t * 4 * math.pi)) / 2) * (1 - t);
    final rainbowHue = (t * 540) % 360;
    final rainbow = HSVColor.fromAHSV(1, rainbowHue, 0.5, 1).toColor();
    final highlightColor = Color.lerp(
      AppColors.label(context),
      rainbow,
      (0.12 + pulse * 0.28).clamp(0.0, 1.0),
    );

    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final isNewLine = i < _highlightNewTopLines && t < 1;
      spans.add(
        TextSpan(
          text: i == lines.length - 1 ? lines[i] : '${lines[i]}\n',
          style: isNewLine
              ? baseStyle.copyWith(color: highlightColor)
              : baseStyle,
        ),
      );
    }
    return TextSpan(children: spans);
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.since,
    required this.tail,
    required this.timestamp,
    required this.follow,
    required this.onSinceChanged,
    required this.onTailChanged,
    required this.onTimestampChanged,
    required this.onFollowChanged,
    required this.onClean,
  });

  final String since;
  final String tail;
  final bool timestamp;
  final bool follow;
  final ValueChanged<String> onSinceChanged;
  final ValueChanged<String> onTailChanged;
  final ValueChanged<bool> onTimestampChanged;
  final ValueChanged<bool> onFollowChanged;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      context.l10n.containers_filter,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppOverlayPicker<String>(
                        options: _sincePickerOptions(context),
                        value: since,
                        onChanged: onSinceChanged,
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
                child: Row(
                  children: [
                    Text(
                      context.l10n.containers_lineCount,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppOverlayPicker<String>(
                        options: _tailPickerOptions(context),
                        value: tail,
                        onChanged: onTailChanged,
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
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SwitchTile(
                  title: context.l10n.containers_time,
                  value: timestamp,
                  onChanged: onTimestampChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SwitchTile(
                  title: context.l10n.containers_follow,
                  value: follow,
                  onChanged: onFollowChanged,
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onClean,
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
                        context.l10n.containers_clear,
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
          ),
          const SizedBox(height: 10),
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
