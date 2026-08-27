import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:re_editor/re_editor.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/app/app_installed_dto.dart';
import '../../../../data/dto/app/app_update_version_dto.dart';
import '../../../../data/repositories_impl/app_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/task_log_sheet.dart';

class AppUpgradeSheet extends ConsumerStatefulWidget {
  const AppUpgradeSheet({super.key, required this.app});

  final AppInstalledDto app;

  @override
  ConsumerState<AppUpgradeSheet> createState() => _AppUpgradeSheetState();
}

class _AppUpgradeSheetState extends ConsumerState<AppUpgradeSheet> {
  bool _loading = true;
  List<AppUpdateVersionDto> _versions = [];
  AppUpdateVersionDto? _selectedVersion;

  bool _backup = true;
  bool _pullImage = true;
  bool _customCompose = false;
  late final CodeLineEditingController _composeController;

  @override
  void initState() {
    super.initState();
    _composeController = CodeLineEditingController();
    _init();
  }

  @override
  void dispose() {
    _composeController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final l10n = context.l10n;
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final list = await repo.getUpdateVersions(widget.app.id);
      if (mounted) {
        setState(() {
          _versions = list;
          if (list.isNotEmpty) {
            _selectedVersion = list.first;
            _composeController.text = list.first.dockerCompose;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(l10n.appStore_loadVersionInfoFailed(e));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _onVersionChanged(AppUpdateVersionDto version) async {
    final l10n = context.l10n;
    setState(() {
      _selectedVersion = version;
      _loading = true;
    });

    try {
      final repo = await ref.read(appRepositoryProvider.future);
      // Fetch details for this specific version to get its dockerCompose
      final list = await repo.getUpdateVersions(
        widget.app.id,
        updateVersion: version.version,
      );
      if (mounted) {
        final detail = list.firstWhere((v) => v.version == version.version);
        setState(() {
          _composeController.text = detail.dockerCompose;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppErrorToast(l10n.appStore_getVersionDetailsFailed(e));
      }
    }
  }

  Future<void> _handleUpgrade() async {
    if (_selectedVersion == null) return;
    final l10n = context.l10n;

    final taskID = const Uuid().v4();
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      await repo.upgradeApp(
        installId: widget.app.id,
        detailId: _selectedVersion!.detailId,
        version: _selectedVersion!.version,
        dockerCompose: _composeController.text,
        taskID: taskID,
        backup: _backup,
        pullImage: _pullImage,
      );

      if (!mounted) return;
      final container = ProviderScope.containerOf(context);
      Navigator.pop(context);

      showTaskLogSheet(
        context,
        title: l10n.appStore_updateAppTaskTitle(widget.app.displayName),
        taskID: taskID,
        reader: (id) => container
            .read(appRepositoryProvider.future)
            .then((r) => r.readTaskLog(id)),
      );
    } catch (e) {
      showAppErrorToast(l10n.appStore_upgradeTaskFailed(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            Expanded(
              child: _loading && _versions.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : _buildContent(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.tertiaryLabel(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Row(
        children: [
          Icon(
            TablerIcons.arrow_up_circle,
            size: 22,
            color: CupertinoColors.systemGreen.resolveFrom(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.appStore_update,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.label(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Icon(TablerIcons.x, color: AppColors.tertiaryLabel(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildSectionTitle(context.l10n.appStore_targetVersion),
        const SizedBox(height: 12),
        AppInlinePicker<AppUpdateVersionDto>(
          backgroundColor: AppColors.secondaryBackground(
            context,
          ).withValues(alpha: 0.8),
          options: _versions
              .map((v) => AppPickerOption(label: v.version, value: v))
              .toList(),
          value: _selectedVersion!,
          onChanged: _onVersionChanged,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(context.l10n.appStore_upgradeOptions),
        const SizedBox(height: 12),
        _buildOptionItem(
          label: context.l10n.appStore_backupBeforeUpgrade,
          subtitle: context.l10n.appStore_backupBeforeUpgradeSubtitle,
          value: _backup,
          onChanged: (v) => setState(() => _backup = v),
        ),
        const SizedBox(height: 12),
        _buildOptionItem(
          label: context.l10n.appStore_pullImage,
          subtitle: context.l10n.appStore_pullImageSubtitle,
          value: _pullImage,
          onChanged: (v) => setState(() => _pullImage = v),
        ),
        const SizedBox(height: 12),
        _buildOptionItem(
          label: context.l10n.appStore_customCompose,
          subtitle: context.l10n.appStore_customComposeSubtitle,
          subtitleColor: CupertinoColors.systemOrange,
          value: _customCompose,
          onChanged: (v) => setState(() => _customCompose = v),
        ),
        if (_customCompose) ...[
          const SizedBox(height: 16),
          _buildComposeEditor(),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.label(context),
      ),
    );
  }

  Widget _buildOptionItem({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              AppToggleSwitch(value: value, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: subtitleColor ?? AppColors.tertiaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context.l10n.appStore_dockerComposeContent),
        const SizedBox(height: 12),
        Container(
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.separator(context).withValues(alpha: 0.2),
            ),
          ),
          child: AppCodeEditor(
            controller: _composeController,
            language: 'yaml',
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(
          top: BorderSide(
            color: AppColors.separator(context).withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(12),
              onPressed: _loading ? null : _handleUpgrade,
              child: _loading
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : Text(
                      context.l10n.appStore_upgradeNow,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

void showAppUpgradeSheet(BuildContext context, AppInstalledDto app) {
  showActionSheet(
    context: context,
    builder: (context) => AppUpgradeSheet(app: app),
  );
}
