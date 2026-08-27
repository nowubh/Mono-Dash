part of '../website_cors_sheet.dart';

class _CorsForm extends StatelessWidget {
  const _CorsForm({
    required this.cors,
    required this.onCorsChanged,
    required this.originsController,
    required this.headersController,
    required this.allowMethods,
    required this.methodOptions,
    required this.onMethodToggle,
    required this.allowCredentials,
    required this.onAllowCredentialsChanged,
    required this.preflight,
    required this.onPreflightChanged,
  });

  final bool cors;
  final ValueChanged<bool> onCorsChanged;
  final TextEditingController originsController;
  final TextEditingController headersController;
  final Set<String> allowMethods;
  final List<String> methodOptions;
  final ValueChanged<String> onMethodToggle;
  final bool allowCredentials;
  final ValueChanged<bool> onAllowCredentialsChanged;
  final bool preflight;
  final ValueChanged<bool> onPreflightChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FormSection(
          icon: TablerIcons.power,
          title: context.l10n.websites_basicSettings,
          children: [
            _CompactSwitchTile(
              icon: TablerIcons.arrows_split_2,
              title: context.l10n.websites_enableCorsAccess,
              value: cors,
              onChanged: onCorsChanged,
            ),
          ],
        ),
        if (cors) ...[
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.world_www,
            title: context.l10n.websites_allowedOrigins,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.tertiaryBackground(
                    context,
                  ).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CupertinoTextField(
                  controller: originsController,
                  placeholder: context.l10n.websites_allowOriginsPlaceholder,
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
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  context.l10n.websites_allowOriginHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.settings_code,
            title: context.l10n.websites_allowMethods,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: methodOptions.map((method) {
                  final isSelected = allowMethods.contains(method);
                  return GestureDetector(
                    onTap: () => onMethodToggle(method),
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
                        method,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? CupertinoColors.activeBlue.resolveFrom(context)
                              : AppColors.label(context),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  context.l10n.websites_allowMethodsHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.cursor_text,
            title: context.l10n.websites_allowHeaders,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.tertiaryBackground(
                    context,
                  ).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CupertinoTextField(
                  controller: headersController,
                  placeholder: context.l10n.websites_allowHeadersPlaceholder,
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
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  context.l10n.websites_allowHeadersHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FormSection(
            icon: TablerIcons.shield_check,
            title: context.l10n.websites_advancedOptions,
            children: [
              _CompactSwitchTile(
                icon: TablerIcons.cookie,
                title: context.l10n.websites_allowCredentialsCookies,
                value: allowCredentials,
                onChanged: onAllowCredentialsChanged,
              ),
              const SizedBox(height: 8),
              _CompactSwitchTile(
                icon: TablerIcons.bolt,
                title: context.l10n.websites_preflightFastResponse,
                value: preflight,
                onChanged: onPreflightChanged,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  context.l10n.websites_preflightFastResponseHint,
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
