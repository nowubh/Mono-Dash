import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../common/components/frosted_dialog.dart';
import '../../../../core/theme/app_theme.dart';

class ComposeDeleteDialog extends StatefulWidget {
  const ComposeDeleteDialog({super.key, required this.name});

  final String name;

  @override
  State<ComposeDeleteDialog> createState() => _ComposeDeleteDialogState();
}

class _ComposeDeleteDialogState extends State<ComposeDeleteDialog> {
  bool withFile = false;
  bool force = false;

  @override
  Widget build(BuildContext context) {
    return FrostedDialog(
      title: context.l10n.containers_deleteCompose,
      icon: TablerIcons.trash,
      confirmText: context.l10n.containers_confirmDelete,
      confirmColor: CupertinoColors.systemRed,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () =>
          Navigator.of(context).pop({'withFile': withFile, 'force': force}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.containers_deleteComposeConfirm(widget.name),
            style: TextStyle(fontSize: 14, color: AppColors.label(context)),
          ),
          const SizedBox(height: 20),
          _OptionRow(
            label: context.l10n.containers_deleteFiles,
            subtitle: context.l10n.containers_deleteFilesSubtitle,
            value: withFile,
            onChanged: (v) => setState(() => withFile = v),
          ),
          const SizedBox(height: 16),
          _OptionRow(
            label: context.l10n.containers_forceDelete,
            subtitle: context.l10n.containers_forceDeleteSubtitle,
            value: force,
            onChanged: (v) => setState(() => force = v),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
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
            color: AppColors.secondaryLabel(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
