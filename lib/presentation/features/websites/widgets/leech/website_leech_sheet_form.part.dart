part of '../website_leech_sheet.dart';

class _LeechForm extends StatelessWidget {
  const _LeechForm({
    required this.enable,
    required this.onEnableChanged,
    required this.selectedExtensions,
    required this.commonExtensions,
    required this.onExtensionToggle,
    required this.customExtController,
    required this.onAddCustomExt,
    required this.allowedDomains,
    required this.domainController,
    required this.onAddDomain,
    required this.onRemoveDomain,
    required this.noneRef,
    required this.onNoneRefChanged,
    required this.blocked,
    required this.onBlockedChanged,
    required this.returnCode,
    required this.onReturnCodeChanged,
    required this.cache,
    required this.onCacheChanged,
    required this.cacheTimeController,
    required this.cacheUint,
    required this.onCacheUintChanged,
    required this.logEnable,
    required this.onLogEnableChanged,
  });

  final bool enable;
  final ValueChanged<bool> onEnableChanged;
  final Set<String> selectedExtensions;
  final List<String> commonExtensions;
  final ValueChanged<String> onExtensionToggle;
  final TextEditingController customExtController;
  final VoidCallback onAddCustomExt;
  final List<String> allowedDomains;
  final TextEditingController domainController;
  final VoidCallback onAddDomain;
  final ValueChanged<String> onRemoveDomain;
  final bool noneRef;
  final ValueChanged<bool> onNoneRefChanged;
  final bool blocked;
  final ValueChanged<bool> onBlockedChanged;
  final String returnCode;
  final ValueChanged<String> onReturnCodeChanged;
  final bool cache;
  final ValueChanged<bool> onCacheChanged;
  final TextEditingController cacheTimeController;
  final String cacheUint;
  final ValueChanged<String> onCacheUintChanged;
  final bool logEnable;
  final ValueChanged<bool> onLogEnableChanged;

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
              title: context.l10n.websites_enableAntiLeech,
              value: enable,
              onChanged: onEnableChanged,
            ),
          ],
        ),
        if (enable) ...[
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.file_type_html,
            title: context.l10n.websites_extensionSettings,
            children: [
              Text(
                context.l10n.websites_extensionSettingsHint,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ext in commonExtensions)
                    _ExtensionChip(
                      label: ext,
                      selected: selectedExtensions.contains(ext),
                      onTap: () => onExtensionToggle(ext),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryBackground(
                          context,
                        ).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CupertinoTextField(
                        controller: customExtController,
                        placeholder: context.l10n.websites_customExtensionHint,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: null,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.label(context),
                        ),
                        onSubmitted: (_) => onAddCustomExt(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(36, 36),
                    color: CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: onAddCustomExt,
                    child: Text(
                      context.l10n.websites_add,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedExtensions.any(
                (e) => !commonExtensions.contains(e),
              )) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.websites_customProtection,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ext in selectedExtensions.where(
                      (e) => !commonExtensions.contains(e),
                    ))
                      _ExtensionChip(
                        label: ext,
                        selected: true,
                        onTap: () => onExtensionToggle(ext),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.world,
            title: context.l10n.websites_allowedDomains,
            children: [
              Text(
                context.l10n.websites_allowedDomainsHint,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryBackground(
                          context,
                        ).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CupertinoTextField(
                        controller: domainController,
                        placeholder: context.l10n.websites_addDomainHint,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: null,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.label(context),
                        ),
                        onSubmitted: (_) => onAddDomain(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(36, 36),
                    color: CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: onAddDomain,
                    child: Text(
                      context.l10n.websites_add,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (allowedDomains.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
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
                        TablerIcons.world_off,
                        size: 24,
                        color: AppColors.tertiaryLabel(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.websites_noAllowedDomains,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final domain in allowedDomains)
                      _DomainChip(
                        label: domain,
                        onDelete: () => onRemoveDomain(domain),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.settings_automation,
            title: context.l10n.websites_ruleControl,
            children: [
              _CompactSwitchTile(
                icon: TablerIcons.link_off,
                title: context.l10n.websites_allowEmptyReferer,
                value: noneRef,
                onChanged: onNoneRefChanged,
              ),
              _CompactSwitchTile(
                icon: TablerIcons.alert_triangle,
                title: context.l10n.websites_allowNonStandardReferer,
                value: blocked,
                onChanged: onBlockedChanged,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.websites_blockedResponse,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              const SizedBox(height: 8),
              AppInlinePicker<String>(
                value: returnCode,
                options: const [
                  AppPickerOption(value: '403', label: '403 Forbidden'),
                  AppPickerOption(value: '400', label: '400 Bad Request'),
                  AppPickerOption(value: '404', label: '404 Not Found'),
                ],
                onChanged: onReturnCodeChanged,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  context.l10n.websites_blockedResponseHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _FormSection(
          icon: TablerIcons.clock,
          title: context.l10n.websites_performanceAndLogs,
          children: [
            _CompactSwitchTile(
              icon: TablerIcons.bolt,
              title: context.l10n.websites_browserCache,
              value: cache,
              onChanged: onCacheChanged,
            ),
            if (cache)
              _CompactDurationField(
                label: context.l10n.websites_cacheTime,
                icon: TablerIcons.hourglass,
                controller: cacheTimeController,
                unit: cacheUint,
                onUnitChanged: onCacheUintChanged,
              ),
            _CompactSwitchTile(
              icon: TablerIcons.history,
              title: context.l10n.websites_recordRequestLogs,
              value: logEnable,
              onChanged: onLogEnableChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

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
                color: CupertinoColors.systemOrange.resolveFrom(context),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
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
      margin: const EdgeInsets.only(bottom: 10),
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

class _ExtensionChip extends StatelessWidget {
  const _ExtensionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = CupertinoColors.activeBlue.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? active.withValues(alpha: 0.15)
              : AppColors.tertiaryBackground(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? active
                : AppColors.separator(context).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? active : AppColors.label(context),
          ),
        ),
      ),
    );
  }
}

class _DomainChip extends StatelessWidget {
  const _DomainChip({required this.label, required this.onDelete});

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 4),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.label(context)),
          ),
          const SizedBox(width: 4),
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

class _CompactDurationField extends StatelessWidget {
  const _CompactDurationField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.tertiaryLabel(context)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryBackground(
                        context,
                      ).withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CupertinoTextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: null,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.label(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: AppOverlayPicker<String>(
                  value: unit,
                  options: [
                    AppPickerOption(
                      value: 's',
                      label: context.l10n.websites_unitSeconds,
                    ),
                    AppPickerOption(
                      value: 'm',
                      label: context.l10n.websites_unitMinutes,
                    ),
                    AppPickerOption(
                      value: 'h',
                      label: context.l10n.websites_unitHours,
                    ),
                    AppPickerOption(
                      value: 'd',
                      label: context.l10n.websites_unitDays,
                    ),
                    AppPickerOption(
                      value: 'w',
                      label: context.l10n.websites_unitWeeks,
                    ),
                    AppPickerOption(
                      value: 'M',
                      label: context.l10n.websites_unitMonths,
                    ),
                    AppPickerOption(
                      value: 'y',
                      label: context.l10n.websites_unitYears,
                    ),
                  ],
                  onChanged: onUnitChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
