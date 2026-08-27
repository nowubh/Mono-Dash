import 'dart:async';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/database_repository_impl.dart';
import '../../../../data/repositories_impl/setting_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../providers/database_connection_info_provider.dart';
import 'database_type_icon.dart';

/// 显示数据库连接信息 Sheet。
Future<void> showDatabaseConnectionInfoSheet(
  BuildContext context, {
  required String dbType,
  required String dbName,
  required int dbId,
  required String dbFrom,
  required bool isRemote,
}) async {
  await showActionSheet<void>(
    context: context,
    builder: (_) => _DatabaseConnectionInfoSheet(
      dbType: dbType,
      dbName: dbName,
      dbId: dbId,
      dbFrom: dbFrom,
      isRemote: isRemote,
    ),
  );
}

class _DatabaseConnectionInfoSheet extends ConsumerStatefulWidget {
  const _DatabaseConnectionInfoSheet({
    required this.dbType,
    required this.dbName,
    required this.dbId,
    required this.dbFrom,
    required this.isRemote,
  });

  final String dbType;
  final String dbName;
  final int dbId;
  final String dbFrom;
  final bool isRemote;

  @override
  ConsumerState<_DatabaseConnectionInfoSheet> createState() =>
      _DatabaseConnectionInfoSheetState();
}

