import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/ssl_manage_dtos.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_picker.dart';

const _keyTypeOptions = [
  AppPickerOption(value: 'P256', label: 'P256'),
  AppPickerOption(value: 'P384', label: 'P384'),
  AppPickerOption(value: '2048', label: '2048'),
  AppPickerOption(value: '4096', label: '4096'),
];

/// Shows the CA SSL certificate issue sheet.
Future<void> showCaObtainSheet(
  BuildContext context, {
  required int caId,
  required Future<void> Function(CaObtainReq req) onSubmit,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (ctx) => _CaObtainSheet(caId: caId, onSubmit: onSubmit),
  );
}

class _CaObtainSheet extends StatefulWidget {
  const _CaObtainSheet({required this.caId, required this.onSubmit});

  final int caId;
  final Future<void> Function(CaObtainReq req) onSubmit;

  @override
  State<_CaObtainSheet> createState() => _CaObtainSheetState();
}

class _CaObtainSheetState extends State<_CaObtainSheet> {
  final _domainsController = TextEditingController();
  final _timeController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _dirController = TextEditingController();
  final _shellController = TextEditingController();
  String _keyType = 'P256';
  String _unit = 'year';
  bool _autoRenew = false;
  bool _pushDir = false;
  bool _execShell = false;
  bool _submitting = false;

  @override
  void dispose() {
    _domainsController.dispose();
    _timeController.dispose();
    _descriptionController.dispose();
    _dirController.dispose();
    _shellController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final domains = _domainsController.text.trim();
    final time = int.tryParse(_timeController.text.trim());
    if (domains.isEmpty) {
      showAppErrorToast(context.l10n.websites_domainsRequired);
      return;
    }
    if (time == null || time <= 0) {
      showAppErrorToast(context.l10n.websites_validityRequired);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        CaObtainReq(
          id: widget.caId,
          domains: domains,
          keyType: _keyType,
          time: time,
          unit: _unit,
          description: _descriptionController.text.trim(),
          dir: _dirController.text.trim(),
          shell: _shellController.text.trim(),
          autoRenew: _autoRenew,
          pushDir: _pushDir,
          execShell: _execShell,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.websites_issueFailed,
          description: e.toString(),
        );
      }
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
                context.l10n.websites_issueSslCertificate,
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
                      context.l10n.websites_issue,
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
              title: context.l10n.websites_certificateInfo,
              icon: TablerIcons.certificate,
            ),
            _buildTextField(
              controller: _domainsController,
              label: context.l10n.websites_domains,
              placeholder: context.l10n.websites_domainsPlaceholder,
              icon: TablerIcons.world,
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: 12),
            _buildPickerSection(
              icon: TablerIcons.key,
              label: context.l10n.websites_keyAlgorithm,
              value: _keyType,
              options: _keyTypeOptions,
              onChanged: (v) => setState(() => _keyType = v),
            ),
            const SizedBox(height: 12),
            _buildValidityField(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descriptionController,
              label: context.l10n.websites_remark,
              placeholder:
                  context.l10n.websites_certificateDescriptionPlaceholder,
              icon: TablerIcons.notes,
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: context.l10n.websites_advancedOptions,
              icon: TablerIcons.adjustments,
            ),
            _buildSwitchRow(
              icon: TablerIcons.refresh,
              label: context.l10n.websites_autoRenew,
              value: _autoRenew,
              onChanged: (v) => setState(() => _autoRenew = v),
            ),
            _buildSwitchRow(
              icon: TablerIcons.folder,
              label: context.l10n.websites_pushToDirectory,
              value: _pushDir,
              onChanged: (v) => setState(() => _pushDir = v),
            ),
            if (_pushDir) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _dirController,
                label: context.l10n.websites_targetDirectory,
                placeholder: '/path/to/certs',
                icon: TablerIcons.folder_open,
              ),
            ],
            _buildSwitchRow(
              icon: TablerIcons.terminal,
              label: context.l10n.websites_executeScript,
              value: _execShell,
              onChanged: (v) => setState(() => _execShell = v),
            ),
            if (_execShell) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _shellController,
                label: context.l10n.websites_scriptCommand,
                placeholder: context.l10n.websites_scriptCommandPlaceholder,
                icon: TablerIcons.terminal_2,
                maxLines: 3,
                minLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidityField() {
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
              Icon(
                TablerIcons.calendar,
                size: 16,
                color: AppColors.secondaryLabel(context),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.websites_validity,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _timeController,
                  placeholder: '1',
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryBackground(
                      context,
                    ).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInlinePicker<String>(
                  options: [
                    AppPickerOption(
                      value: 'year',
                      label: context.l10n.websites_unitYears,
                    ),
                    AppPickerOption(
                      value: 'month',
                      label: context.l10n.websites_unitMonths,
                    ),
                    AppPickerOption(
                      value: 'day',
                      label: context.l10n.websites_unitDays,
                    ),
                  ],
                  value: _unit,
                  onChanged: (v) => setState(() => _unit = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
    int minLines = 1,
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
            maxLines: maxLines,
            minLines: minLines,
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
