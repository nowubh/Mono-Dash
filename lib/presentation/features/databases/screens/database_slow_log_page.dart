import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/database/database_instance_dto.dart';
import '../../../../data/repositories_impl/database_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../../common/components/frosted_action_button.dart';
import '../widgets/database_placeholders.dart';

/// 慢日志配置页面。
class DatabaseSlowLogPage extends ConsumerStatefulWidget {
  const DatabaseSlowLogPage({
    super.key,
    required this.dbType,
    required this.dbName,
  });

  final String dbType;
  final String dbName;

  @override
  ConsumerState<DatabaseSlowLogPage> createState() =>
      _DatabaseSlowLogPageState();
}

class _DatabaseSlowLogPageState extends ConsumerState<DatabaseSlowLogPage> {
  MysqlVariables? _variables;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _longQueryTimeController;
  bool _slowQueryLogEnabled = false;

  @override
  void initState() {
    super.initState();
    _longQueryTimeController = TextEditingController();
    _loadVariables();
  }

  @override
  void dispose() {
    _longQueryTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadVariables() async {
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      final vars = await repo.loadVariables(
        type: widget.dbType,
        name: widget.dbName,
      );
      if (!mounted) return;
      setState(() {
        _variables = vars;
        _slowQueryLogEnabled =
            vars.slowQueryLog?.toLowerCase() == 'on' ||
            vars.slowQueryLog == '1';
        _longQueryTimeController.text = vars.longQueryTime ?? '';
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

  Future<void> _save() async {
    final timeText = _longQueryTimeController.text.trim();
    final timeValue = double.tryParse(timeText);
    if (timeValue == null || timeValue < 0) {
      showAppWarningToast(context.l10n.databases_invalidSlowLogThreshold);
      return;
    }

    final currentLog =
        _variables?.slowQueryLog?.toLowerCase() == 'on' ||
        _variables?.slowQueryLog == '1';
    final currentTime = _variables?.longQueryTime ?? '';

    final variables = <Map<String, dynamic>>[];
    if (_slowQueryLogEnabled != currentLog) {
      variables.add({
        'param': 'slow_query_log',
        'value': _slowQueryLogEnabled ? 'ON' : 'OFF',
      });
    }
    if (timeText != currentTime) {
      variables.add({'param': 'long_query_time', 'value': timeText});
    }

    if (variables.isEmpty) {
      showAppWarningToast(context.l10n.databases_noChanges);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      await repo.updateVariables(
        type: widget.dbType,
        database: widget.dbName,
        variables: variables,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSuccessToast(context.l10n.databases_slowLogSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppErrorToast(context.l10n.databases_saveFailed, description: '$e');
    }
  }

  Future<void> _viewSlowLog() async {
    final l10n = context.l10n;
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      final result = await repo.readSlowLog(
        type: widget.dbType,
        name: widget.dbName,
      );
      if (!mounted) return;
      if (result.lines.isEmpty) {
        showAppWarningToast(l10n.databases_noSlowQueryRecords);
        return;
      }
      await showAppCodeEditorSheet(
        context,
        title: l10n.databases_slowQueryLog,
        subtitle: widget.dbName,
        initialContent: result.lines.join('\n'),
        language: 'sql',
        readOnly: true,
      );
    } catch (e) {
      showAppErrorToast(l10n.databases_readFailed, description: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      title: context.l10n.databases_slowLog,
      trailingBuilder: (isDark, isOverlapping) => FrostedActionButton(
        text: context.l10n.common_save,
        isDark: isDark,
        isOverlapping: isOverlapping,
        isLoading: _saving,
        onTap: _save,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return DatabaseErrorPlaceholder(
        error: _error!,
        iconColor: CupertinoColors.systemRed.resolveFrom(context),
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        FrostedScaffold.contentTopPadding(context) + 12,
        16,
        40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l10n.databases_slowQueryLog,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryLabel(context),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.separator(context).withValues(alpha: 0.14),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              _buildSwitchTile(),
              _buildDivider(context),
              _buildThresholdTile(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            context.l10n.databases_slowLogHint,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.tertiaryLabel(context),
              height: 1.4,
            ),
          ),
        ),
        if (_slowQueryLogEnabled) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              context.l10n.databases_logRecords,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryLabel(context),
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.separator(context).withValues(alpha: 0.14),
                width: 0.5,
              ),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _viewSlowLog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemTeal.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        TablerIcons.eye,
                        size: 18,
                        color: CupertinoColors.systemTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.databases_viewRecords,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.label(context),
                        ),
                      ),
                    ),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 18,
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSwitchTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.databases_enableSlowQueryLog,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.label(context),
              ),
            ),
          ),
          Text(
            _slowQueryLogEnabled
                ? context.l10n.databases_enabled
                : context.l10n.databases_disabled,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(width: 8),
          AppToggleSwitch(
            value: _slowQueryLogEnabled,
            onChanged: (v) => setState(() => _slowQueryLogEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        height: 0.5,
        color: AppColors.separator(context).withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildThresholdTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.databases_thresholdSeconds,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.databases_thresholdHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: CupertinoTextField(
              controller: _longQueryTimeController,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 16, color: AppColors.label(context)),
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              placeholder: '1.0',
              placeholderStyle: TextStyle(
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
