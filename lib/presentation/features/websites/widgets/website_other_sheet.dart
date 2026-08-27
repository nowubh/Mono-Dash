import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/website_detail_dto.dart';
import '../../../../data/dto/website/website_group_dto.dart';
import '../../../../data/dto/website/website_update_req.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_picker.dart';
import '../providers/website_detail_provider.dart';
import '../providers/website_other_provider.dart';
import '../providers/websites_provider.dart';
import 'website_modal_sheet.dart';

Future<void> showWebsiteOtherSheet(
  BuildContext context, {
  required WebsiteDetailDto detail,
}) async {
  await showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteOtherSheet(detail: detail),
  );
}

class _WebsiteOtherSheet extends StatelessWidget {
  const _WebsiteOtherSheet({required this.detail});

  final WebsiteDetailDto detail;

  @override
  Widget build(BuildContext context) {
    return WebsiteAsyncModalSheet<List<WebsiteGroupDto>>(
      provider: websiteGroupsProvider,
      errorTitle: context.l10n.websites_loadGroupsFailed,
      headerBuilder: (context, ref, groupsAsync) => const _OtherHeader(),
      dataBuilder: (context, groups) =>
          _OtherContent(detail: detail, groups: groups),
      onRetry: (ref) => ref.invalidate(websiteGroupsProvider),
    );
  }
}

class _OtherHeader extends StatelessWidget {
  const _OtherHeader();

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
              color: CupertinoColors.systemGrey
                  .resolveFrom(context)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              TablerIcons.dots,
              size: 22,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.websites_otherSettings,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                    letterSpacing: -0.5,
                  ),
                ),
                // const SizedBox(height: 2),
                // Text(
                //   'Name, group, IPv6, and favorite marker',
                //   style: TextStyle(
                //     fontSize: 12,
                //     color: AppColors.secondaryLabel(context),
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherContent extends ConsumerStatefulWidget {
  const _OtherContent({required this.detail, required this.groups});

  final WebsiteDetailDto detail;
  final List<WebsiteGroupDto> groups;

  @override
  ConsumerState<_OtherContent> createState() => _OtherContentState();
}

