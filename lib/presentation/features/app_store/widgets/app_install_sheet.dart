import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:re_editor/re_editor.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/app/app_install_config_dto.dart';
import '../../../../data/dto/app/app_install_req.dart';
import '../../../../data/dto/app/app_store_config_dto.dart';
import '../../../../data/dto/container/container_limit_dto.dart';
import '../../../../data/repositories_impl/app_repository_impl.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/task_log_sheet.dart';

/// 显示应用安装配置 BottomSheet (全屏)
Future<void> showAppInstallSheet({
  required BuildContext context,
  required int serverId,
  required int appId,
  required String appKey,
  required String appName,
  required String version,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (context) => _AppInstallSheet(
      appId: appId,
      appKey: appKey,
      appName: appName,
      version: version,
    ),
  );
}

class _AppInstallSheet extends ConsumerStatefulWidget {
  const _AppInstallSheet({
    required this.appId,
    required this.appKey,
    required this.appName,
    required this.version,
  });

  final int appId;
  final String appKey;
  final String appName;
  final String version;

  @override
  ConsumerState<_AppInstallSheet> createState() => _AppInstallSheetState();
}

class _AppInstallSheetState extends ConsumerState<_AppInstallSheet> {
  bool _loading = true;
  Object? _error;

  AppInstallConfigDto? _config;
  ContainerLimitDto? _systemLimit;

  // Form states
  late final TextEditingController _nameController;
  final Map<String, TextEditingController> _paramControllers = {};

