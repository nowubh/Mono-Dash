import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/container/container_daemon_config_dto.dart';
import '../../../../data/dto/container/docker_status_dto.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../../data/repositories_impl/setting_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/action_sheet_info_card.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_confirm_sheet.dart';
import '../../../common/components/app_notice_sheet.dart';
import '../../../common/components/status_pill.dart';
import 'docker_setting_sheets/docker_cgroup_driver_sheet.dart';
import 'docker_setting_sheets/docker_edit_value_sheet.dart';
import 'docker_setting_sheets/docker_ipv6_sheet.dart';
import 'docker_setting_sheets/docker_log_option_sheet.dart';
import 'docker_setting_sheets/docker_string_list_editor_sheet.dart';

/// 显示 Docker 设置 Sheet。
void showDockerSettingSheet(BuildContext context, {VoidCallback? onChanged}) {
  showActionSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => _DockerSettingSheet(onChanged: onChanged),
  );
}

class _DockerSettingSheet extends ConsumerStatefulWidget {
  const _DockerSettingSheet({this.onChanged});

  final VoidCallback? onChanged;

  @override
  ConsumerState<_DockerSettingSheet> createState() =>
      _DockerSettingSheetState();
}

class _DockerSettingSheetState extends ConsumerState<_DockerSettingSheet> {
  DockerStatusDto? _status;
  ContainerDaemonConfigDto? _config;
  String _sockPath = '';
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final containerRepo = await ref.read(containerRepositoryProvider.future);
      final settingRepo = await ref.read(settingRepositoryProvider.future);
      final results = await Future.wait([
        containerRepo.getDockerStatus(),
        containerRepo.getDaemonConfig(),
        settingRepo.searchSettings(),
      ]);
      if (!mounted) return;
      final settings = results[2] as Map<String, dynamic>;
      setState(() {
        _status = results[0] as DockerStatusDto;
        _config = results[1] as ContainerDaemonConfigDto;
        _sockPath = (settings['dockerSockPath'] as String?) ?? '';
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

  Future<void> _dockerOperate(String operation) async {
    final labels = {
      'start': context.l10n.containers_start,
      'stop': context.l10n.containers_stop,
      'restart': context.l10n.containers_restart,
    };
    final label = labels[operation] ?? operation;

    if (operation == 'stop' || operation == 'restart') {
      final confirmed = await showActionSheet<bool>(
        context: context,
        useRootNavigator: true,
        builder: (context) => AppConfirmSheet(
          title: 'Docker $label',
          content: operation == 'stop'
              ? context.l10n.containers_stopDockerConfirm
              : context.l10n.containers_restartDockerConfirm,
          icon: operation == 'stop'
              ? TablerIcons.player_stop
              : TablerIcons.refresh,
          iconColor: operation == 'stop'
              ? CupertinoColors.systemRed
              : CupertinoColors.systemOrange,
          confirmText: context.l10n.common_confirm,
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.dockerOperate(operation);
      if (!mounted) return;
      widget.onChanged?.call();
      showAppSuccessToast(context.l10n.containers_dockerActionSucceeded(label));
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(
        context.l10n.containers_dockerActionFailed(label),
        description: e.toString(),
      );
    }
  }

  Future<void> _updateDaemonByKey(String key, String value) async {
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.updateDaemonByKey(key, value);
      if (!mounted) return;
      widget.onChanged?.call();
      showAppSuccessToast(context.l10n.containers_configUpdatedRestarting);
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(
        context.l10n.containers_updateRequestFailed(e.toString()),
      );
    }
  }

  Future<void> _openFullConfigEditor() async {
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      final content = await repo.getDaemonJsonFile();
      if (!mounted) return;

      if (content == 'daemon.json is not find in path') {
        showActionSheet<void>(
          context: context,
          useRootNavigator: true,
          builder: (context) => AppNoticeSheet(
            title: context.l10n.containers_configFileMissing,
            content: context.l10n.containers_configFileMissingContent,
            icon: TablerIcons.file_off,
            iconColor: CupertinoColors.systemGrey,
          ),
        );
        return;
      }

      final fullConfigSubtitle = context.l10n.containers_dockerFullConfig;
      final daemonSaved = context.l10n.containers_daemonSavedRestarting;
      final saveFailed = context.l10n.databases_saveFailed;
      await showAppCodeEditorSheet(
        context,
        title: 'daemon.json',
        subtitle: fullConfigSubtitle,
        initialContent: content,
        language: 'json',
        onSave: (newContent) async {
          try {
            await repo.updateDaemonJsonByFile(newContent);
            widget.onChanged?.call();
            showAppSuccessToast(daemonSaved);
            _loadAll();
            return true;
          } catch (e) {
            showAppErrorToast(saveFailed, description: e.toString());
            return false;
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(
        context.l10n.containers_readDaemonFailed,
        description: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final status = _status;

    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      maxHeightFactor: 0.85,
      infoCard: ActionSheetInfoCard(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: CupertinoColors.activeBlue
                .resolveFrom(context)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(
              TablerIcons.brand_docker,
              size: 30,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
          ),
        ),
        title: 'Docker',
        subtitle: _loading
            ? context.l10n.containers_loading
            : _error != null
            ? context.l10n.common_loadingFailed
            : config != null && config.version.isNotEmpty
            ? context.l10n.containers_versionValue(config.version)
            : context.l10n.containers_serviceRunning,
        trailing: status != null
            ? StatusPill(
                label: status.isActive
                    ? context.l10n.containers_running
                    : context.l10n.containers_stopped,
                active: status.isActive,
              )
            : const SizedBox.shrink(),
      ),
      child: _loading
          ? const _LoadingView()
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _loadAll)
          : _buildContent(context, config!, status!),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ContainerDaemonConfigDto config,
    DockerStatusDto status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 服务操作 ──
        AppSectionHeader(
          title: context.l10n.containers_serviceOperations,
          icon: TablerIcons.player_play,
        ),
        AppActionGroup(
          children: [
            AppActionRow(
              icon: TablerIcons.player_play,
              iconColor: CupertinoColors.systemGreen,
              title: context.l10n.containers_start,
              subtitle: Text(context.l10n.containers_startDockerService),
              enabled: !status.isActive,
              onTap: () => _dockerOperate('start'),
            ),
            AppActionRow(
              icon: TablerIcons.player_stop,
              iconColor: CupertinoColors.systemRed,
              title: context.l10n.containers_stop,
              subtitle: Text(context.l10n.containers_stopDockerService),
              enabled: status.isActive,
              isDestructive: true,
              onTap: () => _dockerOperate('stop'),
            ),
            AppActionRow(
              icon: TablerIcons.refresh,
              iconColor: CupertinoColors.systemOrange,
              title: context.l10n.containers_restart,
              subtitle: Text(context.l10n.containers_restartDockerService),
              enabled: status.isActive,
              onTap: () => _dockerOperate('restart'),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── 基础配置 ──
        AppSectionHeader(
          title: context.l10n.containers_basicConfig,
          icon: TablerIcons.settings,
        ),
        AppActionGroup(
          children: [
            AppActionRow(
              icon: TablerIcons.rocket,
              iconColor: CupertinoColors.systemTeal,
              title: context.l10n.containers_imageAccelerator,
              subtitle: Text(
                config.registryMirrors.isEmpty
                    ? context.l10n.containers_notConfigured
                    : context.l10n.containers_itemCount(
                        config.registryMirrors.length,
                      ),
              ),
              onTap: () async {
                final result = await showDockerStringListEditorSheet(
                  context,
                  title: context.l10n.containers_imageAccelerator,
                  initialItems: config.registryMirrors,
                  placeholder: 'https://mirror.example.com',
                );
                if (result != null && mounted) {
                  _updateDaemonByKey('registry-mirrors', result.join(','));
                }
              },
            ),
            AppActionRow(
              icon: TablerIcons.shield_lock,
              iconColor: CupertinoColors.systemOrange,
              title: context.l10n.containers_insecureRegistries,
              subtitle: Text(
                config.insecureRegistries.isEmpty
                    ? context.l10n.containers_notConfigured
                    : context.l10n.containers_itemCount(
                        config.insecureRegistries.length,
                      ),
              ),
              onTap: () async {
                final result = await showDockerStringListEditorSheet(
                  context,
                  title: context.l10n.containers_insecureRegistries,
                  initialItems: config.insecureRegistries,
                  placeholder: 'registry.example.com:5000',
                );
                if (result != null && mounted) {
                  _updateDaemonByKey('insecure-registries', result.join(','));
                }
              },
            ),
            AppActionRow(
              icon: TablerIcons.world_latitude,
              iconColor: CupertinoColors.systemIndigo,
              title: 'IPv6',
              subtitle: Text(
                config.ipv6
                    ? context.l10n.containers_enabled
                    : context.l10n.containers_disabled,
              ),
              onTap: () async {
                final successMessage =
                    context.l10n.containers_ipv6ConfigUpdatedRestarting;
                final failureMessage = context.l10n.databases_updateFailed;
                final result = await showDockerIpv6Sheet(
                  context,
                  currentIp6Tables: config.ip6Tables,
                  currentExperimental: config.experimental,
                  currentFixedCidrV6: config.fixedCidrV6,
                );
                if (result != null && mounted) {
                  try {
                    final repo = await ref.read(
                      containerRepositoryProvider.future,
                    );
                    await repo.updateIpv6Option(
                      fixedCidrV6: result.fixedCidrV6,
                      ip6Tables: result.ip6Tables,
                      experimental: result.experimental,
                    );
                    if (!mounted) return;
                    widget.onChanged?.call();
                    showAppSuccessToast(successMessage);
                    _loadAll();
                  } catch (e) {
                    if (!mounted) return;
                    showAppErrorToast(
                      failureMessage,
                      description: e.toString(),
                    );
                  }
                }
              },
            ),
            AppActionRow(
              icon: TablerIcons.file_text,
              iconColor: CupertinoColors.systemPurple,
              title: context.l10n.containers_logRotation,
              subtitle: Text(
                config.logMaxSize.isEmpty && config.logMaxFile.isEmpty
                    ? context.l10n.containers_notConfigured
                    : '${config.logMaxSize} / ${config.logMaxFile}',
              ),
              onTap: () async {
                final successMessage =
                    context.l10n.containers_logConfigUpdatedRestarting;
                final failureMessage = context.l10n.databases_updateFailed;
                final result = await showDockerLogOptionSheet(
                  context,
                  currentLogMaxSize: config.logMaxSize,
                  currentLogMaxFile: config.logMaxFile,
                );
                if (result != null && mounted) {
                  try {
                    final repo = await ref.read(
                      containerRepositoryProvider.future,
                    );
                    await repo.updateLogOption(
                      logMaxSize: result.logMaxSize,
                      logMaxFile: result.logMaxFile,
                    );
                    if (!mounted) return;
                    widget.onChanged?.call();
                    showAppSuccessToast(successMessage);
                    _loadAll();
                  } catch (e) {
                    if (!mounted) return;
                    showAppErrorToast(
                      failureMessage,
                      description: e.toString(),
                    );
                  }
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── 开关选项 ──
        AppSectionHeader(
          title: context.l10n.containers_switchOptions,
          icon: TablerIcons.toggle_left,
        ),
        AppActionGroup(
          children: [
            _SwitchRow(
              icon: TablerIcons.shield,
              iconColor: CupertinoColors.systemGreen,
              label: 'iptables',
              value: config.iptables,
              onChanged: (v) => _updateDaemonByKey('iptables', v.toString()),
            ),
            _SwitchRow(
              icon: TablerIcons.refresh_dot,
              iconColor: CupertinoColors.systemTeal,
              label: 'Live Restore',
              subtitle: config.isSwarm
                  ? context.l10n.containers_swarmUnavailable
                  : null,
              value: config.liveRestore,
              enabled: !config.isSwarm,
              onChanged: (v) async {
                final confirmed = await showActionSheet<bool>(
                  context: context,
                  useRootNavigator: true,
                  builder: (context) => AppConfirmSheet(
                    title: v
                        ? context.l10n.containers_enableLiveRestore
                        : context.l10n.containers_disableLiveRestore,
                    content: v
                        ? context.l10n.containers_enableLiveRestoreContent
                        : context.l10n.containers_disableLiveRestoreContent,
                    icon: TablerIcons.refresh_dot,
                    iconColor: CupertinoColors.systemTeal,
                    confirmText: context.l10n.common_confirm,
                  ),
                );
                if (confirmed == true && mounted) {
                  _updateDaemonByKey('LiveRestore', v ? 'enable' : 'disable');
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── 高级配置 ──
        AppSectionHeader(
          title: context.l10n.containers_advancedConfig,
          icon: TablerIcons.adjustments,
        ),
        AppActionGroup(
          children: [
            AppActionRow(
              icon: TablerIcons.cpu,
              iconColor: CupertinoColors.systemBlue,
              title: 'Cgroup Driver',
              subtitle: Text(
                config.cgroupDriver.isEmpty ? '--' : config.cgroupDriver,
              ),
              onTap: () async {
                final result = await showDockerCgroupDriverSheet(
                  context,
                  current: config.cgroupDriver.isEmpty
                      ? 'cgroupfs'
                      : config.cgroupDriver,
                );
                if (result != null &&
                    result != config.cgroupDriver &&
                    mounted) {
                  _updateDaemonByKey('cgroup-driver', result);
                }
              },
            ),
            AppActionRow(
              icon: TablerIcons.plug,
              iconColor: CupertinoColors.systemGrey,
              title: 'Docker Sock Path',
              subtitle: Text(_sockPath.isEmpty ? '--' : _sockPath),
              onTap: () async {
                final successMessage = context.l10n.containers_sockPathUpdated;
                final failureMessage = context.l10n.databases_updateFailed;
                final result = await showDockerEditValueSheet(
                  context,
                  title: 'Docker Sock Path',
                  initialValue: _sockPath,
                  placeholder: '/var/run/docker.sock',
                );
                if (result != null && result != _sockPath && mounted) {
                  try {
                    final repo = await ref.read(
                      settingRepositoryProvider.future,
                    );
                    await repo.updateSetting(
                      key: 'DockerSockPath',
                      value: result,
                    );
                    if (!mounted) return;
                    widget.onChanged?.call();
                    showAppSuccessToast(successMessage);
                    setState(() => _sockPath = result);
                  } catch (e) {
                    if (!mounted) return;
                    showAppErrorToast(
                      failureMessage,
                      description: e.toString(),
                    );
                  }
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── 全量配置 ──
        AppSectionHeader(
          title: context.l10n.containers_allConfig,
          icon: TablerIcons.code,
        ),
        AppActionGroup(
          children: [
            AppActionRow(
              icon: TablerIcons.file_code,
              iconColor: CupertinoColors.systemIndigo,
              title: context.l10n.containers_editDaemonJson,
              subtitle: Text(context.l10n.containers_editDaemonJsonSubtitle),
              onTap: _openFullConfigEditor,
            ),
          ],
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}

// ── 内置小组件 ──

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(height: 12),
            Text(
              context.l10n.containers_loadingDockerSettings,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TablerIcons.alert_circle,
            size: 36,
            color: CupertinoColors.systemRed.resolveFrom(context),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.common_loadingFailed,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.label(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: onRetry,
            child: Text(context.l10n.common_retry),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.label(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Opacity(
            opacity: enabled ? 1.0 : 0.4,
            child: AppToggleSwitch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
