import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../providers/ssh_info_provider.dart';

Future<void> showListenAddressSheet(
  BuildContext context, {
  required String currentAddress,
}) async {
  await showActionSheet<void>(
    context: context,
    builder: (_) => _ListenAddressSheet(currentAddress: currentAddress),
  );
}

class _ListenAddressSheet extends ConsumerStatefulWidget {
  const _ListenAddressSheet({required this.currentAddress});

  final String currentAddress;

  @override
  ConsumerState<_ListenAddressSheet> createState() =>
      _ListenAddressSheetState();
}

class _ListenAddressSheetState extends ConsumerState<_ListenAddressSheet> {
  late final TextEditingController _v4Controller;
  late final TextEditingController _v6Controller;
  bool _v4All = false;
  bool _v6All = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final parts = widget.currentAddress
        .split(',')
        .map((s) => s.trim())
        .toList();
    final initV4 = parts.isNotEmpty ? parts[0] : '';
    final initV6 = parts.length > 1 ? parts[1] : '';

    _v4All = initV4 == '0.0.0.0' || initV4.isEmpty;
    _v6All = initV6 == '::';
    _v4Controller = TextEditingController(text: _v4All ? '' : initV4);
    _v6Controller = TextEditingController(text: _v6All ? '' : initV6);
  }

  @override
  void dispose() {
    _v4Controller.dispose();
    _v6Controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final v4 = _v4All ? '0.0.0.0' : _v4Controller.text.trim();
    final v6 = _v6All ? '::' : _v6Controller.text.trim();
    final result = [v4, v6].where((s) => s.isNotEmpty).join(',');

    setState(() => _isLoading = true);
    final ok = await ref
        .read(sshInfoControllerProvider.notifier)
        .updateConfig('ListenAddress', result);
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
        child: Row(
          children: [
            Icon(
              TablerIcons.network,
              size: 22,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.ssh_editListenAddress,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.l10n.common_cancel,
                style: TextStyle(
                  color: AppColors.secondaryLabel(context),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // IPv4
          _buildSectionHeader(context, 'IPv4'),
          const SizedBox(height: 8),
          _buildBindAllRow(
            context,
            value: _v4All,
            onChanged: (v) => setState(() => _v4All = v),
          ),
          if (!_v4All) ...[
            const SizedBox(height: 8),
            _buildFormItem(
              context,
              label: context.l10n.ssh_ipv4Address,
              icon: TablerIcons.network,
              child: SizedBox(
                height: 46,
                child: CupertinoTextField(
                  controller: _v4Controller,
                  placeholder: '192.168.1.10',
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: TextInputType.url,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.18),
                      width: 0.5,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.label(context),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // IPv6
          _buildSectionHeader(context, 'IPv6'),
          const SizedBox(height: 8),
          _buildBindAllRow(
            context,
            value: _v6All,
            onChanged: (v) => setState(() => _v6All = v),
          ),
          if (!_v6All) ...[
            const SizedBox(height: 8),
            _buildFormItem(
              context,
              label: context.l10n.ssh_ipv6Address,
              icon: TablerIcons.network,
              child: SizedBox(
                height: 46,
                child: CupertinoTextField(
                  controller: _v6Controller,
                  placeholder: 'fe80::1',
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textAlignVertical: TextAlignVertical.center,
                  keyboardType: TextInputType.url,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.18),
                      width: 0.5,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.label(context),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.l10n.ssh_bindAllHint,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: CupertinoColors.activeBlue.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CupertinoActivityIndicator(
                      radius: 10,
                      color: CupertinoColors.white,
                    )
                  : Text(
                      context.l10n.common_save,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label) {
    return Row(
      children: [
        Icon(
          TablerIcons.network,
          size: 14,
          color: AppColors.secondaryLabel(context),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.label(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBindAllRow(
    BuildContext context, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.ssh_bindAll,
            style: TextStyle(fontSize: 14, color: AppColors.label(context)),
          ),
          const Spacer(),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildFormItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.secondaryLabel(context)),
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
        ),
        child,
      ],
    );
  }
}
