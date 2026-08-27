import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/router/sheet_route_tracker.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../data/dto/container/container_resource_stats_dto.dart';
import '../../../../data/dto/container/container_search_dto.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/frosted_dialog.dart';
import '../../../common/components/frosted_filter_bar.dart';
import '../../../common/components/task_log_sheet.dart';
import '../models/container_list_state.dart';

final containerListControllerProvider =
    StateNotifierProvider.autoDispose<
      ContainerListController,
      AsyncValue<ContainerListState>
    >((ref) {
      return ContainerListController(ref);
    }, dependencies: [containerRepositoryProvider]);

class ContainerListController
    extends StateNotifier<AsyncValue<ContainerListState>> {
  ContainerListController(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref ref;
  Timer? _statsTimer;
  final _searchDebounce = Debouncer();
  bool _statsPollingEnabled = true;

  Future<void> _init() async {
    final nextState = await AsyncValue.guard(() async {
      final repo = await ref.read(containerRepositoryProvider.future);
      if (!mounted) return const ContainerListState();

      final results = await Future.wait([
        repo.getStatus(),
        repo.searchContainers(state: 'all', page: 1),
        repo.getContainerResourceStats(),
      ]);
      if (!mounted) return const ContainerListState();

      final status = results[0] as dynamic;
      final searchResult = results[1] as dynamic;
      final stats = results[2] as List<ContainerResourceStatsDto>;
      final statsMap = {for (var s in stats) s.containerID: s};

      _startStatsPolling();

      return ContainerListState(
        containers: searchResult.items,
        total: searchResult.total,
        statusSummary: status,
        stats: statsMap,
      );
    });

    if (!mounted) return;
    state = nextState;
  }

  void setStatsPolling(bool enabled) {
    _statsPollingEnabled = enabled;
    if (enabled) {
      _startStatsPolling();
    } else {
      _statsTimer?.cancel();
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    if (!_statsPollingEnabled) return;

    _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || !_statsPollingEnabled) {
        timer.cancel();
        return;
      }
      if (sheetRouteTracker.hasActiveSheet) {
        return;
      }
      try {
        final current = state.valueOrNull;
        if (current == null) return;

        final repo = await ref.read(containerRepositoryProvider.future);
        // ponytail: fetch all loaded pages in one request to avoid shrinking
        // the list and triggering scroll bounce-back
        final loadedCount = current.page * current.pageSize;
        final results = await Future.wait([
          repo.getStatus(),
          repo.searchContainers(
            page: 1,
            pageSize: loadedCount,
            state: current.filterState,
            name: current.searchQuery,
          ),
          repo.getContainerResourceStats(),
        ]);

        final status = results[0] as dynamic;
        final searchResult = results[1] as dynamic;
        final stats = results[2] as List<ContainerResourceStatsDto>;
        final statsMap = {for (var s in stats) s.containerID: s};

        if (!mounted) return;
        final latest = state.valueOrNull;
        if (latest == null) return;
        // 请求期间用户若改了筛选/关键字/翻页，丢弃本轮结果避免错写
        if (latest.filterState != current.filterState ||
            latest.searchQuery != current.searchQuery ||
            latest.page != current.page) {
          return;
        }

        state = AsyncValue.data(
          latest.copyWith(
            containers: searchResult.items,
            total: searchResult.total,
            statusSummary: status,
            stats: statsMap,
            page: current.page,
            isLoadingMore: false,
          ),
        );
      } catch (_) {
        // 轮询中忽略列表 / 统计接口错误，避免打断用户浏览
      }
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _searchDebounce.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final currentState = state.valueOrNull;
    if (currentState == null) {
      return _init();
    }

    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      if (!mounted) return;

      final results = await Future.wait([
        repo.getStatus(),
        repo.searchContainers(
          page: 1, // Refresh always goes back to page 1 but keeps filters
          pageSize: currentState.pageSize,
          state: currentState.filterState,
          name: currentState.searchQuery,
        ),
      ]);
      if (!mounted) return;

      final status = results[0] as dynamic;
      final searchResult = results[1] as dynamic;
      final shouldFetchStats = !sheetRouteTracker.hasActiveSheet;
      final statsMap = shouldFetchStats
          ? {
              for (var s in await repo.getContainerResourceStats())
                s.containerID: s,
            }
          : currentState.stats;
      if (!mounted) return;

      state = AsyncValue.data(
        currentState.copyWith(
          containers: searchResult.items,
          total: searchResult.total,
          statusSummary: status,
          stats: statsMap,
          page: 1,
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final currentState = state.valueOrNull;
    if (currentState == null ||
        currentState.isLoadingMore ||
        currentState.containers.length >= currentState.total) {
      return;
    }

    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      if (!mounted) return;

      final searchResult = await repo.searchContainers(
        page: currentState.page + 1,
        pageSize: currentState.pageSize,
        state: currentState.filterState,
        name: currentState.searchQuery,
      );
      if (!mounted) return;

      state = AsyncValue.data(
        currentState.copyWith(
          containers: [...currentState.containers, ...searchResult.items],
          page: currentState.page + 1,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void filter(String filterState) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncValue.data(
      currentState.copyWith(filterState: filterState, page: 1),
    );

    _triggerFetch();
  }

  void search(String query) {
    _searchDebounce(() {
      final currentState = state.valueOrNull;
      if (currentState == null) return;

      state = AsyncValue.data(
        currentState.copyWith(searchQuery: query, page: 1),
      );

      _triggerFetch();
    });
  }

  Future<void> _triggerFetch() async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      if (!mounted) return;

      final results = await Future.wait([
        repo.getStatus(),
        repo.searchContainers(
          page: 1,
          pageSize: currentState.pageSize,
          state: currentState.filterState,
          name: currentState.searchQuery,
        ),
      ]);
      if (!mounted) return;

      final status = results[0] as dynamic;
      final searchResult = results[1] as dynamic;

      state = AsyncValue.data(
        currentState.copyWith(
          containers: searchResult.items,
          total: searchResult.total,
          statusSummary: status,
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void sortBy(ContainerSortType sortType) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(sortType: sortType));
  }

  List<FilterItem> buildFilters(BuildContext context) {
    final currentState = state.valueOrNull;
    if (currentState == null) return [];
    final status = currentState.statusSummary;
    if (status == null) return [];

    final List<FilterItem> items = [
      FilterItem(
        label: context.l10n.containers_allCount(status.containerCount),
        value: 'all',
      ),
    ];

    final relevantStates = {
      'running': context.l10n.containers_running,
      'exited': context.l10n.containers_stateExited,
      'paused': context.l10n.containers_statePaused,
      'created': context.l10n.containers_stateCreated,
      'restarting': context.l10n.containers_stateRestarting,
      'removing': context.l10n.containers_stateRemoving,
      'dead': context.l10n.containers_stateDead,
    };

    final Map<String, int> counts = {
      'running': status.running,
      'exited': status.exited,
      'paused': status.paused,
      'created': status.created,
      'restarting': status.restarting,
      'removing': status.removing,
      'dead': status.dead,
    };

    final currentFilter = currentState.filterState;

    for (final stateKey in relevantStates.keys) {
      final count = counts[stateKey] ?? 0;
      if (count > 0 || stateKey == currentFilter) {
        items.add(
          FilterItem(
            label: context.l10n.containers_filterCount(
              relevantStates[stateKey]!,
              count,
            ),
            value: stateKey,
          ),
        );
      }
    }

    return items;
  }

  Future<void> pruneContainers(BuildContext context) async {
    final confirmed = await showFrostedConfirmDialog(
      context,
      title: context.l10n.containers_pruneContainers,
      icon: TablerIcons.trash,
      content: context.l10n.containers_pruneContainersConfirm,
      isDestructive: true,
    );

    if (confirmed != true) return;

    final taskID = const Uuid().v4();
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.pruneContainers(taskID: taskID);

      if (context.mounted) {
        showTaskLogSheet(
          context,
          title: context.l10n.containers_pruneContainers,
          taskID: taskID,
          reader: repo.readTaskLog,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showAppErrorToast(
        context.l10n.containers_pruneFailed,
        description: e.toString(),
      );
    }
  }

  Future<void> togglePin(
    BuildContext context,
    ContainerItemDto container,
  ) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final isPinned = !container.isPinned;
    final toastMessage = isPinned
        ? context.l10n.containers_addedFavorite
        : context.l10n.containers_removedFavorite;
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.saveDescription(
        id: container.containerID,
        type: 'container',
        isPinned: isPinned,
        description: container.description,
      );

      refresh();
      showAppToast(toastMessage);
    } catch (e) {
      if (!context.mounted) return;
      showAppErrorToast(
        context.l10n.containers_operationFailed,
        description: e.toString(),
      );
    }
  }

  Future<void> operateContainer({
    required BuildContext context,
    required ContainerItemDto container,
    required String operation,
    required String title,
  }) async {
    final confirmed = await showFrostedConfirmDialog(
      context,
      title: title,
      icon: _getOperationIcon(operation),
      content: context.l10n.containers_operationConfirm(
        _getOperationName(context, operation),
        container.name,
      ),
      isDestructive: operation == 'remove' || operation == 'kill',
    );

    if (confirmed != true) return;

    final taskID = const Uuid().v4();
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.operateContainer(
        names: [container.name],
        operation: operation,
        taskID: taskID,
      );

      if (context.mounted) {
        showTaskLogSheet(
          context,
          title: '$title: ${container.name}',
          taskID: taskID,
          reader: repo.readTaskLog,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showAppErrorToast(
        context.l10n.containers_operationFailed,
        description: e.toString(),
      );
    }
  }

  IconData _getOperationIcon(String op) {
    switch (op) {
      case 'start':
        return TablerIcons.player_play;
      case 'stop':
        return TablerIcons.player_stop;
      case 'restart':
        return TablerIcons.refresh;
      case 'pause':
        return TablerIcons.player_pause;
      case 'unpause':
        return TablerIcons.player_play;
      case 'kill':
        return TablerIcons.bolt;
      case 'remove':
        return TablerIcons.trash;
      default:
        return TablerIcons.box;
    }
  }

  String _getOperationName(BuildContext context, String op) {
    switch (op) {
      case 'start':
        return context.l10n.containers_start;
      case 'stop':
        return context.l10n.containers_stop;
      case 'restart':
        return context.l10n.containers_restart;
      case 'pause':
        return context.l10n.containers_pause;
      case 'unpause':
        return context.l10n.containers_restore;
      case 'kill':
        return context.l10n.containers_forceStop;
      case 'remove':
        return context.l10n.common_delete;
      default:
        return context.l10n.containers_operationGeneric;
    }
  }
}
