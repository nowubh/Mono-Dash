import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:re_editor/re_editor.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../../data/repositories_impl/setting_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/task_log_sheet.dart';
import '../../../common/components/thin_divider.dart';
import '../providers/container_compose_provider.dart';

/// 显示创建容器编排 BottomSheet (全屏)
void showComposeCreateSheet(BuildContext context) {
  showActionSheet<void>(
    context: context,
    expand: true,
    useRootNavigator: true,
    builder: (context) => const _ComposeCreateSheet(),
  );
}

class _ComposeCreateSheet extends ConsumerStatefulWidget {
  const _ComposeCreateSheet();

  @override
  ConsumerState<_ComposeCreateSheet> createState() =>
      _ComposeCreateSheetState();
}

class _ComposeCreateSheetState extends ConsumerState<_ComposeCreateSheet> {
  final _nameController = TextEditingController();
  late final CodeLineEditingController _composeController;
  final List<TextEditingController> _envKeyControllers = [];
  final List<TextEditingController> _envValueControllers = [];
  bool _forcePull = false;
  String _baseDir = '/opt/1panel';

  @override
  void initState() {
    super.initState();
    _composeController = CodeLineEditingController();
    _loadBaseDir();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _composeController.dispose();
    for (final c in _envKeyControllers) {
      c.dispose();
    }
    for (final c in _envValueControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBaseDir() async {
    try {
      final repo = await ref.read(settingRepositoryProvider.future);
      final dir = await repo.getBaseDir();
      if (mounted) {
        setState(() => _baseDir = dir);
      }
    } catch (e) {
      // Use default
    }
  }

  void _addEnv() {
    setState(() {
      _envKeyControllers.add(TextEditingController());
      _envValueControllers.add(TextEditingController());
    });
  }

  void _removeEnv(int index) {
    setState(() {
      _envKeyControllers[index].dispose();
      _envValueControllers[index].dispose();
      _envKeyControllers.removeAt(index);
      _envValueControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppErrorToast(context.l10n.containers_nameRequired);
      return;
    }

    final composeContent = _composeController.text;
    if (composeContent.trim().isEmpty) {
      showAppErrorToast(context.l10n.containers_composeContentRequired);
      return;
    }

    final envs = <String>[];
    for (var i = 0; i < _envKeyControllers.length; i++) {
      final key = _envKeyControllers[i].text.trim();
      final val = _envValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        envs.add('$key=$val');
      }
    }

    final taskID = const Uuid().v4();
    final envStr = envs.join('\n');
    final validationFailedText =
        context.l10n.containers_composeValidationFailed;
    final creatingTaskTitle = context.l10n.containers_creatingComposeTask(name);
    final retryFailedText = context.l10n.containers_retryFailed;
    final operationFailedText = context.l10n.containers_operationFailed;
    Future<void> performSubmit(Map<String, dynamic> requestData) async {
      final repo = await ref.read(containerRepositoryProvider.future);
      final testResult = await repo.testCompose(requestData);
      if (testResult != true) {
        throw ApiBusinessException(400, validationFailedText);
      }

      if (!mounted) return;
      await repo.createCompose(requestData);

      if (mounted) {
        Navigator.pop(context);
        showTaskLogSheet(
          context,
          title: creatingTaskTitle,
          taskID: taskID,
          reader: repo.readTaskLog,
        );
        ref.read(containerComposeControllerProvider.notifier).refresh();
      }
    }

    // Default payload (Newer version: env is string)
    final baseData = {
      'taskID': taskID,
      'name': name,
      'from': 'edit',
      'path': '',
      'file': composeContent,
      'template': null,
      'env': envStr,
      'envStr': envStr,
      'envFileContent': "env_file:\n  - 1panel.env",
      'forcePull': _forcePull,
    };

    try {
      await performSubmit(baseData);
    } catch (e) {
      // If failed with unmarshal error (string -> []string), it's likely an older v2.0.0 server.
      // Retry with List format.
      final errorMessage = e.toString();
      if (errorMessage.contains('cannot unmarshal string') &&
          errorMessage.contains('ComposeCreate.env') &&
          errorMessage.contains('[]string')) {
        try {
          final legacyData = Map<String, dynamic>.from(baseData);
          legacyData['env'] = envs; // Change to List for old versions
          await performSubmit(legacyData);
          return;
        } catch (retryError) {
          showAppErrorToast(retryFailedText, description: '$retryError');
          return;
        }
      }

      showAppErrorToast(operationFailedText, description: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            Expanded(child: _buildForm()),
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
              context.l10n.containers_newCompose,
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
            onPressed: _submit,
            child: Text(
              context.l10n.common_create,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final pathPreview = '$_baseDir/docker/compose/${_nameController.text}';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        _buildSectionTitle(
          context.l10n.containers_basicInfo,
          TablerIcons.info_circle,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoTextField(
                controller: _nameController,
                placeholder:
                    context.l10n.containers_folderNameRequiredPlaceholder,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: null,
                style: TextStyle(color: AppColors.label(context), fontSize: 15),
                onChanged: (_) => setState(() {}),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: ThinDivider(),
              ),
              Text(
                context.l10n.containers_savePathLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryLabel(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pathPreview,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          context.l10n.containers_composeConfig,
          TablerIcons.file_code,
        ),
        const SizedBox(height: 12),
        Container(
          height: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.separator(context).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: AppCodeEditor(
              controller: _composeController,
              language: 'yaml',
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          context.l10n.containers_extraEnvVars,
          TablerIcons.list_details,
        ),
        const SizedBox(height: 12),
        _buildEnvList(),
        const SizedBox(height: 24),
        _buildSectionTitle(
          context.l10n.containers_createOptions,
          TablerIcons.settings,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _OptionItem(
            label: context.l10n.containers_forcePullImage,
            subtitle: context.l10n.containers_forcePullImageSubtitle,
            value: _forcePull,
            onChanged: (v) => setState(() => _forcePull = v),
          ),
        ),
        const SizedBox(height: 40),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvList() {
    if (_envKeyControllers.isEmpty) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _addEnv,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.separator(context).withValues(alpha: 0.1),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                TablerIcons.plus,
                size: 20,
                color: CupertinoColors.activeBlue
                    .resolveFrom(context)
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.containers_tapAddEnvVar,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryLabel(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildEnvTable(),
        const SizedBox(height: 10),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addEnv,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue
                  .resolveFrom(context)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  TablerIcons.plus,
                  size: 14,
                  color: CupertinoColors.activeBlue
                      .resolveFrom(context)
                      .withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.containers_addEnvVarItem,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.activeBlue
                        .resolveFrom(context)
                        .withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvTable() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _envKeyControllers.length,
        itemBuilder: (context, i) {
          return Container(
            decoration: BoxDecoration(
              border: i == _envKeyControllers.length - 1
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: AppColors.separator(
                          context,
                        ).withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: CupertinoTextField(
                      controller: _envKeyControllers[i],
                      placeholder: 'Key',
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: null,
                      minLines: 1,
                      style: TextStyle(
                        color: AppColors.label(context),
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: AppColors.secondaryLabel(
                          context,
                        ).withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: CupertinoTextField(
                      controller: _envValueControllers[i],
                      placeholder: 'Value',
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: null,
                      minLines: 1,
                      style: TextStyle(
                        color: AppColors.label(context),
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () => _removeEnv(i),
                    child: Icon(
                      TablerIcons.x,
                      color: AppColors.tertiaryLabel(context),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
