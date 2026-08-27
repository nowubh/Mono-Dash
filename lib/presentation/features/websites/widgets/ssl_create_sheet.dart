import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/ssl_manage_dtos.dart';
import '../../../../data/dto/website/website_acme_account_dto.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/file_browser_picker_sheet.dart';

/// Shows the SSL certificate creation sheet.
Future<void> showSslCreateSheet(
  BuildContext context, {
  required List<WebsiteAcmeAccountDto> acmeAccounts,
  required List<DnsAccountDto> dnsAccounts,
  required Future<void> Function(SslCreateReq req) onSubmit,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (ctx) => _SslCreateSheet(
      acmeAccounts: acmeAccounts,
      dnsAccounts: dnsAccounts,
      onSubmit: onSubmit,
    ),
  );
}

class _SslCreateSheet extends StatefulWidget {
  const _SslCreateSheet({
    required this.acmeAccounts,
    required this.dnsAccounts,
    required this.onSubmit,
  });

  final List<WebsiteAcmeAccountDto> acmeAccounts;
  final List<DnsAccountDto> dnsAccounts;
  final Future<void> Function(SslCreateReq req) onSubmit;

  @override
  State<_SslCreateSheet> createState() => _SslCreateSheetState();
}

class _SslCreateSheetState extends State<_SslCreateSheet> {
  final _primaryDomainController = TextEditingController();
  final _otherDomainsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dirController = TextEditingController();
  final _shellController = TextEditingController();
  final _nameserver1Controller = TextEditingController();
  final _nameserver2Controller = TextEditingController();

  String _provider = 'dnsAccount';
  String _keyType = 'P256';
  int _acmeAccountId = 0;
  int _dnsAccountId = 0;
  bool _autoRenew = true;
  bool _pushDir = false;
  bool _execShell = false;
  // bool _isIp = false;
  bool _disableCNAME = false;
  bool _skipDNS = false;
  bool _submitting = false;

