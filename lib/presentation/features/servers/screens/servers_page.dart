import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/components/floating_tab_bar.dart';
import '../../../common/components/frosted_action_button.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../purchases/widgets/purchase_prompt.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../providers/servers_provider.dart';
import '../widgets/add_server_sheet.dart';
import '../widgets/server_card.dart';
import '../widgets/server_context_menu.dart';
import '../widgets/server_memo_curl_card.dart';
import 'servers_settings_tab.dart';

class ServersPage extends ConsumerStatefulWidget {
  const ServersPage({super.key});

  @override
  ConsumerState<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends ConsumerState<ServersPage> with RouteAware {
  List<FloatingTabItemData> _tabItems(BuildContext context) => [
    FloatingTabItemData(
      icon: CupertinoIcons.rectangle_stack,
      activeIcon: CupertinoIcons.rectangle_stack_fill,
      label: context.l10n.nav_servers,
      nativeSymbol: 'rectangle.stack.fill',
    ),
    FloatingTabItemData(
      icon: CupertinoIcons.gear,
      activeIcon: CupertinoIcons.gear_solid,
      label: context.l10n.nav_settings,
      nativeSymbol: 'gearshape.fill',
    ),
  ];

  int _selectedIndex = 0;
  Timer? _refreshTimer;
  ProviderSubscription<AsyncValue<AppSettings>>? _settingsSubscription;
  bool _autoRefreshEnabled = true;
  int _refreshIntervalSeconds =
      AppSettingsController.defaultServersRefreshIntervalSeconds;
  bool _isCurrentRoute = true;

  @override
  void initState() {
    super.initState();
    _settingsSubscription = ref.listenManual<AsyncValue<AppSettings>>(
      appSettingsControllerProvider,
      (_, next) => _applyRefreshSettings(next.valueOrNull),
      fireImmediately: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPushNext() {
    _isCurrentRoute = false;
    _stopTimer();
  }

  @override
  void didPopNext() {
    _isCurrentRoute = true;
    _syncTimerWithSettings();
    _refreshServerSnapshots();
  }

  void _applyRefreshSettings(AppSettings? settings) {
    _autoRefreshEnabled = settings?.serversAutoRefreshEnabled ?? true;
    _refreshIntervalSeconds =
        settings?.serversRefreshIntervalSeconds ??
        AppSettingsController.defaultServersRefreshIntervalSeconds;
    _syncTimerWithSettings();
  }

  void _syncTimerWithSettings() {
    if (!_isCurrentRoute || !_autoRefreshEnabled) {
      _stopTimer();
      return;
    }
    _startTimer(Duration(seconds: _refreshIntervalSeconds));
  }

  void _startTimer(Duration interval) {
    _stopTimer();
    _refreshTimer = Timer.periodic(interval, (_) => _refreshServerSnapshots());
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _settingsSubscription?.close();
    _stopTimer();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _refreshServerSnapshots();
    }
  }

  void _refreshServerSnapshots() {
    if (!mounted || _selectedIndex != 0) return;
    final servers = ref.read(serversNotifierProvider).valueOrNull;
    if (servers == null || servers.isEmpty) return;
    for (final server in servers) {
      ref.invalidate(serverDashboardSnapshotProvider(server.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabItems = _tabItems(context);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(context),
      child: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _ServerListTab(onAddServer: _handleAddServer),
              const ServersSettingsTab(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              items: tabItems,
              selectedIndex: _selectedIndex,
              onTabSelected: _selectTab,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddServer() async {
    final servers = ref.read(serversNotifierProvider).valueOrNull ?? const [];
    final serverCount = servers.length;
    final purchaseState = await ref.read(purchaseControllerProvider.future);
    if (!mounted) return;

    if (serverCount == 0 || purchaseState.canAddServer(serverCount)) {
      await AddServerSheet.show(context);
      return;
    }

    await showUnlimitedServersPurchasePrompt(
      context,
      ref,
      serverCount: serverCount,
    );
  }
}

class _ServerListTab extends ConsumerStatefulWidget {
  final VoidCallback onAddServer;

  const _ServerListTab({required this.onAddServer});

  @override
  ConsumerState<_ServerListTab> createState() => _ServerListTabState();
}

class _ServerListTabState extends ConsumerState<_ServerListTab> {
  List<Server>? _orderedServers;
  List<int> _sourceIds = const [];
  bool _isSorting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final serversAsync = ref.watch(serversNotifierProvider);
    final cardStyle =
        ref.watch(appSettingsControllerProvider).valueOrNull?.serverCardStyle ??
        ServerCardStyle.simple;

    return FrostedScaffold(
      title: 'Mono Dash',
      showBackButton: false,
      largeTitle: true,
      fadeOutDistance: 41,
      trailingBuilder: (isDark, isOverlapping) => FrostedActionButton(
        text: '',
        icon: CupertinoIcons.add,
        isDark: isDark,
        isOverlapping: isOverlapping,
        onTap: widget.onAddServer,
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: FrostedScaffold.contentTopPadding(context) + 60,
            ),
          ),
          if (_isSorting)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground(
                      context,
                    ).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.12),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.line_horizontal_3,
                        size: 18,
                        color: AppColors.secondaryLabel(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.servers_sortHint,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => setState(() => _isSorting = false),
                        child: Text(l10n.common_done),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          serversAsync.when(
            data: (servers) {
              final orderedServers = _syncOrderedServers(servers);
              if (servers.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Center(
                      child: Text(
                        l10n.servers_empty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 132),
                sliver: SliverReorderableList(
                  itemBuilder: (context, index) {
                    final server = orderedServers[index];
                    return Builder(
                      key: ValueKey(server.id),
                      builder: (itemContext) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: _isSorting
                                ? null
                                : () => _showServerMenu(
                                    itemContext,
                                    server,
                                    cardStyle,
                                  ),
                            child: _isSorting
                                ? ReorderableDragStartListener(
                                    index: index,
                                    child: ServerCard(
                                      server: server,
                                      style: cardStyle,
                                    ),
                                  )
                                : ServerMemoCurlCard(
                                    server: server,
                                    style: cardStyle,
                                    onTap: () =>
                                        context.push('/server/${server.id}'),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                  itemCount: orderedServers.length,
                  onReorder: _reorderServers,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text(l10n.servers_loadFailed('$err'))),
            ),
          ),
        ],
      ),
    );
  }

  void _showServerMenu(
    BuildContext itemContext,
    Server server,
    ServerCardStyle cardStyle,
  ) {
    ServerContextMenu.show(
      itemContext,
      server,
      style: cardStyle,
      onSort: () => setState(() => _isSorting = true),
      onEdit: () => AddServerSheet.edit(context, server),
      onDelete: () => _confirmDelete(server),
    );
  }

  Future<void> _confirmDelete(Server server) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.servers_deleteTitle),
        content: Text(context.l10n.servers_deleteContent(server.displayName)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(serversNotifierProvider.notifier).removeServer(server.id);
  }

  List<Server> _syncOrderedServers(List<Server> servers) {
    final ids = [for (final server in servers) server.id];
    if (_orderedServers == null || !_sameIds(ids, _sourceIds)) {
      _orderedServers = [...servers];
      _sourceIds = ids;
      return _orderedServers!;
    }

    final latestById = {for (final server in servers) server.id: server};
    final orderedIds = [for (final server in _orderedServers!) server.id];
    _orderedServers = [for (final id in orderedIds) ?latestById[id]];
    return _orderedServers!;
  }

  void _reorderServers(int oldIndex, int newIndex) {
    final orderedServers = _orderedServers;
    if (orderedServers == null) return;

    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = orderedServers.removeAt(oldIndex);
      orderedServers.insert(newIndex, moved);
      _sourceIds = [for (final server in orderedServers) server.id];
    });

    ref.read(serversNotifierProvider.notifier).reorderServers([
      for (final server in orderedServers) server.id,
    ]);
  }

  bool _sameIds(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}
