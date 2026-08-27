import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/container/image_dtos.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/frosted_dialog.dart';
import '../providers/image_repo_provider.dart';

/// 显示创建/编辑镜像仓库 BottomSheet
void showImageRepoCreateSheet(BuildContext context, {ImageRepoDto? repo}) {
  showActionSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => _ImageRepoCreateSheet(repo: repo),
  );
}

class _ImageRepoCreateSheet extends ConsumerStatefulWidget {
  const _ImageRepoCreateSheet({this.repo});

  final ImageRepoDto? repo;

  @override
  ConsumerState<_ImageRepoCreateSheet> createState() =>
      _ImageRepoCreateSheetState();
}

class _ImageRepoCreateSheetState extends ConsumerState<_ImageRepoCreateSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  String _protocol = 'https';
  bool _auth = false;

  bool get _isEdit => widget.repo != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.repo?.name ?? '');
    _urlController = TextEditingController(
      text: widget.repo?.downloadUrl ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.repo?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.repo?.password ?? '',
    );
    _protocol = widget.repo?.protocol ?? 'https';
    _auth = widget.repo?.auth ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (!_isEdit && name.isEmpty) {
      showAppErrorToast(context.l10n.containers_nameRequired);
      return;
    }

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showAppErrorToast(context.l10n.containers_repoAddressRequired);
      return;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      showAppErrorToast(context.l10n.containers_repoAddressNoProtocol);
      return;
    }

    final successText = _isEdit
        ? context.l10n.containers_repoUpdated
        : context.l10n.containers_repoCreated;
    final failureText = _isEdit
        ? context.l10n.containers_updateFailed
        : context.l10n.containers_createFailed;

    if (_protocol == 'http') {
      final originalProtocol = widget.repo?.protocol ?? 'https';
      final urlChanged =
          _isEdit && _urlController.text.trim() != widget.repo?.downloadUrl;
      final protocolChanged = _protocol != originalProtocol;

      if (!_isEdit || protocolChanged || urlChanged) {
        final confirmed = await showFrostedConfirmDialog(
          context,
          title: context.l10n.containers_httpProtocolWarning,
          icon: TablerIcons.alert_triangle,
          content: context.l10n.containers_httpProtocolWarningContent,
          confirmText: context.l10n.common_confirm,
        );
        if (confirmed != true) return;
      }
    }

    final username = _auth ? _usernameController.text.trim() : '';
    final password = _auth ? _passwordController.text.trim() : '';

    try {
      final repo = await ref.read(containerRepositoryProvider.future);

      if (_isEdit) {
        await repo.updateImageRepo(
          id: widget.repo!.id,
          downloadUrl: url,
          protocol: _protocol,
          auth: _auth,
          username: username,
          password: password,
        );
      } else {
        await repo.createImageRepo(
          name: name,
          downloadUrl: url,
          protocol: _protocol,
          auth: _auth,
          username: username,
          password: password,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      showAppSuccessToast(successText);
      ref.read(imageRepoControllerProvider.notifier).refresh();
    } catch (e) {
      showAppErrorToast(failureText, description: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      maxHeightFactor: 0.78,
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      panelHeader: Padding(
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
                _isEdit
                    ? context.l10n.containers_editRepo
                    : context.l10n.containers_addRepo,
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
                _isEdit
                    ? context.l10n.common_save
                    : context.l10n.containers_add,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                children: [
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder:
                        context.l10n.containers_repoNameRequiredPlaceholder,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: null,
                    readOnly: _isEdit,
                    style: TextStyle(
                      color: _isEdit
                          ? AppColors.secondaryLabel(context)
                          : AppColors.label(context),
                      fontSize: 15,
                    ),
                  ),
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    color: AppColors.separator(context).withValues(alpha: 0.15),
                  ),
                  CupertinoTextField(
                    controller: _urlController,
                    placeholder: context.l10n.containers_repoAddressPlaceholder,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: null,
                    style: TextStyle(
                      color: AppColors.label(context),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context.l10n.containers_protocol,
              TablerIcons.protocol,
            ),
            const SizedBox(height: 12),
            AppInlinePicker<String>(
              options: const [
                AppPickerOption(value: 'https', label: 'HTTPS'),
                AppPickerOption(value: 'http', label: 'HTTP'),
              ],
              value: _protocol,
              onChanged: (v) => setState(() => _protocol = v),
              maxVisibleItems: 2,
              backgroundColor: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context.l10n.containers_authSettings,
              TablerIcons.lock,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _OptionItem(
                    label: context.l10n.containers_enableAuth,
                    subtitle: context.l10n.containers_enableAuthSubtitle,
                    value: _auth,
                    onChanged: (v) => setState(() => _auth = v),
                  ),
                  if (_auth) ...[
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.15),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        children: [
                          CupertinoTextField(
                            controller: _usernameController,
                            placeholder: context.l10n.containers_username,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: null,
                            style: TextStyle(
                              color: AppColors.label(context),
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            height: 0.5,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            color: AppColors.separator(
                              context,
                            ).withValues(alpha: 0.15),
                          ),
                          CupertinoTextField(
                            controller: _passwordController,
                            placeholder: context.l10n.containers_password,
                            obscureText: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: null,
                            style: TextStyle(
                              color: AppColors.label(context),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
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