  static const _keyTypeOptions = [
    AppPickerOption(value: 'P256', label: 'P256'),
    AppPickerOption(value: 'P384', label: 'P384'),
    AppPickerOption(value: '2048', label: '2048'),
    AppPickerOption(value: '4096', label: '4096'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.acmeAccounts.isNotEmpty) {
      _acmeAccountId = widget.acmeAccounts.first.id;
    }
    if (widget.dnsAccounts.isNotEmpty) {
      _dnsAccountId = widget.dnsAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _primaryDomainController.dispose();
    _otherDomainsController.dispose();
    _descriptionController.dispose();
    _dirController.dispose();
    _shellController.dispose();
    _nameserver1Controller.dispose();
    _nameserver2Controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final primaryDomain = _primaryDomainController.text.trim();
    if (primaryDomain.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        SslCreateReq(
          primaryDomain: primaryDomain,
          otherDomains: _otherDomainsController.text.trim(),
          provider: _provider,
          keyType: _keyType,
          description: _descriptionController.text.trim(),
          dir: _dirController.text.trim(),
          shell: _shellController.text.trim(),
          nodes: '',
          acmeAccountId: _acmeAccountId,
          dnsAccountId: _dnsAccountId,
          autoRenew: _autoRenew,
          pushDir: _pushDir,
          execShell: _execShell,
          pushNode: false,
          isIp: false,
          disableCNAME: _disableCNAME,
          skipDNS: _skipDNS,
          nameserver1: _nameserver1Controller.text.trim(),
          nameserver2: _nameserver2Controller.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // error toast handled by caller
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<AppPickerOption<String>> _providerOptions(BuildContext context) => [
    AppPickerOption(
      value: 'dnsAccount',
      label: context.l10n.websites_dnsAccountValidation,
    ),
    AppPickerOption(
      value: 'dnsManual',
      label: context.l10n.websites_manualDnsValidation,
    ),
    AppPickerOption(value: 'http', label: context.l10n.websites_httpValidation),
    AppPickerOption(
      value: 'selfSigned',
      label: context.l10n.websites_selfSigned,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      maxHeightFactor: 0.85,
      showHandle: false,
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
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
                context.l10n.websites_applyCertificate,
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
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Text(
                      context.l10n.websites_submit,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: context.l10n.websites_basicInfo,
            icon: TablerIcons.info_circle,
          ),
          _buildTextField(
            controller: _primaryDomainController,
            label: context.l10n.websites_primaryDomain,
            placeholder: context.l10n.websites_primaryDomainExample,
            icon: TablerIcons.world,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _otherDomainsController,
            label: context.l10n.websites_otherDomains,
            placeholder: context.l10n.websites_otherDomainsPlaceholder,
            icon: TablerIcons.world_latitude,
            multiline: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _descriptionController,
            label: context.l10n.common_description,
            placeholder: context.l10n.websites_optional,
            icon: TablerIcons.notes,
          ),
          const SizedBox(height: 18),
          AppSectionHeader(
            title: context.l10n.websites_validationMethod,
            icon: TablerIcons.shield_check,
          ),
          _buildPickerSection<String>(
            icon: TablerIcons.shield_check,
            label: context.l10n.websites_validationMethod,
            value: _provider,
            options: _providerOptions(context),
            onChanged: (v) => setState(() => _provider = v),
          ),
          if (_provider != 'selfSigned') ...[
            const SizedBox(height: 12),
            _buildPickerSection<int>(
              icon: TablerIcons.user_circle,
              label: context.l10n.websites_acmeAccount,
              value: _acmeAccountId,
              options: widget.acmeAccounts
                  .map(
                    (a) => AppPickerOption(value: a.id, label: a.displayName),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _acmeAccountId = v),
            ),
          ],
          if (_provider == 'dnsAccount') ...[
            const SizedBox(height: 12),
            _buildPickerSection<int>(
              icon: TablerIcons.world,
              label: context.l10n.websites_dnsAccount,
              value: _dnsAccountId,
              options: widget.dnsAccounts
                  .map(
                    (a) => AppPickerOption(
                      value: a.id,
                      label: a.name.isEmpty ? 'DNS #${a.id}' : a.name,
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _dnsAccountId = v),
            ),
          ],
          const SizedBox(height: 18),
          AppSectionHeader(
            title: context.l10n.websites_advancedOptions,
            icon: TablerIcons.adjustments,
          ),
          _buildPickerSection<String>(
            icon: TablerIcons.key,
            label: context.l10n.websites_keyAlgorithm,
            value: _keyType,
            options: _keyTypeOptions,
            onChanged: (v) => setState(() => _keyType = v),
          ),
          const SizedBox(height: 12),
          if (_provider != 'dnsManual' && _provider != 'selfSigned')
            _buildSwitchRow(
              icon: TablerIcons.refresh,
              label: context.l10n.websites_autoRenew,
              value: _autoRenew,
              onChanged: (v) => setState(() => _autoRenew = v),
            ),
          if (_provider != 'selfSigned') ...[
            _buildSwitchRow(
              icon: TablerIcons.router,
              label: context.l10n.websites_skipDnsValidation,
              value: _skipDNS,
              onChanged: (v) => setState(() => _skipDNS = v),
            ),
            _buildSwitchRow(
              icon: TablerIcons.link_off,
              label: context.l10n.websites_disableCname,
              value: _disableCNAME,
              onChanged: (v) => setState(() => _disableCNAME = v),
            ),
            _buildSwitchRow(
              icon: TablerIcons.folder,
              label: context.l10n.websites_pushToLocalDir,
              value: _pushDir,
              onChanged: (v) => setState(() => _pushDir = v),
            ),
            if (_pushDir) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _dirController,
                label: context.l10n.websites_certificateDirectory,
                placeholder: context.l10n.websites_absolutePathExample,
                icon: TablerIcons.folder,
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () async {
                    final result = await FileBrowserPickerSheet.show(
                      context,
                      title: context.l10n.websites_chooseCertificateDirectory,
                      selectionMode: FilePickerSelectionMode.directories,
                    );
                    if (result != null && mounted) {
                      setState(() => _dirController.text = result.path);
                    }
                  },
                  child: Icon(
                    TablerIcons.folder_open,
                    size: 18,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                ),
              ),
            ],
            _buildSwitchRow(
              icon: TablerIcons.terminal,
              label: context.l10n.websites_runScriptAfterApply,
              value: _execShell,
              onChanged: (v) => setState(() => _execShell = v),
            ),
            if (_execShell) ...[
              const SizedBox(height: 12),
              _buildShellEditor(),
            ],
            const SizedBox(height: 18),
            AppSectionHeader(
              title: context.l10n.websites_dnsServers,
              icon: TablerIcons.server,
            ),
            _buildTextField(
              controller: _nameserver1Controller,
              label: context.l10n.websites_preferredDns,
              placeholder: context.l10n.websites_optionalDnsExample,
              icon: TablerIcons.server,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameserver2Controller,
              label: context.l10n.websites_alternateDns,
              placeholder: context.l10n.websites_optional,
              icon: TablerIcons.server_2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    bool multiline = false,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.secondaryLabel(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            maxLines: multiline ? 4 : 1,
            minLines: multiline ? 2 : 1,
            autocorrect: false,
            enableSuggestions: false,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            style: TextStyle(color: AppColors.label(context), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildShellEditor() {
    final hasContent = _shellController.text.isNotEmpty;
    final preview = hasContent
        ? _shellController.text.split('\n').take(2).join('\n')
        : '';

    return GestureDetector(
      onTap: () async {
        await showAppCodeEditorSheet(
          context,
          title: context.l10n.websites_executeScript,
          initialContent: _shellController.text,
          onSave: (content) async {
            setState(() => _shellController.text = content);
            return true;
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  TablerIcons.terminal,
                  size: 16,
                  color: AppColors.secondaryLabel(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.websites_scriptContent,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ),
                Icon(
                  TablerIcons.chevron_right,
                  size: 16,
                  color: AppColors.tertiaryLabel(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.tertiaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasContent ? preview : context.l10n.websites_editScriptHint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasContent
                      ? AppColors.label(context)
                      : AppColors.tertiaryLabel(context),
                  fontSize: 13,
                  fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerSection<T>({
    required IconData icon,
    required String label,
    required T value,
    required List<AppPickerOption<T>> options,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.secondaryLabel(context)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppInlinePicker<T>(
            options: options,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen
                  .resolveFrom(context)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: CupertinoColors.systemGreen.resolveFrom(context),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
