import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_picker.dart';
import '../../../../data/dto/website/website_limit_config_dto.dart';
import '../providers/website_limit_provider.dart';
import 'website_modal_sheet.dart';

class _LimitPreset {
  const _LimitPreset({
    required this.name,
    required this.perServerLimit,
    required this.perIpLimit,
    required this.rateKb,
  });

  final String name;
  final int? perServerLimit;
  final int? perIpLimit;
  final int? rateKb;
}

const _limitPresets = <_LimitPreset>[
  _LimitPreset(
    name: 'forumBlog',
    perServerLimit: 300,
    perIpLimit: 25,
    rateKb: 512,
  ),
  _LimitPreset(
    name: 'imageSite',
    perServerLimit: 200,
    perIpLimit: 10,
    rateKb: 1024,
  ),
  _LimitPreset(
    name: 'downloadSite',
    perServerLimit: 50,
    perIpLimit: 3,
    rateKb: 2048,
  ),
  _LimitPreset(name: 'shop', perServerLimit: 500, perIpLimit: 10, rateKb: 2048),
  _LimitPreset(
    name: 'portal',
    perServerLimit: 400,
    perIpLimit: 15,
    rateKb: 1024,
  ),
  _LimitPreset(
    name: 'enterprise',
    perServerLimit: 60,
    perIpLimit: 10,
    rateKb: 512,
  ),
  _LimitPreset(name: 'video', perServerLimit: 150, perIpLimit: 4, rateKb: 1024),
];

void showWebsiteLimitSheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteLimitSheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteLimitSheet extends StatelessWidget {
  const _WebsiteLimitSheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return WebsiteAsyncModalSheet<WebsiteLimitConfigDto>(
      provider: websiteLimitControllerProvider(websiteId),
      errorTitle: context.l10n.websites_loadTrafficLimitFailed,
      headerBuilder: (context, ref, async) => _LimitHeader(title: title),
      dataBuilder: (context, dto) => _LimitBody(websiteId: websiteId, dto: dto),
      onRetry: (ref) =>
          ref.invalidate(websiteLimitControllerProvider(websiteId)),
    );
  }
}

class _LimitHeader extends StatelessWidget {
  const _LimitHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CupertinoColors.systemTeal
                  .resolveFrom(context)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              TablerIcons.gauge,
              size: 22,
              color: CupertinoColors.systemTeal.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.websites_trafficLimit,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitBody extends ConsumerStatefulWidget {
  const _LimitBody({required this.websiteId, required this.dto});

  final int websiteId;
  final WebsiteLimitConfigDto dto;

  @override
  ConsumerState<_LimitBody> createState() => _LimitBodyState();
}

class _LimitBodyState extends ConsumerState<_LimitBody> {
  late bool _enabled;
  late _LimitPreset _preset;
  late final TextEditingController _perServerController;
  late final TextEditingController _perIpController;
  late final TextEditingController _rateKbController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.dto.enable;
    _preset = _matchPreset(widget.dto) ?? _limitPresets.first;
    _perServerController = TextEditingController();
    _perIpController = TextEditingController();
    _rateKbController = TextEditingController();
    _applyPreset(_preset, updateSelection: false);
    _applyDtoValues(widget.dto);
  }

