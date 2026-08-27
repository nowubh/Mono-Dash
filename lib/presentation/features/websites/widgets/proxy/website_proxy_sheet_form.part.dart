part of '../website_proxy_sheet.dart';

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.children,
    this.action,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? action;

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
              // ignore: use_null_aware_elements - current analyzer language level rejects ?action.
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CompactInputField extends StatelessWidget {
  const _CompactInputField({
    required this.label,
    required this.icon,
    required this.controller,
    this.required = false,
    this.enabled = true,
    this.hint,
    this.helper,
    this.keyboardType,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool required;
  final bool enabled;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;

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
              if (required)
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.tertiaryBackground(
                      context,
                    ).withValues(alpha: 0.58)
                  : AppColors.tertiaryBackground(
                      context,
                    ).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CupertinoTextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              placeholder: hint,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: const BoxDecoration(),
              style: TextStyle(fontSize: 14, color: AppColors.label(context)),
            ),
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 2),
              child: Text(
                helper!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                      decoration: const BoxDecoration(),
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
                width: 132,
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

class _CompactServerCacheField extends StatelessWidget {
  const _CompactServerCacheField({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.websites_serverCache,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 7),
          AppInlinePicker<bool>(
            value: value,
            options: [
              AppPickerOption(value: true, label: context.l10n.websites_enable),
              AppPickerOption(
                value: false,
                label: context.l10n.websites_disable,
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CompactCacheModeField extends StatelessWidget {
  const _CompactCacheModeField({required this.value, required this.onChanged});

  final _BrowserCacheMode value;
  final ValueChanged<_BrowserCacheMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.websites_browserCache,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 7),
          AppInlinePicker<_BrowserCacheMode>(
            value: value,
            options: [
              AppPickerOption(
                value: _BrowserCacheMode.noModify,
                label: context.l10n.websites_noModify,
              ),
              AppPickerOption(
                value: _BrowserCacheMode.enable,
                label: context.l10n.websites_enable,
              ),
              AppPickerOption(
                value: _BrowserCacheMode.disable,
                label: context.l10n.websites_disable,
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CompactMethodChip extends StatelessWidget {
  const _CompactMethodChip({
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? active.withValues(alpha: 0.16)
              : AppColors.tertiaryBackground(context).withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? active
                : AppColors.separator(context).withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? active : AppColors.secondaryLabel(context),
          ),
        ),
      ),
    );
  }
}

class _CompactMethodsField extends StatelessWidget {
  const _CompactMethodsField({
    required this.selectedMethods,
    required this.onToggle,
  });

  final Set<String> selectedMethods;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.websites_allowedMethods,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final method in _methodOptions)
                _CompactMethodChip(
                  label: method,
                  selected: selectedMethods.contains(method),
                  onTap: () => onToggle(method),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactEmptyHint extends StatelessWidget {
  const _CompactEmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.tertiaryLabel(context)),
      ),
    );
  }
}

class _ReplaceRow extends StatefulWidget {
  const _ReplaceRow({required this.item, required this.onDelete});

  final _ReplaceRule item;
  final VoidCallback onDelete;

  @override
  State<_ReplaceRow> createState() => _ReplaceRowState();
}

class _ReplaceRowState extends State<_ReplaceRow> {
  late final TextEditingController _searchController;
  late final TextEditingController _replaceController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.item.search);
    _replaceController = TextEditingController(text: widget.item.replace);
    _searchController.addListener(
      () => widget.item.search = _searchController.text,
    );
    _replaceController.addListener(
      () => widget.item.replace = _replaceController.text,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            TablerIcons.grip_vertical,
            size: 16,
            color: AppColors.tertiaryLabel(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                CupertinoTextField(
                  controller: _searchController,
                  placeholder: context.l10n.websites_searchString,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: _replaceController,
                  placeholder: context.l10n.websites_replaceWithString,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            onPressed: widget.onDelete,
            child: Icon(
              TablerIcons.trash,
              size: 16,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
