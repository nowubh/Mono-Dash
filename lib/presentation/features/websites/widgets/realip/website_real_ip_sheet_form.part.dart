part of '../website_real_ip_sheet.dart';

class _RealIpForm extends StatelessWidget {
  const _RealIpForm({
    required this.open,
    required this.onOpenChanged,
    required this.ipFromList,
    required this.isTextMode,
    required this.onModeChanged,
    required this.isAddingIp,
    required this.onAddingChanged,
    required this.addIpController,
    required this.onAddIp,
    required this.onRemoveIp,
    required this.codeController,
    required this.ipHeader,
    required this.onIpHeaderChanged,
    required this.ipOtherController,
    required this.headerOptions,
  });

  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final List<String> ipFromList;
  final bool isTextMode;
  final ValueChanged<bool> onModeChanged;
  final bool isAddingIp;
  final ValueChanged<bool> onAddingChanged;
  final TextEditingController addIpController;
  final VoidCallback onAddIp;
  final ValueChanged<String> onRemoveIp;
  final CodeLineEditingController codeController;
  final String ipHeader;
  final ValueChanged<String> onIpHeaderChanged;
  final TextEditingController ipOtherController;
  final List<String> headerOptions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormSection(
          icon: TablerIcons.power,
          title: context.l10n.websites_basicConfig,
          children: [
            _CompactSwitchTile(
              icon: TablerIcons.shield_check,
              title: context.l10n.websites_enableRealIp,
              value: open,
              onChanged: onOpenChanged,
            ),
          ],
        ),
        if (open) ...[
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.network,
            title: context.l10n.websites_ipSourceSetRealIpFrom,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => onModeChanged(!isTextMode),
              child: Icon(
                isTextMode ? TablerIcons.list : TablerIcons.edit,
                size: 18,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
            ),
            children: [
              if (isTextMode)
                Container(
                  height: 240,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.1),
                    ),
                  ),
                  child: AppCodeEditor(
                    controller: codeController,
                    showLineNumbers: false,
                    hint: context.l10n.websites_ipSourceHint,
                  ),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      context.l10n.websites_trustedProxyIpList,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => onAddingChanged(true),
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.plus,
                            size: 14,
                            color: CupertinoColors.activeBlue.resolveFrom(
                              context,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.websites_add,
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.activeBlue.resolveFrom(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isAddingIp)
                  _InlineIpEditor(
                    controller: addIpController,
                    onCancel: () => onAddingChanged(false),
                    onConfirm: onAddIp,
                  ),
                if (ipFromList.isEmpty && !isAddingIp)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryBackground(
                        context,
                      ).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.separator(
                          context,
                        ).withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          TablerIcons.route,
                          size: 24,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.websites_noTrustedProxyIp,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.tertiaryLabel(context),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final ip in ipFromList)
                    _IpListItem(ip: ip, onDelete: () => onRemoveIp(ip)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.cursor_text,
            title: context.l10n.websites_realIpHeader,
            children: [
              AppInlinePicker<String>(
                value: ipHeader,
                options: [
                  const AppPickerOption(
                    value: 'X-Forwarded-For',
                    label: 'X-Forwarded-For',
                  ),
                  const AppPickerOption(value: 'X-Real-IP', label: 'X-Real-IP'),
                  const AppPickerOption(
                    value: 'CF-Connecting-IP',
                    label: 'CF-Connecting-IP',
                  ),
                  AppPickerOption(
                    value: 'other',
                    label: context.l10n.websites_otherCustom,
                  ),
                ],
                onChanged: onIpHeaderChanged,
              ),
              if (ipHeader == 'other') ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryBackground(
                      context,
                    ).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CupertinoTextField(
                    controller: ipOtherController,
                    placeholder: context.l10n.websites_customHeaderPlaceholder,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: null,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  context.l10n.websites_realIpHeaderHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InlineIpEditor extends StatelessWidget {
  const _InlineIpEditor({
    required this.controller,
    required this.onCancel,
    required this.onConfirm,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.activeBlue
              .resolveFrom(context)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: context.l10n.websites_ipOrCidrPlaceholder,
              autofocus: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: null,
              style: TextStyle(fontSize: 13, color: AppColors.label(context)),
              onSubmitted: (_) => onConfirm(),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            onPressed: onCancel,
            child: Text(
              context.l10n.common_cancel,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            onPressed: onConfirm,
            child: Text(
              context.l10n.common_confirm,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _IpListItem extends StatelessWidget {
  const _IpListItem({required this.ip, required this.onDelete});

  final String ip;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            TablerIcons.route,
            size: 14,
            color: AppColors.tertiaryLabel(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ip,
              style: TextStyle(fontSize: 13, color: AppColors.label(context)),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onDelete,
            child: Icon(
              TablerIcons.x,
              size: 14,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.16),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: CupertinoColors.systemGreen.resolveFrom(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CompactSwitchTile extends StatelessWidget {
  const _CompactSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 13, color: AppColors.label(context)),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
