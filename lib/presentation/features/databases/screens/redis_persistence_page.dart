import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/database_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/frosted_header.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../widgets/database_placeholders.dart';
import '../widgets/settings_components.dart';

/// Redis 持久化配置页面（AOF + RDB 分区，各自独立保存）。
class RedisPersistencePage extends ConsumerStatefulWidget {
  const RedisPersistencePage({
    super.key,
    required this.dbType,
    required this.dbName,
  });

  final String dbType;
  final String dbName;

  @override
  ConsumerState<RedisPersistencePage> createState() =>
      _RedisPersistencePageState();
}

class _RedisPersistencePageState extends ConsumerState<RedisPersistencePage> {
  // AOF state.
  String _appendonly = 'no';
  String _appendfsync = 'everysec';
  bool _aofSaving = false;

  // RDB state.
  List<_SaveRule> _saveRules = [];
  bool _rdbSaving = false;

  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPersistence();
  }

  Future<void> _loadPersistence() async {
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      final conf = await repo.getRedisPersistence(
        type: widget.dbType,
        name: widget.dbName,
      );
      if (!mounted) return;
      setState(() {
        _appendonly = conf.aofEnabled;
        _appendfsync = conf.appendfsync;
        _saveRules = _parseSaveRules(conf.save);
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

  /// Parses Redis' whitespace-separated save string into rules.
  /// Input `"3600 1 300 100 60 10000"` -> [{second:3600, count:1}, ...]
  List<_SaveRule> _parseSaveRules(String save) {
    if (save.trim().isEmpty) return [];
    final parts = save.trim().split(RegExp(r'\s+'));
    final rules = <_SaveRule>[];
    for (var i = 0; i + 1 < parts.length; i += 2) {
      rules.add(_SaveRule(second: parts[i], count: parts[i + 1]));
    }
    return rules;
  }

  /// Serializes rules into the comma-separated save string expected by the API.
  /// [{second:"3600", count:"1"}, ...] -> `"3600 1,300 100"`
  String _serializeSaveRules() {
    return _saveRules.map((r) => '${r.second.text} ${r.count.text}').join(',');
  }

  Future<void> _saveAof() async {
    setState(() => _aofSaving = true);
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      await repo.updateRedisAofPersistence(
        dbType: widget.dbType,
        database: widget.dbName,
        appendonly: _appendonly,
        appendfsync: _appendfsync,
      );
      if (!mounted) return;
      setState(() => _aofSaving = false);
      showAppSuccessToast(context.l10n.databases_aofConfigSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aofSaving = false);
      showAppErrorToast(context.l10n.databases_saveFailed, description: '$e');
    }
  }

  Future<void> _saveRdb() async {
    for (final r in _saveRules) {
      final s = int.tryParse(r.second.text);
      final c = int.tryParse(r.count.text);
      if (s == null || s < 0 || s > 100000) {
        showAppWarningToast(context.l10n.databases_secondsRange);
        return;
      }
      if (c == null || c < 0 || c > 100000) {
        showAppWarningToast(context.l10n.databases_countRange);
        return;
      }
    }

    setState(() => _rdbSaving = true);
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      await repo.updateRedisRdbPersistence(
        dbType: widget.dbType,
        database: widget.dbName,
        save: _serializeSaveRules(),
      );
      if (!mounted) return;
      setState(() => _rdbSaving = false);
      showAppSuccessToast(context.l10n.databases_rdbConfigSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _rdbSaving = false);
      showAppErrorToast(context.l10n.databases_saveFailed, description: '$e');
    }
  }

  void _addRule() {
    setState(() {
      _saveRules.add(_SaveRule(second: '300', count: '100'));
    });
  }

  void _removeRule(int index) {
    setState(() {
      _saveRules[index].dispose();
      _saveRules.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (final r in _saveRules) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      title: context.l10n.databases_persistenceConfig,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        child: DatabaseErrorPlaceholder(
          error: _error!,
          iconColor: CupertinoColors.systemRed
              .resolveFrom(context)
              .withValues(alpha: 0.5),
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height:
                FrostedHeader.headerHeight +
                MediaQuery.paddingOf(context).top +
                8,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAofSection(),
                const SizedBox(height: 24),
                _buildRdbSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAofSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SettingsSectionHeader(title: context.l10n.databases_aofPersistence),
            const Spacer(),
            _SaveButton(loading: _aofSaving, onTap: _saveAof),
          ],
        ),
        SettingsGroupedBox(
          margin: EdgeInsets.zero,
          dividerLeftPadding: 60,
          children: [
            _SwitchRow(
              icon: TablerIcons.power,
              iconColor: CupertinoColors.systemGreen,
              label: context.l10n.databases_enableAof,
              value: _appendonly == 'yes',
              onChanged: (v) => setState(() => _appendonly = v ? 'yes' : 'no'),
            ),
            _PickerRow(
              icon: TablerIcons.refresh_dot,
              iconColor: CupertinoColors.systemBlue,
              label: context.l10n.databases_fsyncPolicy,
              value: _appendfsync,
              options: const [
                AppPickerOption(value: 'always', label: 'always'),
                AppPickerOption(value: 'everysec', label: 'everysec'),
                AppPickerOption(value: 'no', label: 'no'),
              ],
              onChanged: (v) => setState(() => _appendfsync = v),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            context.l10n.databases_aofHint,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRdbSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SettingsSectionHeader(title: context.l10n.databases_rdbSnapshot),
            const Spacer(),
            _SaveButton(loading: _rdbSaving, onTap: _saveRdb),
          ],
        ),
        SettingsGroupedBox(
          margin: EdgeInsets.zero,
          dividerLeftPadding: 60,
          children: [
            if (_saveRules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        TablerIcons.database_off,
                        size: 32,
                        color: AppColors.tertiaryLabel(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.databases_noRdbRules,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (var i = 0; i < _saveRules.length; i++) _buildRuleTile(i),

            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addRule,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.plus,
                      size: 16,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.databases_addSnapshotRule,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            context.l10n.databases_rdbHint,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleTile(int index) {
    final rule = _saveRules[index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              TablerIcons.clock_record,
              size: 16,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(width: 12),
          _NumberInput(
            controller: rule.second,
            placeholder: context.l10n.databases_secondsPlaceholder,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.databases_withinSeconds,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          _NumberInput(
            controller: rule.count,
            placeholder: context.l10n.databases_countPlaceholder,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.databases_changeTimes,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => _removeRule(index),
            child: Icon(
              TablerIcons.x,
              size: 16,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveRule {
  _SaveRule({required String second, required String count})
    : second = TextEditingController(text: second),
      count = TextEditingController(text: count);

  final TextEditingController second;
  final TextEditingController count;

  void dispose() {
    second.dispose();
    count.dispose();
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.label(context),
              ),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final List<AppPickerOption<String>> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 38,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.label(context),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: AppInlinePicker<String>(
              options: options,
              value: value,
              onChanged: onChanged,
              anchorHeight: 38,
              itemHeight: 36,
              maxVisibleItems: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({required this.controller, required this.placeholder});

  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: CupertinoTextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: AppColors.label(context),
          fontWeight: FontWeight.w600,
        ),
        decoration: BoxDecoration(
          color: AppColors.tertiaryBackground(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        placeholder: placeholder,
        placeholderStyle: TextStyle(
          fontSize: 14,
          color: AppColors.tertiaryLabel(context),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onPressed: loading ? null : onTap,
      child: loading
          ? const CupertinoActivityIndicator(radius: 8)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue
                    .resolveFrom(context)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.common_save,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
              ),
            ),
    );
  }
}
