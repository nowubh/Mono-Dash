import 'dart:async';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/api/file_api.dart';
import '../../../../data/api/log_api.dart';
import '../../../../data/api/process_api.dart';
import '../../../../data/dto/host/ssh_info_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_confirm_sheet.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/floating_tab_bar.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../../common/components/mini_button.dart';
import '../../../common/components/status_pill.dart';
import '../../log/providers/ssh_log_provider.dart';
import '../../log/widgets/ssh_log_list.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../providers/ssh_info_provider.dart';
import '../widgets/ssh_session_item.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/frosted_overlay_menu.dart';
import '../../../common/components/app_header_search_field.dart';
import '../widgets/auth_keys_sheet.dart';
import '../widgets/listen_address_sheet.dart';
import '../widgets/port_edit_sheet.dart';
import '../widgets/ssh_cert_sheet.dart';
import '../../../common/components/app_action_picker_sheet.dart';

// ─── Page shell ──────────────────────────────────────────────────────────────

class SshPage extends StatelessWidget {
  const SshPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: const _SshContent(),
    );
  }
}

class _SshContent extends ConsumerStatefulWidget {
  const _SshContent();

  @override
  ConsumerState<_SshContent> createState() => _SshContentState();
}

class _SshContentState extends ConsumerState<_SshContent> {
  int _tabIndex = 0;

  List<FloatingTabItemData> _tabItems(BuildContext context) => [
    FloatingTabItemData(
      icon: TablerIcons.settings,
      activeIcon: TablerIcons.settings,
      label: context.l10n.nav_configuration,
      nativeSymbol: 'gearshape.fill',
    ),
    FloatingTabItemData(
      icon: TablerIcons.terminal_2,
      activeIcon: TablerIcons.terminal_2,
      label: context.l10n.nav_sessions,
      nativeSymbol: 'terminal',
    ),
    FloatingTabItemData(
      icon: TablerIcons.file_text,
      activeIcon: TablerIcons.file_text,
      label: context.l10n.nav_logs,
      nativeSymbol: 'doc.text.fill',
    ),
  ];

