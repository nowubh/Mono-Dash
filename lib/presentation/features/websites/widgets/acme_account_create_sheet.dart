import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../data/dto/website/ssl_manage_dtos.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_picker.dart';

/// Shows the ACME account create sheet.
Future<void> showAcmeAccountCreateSheet(
  BuildContext context, {
  required Future<void> Function(AcmeAccountCreateReq req) onSubmit,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (ctx) => _AcmeAccountCreateSheet(onSubmit: onSubmit),
  );
}

class _AcmeAccountCreateSheet extends StatefulWidget {
  const _AcmeAccountCreateSheet({required this.onSubmit});

  final Future<void> Function(AcmeAccountCreateReq req) onSubmit;

  @override
  State<_AcmeAccountCreateSheet> createState() =>
      _AcmeAccountCreateSheetState();
}

class _AcmeAccountCreateSheetState extends State<_AcmeAccountCreateSheet> {
  final _emailController = TextEditingController();
  final _caDirUrlController = TextEditingController();
  final _eabKidController = TextEditingController();
  final _eabHmacKeyController = TextEditingController();

  String _type = 'letsencrypt';
  String _keyType = 'P256';
  bool _useEAB = false;
  bool _useProxy = false;
  bool _submitting = false;

  static const _typeOptions = [
    AppPickerOption(value: 'letsencrypt', label: "Let's Encrypt"),
    AppPickerOption(value: 'zerossl', label: 'ZeroSSL'),
  ];

  static const _keyTypeOptions = [
    AppPickerOption(value: 'P256', label: 'P256'),
    AppPickerOption(value: 'P384', label: 'P384'),
    AppPickerOption(value: '2048', label: '2048'),
    AppPickerOption(value: '4096', label: '4096'),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _caDirUrlController.dispose();
    _eabKidController.dispose();
    _eabHmacKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        AcmeAccountCreateReq(
          email: email,
          type: _type,
          keyType: _keyType,
          caDirURL: _caDirUrlController.text.trim(),
          eabKid: _eabKidController.text.trim(),
          eabHmacKey: _eabHmacKeyController.text.trim(),
          useProxy: _useProxy,
          useEAB: _useEAB,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // error toast handled by caller
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      maxHeightFactor: 0.85,
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
                context.l10n.websites_createAcmeAccount,
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
                      context.l10n.common_create,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: context.l10n.websites_basicInfo,
              icon: TablerIcons.info_circle,
            ),
            _buildTextField(
              controller: _emailController,
              label: context.l10n.websites_email,
              placeholder: context.l10n.websites_certificateExpiryEmailHint,
              icon: TablerIcons.mail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildPickerSection<String>(
              icon: TablerIcons.server,
              label: context.l10n.websites_accountType,
              value: _type,
              options: _typeOptions,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),
            _buildPickerSection<String>(
              icon: TablerIcons.key,
              label: context.l10n.websites_keyAlgorithm,
              value: _keyType,
              options: _keyTypeOptions,
              onChanged: (v) => setState(() => _keyType = v),
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: context.l10n.websites_advancedOptions,
              icon: TablerIcons.adjustments,
            ),
            _buildTextField(
              controller: _caDirUrlController,
              label: context.l10n.websites_customAcmeDirectory,
              placeholder: context.l10n.websites_optionalUseDefault,
              icon: TablerIcons.link,
            ),
            const SizedBox(height: 12),
            _buildSwitchRow(
              icon: TablerIcons.shield_check,
              label: context.l10n.websites_useEab,
              value: _useEAB,
              onChanged: (v) => setState(() => _useEAB = v),
            ),
            if (_useEAB) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _eabKidController,
                label: 'EAB Key ID',
                placeholder: context.l10n.websites_eabKeyIdPlaceholder,
                icon: TablerIcons.id,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _eabHmacKeyController,
                label: 'EAB HMAC Key',
                placeholder: context.l10n.websites_eabHmacKeyPlaceholder,
                icon: TablerIcons.hash,
              ),
            ],
            _buildSwitchRow(
              icon: TablerIcons.world,
              label: context.l10n.websites_useProxy,
              value: _useProxy,
              onChanged: (v) => setState(() => _useProxy = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
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
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            keyboardType: keyboardType,
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
