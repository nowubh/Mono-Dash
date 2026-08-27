import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/app/app_store_config_dto.dart';
import '../../../../data/repositories_impl/app_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/frosted_scaffold.dart';

class AppSettingsTab extends ConsumerStatefulWidget {
  const AppSettingsTab({super.key});

  @override
  ConsumerState<AppSettingsTab> createState() => _AppSettingsTabState();
}

class _AppSettingsTabState extends ConsumerState<AppSettingsTab> {
  bool _loading = true;
  AppStoreConfigDto? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final config = await repo.getStoreConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppErrorToast(context.l10n.appStore_getConfigFailed('$e'));
      }
    }
  }

  Future<void> _updateConfig(String scope, bool enable) async {
    // Optimistic update
    final oldConfig = _config;
    if (_config == null) return;

    setState(() {
      _config = _patchConfig(scope, enable);
    });

    try {
      final repo = await ref.read(appRepositoryProvider.future);
      await repo.updateStoreConfig(scope: scope, enable: enable);
    } catch (e) {
      if (mounted) {
        setState(() => _config = oldConfig);
        showAppErrorToast(context.l10n.appStore_updateConfigFailed('$e'));
      }
    }
  }

  AppStoreConfigDto _patchConfig(String scope, bool enable) {
    if (_config == null) return _config!;
    return AppStoreConfigDto(
      uninstallDeleteImage: scope == 'UninstallDeleteImage'
          ? enable
          : _config!.uninstallDeleteImage,
      upgradeBackup: scope == 'UpgradeBackup' ? enable : _config!.upgradeBackup,
      uninstallDeleteBackup: scope == 'UninstallDeleteBackup'
          ? enable
          : _config!.uninstallDeleteBackup,
      installAllowPort: scope == 'InstallAllowPort'
          ? enable
          : _config!.installAllowPort,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverToBoxAdapter(
          child: SizedBox(
            height: FrostedScaffold.contentTopPadding(context) + 8,
          ),
        ),
        if (_loading && _config == null)
          const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection(
                  title: context.l10n.appStore_settingsUninstall,
                  items: [
                    _buildSettingItem(
                      label: context.l10n.appStore_settingsDeleteBackupLabel,
                      subtitle:
                          context.l10n.appStore_settingsDeleteBackupSubtitle,
                      value: _config?.uninstallDeleteBackup ?? false,
                      onChanged: (v) =>
                          _updateConfig('UninstallDeleteBackup', v),
                    ),
                    _buildSettingItem(
                      label: context.l10n.appStore_settingsDeleteImageLabel,
                      subtitle:
                          context.l10n.appStore_settingsDeleteImageSubtitle,
                      value: _config?.uninstallDeleteImage ?? false,
                      onChanged: (v) =>
                          _updateConfig('UninstallDeleteImage', v),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: context.l10n.appStore_settingsUpdate,
                  items: [
                    _buildSettingItem(
                      label: context.l10n.appStore_settingsUpgradeBackupLabel,
                      subtitle:
                          context.l10n.appStore_settingsUpgradeBackupSubtitle,
                      value: _config?.upgradeBackup ?? false,
                      onChanged: (v) => _updateConfig('UpgradeBackup', v),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: context.l10n.appStore_settingsInstall,
                  items: [
                    _buildSettingItem(
                      label: context.l10n.appStore_settingsInstallOpenPortLabel,
                      subtitle:
                          context.l10n.appStore_settingsInstallOpenPortSubtitle,
                      value: _config?.installAllowPort ?? false,
                      onChanged: (v) => _updateConfig('InstallAllowPort', v),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 100),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.separator(context).withValues(alpha: 0.1),
            ),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