  void _switchTab(int index) {
    if (index != _tabIndex) setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tabItems = _tabItems(context);

    return FrostedScaffold(
      title: context.l10n.ssh_title,
      trailingBuilder: (isDark, isOverlapping) {
        if (_tabIndex == 0) {
          return _ConfigTrailing(isDark: isDark, isOverlapping: isOverlapping);
        }
        if (_tabIndex == 2) {
          return _LogTrailing(isDark: isDark, isOverlapping: isOverlapping);
        }
        return const SizedBox.shrink();
      },
      body: Stack(
        children: [
          IndexedStack(
            index: _tabIndex,
            children: [
              const _SshConfigTab(),
              _SshSessionTab(active: _tabIndex == 1),
              const _SshLogTabContent(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              items: tabItems,
              selectedIndex: _tabIndex,
              onTabSelected: _switchTab,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Config trailing menu ────────────────────────────────────────────────────

class _ConfigTrailing extends ConsumerWidget {
  const _ConfigTrailing({required this.isDark, required this.isOverlapping});

  final bool isDark;
  final bool isOverlapping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FrostedOverlayMenuButton(
      label: context.l10n.ssh_manage,
      isDark: isDark,
      isOverlapping: isOverlapping,
      items: [
        FrostedMenuItem(
          text: context.l10n.ssh_refreshConfig,
          icon: TablerIcons.refresh,
          action: () => ref.read(sshInfoControllerProvider.notifier).refresh(),
        ),
        FrostedMenuItem(
          text: context.l10n.ssh_fullConfig,
          icon: TablerIcons.file_code,
          action: () => showAllConfigSheet(context, ref),
        ),
        FrostedMenuItem(
          text: context.l10n.ssh_publicKeyManagement,
          icon: TablerIcons.key,
          action: () => showSshCertSheet(context),
        ),
        FrostedMenuItem(
          text: context.l10n.ssh_authorizedKeys,
          icon: TablerIcons.list,
          action: () => showAuthKeysSheet(context, ref),
        ),
      ],
    );
  }
}

// ─── Log trailing menu ───────────────────────────────────────────────────────

class _LogTrailing extends ConsumerStatefulWidget {
  const _LogTrailing({required this.isDark, required this.isOverlapping});

  final bool isDark;
  final bool isOverlapping;

  @override
  ConsumerState<_LogTrailing> createState() => _LogTrailingState();
}

class _LogTrailingState extends ConsumerState<_LogTrailing> {
  bool _isSearchMode = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(sshLogControllerProvider.notifier);

    if (_isSearchMode) {
      return AppHeaderSearchField(
        controller: _controller,
        focusNode: _focusNode,
        placeholder: context.l10n.ssh_logSearchPlaceholder,
        onChanged: notifier.searchByInfo,
        onClear: () => notifier.searchByInfo(''),
        onCancel: () {
          setState(() => _isSearchMode = false);
          _controller.clear();
          notifier.searchByInfo('');
        },
      );
    }

    return FrostedOverlayMenuButton(
      label: context.l10n.common_menu,
      isDark: widget.isDark,
      isOverlapping: widget.isOverlapping,
      items: [
        FrostedMenuItem(
          text: context.l10n.ssh_searchLogs,
          icon: TablerIcons.search,
          action: () {
            setState(() => _isSearchMode = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _focusNode.requestFocus();
            });
          },
        ),
        FrostedMenuItem(
          text: context.l10n.ssh_exportLogs,
          icon: TablerIcons.download,
          action: () => _exportLogs(context),
        ),
        FrostedMenuItem(
          text: context.l10n.ssh_refreshList,
          icon: TablerIcons.refresh,
          action: notifier.refresh,
        ),
      ],
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final serverId = ref.read(activeServerIdProvider);
      final client = await ref.read(dioClientProvider(serverId).future);
      final serverPath = await LogApi(client).exportSshLogs();

      final dir = await getTemporaryDirectory();
      final localPath = '${dir.path}/ssh_logs.csv';
      final localFile = File(localPath);
      if (await localFile.exists()) await localFile.delete();

      await FileApi(client).downloadFile(path: serverPath, savePath: localPath);

      if (!await localFile.exists() || await localFile.length() == 0) {
        throw l10n.ssh_downloadEmpty;
      }

      await SharePlus.instance.share(
        ShareParams(
          title: l10n.ssh_loginLogTitle,
          subject: l10n.ssh_loginLogTitle,
          files: [XFile(localPath, mimeType: 'text/csv')],
          fileNameOverrides: ['ssh_logs.csv'],
        ),
      );
    } catch (e) {
      showAppErrorToast(l10n.ssh_exportFailed, description: '$e');
    }
  }
}

// ─── Tab 0: Config ───────────────────────────────────────────────────────────

class _SshConfigTab extends ConsumerWidget {
  const _SshConfigTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(sshInfoControllerProvider);
    final notifier = ref.read(sshInfoControllerProvider.notifier);

    return stateAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          top: FrostedScaffold.contentTopPadding(context),
        ),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          AppEmptyState(
            icon: TablerIcons.alert_triangle,
            title: context.l10n.common_loadingFailed,
            subtitle: e.toString(),
            actionLabel: context.l10n.common_retry,
            onAction: notifier.refresh,
          ),
        ],
      ),
      data: (info) => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [SliverToBoxAdapter(child: _ConfigBody(info: info))],
      ),
    );
  }
}

class _ConfigBody extends ConsumerWidget {
  const _ConfigBody({required this.info});

