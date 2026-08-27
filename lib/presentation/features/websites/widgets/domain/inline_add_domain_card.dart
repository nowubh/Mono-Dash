import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../../core/localization/l10n_x.dart';
import '../../../../../core/theme/app_theme.dart';
import 'domain_components.dart';
import 'domain_models.dart';

class InlineAddDomainCard extends StatefulWidget {
  const InlineAddDomainCard({
    super.key,
    required this.onCancel,
    required this.onSave,
    required this.onInvalidInput,
  });

  final VoidCallback onCancel;
  final Future<void> Function(NewDomainInput input) onSave;
  final ValueChanged<String> onInvalidInput;

  @override
  State<InlineAddDomainCard> createState() => _InlineAddDomainCardState();
}

class _InlineAddDomainCardState extends State<InlineAddDomainCard> {
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '80',
  );
  bool _ssl = false;
  bool _saving = false;

  @override
  void dispose() {
    _domainController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _ssl
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.16),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(
            icon: TablerIcons.at,
            label: context.l10n.websites_domain,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          ),
          const SizedBox(height: 7),
          CupertinoTextField(
            controller: _domainController,
            placeholder: context.l10n.websites_domainOrIpPlaceholder,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(
                context,
              ).withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(
                      icon: TablerIcons.plug_connected,
                      label: context.l10n.websites_port,
                      color: CupertinoColors.systemTeal.resolveFrom(context),
                    ),
                    const SizedBox(height: 7),
                    CupertinoTextField(
                      controller: _portController,
                      placeholder: context.l10n.websites_port,
                      keyboardType: TextInputType.number,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryBackground(
                          context,
                        ).withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(
                      icon: TablerIcons.shield_lock,
                      label: context.l10n.websites_enableSsl,
                      color: accent,
                    ),
                    const SizedBox(height: 7),
                    Container(
                      height: 34,
                      padding: const EdgeInsets.only(left: 10, right: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _ssl ? 'HTTPS' : 'HTTP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          AppToggleSwitch(value: _ssl, onChanged: _setSsl),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DomainActionButton(
                  icon: TablerIcons.x,
                  label: context.l10n.common_cancel,
                  color: AppColors.secondaryLabel(context),
                  onPressed: _saving ? null : widget.onCancel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DomainActionButton(
                  icon: TablerIcons.check,
                  label: _saving
                      ? context.l10n.websites_saving
                      : context.l10n.common_save,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                  onPressed: _saving ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setSsl(bool value) {
    setState(() {
      _ssl = value;
      final port = _portController.text.trim();
      if (_ssl && port == '80') {
        _portController.text = '443';
      } else if (!_ssl && port == '443') {
        _portController.text = '80';
      }
    });
  }

  Future<void> _submit() async {
    final domain = _domainController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 0;
    if (domain.isEmpty || port <= 0 || port > 65535) {
      widget.onInvalidInput(context.l10n.websites_validDomainPortRequired);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        NewDomainInput(domain: domain, port: port, ssl: _ssl),
      );
    } catch (_) {
      // Parent handles the error message; keep the card open for correction.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ],
    );
  }
}