class _DatabaseConnectionInfoSheetState
    extends ConsumerState<_DatabaseConnectionInfoSheet> {
  ConnectionInfoState? _info;
  Object? _error;
  bool _loading = true;
  String? _copiedField;
  Timer? _copyTimer;
  bool _remoteAccessLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final dbRepo = await ref.read(databaseRepositoryProvider.future);

      if (widget.isRemote) {
        final raw = await dbRepo.getDatabase(widget.dbName);
        if (!mounted) return;
        setState(() {
          _info = ConnectionInfoState(
            isRemote: true,
            remoteAddress: (raw['address'] as String?) ?? '',
            remotePort: '${raw['port'] ?? ''}',
            remoteUsername: (raw['username'] as String?) ?? '',
            remotePassword: (raw['password'] as String?) ?? '',
          );
          _loading = false;
        });
        return;
      }

      // 本地：并行请求三个接口
      final settingRepo = await ref.read(settingRepositoryProvider.future);
      final isMysql =
          widget.dbType.contains('mysql') || widget.dbType.contains('mariadb');
      final results = await (
        dbRepo.getConnInfo(type: widget.dbType, name: widget.dbName),
        isMysql
            ? dbRepo.getRemoteAccess(type: widget.dbType, name: widget.dbName)
            : Future.value(false),
        settingRepo.getSystemIP(),
      ).wait;

      if (!mounted) return;
      final conninfo = results.$1;
      final systemIP = results.$3.isNotEmpty
          ? results.$3
          : settingRepo.getServerHost();
      setState(() {
        _info = ConnectionInfoState(
          isRemote: false,
          containerName: (conninfo['containerName'] as String?) ?? '',
          port:
              '${conninfo['port'] ?? (widget.dbType.contains('postgresql')
                      ? '5432'
                      : widget.dbType.contains('redis')
                      ? '6379'
                      : '3306')}',
          password: (conninfo['password'] as String?) ?? '',
          isRunning: conninfo['status'] == 'Running',
          systemIP: systemIP,
          remoteAccess: results.$2,
        );
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

  void _copy(String field, String value) {
    Clipboard.setData(ClipboardData(text: value));
    setState(() => _copiedField = field);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedField = null);
    });
  }

  Future<void> _toggleRemoteAccess(bool value) async {
    if (_info == null) return;
    final l10n = context.l10n;

    // 弹出确认框
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          value
              ? l10n.databases_enableRemoteAccess
              : l10n.databases_disableRemoteAccess,
        ),
        content: Text(
          value
              ? l10n.databases_enableRemoteAccessContent
              : l10n.databases_disableRemoteAccessContent,
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: !value,
            onPressed: () => Navigator.pop(context, true),
            child: Text(value ? l10n.databases_enable : l10n.databases_disable),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _remoteAccessLoading = true);
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      await repo.updateRemoteAccess(
        type: widget.dbType,
        database: widget.dbName, // 使用实例名
        remote: value,
      );

      if (mounted) {
        setState(() {
          _info = _info!.copyWith(remoteAccess: value);
          _remoteAccessLoading = false;
        });
        showAppSuccessToast(
          value
              ? l10n.databases_remoteAccessEnabled
              : l10n.databases_remoteAccessDisabled,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _remoteAccessLoading = false);
        showAppErrorToast(l10n.databases_operationFailed, description: '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      hasHorizontalPadding: true,
      contentPadding: EdgeInsets.zero,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
        child: Row(
          children: [
            DatabaseTypeIcon(type: widget.dbType, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.databases_connectionInfo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.l10n.common_done,
                style: TextStyle(
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            context.l10n.databases_loadFailedWithError(_error!),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
      );
    }
    final info = _info!;
    return info.isRemote ? _buildRemoteContent(info) : _buildLocalContent(info);
  }

  // ── 本地数据库 ──────────────────────────────────────────────

  Widget _buildLocalContent(ConnectionInfoState info) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.databases_containerConnection),
        _GroupedBox(
          children: [
            _ConnectionTile(
              label: context.l10n.databases_address,
              value: info.containerName,
              field: 'container',
              isCopied: _copiedField == 'container',
              onCopy: () => _copy('container', info.containerName),
            ),
            _ConnectionTile(
              label: context.l10n.databases_port,
              value: info.port.isEmpty ? '3306' : info.port,
              field: 'containerPort',
              isCopied: _copiedField == 'containerPort',
              onCopy: () => _copy(
                'containerPort',
                info.port.isEmpty ? '3306' : info.port,
              ),
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: context.l10n.databases_externalConnection),
        _GroupedBox(
          children: [
            _ConnectionTile(
              label: context.l10n.databases_address,
              value: info.systemIP.isEmpty ? '-' : info.systemIP,
              field: 'host',
              isCopied: _copiedField == 'host',
              onCopy: info.systemIP.isNotEmpty
                  ? () => _copy('host', info.systemIP)
                  : null,
            ),
            _ConnectionTile(
              label: context.l10n.databases_port,
              value: info.port.isEmpty ? '3306' : info.port,
              field: 'port',
              isCopied: _copiedField == 'port',
              onCopy: () =>
                  _copy('port', info.port.isEmpty ? '3306' : info.port),
              isLast: true,
            ),
          ],
        ),
        // 仅 MySQL/MariaDB 显示访问权限开关
        if (widget.dbType.contains('mysql') ||
            widget.dbType.contains('mariadb')) ...[
          const SizedBox(height: 24),
          _SectionHeader(title: context.l10n.databases_accessPermissions),
          _GroupedBox(children: [_buildRemoteAccessTile(info)]),
        ],
        const SizedBox(height: 24),
        _SectionHeader(title: context.l10n.databases_adminCredentials),
        _GroupedBox(
          children: [
            _ConnectionTile(
              label: context.l10n.databases_username,
              value: 'root',
              field: 'rootUser',
              isCopied: _copiedField == 'rootUser',
              onCopy: () => _copy('rootUser', 'root'),
            ),
            _ConnectionTile(
              label: context.l10n.databases_password,
              value: info.password,
              field: 'rootPassword',
              isCopied: _copiedField == 'rootPassword',
              onCopy: info.password.isNotEmpty
                  ? () => _copy('rootPassword', info.password)
                  : null,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRemoteAccessTile(ConnectionInfoState info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.databases_remoteAccess,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.label(context),
              ),
            ),
          ),
          if (_remoteAccessLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: CupertinoActivityIndicator(radius: 8),
            ),
          Text(
            info.remoteAccess
                ? context.l10n.databases_enabled
                : context.l10n.databases_disabled,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(width: 8),
          AppToggleSwitch(
            value: info.remoteAccess,
            onChanged: (info.isRunning && !_remoteAccessLoading)
                ? _toggleRemoteAccess
                : null,
          ),
        ],
      ),
    );
  }

  // ── 远程数据库 ──────────────────────────────────────────────

  Widget _buildRemoteContent(ConnectionInfoState info) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.databases_connectionAddress),
        _GroupedBox(
          children: [
            _ConnectionTile(
              label: context.l10n.databases_address,
              value: info.remoteAddress.isEmpty ? '-' : info.remoteAddress,
              field: 'remoteAddr',
              isCopied: _copiedField == 'remoteAddr',
              onCopy: info.remoteAddress.isNotEmpty
                  ? () => _copy('remoteAddr', info.remoteAddress)
                  : null,
            ),
            _ConnectionTile(
              label: context.l10n.databases_port,
              value: info.remotePort.isEmpty ? '-' : info.remotePort,
              field: 'remotePort',
              isCopied: _copiedField == 'remotePort',
              onCopy: info.remotePort.isNotEmpty
                  ? () => _copy('remotePort', info.remotePort)
                  : null,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: context.l10n.databases_authentication),
        _GroupedBox(
          children: [
            _ConnectionTile(
              label: context.l10n.databases_username,
              value: info.remoteUsername.isEmpty ? '-' : info.remoteUsername,
              field: 'remoteUser',
              isCopied: _copiedField == 'remoteUser',
              onCopy: info.remoteUsername.isNotEmpty
                  ? () => _copy('remoteUser', info.remoteUsername)
                  : null,
            ),
            _ConnectionTile(
              label: context.l10n.databases_password,
              value: info.remotePassword.isEmpty ? '-' : info.remotePassword,
              field: 'remotePass',
              isCopied: _copiedField == 'remotePass',
              onCopy: info.remotePassword.isNotEmpty
                  ? () => _copy('remotePass', info.remotePassword)
                  : null,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── 通用组件 ────────────────────────────────────────────────
}

/// Apple 风格的分组区块头部
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.secondaryLabel(context),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Apple 风格的分组容器
class _GroupedBox extends StatelessWidget {
  const _GroupedBox({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.14),
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }
}

/// Apple 风格的信息条目
class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.label,
    required this.value,
    required this.field,
    required this.isCopied,
    this.onCopy,
    this.isLast = false,
  });

  final String label;
  final String value;
  final String field;
  final bool isCopied;
  final VoidCallback? onCopy;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.label(context),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value.isEmpty ? '-' : value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.secondaryLabel(context),
                    letterSpacing: field.contains('Pass') ? 1.0 : 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(12),
                onPressed: onCopy,
                child: Icon(
                  isCopied ? TablerIcons.check : TablerIcons.copy,
                  size: 16,
                  color: isCopied
                      ? CupertinoColors.activeGreen
                      : AppColors.tertiaryLabel(context),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 0.5,
              color: AppColors.separator(context).withValues(alpha: 0.1),
            ),
          ),
      ],
    );
  }
}