  final SshInfoDto info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sshInfoControllerProvider.notifier);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        FrostedScaffold.contentTopPadding(context) + 8,
        16,
        132,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 服务状态 ──
          AppSectionHeader(
            title: context.l10n.ssh_serviceStatus,
            icon: TablerIcons.activity,
          ),
          AppActionGroup(
            children: [
              AppActionRow(
                icon: TablerIcons.key,
                iconColor: CupertinoColors.systemGreen,
                title: context.l10n.ssh_runningStatus,
                subtitle: Text(
                  info.message.isEmpty
                      ? context.l10n.ssh_serviceRunningMessage
                      : info.message,
                ),
                trailing: StatusPill(
                  label: info.isActive
                      ? context.l10n.ssh_running
                      : context.l10n.ssh_stopped,
                  active: info.isActive,
                ),
              ),
              AppActionRow(
                icon: TablerIcons.plug,
                iconColor: AppColors.secondaryLabel(context),
                title: context.l10n.ssh_port,
                subtitle: Text(
                  info.port.isEmpty
                      ? context.l10n.ssh_notConfigured
                      : info.port,
                ),
                trailing: Icon(
                  TablerIcons.chevron_right,
                  size: 16,
                  color: AppColors.tertiaryLabel(context),
                ),
                onTap: () => showPortEditSheet(context, currentPort: info.port),
              ),
              AppActionRow(
                icon: TablerIcons.network,
                iconColor: AppColors.secondaryLabel(context),
                title: context.l10n.ssh_listenAddress,
                subtitle: Text(
                  info.listenAddress.isEmpty
                      ? context.l10n.ssh_notConfigured
                      : info.listenAddress,
                ),
                trailing: Icon(
                  TablerIcons.chevron_right,
                  size: 16,
                  color: AppColors.tertiaryLabel(context),
                ),
                onTap: () => showListenAddressSheet(
                  context,
                  currentAddress: info.listenAddress,
                ),
              ),
              _InfoRow(
                label: context.l10n.ssh_currentUser,
                value: info.currentUser,
                icon: TablerIcons.user,
              ),
              _SwitchRow(
                label: context.l10n.ssh_autoStart,
                icon: TablerIcons.rocket,
                value: info.autoStart,
                onChanged: (v) => notifier.operate(v ? 'enable' : 'disable'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 操作按钮 ──
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: MiniButton(
                  label: info.isActive
                      ? context.l10n.ssh_stopService
                      : context.l10n.ssh_startService,
                  icon: info.isActive
                      ? TablerIcons.player_stop
                      : TablerIcons.player_play,
                  color: info.isActive
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemGreen,
                  onTap: () => _operate(
                    context,
                    notifier,
                    info.isActive ? 'stop' : 'start',
                    info.isActive
                        ? context.l10n.ssh_stop
                        : context.l10n.ssh_start,
                  ),
                ),
              ),
              Expanded(
                child: MiniButton(
                  label: context.l10n.ssh_restartService,
                  icon: TablerIcons.refresh,
                  onTap: () => _operate(
                    context,
                    notifier,
                    'restart',
                    context.l10n.ssh_restart,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 认证配置 ──
          AppSectionHeader(
            title: context.l10n.ssh_authConfig,
            icon: TablerIcons.shield_lock,
          ),
          AppActionGroup(
            children: [
              _SwitchRow(
                label: context.l10n.ssh_passwordLogin,
                icon: TablerIcons.keyboard,
                value: info.passwordAuthentication == 'yes',
                onChanged: (v) => notifier.updateConfig(
                  'PasswordAuthentication',
                  v ? 'yes' : 'no',
                ),
              ),
              _SwitchRow(
                label: context.l10n.ssh_keyLogin,
                icon: TablerIcons.id,
                value: info.pubkeyAuthentication == 'yes',
                onChanged: (v) => notifier.updateConfig(
                  'PubkeyAuthentication',
                  v ? 'yes' : 'no',
                ),
              ),
              _SwitchRow(
                label: context.l10n.ssh_useDns,
                icon: TablerIcons.world,
                value: info.useDNS == 'yes',
                onChanged: (v) =>
                    notifier.updateConfig('UseDNS', v ? 'yes' : 'no'),
              ),
              _RootLoginPicker(
                currentValue: info.permitRootLogin,
                onChanged: (v) => notifier.updateConfig('PermitRootLogin', v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _operate(
    BuildContext context,
    SshInfoController notifier,
    String operation,
    String label,
  ) async {
    final confirmed = await showActionSheet<bool>(
      context: context,
      builder: (_) => AppConfirmSheet(
        title: context.l10n.ssh_confirmOperationTitle(label),
        content: context.l10n.ssh_confirmOperationContent(operation),
        confirmText: label,
        confirmColor: operation == 'stop'
            ? CupertinoColors.systemRed
            : CupertinoColors.activeBlue,
      ),
    );
    if (confirmed == true) notifier.operate(operation);
  }
}

// ─── All Config Sheet ───────────────────────────────────────────────────────

Future<void> showAllConfigSheet(BuildContext context, WidgetRef ref) {
  return showActionSheet<void>(
    context: context,
    builder: (_) => const _AllConfigSheet(),
  );
}

class _AllConfigSheet extends ConsumerStatefulWidget {
  const _AllConfigSheet();

  @override
  ConsumerState<_AllConfigSheet> createState() => _AllConfigSheetState();
}

class _AllConfigSheetState extends ConsumerState<_AllConfigSheet> {
  List<_SshConfOption> _options = [];
  String _selectedPath = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final notifier = ref.read(sshInfoControllerProvider.notifier);
      final raw = await notifier.loadSshFile('sshdConfOptions');
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (e) => _SshConfOption(
              path: e['path']?.toString() ?? '',
              priority: (e['priority'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((o) => o.path.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _options = list;
        if (_selectedPath.isEmpty && list.isNotEmpty) {
          _selectedPath = list.first.path;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openEditor() async {
    if (_selectedPath.isEmpty) return;
    final notifier = ref.read(sshInfoControllerProvider.notifier);
    await showAppCodeEditorSheet(
      context,
      title: context.l10n.ssh_configFileTitle,
      subtitle: _selectedPath,
      language: 'ini',
      onLoad: () => notifier.loadSshFile('sshdConfPath:$_selectedPath'),
      onSave: (content) =>
          notifier.updateSshFile('sshdConfPath', _selectedPath, content),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      maxHeightFactor: 0.85,
      isAdaptive: false,
      showHandle: false,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
        child: Row(
          children: [
            Icon(
              TablerIcons.file_code,
              size: 22,
              color: CupertinoColors.systemOrange.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.ssh_fullConfig,
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
                context.l10n.common_close,
                style: TextStyle(
                  color: AppColors.secondaryLabel(context),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 提示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange
                          .resolveFrom(context)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          TablerIcons.alert_triangle,
                          size: 16,
                          color: CupertinoColors.systemOrange.resolveFrom(
                            context,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.ssh_fullConfigWarning,
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemOrange.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 文件选择
                  if (_options.isNotEmpty) ...[
                    Text(
                      context.l10n.ssh_configFile,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._options.map(
                      (opt) => GestureDetector(
                        onTap: () => setState(() => _selectedPath = opt.path),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: opt.path == _selectedPath
                                ? CupertinoColors.activeBlue
                                      .resolveFrom(context)
                                      .withValues(alpha: 0.16)
                                : AppColors.secondaryBackground(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: opt.path == _selectedPath
                                  ? CupertinoColors.activeBlue
                                        .resolveFrom(context)
                                        .withValues(alpha: 0.55)
                                  : AppColors.separator(
                                      context,
                                    ).withValues(alpha: 0.18),
                              width: opt.path == _selectedPath ? 1.2 : 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                opt.path == _selectedPath
                                    ? TablerIcons.circle_check_filled
                                    : TablerIcons.circle,
                                size: 18,
                                color: opt.path == _selectedPath
                                    ? CupertinoColors.activeBlue.resolveFrom(
                                        context,
                                      )
                                    : AppColors.tertiaryLabel(context),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  opt.path,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.label(context),
                                  ),
                                ),
                              ),
                              Text(
                                context.l10n.ssh_priority(opt.priority),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.tertiaryLabel(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 编辑按钮
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _selectedPath.isNotEmpty ? _openEditor : null,
                      child: Text(context.l10n.ssh_editConfigFile),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SshConfOption {
  const _SshConfOption({required this.path, required this.priority});
  final String path;
  final int priority;
}

// ─── Root Login Picker ───────────────────────────────────────────────────────

class _RootLoginPicker extends StatelessWidget {
  const _RootLoginPicker({required this.currentValue, required this.onChanged});

  final String currentValue;
  final ValueChanged<String> onChanged;

  String _getLabel(BuildContext context, String value) {
    switch (value) {
      case 'yes':
        return context.l10n.ssh_rootLoginAllow;
      case 'no':
        return context.l10n.ssh_rootLoginDeny;
      case 'prohibit-password':
        return context.l10n.ssh_rootLoginProhibitPassword;
      case 'forced-commands-only':
        return context.l10n.ssh_rootLoginForcedCommandsOnly;
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      AppPickerOption(value: 'yes', label: context.l10n.ssh_rootLoginAllow),
      AppPickerOption(value: 'no', label: context.l10n.ssh_rootLoginDeny),
      AppPickerOption(
        value: 'prohibit-password',
        label: context.l10n.ssh_rootLoginProhibitPassword,
      ),
      AppPickerOption(
        value: 'forced-commands-only',
        label: context.l10n.ssh_rootLoginForcedCommandsOnly,
      ),
    ];

    return AppActionRow(
      icon: TablerIcons.user_shield,
      iconColor: AppColors.secondaryLabel(context),
      title: context.l10n.ssh_rootLoginPolicy,
      subtitle: Text(_getLabel(context, currentValue)),
      trailing: Icon(
        TablerIcons.chevron_right,
        size: 16,
        color: AppColors.tertiaryLabel(context),
      ),
      onTap: () async {
        final result = await showAppActionPickerSheet<String>(
          context,
          title: context.l10n.ssh_rootLoginPolicy,
          options: options,
          selectedValue: currentValue,
        );
        if (result != null) {
          onChanged(result);
        }
      },
    );
  }
}

// ─── Tab 1: Session ─────────────────────────────────────────────────────────

class _SshSessionTab extends ConsumerStatefulWidget {
  const _SshSessionTab({required this.active});

  final bool active;

  @override
  ConsumerState<_SshSessionTab> createState() => _SshSessionTabState();
}

class _SshSessionTabState extends ConsumerState<_SshSessionTab> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _timer;
  bool _connectionOpening = false;

  List<Map<String, dynamic>> _sessions = const [];
  bool _connecting = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _connect();
  }

  @override
  void didUpdateWidget(covariant _SshSessionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;

    if (widget.active) {
      _connect();
    } else {
      _closeConnection();
    }
  }

  Future<void> _connect() async {
    if (_channel != null || _connectionOpening) return;

    final l10n = ref.read(appLocalizationsProvider);
    _connectionOpening = true;
    if (mounted) {
      setState(() {
        _connecting = true;
        _error = null;
      });
    }

    try {
      final serverId = ref.read(activeServerIdProvider);
      final storage = ref.read(storageServiceProvider);
      final server = await storage.getServer(serverId);
      final apiKey = await storage.getApiKey(serverId) ?? '';
      if (server == null) throw StateError(l10n.common_serverNotFound);
      if (!mounted || !widget.active) return;

      final channel = await ProcessApi.connectProcessWebSocket(
        baseUrl: server.baseUrl.toString(),
        apiKey: apiKey,
        allowInsecureConnections: server.allowInsecureConnections,
        operateNode: null,
      );
      if (!mounted || !widget.active) {
        channel.sink.close();
        return;
      }

      _channel = channel;
      _subscription = channel.stream.listen(
        (event) {
          final decoded = jsonDecode(event.toString());
          final next = decoded is List
              ? decoded
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList()
              : <Map<String, dynamic>>[];
          if (!mounted) return;
          setState(() {
            _sessions = next;
            _connecting = false;
            _error = null;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _error = e;
            _connecting = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _connecting = false);
        },
      );
      await channel.ready.timeout(const Duration(seconds: 15));
      if (!mounted || !widget.active || _channel != channel) return;
      _sendRequest();
      _timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _sendRequest(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _connecting = false;
      });
    } finally {
      _connectionOpening = false;
    }
  }

  void _sendRequest() {
    _channel?.sink.add(jsonEncode({'type': 'ssh', 'loginUser': ''}));
  }

  void _closeConnection() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _disconnect(int pid) async {
    final l10n = context.l10n;
    final confirmed = await showActionSheet<bool>(
      context: context,
      builder: (_) => AppConfirmSheet(
        title: l10n.ssh_disconnectTitle,
        content: l10n.ssh_disconnectContent(pid),
        confirmText: l10n.ssh_disconnectAction,
        confirmColor: CupertinoColors.systemRed,
      ),
    );
    if (confirmed != true) return;
    try {
      final serverId = ref.read(activeServerIdProvider);
      final client = await ref.read(dioClientProvider(serverId).future);
      await ProcessApi(client).stopProcess(pid);
      _sendRequest();
      showAppSuccessToast(l10n.ssh_disconnected);
    } catch (e) {
      showAppErrorToast(l10n.ssh_disconnectFailed, description: '$e');
    }
  }

  @override
  void dispose() {
    _closeConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting && _sessions.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.separator(context).withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(width: 12),
              Text(
                context.l10n.ssh_connectingSessions,
                style: TextStyle(color: AppColors.secondaryLabel(context)),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _sessions.isEmpty) {
      return AppErrorState(
        title: context.l10n.ssh_connectionFailed,
        error: _error!,
        onRetry: _connect,
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () async => _sendRequest()),
        SliverToBoxAdapter(
          child: SizedBox(
            height: FrostedScaffold.contentTopPadding(context) + 8,
          ),
        ),
        if (_sessions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.15,
              ),
              child: AppEmptyState(
                icon: TablerIcons.terminal_2,
                title: context.l10n.ssh_noActiveSessions,
                subtitle: context.l10n.ssh_sessionsEmptySubtitle,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 132),
            sliver: SliverList.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final s = _sessions[index];
                final pid = s['PID'] is int
                    ? s['PID'] as int
                    : int.tryParse('${s['PID'] ?? s['pid']}') ?? 0;
                return SshSessionItem(
                  username: '${s['username'] ?? ''}',
                  pid: pid,
                  terminal: '${s['terminal'] ?? ''}',
                  host: '${s['host'] ?? ''}',
                  loginTime: '${s['loginTime'] ?? ''}',
                  onDisconnect: () => _disconnect(pid),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─── Tab 2: Log ──────────────────────────────────────────────────────────────

class _SshLogTabContent extends StatelessWidget {
  const _SshLogTabContent();

  @override
  Widget build(BuildContext context) {
    return const SshLogList(bottomPadding: 132);
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      icon: icon,
      iconColor: AppColors.secondaryLabel(context),
      title: label,
      subtitle: Text(value.isEmpty ? context.l10n.ssh_notConfigured : value),
      trailing: const SizedBox.shrink(),
    );
  }
}

class _SwitchRow extends StatefulWidget {
  const _SwitchRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final Future<bool> Function(bool value) onChanged;

  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  late bool _displayValue;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SwitchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isWorking && widget.value != _displayValue) {
      _displayValue = widget.value;
    }
  }

  Future<void> _handleChanged(bool value) async {
    if (_isWorking) return;

    final previousValue = _displayValue;
    setState(() {
      _displayValue = value;
      _isWorking = true;
    });

    final ok = await widget.onChanged(value);
    if (!mounted) return;

    setState(() {
      _isWorking = false;
      if (!ok) _displayValue = previousValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      icon: widget.icon,
      iconColor: AppColors.secondaryLabel(context),
      title: widget.label,
      subtitle: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text(
          _isWorking
              ? context.l10n.ssh_updating
              : (_displayValue
                    ? context.l10n.ssh_enabled
                    : context.l10n.ssh_disabled),
          key: ValueKey('${widget.label}-$_isWorking-$_displayValue'),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isWorking
                ? const Padding(
                    key: ValueKey('working'),
                    padding: EdgeInsets.only(right: 8),
                    child: CupertinoActivityIndicator(radius: 8),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _isWorking ? 0.72 : 1,
            child: AppToggleSwitch(
              value: _displayValue,
              onChanged: _isWorking ? null : _handleChanged,
            ),
          ),
        ],
      ),
    );
  }
}
