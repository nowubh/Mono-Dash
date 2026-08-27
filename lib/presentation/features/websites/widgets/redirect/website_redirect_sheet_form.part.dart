part of '../website_redirect_sheet.dart';

class _RedirectForm extends StatelessWidget {
  const _RedirectForm({
    required this.isEdit,
    required this.nameController,
    required this.targetController,
    required this.type,
    required this.onTypeChanged,
    required this.redirect,
    required this.onRedirectChanged,
    required this.keepPath,
    required this.onKeepPathChanged,
    required this.availableDomains,
    required this.selectedDomains,
    required this.onDomainToggle,
  });

  final bool isEdit;
  final TextEditingController nameController;
  final TextEditingController targetController;
  final String type;
  final ValueChanged<String> onTypeChanged;
  final String redirect;
  final ValueChanged<String> onRedirectChanged;
  final bool keepPath;
  final ValueChanged<bool> onKeepPathChanged;
  final List<WebsiteDomainDto> availableDomains;
  final Set<String> selectedDomains;
  final ValueChanged<String> onDomainToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _FormSection(
            icon: TablerIcons.info_circle,
            title: context.l10n.websites_basicInfo,
            children: [
              _FormInput(
                label: context.l10n.websites_ruleName,
                child: CupertinoTextField(
                  controller: nameController,
                  placeholder: context.l10n.websites_ruleNamePlaceholder,
                  enabled: !isEdit,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isEdit
                                ? AppColors.tertiaryBackground(context)
                                : AppColors.background(context))
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FormInput(
                label: context.l10n.websites_redirectType,
                child: AppInlinePicker<String>(
                  value: type,
                  options: [
                    AppPickerOption(
                      value: 'domain',
                      label: context.l10n.websites_domain,
                    ),
                    AppPickerOption(
                      value: 'path',
                      label: context.l10n.websites_path,
                    ),
                    const AppPickerOption(value: '404', label: '404'),
                  ],
                  enabled: !isEdit,
                  onChanged: onTypeChanged,
                ),
              ),
              const SizedBox(height: 12),
              _FormInput(
                label: context.l10n.websites_redirectMethod,
                child: AppInlinePicker<String>(
                  value: redirect,
                  options: [
                    AppPickerOption(
                      value: '301',
                      label: context.l10n.websites_redirect301,
                    ),
                    AppPickerOption(
                      value: '302',
                      label: context.l10n.websites_redirect302,
                    ),
                  ],
                  onChanged: onRedirectChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: TablerIcons.world,
            title: context.l10n.websites_domainSelection,
            children: [
              if (availableDomains.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      context.l10n.websites_noSelectableDomains,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableDomains.map((domain) {
                    final isSelected = selectedDomains.contains(domain.domain);
                    return GestureDetector(
                      onTap: () => onDomainToggle(domain.domain),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CupertinoColors.activeBlue
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.1)
                              : AppColors.tertiaryBackground(
                                  context,
                                ).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? CupertinoColors.activeBlue
                                      .resolveFrom(context)
                                      .withValues(alpha: 0.3)
                                : AppColors.separator(
                                    context,
                                  ).withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          domain.domain,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? CupertinoColors.activeBlue.resolveFrom(
                                    context,
                                  )
                                : AppColors.label(context),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: TablerIcons.link,
            title: context.l10n.websites_targetSettings,
            children: [
              _FormInput(
                label: context.l10n.websites_targetUrl,
                child: CupertinoTextField(
                  controller: targetController,
                  placeholder: context.l10n.websites_targetUrlPlaceholder,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CompactSwitchTile(
                icon: TablerIcons.arrows_join,
                title: context.l10n.websites_keepUriParameters,
                value: keepPath,
                onChanged: onKeepPathChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormInput extends StatelessWidget {
  const _FormInput({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
        child,
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
                color: CupertinoColors.systemBlue.resolveFrom(context),
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
