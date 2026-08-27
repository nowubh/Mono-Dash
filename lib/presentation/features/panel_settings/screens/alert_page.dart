import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/alert/alert_dto.dart';
import '../../../../data/repositories_impl/alert_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_action_components.dart';
import '../../server_detail/providers/active_server_provider.dart';

class AlertPage extends StatelessWidget {
  const AlertPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: const _AlertContent(),
    );
  }
}

class _AlertContent extends StatefulWidget {
  const _AlertContent();

  @override
  State<_AlertContent> createState() => _AlertContentState();
}

class _AlertContentState extends State<_AlertContent> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.panelSettings_alerts),
        backgroundColor: AppColors.background(context).withValues(alpha: 0.8),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            CupertinoSegmentedControl<int>(
              children: {
                0: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(l10n.panelSettings_alertList),
                ),
                1: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(l10n.panelSettings_alertLogs),
                ),
                2: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(l10n.settings_title),
                ),
              },
              onValueChanged: (i) => setState(() => _selectedIndex = i),
              groupValue: _selectedIndex,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _AlertListTab(),
                  _AlertLogTab(),
                  _AlertSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 告警列表 Tab
class _AlertListTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AlertListTab> createState() => _AlertListTabState();
}

class _AlertListTabState extends ConsumerState<_AlertListTab> {
  List<AlertInfo> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = await ref.read(alertRepositoryProvider.future);
      final result = await repo.searchAlerts(
        const AlertSearchReq(page: 1, pageSize: 100),
      );
      if (!mounted) return;
      setState(() {
        _alerts = result.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator());

    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TablerIcons.bell_off,
              size: 48,
              color: AppColors.tertiaryLabel(context),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.panelSettings_noAlertRules,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        return _AlertCard(
          alert: alert,
          onToggle: () async {
            final l10n = context.l10n;
            try {
              final repo = await ref.read(alertRepositoryProvider.future);
              final newStatus = alert.status == 'Enable' ? 'Disable' : 'Enable';
              await repo.updateAlertStatus(alert.id, newStatus);
              if (mounted) _load();
            } catch (e) {
              if (mounted) {
                showAppErrorToast(
                  l10n.panelSettings_operationFailed,
                  description: e.toString(),
                );
              }
            }
          },
          onDelete: () async {
            final l10n = context.l10n;
            try {
              final repo = await ref.read(alertRepositoryProvider.future);
              await repo.deleteAlert(alert.id);
              if (mounted) {
                showAppSuccessToast(l10n.panelSettings_deleted);
                _load();
              }
            } catch (e) {
              if (mounted) {
                showAppErrorToast(
                  l10n.panelSettings_deleteFailed,
                  description: e.toString(),
                );
              }
            }
          },
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onToggle,
    required this.onDelete,
  });

  final AlertInfo alert;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.16),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    (alert.status == 'Enable'
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemGrey)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                TablerIcons.bell,
                size: 20,
                color: alert.status == 'Enable'
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title.isNotEmpty ? alert.title : alert.type,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.panelSettings_alertCardMeta(
                      alert.type,
                      alert.method,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ],
              ),
            ),
            AppToggleSwitch(
              value: alert.status == 'Enable',
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: onDelete,
              child: Icon(
                TablerIcons.trash,
                size: 18,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 告警日志 Tab
class _AlertLogTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AlertLogTab> createState() => _AlertLogTabState();
}

class _AlertLogTabState extends ConsumerState<_AlertLogTab> {
  List<AlertLogInfo> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = await ref.read(alertRepositoryProvider.future);
      final result = await repo.searchAlertLogs(
        const AlertLogSearchReq(page: 1, pageSize: 50),
      );
      if (!mounted) return;
      setState(() {
        _logs = result.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CupertinoActivityIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: CupertinoColors.systemRed.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
                onPressed: () async {
                  final l10n = context.l10n;
                  try {
                    final repo = await ref.read(alertRepositoryProvider.future);
                    await repo.cleanAlertLogs();
                    if (mounted) {
                      showAppSuccessToast(l10n.panelSettings_logsCleared);
                      _load();
                    }
                  } catch (e) {
                    if (mounted) {
                      showAppErrorToast(
                        l10n.panelSettings_clearFailed,
                        description: e.toString(),
                      );
                    }
                  }
                },
                child: Text(
                  context.l10n.panelSettings_clearLogs,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _logs.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.panelSettings_noLogs,
                    style: TextStyle(color: AppColors.secondaryLabel(context)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground(
                          context,
                        ).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.label(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                log.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      log.status == 'PushSuccess' ||
                                          log.status == 'Success'
                                      ? CupertinoColors.systemGreen
                                      : CupertinoColors.systemRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                log.createdAt ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.tertiaryLabel(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 告警设置 Tab
class _AlertSettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AppSectionHeader(
          title: context.l10n.panelSettings_notificationMethods,
          icon: TablerIcons.settings,
        ),
        AppActionGroup(
          children: [
            AppActionRow(
              icon: TablerIcons.mail,
              iconColor: CupertinoColors.systemBlue,
              title: context.l10n.panelSettings_emailNotification,
              subtitle: Text(context.l10n.panelSettings_smtpSubtitle),
              onTap: () =>
                  showAppTodoToast(context.l10n.panelSettings_emailTodo),
            ),
            AppActionRow(
              icon: TablerIcons.brand_wechat,
              iconColor: CupertinoColors.systemGreen,
              title: context.l10n.panelSettings_weCom,
              subtitle: Text(context.l10n.panelSettings_webhookSubtitle),
              onTap: () =>
                  showAppTodoToast(context.l10n.panelSettings_weComTodo),
            ),
            AppActionRow(
              icon: TablerIcons.brand_dingtalk,
              iconColor: CupertinoColors.systemBlue,
              title: context.l10n.panelSettings_dingTalk,
              subtitle: Text(context.l10n.panelSettings_webhookSubtitle),
              onTap: () =>
                  showAppTodoToast(context.l10n.panelSettings_dingTalkTodo),
            ),
            AppActionRow(
              icon: TablerIcons.brand_telegram,
              iconColor: CupertinoColors.systemTeal,
              title: context.l10n.panelSettings_feishu,
              subtitle: Text(context.l10n.panelSettings_webhookSubtitle),
              onTap: () =>
                  showAppTodoToast(context.l10n.panelSettings_feishuTodo),
            ),
            AppActionRow(
              icon: TablerIcons.bell_ringing,
              iconColor: CupertinoColors.systemOrange,
              title: 'Bark',
              subtitle: Text(context.l10n.panelSettings_webhookSubtitle),
              onTap: () =>
                  showAppTodoToast(context.l10n.panelSettings_barkTodo),
            ),
          ],
        ),
      ],
    );
  }
}