  // Advanced settings
  final bool _advanced = true;
  late final TextEditingController _containerNameController;
  bool _allowPort = false;
  String _restartPolicy = 'always';
  late final TextEditingController _cpuController;
  late final TextEditingController _memoryController;
  bool _pullImage = true;
  bool _editCompose = false;
  late final CodeLineEditingController _composeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appKey);
    _containerNameController = TextEditingController();
    _cpuController = TextEditingController(text: '0');
    _memoryController = TextEditingController(text: '0');
    _composeController = CodeLineEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _containerNameController.dispose();
    _cpuController.dispose();
    _memoryController.dispose();
    _composeController.dispose();
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final appRepo = await ref.read(appRepositoryProvider.future);
      final containerRepo = await ref.read(containerRepositoryProvider.future);

      final results = await Future.wait([
        appRepo.getAppInstallConfig(widget.appId, widget.version),
        containerRepo.getContainerLimit(),
        appRepo.getStoreConfig(),
      ]);

      if (mounted) {
        setState(() {
          _config = results[0] as AppInstallConfigDto;
          _systemLimit = results[1] as ContainerLimitDto;
          final storeConfig = results[2] as AppStoreConfigDto;

          _allowPort = storeConfig.installAllowPort;

          // Init controllers from config
          for (final field in _config!.params.formFields) {
            _paramControllers[field.envKey] = TextEditingController(
              text: field.defaultValue?.toString() ?? '',
            );
          }
          _composeController.text = _config!.dockerCompose;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _install() async {
    final l10n = context.l10n;
    if (_nameController.text.isEmpty) {
      showAppErrorToast(l10n.appStore_nameRequired);
      return;
    }
    // 资源限制校验
    final cpuInput = double.tryParse(_cpuController.text) ?? 0;
    final memInput = double.tryParse(_memoryController.text) ?? 0;

    if (_systemLimit != null) {
      if (cpuInput > 0 && cpuInput > _systemLimit!.cpu) {
        showAppErrorToast(l10n.appStore_cpuLimitExceeded(_systemLimit!.cpu));
        return;
      }
      final maxMemMb = (_systemLimit!.memory / 1024 / 1024).floor();
      if (memInput > 0 && memInput > maxMemMb) {
        showAppErrorToast(l10n.appStore_memoryLimitExceeded(maxMemMb));
        return;
      }
    }

    final taskID = const Uuid().v4();
    final params = <String, dynamic>{};
    for (final entry in _paramControllers.entries) {
      final field = _config!.params.formFields.firstWhere(
        (f) => f.envKey == entry.key,
      );
      if (field.type == 'number') {
        params[entry.key] =
            num.tryParse(entry.value.text) ?? field.defaultValue;
      } else {
        params[entry.key] = entry.value.text;
      }
    }

    final req = AppInstallReq(
      appDetailId: _config!.id,
      params: params,
      name: _nameController.text,
      version: widget.version,
      taskID: taskID,
      advanced: _advanced,
      containerName: _containerNameController.text,
      allowPort: _allowPort,
      restartPolicy: _restartPolicy,
      cpuQuota: int.tryParse(_cpuController.text) ?? 0,
      memoryLimit: int.tryParse(_memoryController.text) ?? 0,
      memoryUnit: 'M',
      pullImage: _pullImage,
      editCompose: _editCompose,
      dockerCompose: _composeController.text,
    );

    try {
      final repo = await ref.read(appRepositoryProvider.future);
      await repo.installApp(req);
      if (mounted) {
        Navigator.pop(context);
        showTaskLogSheet(
          context,
          title: l10n.appStore_installingApp(widget.appName),
          taskID: taskID,
          reader: repo.readTaskLog,
        );
      }
    } catch (e) {
      showAppErrorToast(l10n.appStore_installRequestFailed(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.9,
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _error != null
                    ? _buildError()
                    : _buildForm(),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.l10n.common_cancel,
              style: TextStyle(
                color: AppColors.secondaryLabel(context),
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.l10n.appStore_installApp,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.label(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _loading || _error != null ? null : _install,
            child: Text(
              context.l10n.appStore_install,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return AppErrorState(
      title: context.l10n.appStore_loadInstallConfigFailed,
      error: _error ?? context.l10n.common_unknown,
      onRetry: _load,
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        _buildSectionTitle(
          context.l10n.appStore_basicSettings,
          TablerIcons.settings,
        ),
        const SizedBox(height: 12),
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
          child: Column(
            children: [
              _InputItem(
                label: context.l10n.appStore_name,
                controller: _nameController,
                placeholder: context.l10n.appStore_appRunNamePlaceholder,
              ),
              for (final field in _config!.params.formFields) ...[
                const _CardDivider(),
                _InputItem(
                  label: _installFieldLabel(context, field),
                  controller: _paramControllers[field.envKey]!,
                  enabled: field.edit,
                  keyboardType: field.type == 'number'
                      ? TextInputType.number
                      : TextInputType.text,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildAdvancedSection(),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection() {
    final maxCpu = _systemLimit?.cpu ?? 1;
    final maxMemMb = ((_systemLimit?.memory ?? 0) / 1024 / 1024).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.appStore_advancedSettings,
          TablerIcons.adjustments,
        ),
        const SizedBox(height: 12),
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
          child: Column(
            children: [
              _InputItem(
                label: context.l10n.appStore_containerName,
                controller: _containerNameController,
                placeholder: context.l10n.appStore_autoGeneratedPlaceholder,
              ),
              const _CardDivider(),
              _OptionItem(
                label: context.l10n.appStore_externalPortAccess,
                subtitle: context.l10n.appStore_externalPortAccessSubtitle,
                value: _allowPort,
                onChanged: (v) => setState(() => _allowPort = v),
              ),
              const _CardDivider(),
              _RestartPolicyItem(
                value: _restartPolicy,
                onChanged: (v) => setState(() => _restartPolicy = v),
              ),
              const _CardDivider(),
              _InputItem(
                label: context.l10n.appStore_cpuLimit,
                controller: _cpuController,
                keyboardType: TextInputType.number,
                trailing: Text(
                  context.l10n.appStore_cpuMaxUnit(maxCpu),
                  style: TextStyle(
                    color: AppColors.tertiaryLabel(context),
                    fontSize: 12,
                  ),
                ),
              ),
              const _CardDivider(),
              _InputItem(
                label: context.l10n.appStore_memoryLimit,
                controller: _memoryController,
                keyboardType: TextInputType.number,
                trailing: Text(
                  context.l10n.appStore_memoryMaxUnit(maxMemMb),
                  style: TextStyle(
                    color: AppColors.tertiaryLabel(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          context.l10n.appStore_imageCompose,
          TablerIcons.brand_docker,
        ),
        const SizedBox(height: 12),
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
          child: Column(
            children: [
              _OptionItem(
                label: context.l10n.appStore_pullImage,
                subtitle: context.l10n.appStore_pullImageSubtitle,
                value: _pullImage,
                onChanged: (v) => setState(() => _pullImage = v),
              ),
              const _CardDivider(),
              _OptionItem(
                label: context.l10n.appStore_editCompose,
                subtitle: context.l10n.appStore_editComposeSubtitle,
                value: _editCompose,
                onChanged: (v) => setState(() => _editCompose = v),
              ),
              if (_editCompose) ...[
                const _CardDivider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    height: 300,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.separator(
                          context,
                        ).withValues(alpha: 0.2),
                      ),
                    ),
                    child: AppCodeEditor(
                      controller: _composeController,
                      language: 'yaml',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _InputItem extends StatelessWidget {
  const _InputItem({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.placeholder,
    this.keyboardType,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? placeholder;
  final TextInputType? keyboardType;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.label(context),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              enabled: enabled,
              placeholder: placeholder,
              keyboardType: keyboardType,
              placeholderStyle: TextStyle(
                color: AppColors.tertiaryLabel(context),
                fontSize: 15,
              ),
              style: TextStyle(
                color: enabled
                    ? AppColors.label(context)
                    : AppColors.secondaryLabel(context),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: null,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  const _OptionItem({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AppToggleSwitch(value: value, onChanged: onChanged),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.tertiaryLabel(context),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RestartPolicyItem extends StatelessWidget {
  const _RestartPolicyItem({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.appStore_restartPolicy,
            style: TextStyle(
              color: AppColors.label(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          AppInlinePicker<String>(
            backgroundColor: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.8),
            options: [
              AppPickerOption(
                label: context.l10n.appStore_restartAlways,
                value: 'always',
              ),
              AppPickerOption(
                label: context.l10n.appStore_restartNo,
                value: 'no',
              ),
              AppPickerOption(
                label: context.l10n.appStore_restartOnFailure,
                value: 'on-failure',
              ),
              AppPickerOption(
                label: context.l10n.appStore_restartUnlessStopped,
                value: 'unless-stopped',
              ),
            ],
            value: value,
            onChanged: onChanged,
          ),
          if (value == 'on-failure') ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.appStore_restartOnFailureHint,
              style: TextStyle(
                color: AppColors.tertiaryLabel(context),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _installFieldLabel(BuildContext context, AppInstallFieldDto field) {
  final useChinese = context.l10n.localeName.toLowerCase().startsWith('zh');
  if (useChinese) {
    return field.labelZh.isNotEmpty ? field.labelZh : field.labelEn;
  }
  return field.labelEn.isNotEmpty ? field.labelEn : field.labelZh;
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        height: 0.5,
        color: AppColors.separator(context).withValues(alpha: 0.12),
      ),
    );
  }
}