  @override
  void didUpdateWidget(covariant _LimitBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dto != widget.dto) {
      _enabled = widget.dto.enable;
      _preset = _matchPreset(widget.dto) ?? _preset;
      _applyPreset(_preset, updateSelection: false);
      _applyDtoValues(widget.dto);
    }
  }

  @override
  void dispose() {
    _perServerController.dispose();
    _perIpController.dispose();
    _rateKbController.dispose();
    super.dispose();
  }

  _LimitPreset? _matchPreset(WebsiteLimitConfigDto dto) {
    if (dto.perServerLimit == null ||
        dto.perIpLimit == null ||
        dto.rateKb == null) {
      return null;
    }
    for (final preset in _limitPresets) {
      if (preset.perServerLimit == dto.perServerLimit &&
          preset.perIpLimit == dto.perIpLimit &&
          preset.rateKb == dto.rateKb) {
        return preset;
      }
    }
    return null;
  }

  void _applyDtoValues(WebsiteLimitConfigDto dto) {
    if (dto.perServerLimit != null) {
      _perServerController.text = '${dto.perServerLimit}';
    }
    if (dto.perIpLimit != null) {
      _perIpController.text = '${dto.perIpLimit}';
    }
    if (dto.rateKb != null) {
      _rateKbController.text = '${dto.rateKb}';
    }
  }

  void _applyPreset(_LimitPreset preset, {bool updateSelection = true}) {
    _perServerController.text = preset.perServerLimit != null
        ? '${preset.perServerLimit}'
        : '';
    _perIpController.text = preset.perIpLimit != null
        ? '${preset.perIpLimit}'
        : '';
    _rateKbController.text = preset.rateKb != null ? '${preset.rateKb}' : '';
    if (updateSelection) {
      _preset = preset;
    }
  }

  int? _parsePositiveInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _save() async {
    final perServer = _parsePositiveInt(_perServerController.text);
    final perIp = _parsePositiveInt(_perIpController.text);
    final rateKb = _parsePositiveInt(_rateKbController.text);
    if (perServer == null || perIp == null || rateKb == null) {
      showAppWarningToast(context.l10n.websites_positiveIntegerRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(websiteLimitControllerProvider(widget.websiteId).notifier)
          .save(
            enable: _enabled,
            perServerLimit: perServer,
            perIpLimit: perIp,
            rateKb: rateKb,
          );
      if (mounted) {
        showAppSuccessToast(
          _enabled
              ? context.l10n.websites_trafficLimitEnabled
              : context.l10n.websites_trafficLimitDisabled,
        );
      }
    } on AppNetworkException catch (error) {
      if (mounted) showAppErrorToast(error.message);
    } catch (error) {
      if (mounted) showAppErrorToast('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          icon: TablerIcons.toggle_left,
          title: context.l10n.websites_enableStatus,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _enabled
                      ? context.l10n.websites_trafficLimitEnabledStatus
                      : context.l10n.websites_trafficLimitDisabledStatus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label(context),
                  ),
                ),
              ),
              AppToggleSwitch(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: TablerIcons.layout_grid,
          title: context.l10n.websites_candidatePresets,
          child: _LimitPresetPicker(
            presets: _limitPresets,
            value: _preset,
            enabled: true,
            onChanged: (value) {
              setState(() => _applyPreset(value));
            },
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: TablerIcons.settings,
          title: context.l10n.websites_parameterSettings,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _enabled ? 1 : 0.6,
            child: Column(
              children: [
                if (!_enabled)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          TablerIcons.lock,
                          size: 14,
                          color: AppColors.secondaryLabel(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.websites_editAfterEnable,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _NumberFieldBlock(
                        label: context.l10n.websites_concurrencyLimit,
                        controller: _perServerController,
                        enabled: _enabled,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumberFieldBlock(
                        label: context.l10n.websites_perIpLimit,
                        controller: _perIpController,
                        enabled: _enabled,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NumberFieldBlock(
                        label: context.l10n.websites_requestRateLimit,
                        unit: 'KB/s',
                        controller: _rateKbController,
                        enabled: _enabled,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: TablerIcons.list_details,
          title: context.l10n.websites_limitItemsDescription,
          child: Column(
            children: [
              _DescRow(
                name: context.l10n.websites_concurrencyLimit,
                desc: context.l10n.websites_concurrencyLimitDesc,
              ),
              const SizedBox(height: 8),
              _DescRow(
                name: context.l10n.websites_perIpLimit,
                desc: context.l10n.websites_perIpLimitDesc,
              ),
              const SizedBox(height: 8),
              _DescRow(
                name: context.l10n.websites_requestRateLimit,
                desc: context.l10n.websites_requestRateLimitDesc,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SaveButton(
          saving: _saving,
          onPressed: (_saving || !_enabled) ? null : _save,
        ),
      ],
    );
  }
}

class _LimitPresetPicker extends StatelessWidget {
  const _LimitPresetPicker({
    required this.presets,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<_LimitPreset> presets;
  final _LimitPreset value;
  final bool enabled;
  final ValueChanged<_LimitPreset> onChanged;

  String _name(BuildContext context, _LimitPreset preset) {
    return switch (preset.name) {
      'forumBlog' => context.l10n.websites_limitPresetForumBlog,
      'imageSite' => context.l10n.websites_limitPresetImageSite,
      'downloadSite' => context.l10n.websites_limitPresetDownloadSite,
      'shop' => context.l10n.websites_limitPresetShop,
      'portal' => context.l10n.websites_limitPresetPortal,
      'enterprise' => context.l10n.websites_limitPresetEnterprise,
      'video' => context.l10n.websites_limitPresetVideo,
      _ => preset.name,
    };
  }

  String _summary(BuildContext context, _LimitPreset preset) =>
      context.l10n.websites_limitPresetSummary(
        _name(context, preset),
        '${preset.perServerLimit ?? '-'}',
        '${preset.perIpLimit ?? '-'}',
        '${preset.rateKb ?? '-'}',
      );

  @override
  Widget build(BuildContext context) {
    return AppInlinePicker<_LimitPreset>(
      options: presets
          .map(
            (preset) => AppPickerOption(
              value: preset,
              label: _summary(context, preset),
            ),
          )
          .toList(),
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      selectedColor: CupertinoColors.systemTeal.resolveFrom(context),
      anchorHeight: 42,
      itemHeight: 42,
      maxVisibleItems: 4,
    );
  }
}

class _NumberFieldBlock extends StatelessWidget {
  const _NumberFieldBlock({
    required this.label,
    required this.controller,
    required this.enabled,
    this.unit,
  });

  final String label;
  final String? unit;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.tertiaryBackground(context).withValues(alpha: 0.58)
                : CupertinoColors.systemGrey5.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: const BoxDecoration(
                    color: CupertinoColors.transparent,
                  ),
                ),
              ),
              if (unit != null)
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

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
                color: CupertinoColors.systemTeal.resolveFrom(context),
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
          child,
        ],
      ),
    );
  }
}

class _DescRow extends StatelessWidget {
  const _DescRow({required this.name, required this.desc});

  final String name;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.label(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoColors.activeBlue.resolveFrom(context);
    final active = onPressed != null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              TablerIcons.device_floppy,
              size: 17,
              color: color.withValues(alpha: active ? 1 : 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              saving ? context.l10n.websites_saving : context.l10n.common_save,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: active ? 1 : 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
