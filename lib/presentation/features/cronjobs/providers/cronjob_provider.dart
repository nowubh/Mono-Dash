import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../data/repositories_impl/cronjob_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/frosted_dialog.dart';
import '../models/cronjob_state.dart';

part 'cronjob_provider.g.dart';

const cronjobTypeIcons = {
  'shell': TablerIcons.terminal,
  'app': TablerIcons.apps,
  'website': TablerIcons.world,
  'database': TablerIcons.database,
  'directory': TablerIcons.folder,
  'log': TablerIcons.file_text,
  'curl': TablerIcons.link,
  'cutWebsiteLog': TablerIcons.scissors,
  'clean': TablerIcons.eraser,
  'snapshot': TablerIcons.camera,
  'ntp': TablerIcons.clock,
  'syncIpGroup': TablerIcons.shield,
  'cleanLog': TablerIcons.trash,
};

bool cronjobStatusIsEnabled(String status) => status.toLowerCase() == 'enable';

String cronjobTypeLabel(String type, AppLocalizations l10n) {
  return switch (type) {
    'shell' => l10n.cronjobs_typeShell,
    'app' => l10n.cronjobs_typeApp,
    'website' => l10n.cronjobs_typeWebsite,
    'database' => l10n.cronjobs_typeDatabase,
    'directory' => l10n.cronjobs_typeDirectory,
    'log' => l10n.cronjobs_typeLog,
    'curl' => l10n.cronjobs_typeCurl,
    'cutWebsiteLog' => l10n.cronjobs_typeCutWebsiteLog,
    'clean' => l10n.cronjobs_typeClean,
    'snapshot' => l10n.cronjobs_typeSnapshot,
    'ntp' => l10n.cronjobs_typeNtp,
    'syncIpGroup' => l10n.cronjobs_typeSyncIpGroup,
    'cleanLog' => l10n.cronjobs_typeCleanLog,
    _ => type,
  };
}

@Riverpod(dependencies: [cronjobRepository])
class CronjobController extends _$CronjobController {
  final _searchDebounce = Debouncer();

  @override
  FutureOr<CronjobState> build() async {
    final repo = await ref.watch(cronjobRepositoryProvider.future);
    final data = await repo.searchCronjobs({
      'page': 1,
      'pageSize': 20,
      'info': '',
      'orderBy': 'createdAt',
      'order': 'descending',
    });

    return CronjobState(items: data.items, page: 1, total: data.total);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final repo = await ref.read(cronjobRepositoryProvider.future);
      final current = state.valueOrNull ?? const CronjobState();

      final data = await repo.searchCronjobs({
        'page': 1,
        'pageSize': current.pageSize,
        'info': current.searchQuery,
        'orderBy': 'createdAt',
        'order': 'descending',
      });

      return current.copyWith(items: data.items, page: 1, total: data.total);
    });
  }

  void search(String query) {
    _searchDebounce(() {
      final current = state.valueOrNull;
      if (current == null) return;

      final trimmed = query.trim();
      state = AsyncValue.data(current.copyWith(searchQuery: trimmed));
      refresh();
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final repo = await ref.read(cronjobRepositoryProvider.future);
      final nextPage = current.page + 1;

      final data = await repo.searchCronjobs({
        'page': nextPage,
        'pageSize': current.pageSize,
        'info': current.searchQuery,
        'orderBy': 'createdAt',
        'order': 'descending',
      });

      final updated = state.valueOrNull;
      if (updated == null) return;

      state = AsyncValue.data(
        updated.copyWith(
          items: [...updated.items, ...data.items],
          page: nextPage,
          total: data.total,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      final updated = state.valueOrNull;
      if (updated != null) {
        state = AsyncValue.data(updated.copyWith(isLoadingMore: false));
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleStatus(
    BuildContext context,
    int id,
    String currentStatus,
  ) async {
    final newStatus = cronjobStatusIsEnabled(currentStatus)
        ? 'disable'
        : 'enable';
    final l10n = ref.read(appLocalizationsProvider);
    final isEnable = newStatus == 'enable';

    final confirmed = await showFrostedConfirmDialog(
      context,
      title: isEnable ? l10n.cronjobs_enableTitle : l10n.cronjobs_disableTitle,
      icon: newStatus == 'enable'
          ? TablerIcons.player_play
          : TablerIcons.player_stop,
      content: isEnable
          ? l10n.cronjobs_enableConfirm
          : l10n.cronjobs_disableConfirm,
    );

    if (confirmed != true) return;

    try {
      final repo = await ref.read(cronjobRepositoryProvider.future);
      await repo.updateStatus(id, newStatus);
      showAppSuccessToast(
        isEnable
            ? l10n.cronjobs_enableSucceeded
            : l10n.cronjobs_disableSucceeded,
      );
      refresh();
    } catch (e) {
      showAppErrorToast(
        isEnable ? l10n.cronjobs_enableFailed : l10n.cronjobs_disableFailed,
        description: e.toString(),
      );
    }
  }

  Future<void> handleOnce(int id) async {
    try {
      final repo = await ref.read(cronjobRepositoryProvider.future);
      await repo.handleOnce(id);
      final l10n = ref.read(appLocalizationsProvider);
      showAppSuccessToast(l10n.cronjobs_runTriggered);
      refresh();
    } catch (e) {
      final l10n = ref.read(appLocalizationsProvider);
      showAppErrorToast(
        l10n.cronjobs_runTriggerFailed,
        description: e.toString(),
      );
    }
  }

  Future<void> delete(int id) async {
    try {
      final repo = await ref.read(cronjobRepositoryProvider.future);
      await repo.deleteCronjob([id]);
      final l10n = ref.read(appLocalizationsProvider);
      showAppSuccessToast(l10n.cronjobs_deleteSucceeded);
      refresh();
    } catch (e) {
      final l10n = ref.read(appLocalizationsProvider);
      showAppErrorToast(l10n.cronjobs_deleteFailed, description: e.toString());
    }
  }
}