class _OtherContentState extends ConsumerState<_OtherContent> {
  late final TextEditingController _primaryDomainController;
  late final TextEditingController _aliasController;
  late final TextEditingController _remarkController;
  late int _groupId;
  late bool _ipv6;
  late bool _favorite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final website = widget.detail.website;
    _primaryDomainController = TextEditingController(
      text: website.primaryDomain,
    );
    _aliasController = TextEditingController(text: widget.detail.alias);
    _remarkController = TextEditingController(text: website.remark);
    _groupId = _initialGroupId();
    _ipv6 = widget.detail.ipv6;
    _favorite = widget.detail.favorite;
  }

  @override
  void didUpdateWidget(covariant _OtherContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups &&
        !widget.groups.any((group) => group.id == _groupId)) {
      _groupId = _initialGroupId();
    }
  }

  @override
  void dispose() {
    _primaryDomainController.dispose();
    _aliasController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  int _initialGroupId() {
    final detailGroupId = widget.detail.webSiteGroupId;
    if (widget.groups.any((group) => group.id == detailGroupId)) {
      return detailGroupId;
    }
    final defaultGroup = widget.groups.where((group) => group.isDefault);
    if (defaultGroup.isNotEmpty) return defaultGroup.first.id;
    return widget.groups.isEmpty ? detailGroupId : widget.groups.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final groupOptions = widget.groups
        .map(
          (group) => AppPickerOption<int>(
            value: group.id,
            label: group.isDefault
                ? '${group.name} · ${context.l10n.websites_default}'
                : group.name,
          ),
        )
        .toList();

    return Column(
      children: [
        _SectionCard(
          icon: TablerIcons.edit,
          title: context.l10n.websites_basicInfo,
          child: Column(
            children: [
              _TextFieldBlock(
                label: context.l10n.websites_websiteName,
                placeholder: context.l10n.websites_primaryDomainExample,
                controller: _primaryDomainController,
              ),
              const SizedBox(height: 12),
              _TextFieldBlock(
                label: context.l10n.websites_websiteAlias,
                placeholder: context.l10n.websites_websiteAliasPlaceholder,
                controller: _aliasController,
                readOnly: true,
              ),
              const SizedBox(height: 12),
              _TextFieldBlock(
                label: context.l10n.websites_remark,
                placeholder: context.l10n.websites_optionalRemark,
                controller: _remarkController,
                minLines: 3,
                maxLines: 5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: TablerIcons.category,
          title: context.l10n.websites_group,
          child: groupOptions.isEmpty
              ? _EmptyGroupNotice()
              : AppInlinePicker<int>(
                  options: groupOptions,
                  value: _groupId,
                  onChanged: (value) => setState(() => _groupId = value),
                  selectedColor: CupertinoColors.systemBlue.resolveFrom(
                    context,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: TablerIcons.adjustments,
          title: context.l10n.websites_switches,
          child: Column(
            children: [
              _SwitchRow(
                icon: TablerIcons.network,
                title: context.l10n.websites_listenIpv6,
                subtitle: context.l10n.websites_listenIpv6Subtitle,
                value: _ipv6,
                onChanged: (value) => setState(() => _ipv6 = value),
              ),
              const _CardDivider(),
              _SwitchRow(
                icon: _favorite ? TablerIcons.star_filled : TablerIcons.star,
                title: context.l10n.websites_favoriteWebsite,
                subtitle: context.l10n.websites_favoriteWebsiteSubtitle,
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(
          icon: TablerIcons.device_floppy,
          label: _saving
              ? context.l10n.websites_saving
              : context.l10n.websites_saveChanges,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    final primaryDomain = _primaryDomainController.text.trim();
    // Alias is bound to the panel directory and cannot be changed here.
    final alias = widget.detail.alias.trim();
    final remark = _remarkController.text.trim();

    if (primaryDomain.isEmpty) {
      showAppWarningToast(context.l10n.websites_websiteNameRequired);
      return;
    }
    if (alias.isEmpty) {
      showAppWarningToast(context.l10n.websites_websiteAliasRequired);
      return;
    }
    if (widget.groups.isNotEmpty &&
        !widget.groups.any((group) => group.id == _groupId)) {
      showAppWarningToast(context.l10n.websites_selectWebsiteGroup);
      return;
    }

    setState(() => _saving = true);
    try {
      final req = WebsiteUpdateReq(
        id: widget.detail.website.id,
        primaryDomain: primaryDomain,
        remark: remark,
        webSiteGroupId: _groupId,
        ipv6: _ipv6,
        alias: alias,
        favorite: _favorite,
      );
      await ref
          .read(
            websiteOtherControllerProvider(widget.detail.website.id).notifier,
          )
          .save(req);
      if (!mounted) return;
      final state = ref.read(
        websiteOtherControllerProvider(widget.detail.website.id),
      );
      final error = state.error;
      if (error != null) {
        _showSaveError(error);
        return;
      }
      ref.invalidate(websiteDetailProvider(widget.detail.website.id));
      ref.invalidate(websitesControllerProvider);
      showAppSuccessToast(context.l10n.websites_websiteInfoUpdated);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showSaveError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSaveError(Object error) {
    final message = error is AppNetworkException ? error.message : '$error';
    showAppErrorToast(context.l10n.websites_saveFailed, description: message);
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
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.82),
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
              Icon(icon, size: 17, color: AppColors.secondaryLabel(context)),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
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

class _TextFieldBlock extends StatelessWidget {
  const _TextFieldBlock({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
    this.readOnly = false,
  });

  final String label;
  final String placeholder;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final labelColor = AppColors.secondaryLabel(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              // if (readOnly) ...[
              //   const SizedBox(width: 8),
              //   Text(
              //     'Cannot be changed',
              //     style: TextStyle(
              //       fontSize: 11,
              //       fontWeight: FontWeight.w500,
              //       color: labelColor.withValues(alpha: 0.85),
              //     ),
              //   ),
              // ],
            ],
          ),
        ),
        CupertinoTextField(
          controller: controller,
          readOnly: readOnly,
          minLines: minLines,
          maxLines: maxLines,
          autocorrect: false,
          enableSuggestions: false,
          placeholder: placeholder,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.tertiaryBackground(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(13),
          ),
          style: TextStyle(
            fontSize: 14,
            color: readOnly
                ? AppColors.secondaryLabel(context)
                : AppColors.label(context),
          ),
          placeholderStyle: TextStyle(
            fontSize: 14,
            color: AppColors.tertiaryLabel(context),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  (value
                          ? CupertinoColors.systemBlue
                          : CupertinoColors.systemGrey)
                      .resolveFrom(context)
                      .withValues(alpha: value ? 0.14 : 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  (value
                          ? CupertinoColors.systemBlue
                          : CupertinoColors.systemGrey)
                      .resolveFrom(context),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _EmptyGroupNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange
            .resolveFrom(context)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            TablerIcons.alert_triangle,
            size: 17,
            color: CupertinoColors.systemOrange.resolveFrom(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.websites_groupFallbackWarning,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        height: 0.5,
        color: AppColors.separator(context).withValues(alpha: 0.18),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 46,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBlue
              .resolveFrom(context)
              .withValues(alpha: enabled ? 1 : 0.36),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (enabled)
              Icon(icon, size: 18, color: CupertinoColors.white)
            else
              const CupertinoActivityIndicator(color: CupertinoColors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
