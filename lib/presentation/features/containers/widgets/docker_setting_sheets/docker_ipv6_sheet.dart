import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../../core/localization/l10n_x.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../common/components/action_sheet_launcher.dart';
import '../../../../common/components/action_sheet_scaffold.dart';
import '../../../../common/components/app_action_components.dart';

/// IPv6 配置结果。
class Ipv6ConfigResult {
  const Ipv6ConfigResult({
    required this.fixedCidrV6,
    required this.ip6Tables,
    required this.experimental,
  });

  final String fixedCidrV6;
  final bool ip6Tables;
  final bool experimental;
}

/// 显示 IPv6 配置 Sheet。
///
/// 返回 [Ipv6ConfigResult]；用户取消返回 `null`。
Future<Ipv6ConfigResult?> showDockerIpv6Sheet(
  BuildContext context, {
  required bool currentIp6Tables,
  required bool currentExperimental,
  required String currentFixedCidrV6,
}) {
  return showActionSheet<Ipv6ConfigResult>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => _Ipv6Sheet(
      initialIp6Tables: currentIp6Tables,
      initialExperimental: currentExperimental,
      initialFixedCidrV6: currentFixedCidrV6,
    ),
  );
}

class _Ipv6Sheet extends StatefulWidget {
  const _Ipv6Sheet({
    required this.initialIp6Tables,
    required this.initialExperimental,
    required this.initialFixedCidrV6,
  });

  final bool initialIp6Tables;
  final bool initialExperimental;
  final String initialFixedCidrV6;

  @override
  State<_Ipv6Sheet> createState() => _Ipv6SheetState();
}

class _Ipv6SheetState extends State<_Ipv6Sheet> {
  late bool _ip6Tables;
  late bool _experimental;
  late final TextEditingController _cidrController;

  @override
  void initState() {
    super.initState();
    _ip6Tables = widget.initialIp6Tables;
    _experimental = widget.initialExperimental;
    _cidrController = TextEditingController(text: widget.initialFixedCidrV6);
  }

  @override
  void dispose() {
    _cidrController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.pop(
      context,
      Ipv6ConfigResult(
        fixedCidrV6: _cidrController.text.trim(),
        ip6Tables: _ip6Tables,
        experimental: _experimental,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      maxHeightFactor: 0.55,
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
                context.l10n.containers_ipv6Config,
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
              onPressed: _confirm,
              child: Text(
                context.l10n.common_confirm,
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: context.l10n.containers_switchOptions,
              icon: TablerIcons.toggle_left,
            ),
            AppActionGroup(
              children: [
                _SheetSwitchRow(
                  icon: TablerIcons.shield,
                  iconColor: CupertinoColors.systemGreen,
                  label: 'ip6tables',
                  value: _ip6Tables,
                  onChanged: (v) => setState(() => _ip6Tables = v),
                ),
                _SheetSwitchRow(
                  icon: TablerIcons.flask,
                  iconColor: CupertinoColors.systemOrange,
                  label: 'Experimental',
                  value: _experimental,
                  onChanged: (v) => setState(() => _experimental = v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: context.l10n.containers_networkSettings,
              icon: TablerIcons.network,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fixed CIDR v6',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _cidrController,
                    placeholder: context.l10n.containers_subnetV6Example,
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
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SheetSwitchRow extends StatelessWidget {
  const _SheetSwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
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
