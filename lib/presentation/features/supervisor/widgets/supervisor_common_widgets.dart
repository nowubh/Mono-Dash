import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/host_tool/supervisor_dto.dart';

class SupervisorProcessCard extends StatelessWidget {
  const SupervisorProcessCard({
    super.key,
    required this.process,
    required this.onTap,
    required this.onPrimaryOperate,
    required this.onDirectoryTap,
    required this.onPidTap,
  });

  final SupervisorProcessConfig process;
  final VoidCallback onTap;
  final VoidCallback onPrimaryOperate;
  final ValueChanged<String> onDirectoryTap;
  final void Function(int pid, SupervisorProcessStatus status) onPidTap;

  @override
  Widget build(BuildContext context) {
    final state = supervisorGroupState(process.status);
    final color = supervisorStateColor(state).resolveFrom(context);
    final label = supervisorStateLabel(context, state);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    process.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                process.hasLoad
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(64, 30),
                        onPressed: onPrimaryOperate,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      )
                    : const CupertinoActivityIndicator(),
              ],
            ),
            const SizedBox(height: 10),
            _CommandLine(command: process.command),
            const SizedBox(height: 8),
            _MetaLine(process: process),
            if (process.dir.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DirectoryLine(
                path: process.dir,
                onTap: () => onDirectoryTap(process.dir),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommandLine extends StatelessWidget {
  const _CommandLine({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            TablerIcons.terminal_2,
            size: 15,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            command,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.32,
              color: AppColors.label(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.process});

  final SupervisorProcessConfig process;

  @override
  Widget build(BuildContext context) {
    final user = process.user.trim().isEmpty
        ? context.l10n.common_unknown
        : process.user.trim();
    final pid = _pidSummary(process);
    final text = [user, _statusSummary(context, process), ?pid].join(' · ');
    return Row(
      children: [
        Icon(
          TablerIcons.info_circle,
          size: 14,
          color: AppColors.tertiaryLabel(context),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
      ],
    );
  }

  String _statusSummary(BuildContext context, SupervisorProcessConfig process) {
    if (!process.hasLoad) return context.l10n.common_loading;
    final statuses = process.status;
    if (statuses.isEmpty) {
      return supervisorStateLabel(context, SupervisorGroupState.stopped);
    }
    final running = statuses.where((item) => item.status == 'RUNNING').length;
    final other = statuses.length - running;
    if (other == 0) {
      return '$running ${context.l10n.supervisor_statusRunning}';
    }
    if (running == 0) {
      return '$other ${context.l10n.supervisor_statusStopped}';
    }
    return '$running ${context.l10n.supervisor_statusRunning} · $other ${context.l10n.supervisor_statusStopped}';
  }

  String? _pidSummary(SupervisorProcessConfig process) {
    final pids = process.status
        .map((item) => item.pid.trim())
        .where((pid) => pid.isNotEmpty)
        .toList(growable: false);
    if (pids.isEmpty) return null;
    if (pids.length == 1) return 'PID ${pids.first}';
    if (pids.length == 2) return 'PID ${pids.join(', ')}';
    return 'PID ${pids.take(2).join(', ')} +${pids.length - 2}';
  }
}

class _DirectoryLine extends StatelessWidget {
  const _DirectoryLine({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 22),
      alignment: Alignment.centerLeft,
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            CupertinoIcons.folder,
            size: 14,
            color: CupertinoColors.systemOrange.resolveFrom(context),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_right,
            size: 11,
            color: AppColors.tertiaryLabel(context),
          ),
        ],
      ),
    );
  }
}

class SupervisorSwitchTile extends StatelessWidget {
  const SupervisorSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context),
        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 2),
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

class SupervisorNoticeCard extends StatelessWidget {
  const SupervisorNoticeCard({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolved.withValues(alpha: 0.18), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: resolved),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.35, color: resolved),
            ),
          ),
        ],
      ),
    );
  }
}

String supervisorOperateLabel(BuildContext context, String operate) {
  return switch (operate) {
    'start' => context.l10n.supervisor_start,
    'stop' => context.l10n.supervisor_stop,
    'restart' => context.l10n.supervisor_restart,
    'delete' => context.l10n.common_delete,
    _ => operate,
  };
}

IconData supervisorOperateIcon(String operate) {
  return switch (operate) {
    'start' => TablerIcons.player_play,
    'stop' => TablerIcons.player_stop,
    'restart' => TablerIcons.refresh,
    'delete' => TablerIcons.trash,
    _ => TablerIcons.tool,
  };
}

Color supervisorOperateColor(String operate) {
  return switch (operate) {
    'start' => CupertinoColors.systemGreen,
    'stop' => CupertinoColors.systemRed,
    'restart' => CupertinoColors.systemOrange,
    'delete' => CupertinoColors.destructiveRed,
    _ => CupertinoColors.activeBlue,
  };
}

String supervisorStateLabel(BuildContext context, SupervisorGroupState state) {
  return switch (state) {
    SupervisorGroupState.starting => context.l10n.supervisor_statusStarting,
    SupervisorGroupState.running => context.l10n.supervisor_statusRunning,
    SupervisorGroupState.warning => context.l10n.supervisor_statusWarning,
    SupervisorGroupState.stopped => context.l10n.supervisor_statusStopped,
  };
}

CupertinoDynamicColor supervisorStateColor(SupervisorGroupState state) {
  return switch (state) {
    SupervisorGroupState.starting => CupertinoColors.systemOrange,
    SupervisorGroupState.running => CupertinoColors.systemGreen,
    SupervisorGroupState.warning => CupertinoColors.systemYellow,
    SupervisorGroupState.stopped => CupertinoColors.systemGrey,
  };
}
