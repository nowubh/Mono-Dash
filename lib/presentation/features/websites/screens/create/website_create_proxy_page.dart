import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/localization/l10n_x.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/dto/website/website_acme_account_dto.dart';
import '../../../../../data/dto/website/website_create_req.dart';
import '../../../../../data/dto/website/website_domain_req.dart';
import '../../../../../data/dto/website/website_group_dto.dart';
import '../../../../../data/dto/website/website_ssl_dto.dart';
import '../../../server_detail/providers/active_server_provider.dart';
import '../../../../common/app_toast.dart';
import '../../../../common/components/app_picker.dart';
import '../../../../common/components/frosted_action_button.dart';
import '../../../../common/components/frosted_scaffold.dart';
import '../../providers/website_create_provider.dart';

class WebsiteCreateProxyPage extends StatelessWidget {
  const WebsiteCreateProxyPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: const _WebsiteCreateProxyForm(),
    );
  }
}

class _WebsiteCreateProxyForm extends ConsumerStatefulWidget {
  const _WebsiteCreateProxyForm();

  @override
  ConsumerState<_WebsiteCreateProxyForm> createState() =>
      _WebsiteCreateProxyPageState();
}

class _WebsiteCreateProxyPageState
    extends ConsumerState<_WebsiteCreateProxyForm> {
  static const double _formControlHeight = 40;

  final _aliasController = TextEditingController();
  final _domainController = TextEditingController();
  final _portController = TextEditingController(text: '80');
  final _proxyAddressController = TextEditingController();
  final _remarkController = TextEditingController();

  bool _isSubmitting = false;
  int? _selectedGroupId;
  bool _enableSSL = false;
  int _selectedAcmeAccountId = 0;
  int? _selectedSslId;
  bool _enableIPv6 = false;
  String _proxyProtocol = 'http://';

  @override
  void dispose() {
    _aliasController.dispose();
    _domainController.dispose();
    _portController.dispose();
    _proxyAddressController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final metadata = ref.read(websiteCreateMetadataProvider).valueOrNull;
    final alias = _aliasController.text.trim();
    final domain = _domainController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText) ?? 80;
    final groupId = _selectedGroupId ?? metadata?.defaultGroup?.id ?? 1;
    final sslId = _selectedSslId ?? 0;
    final proxyAddress = _proxyAddressController.text.trim();

    if (alias.isEmpty || domain.isEmpty) {
      _showError(context.l10n.websites_primaryDomainAliasRequired);
      return;
    }
    if (proxyAddress.isEmpty) {
      _showError(context.l10n.websites_proxyAddressRequired);
      return;
    }
    if (_enableSSL && sslId == 0) {
      _showError(context.l10n.websites_sslCertificateRequired);
      return;
    }

    setState(() => _isSubmitting = true);

    final proxyUrl = '$_proxyProtocol$proxyAddress';

    final req = WebsiteCreateReq(
      alias: alias,
      type: 'proxy',
      domains: [WebsiteDomainReq(domain: domain, host: domain, port: port)],
      webSiteGroupID: groupId,
      proxy: proxyUrl,
      remark: _remarkController.text.trim(),
      taskID: const Uuid().v4(),
      enableSSL: _enableSSL,
      websiteSSLID: _enableSSL ? sslId : 0,
      acmeAccountID: _enableSSL ? _selectedAcmeAccountId : 0,
      ipv6: _enableIPv6,
    );

    final success = await ref
        .read(websiteCreateControllerProvider.notifier)
        .createWebsite(req);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        showAppSuccessToast(
          context.l10n.websites_createSuccess,
          description: context.l10n.websites_proxySiteCreated(alias, domain),
        );
        Navigator.of(context).pop();
      } else {
        final state = ref.read(websiteCreateControllerProvider);
        if (state.hasError) {
          _showError(
            state.error.toString(),
            title: context.l10n.websites_createFailed,
          );
        } else {
          _showError(
            context.l10n.websites_tryAgainLater,
            title: context.l10n.websites_createFailed,
          );
        }
      }
    }
  }

  void _showError(String message, {String? title}) {
    final effectiveTitle = title ?? context.l10n.websites_notice;
    if (effectiveTitle == context.l10n.websites_createFailed) {
      showAppErrorToast(effectiveTitle, description: message);
    } else {
      showAppWarningToast(effectiveTitle, description: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(websiteCreateMetadataProvider);
    final acmeAccountsAsync = _enableSSL
        ? ref.watch(websiteAcmeAccountsProvider)
        : const AsyncValue<List<WebsiteAcmeAccountDto>>.data([]);
    final sslListAsync = _enableSSL
        ? ref.watch(websiteSslListProvider(_selectedAcmeAccountId))
        : const AsyncValue<List<WebsiteSslDto>>.data([]);

    return FrostedScaffold(
      title: context.l10n.websites_createProxySite,
      trailingBuilder: (isDark, isOverlapping) => FrostedActionButton(
        text: context.l10n.common_create,
        isLoading: _isSubmitting,
        onTap: _isSubmitting ? null : _submit,
        isDark: isDark,
        isOverlapping: isOverlapping,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: FrostedScaffold.contentTopPadding(context) + 14,
                left: 14,
                right: 14,
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionCard(
                    context,
                    icon: TablerIcons.world_www,
                    title: context.l10n.websites_basicConfig,
                    child: Column(
                      children: [
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_primaryDomain,
                          placeholder: 'example.com',
                          controller: _domainController,
                        ),
                        const SizedBox(height: 12),
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_alias,
                          placeholder: context.l10n.websites_aliasPlaceholder,
                          controller: _aliasController,
                        ),
                        metadataAsync.maybeWhen(
                          data: (metadata) => _buildRootHint(
                            context,
                            context.l10n.websites_relativeToRoot(
                              metadata.sitesRootDir,
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: metadataAsync.when(
                                data: (metadata) => _buildGroupPickerField(
                                  context,
                                  groups: metadata.groups,
                                  selectedId:
                                      _selectedGroupId ??
                                      metadata.defaultGroup?.id ??
                                      1,
                                ),
                                loading: () => _buildStaticRow(
                                  context,
                                  context.l10n.websites_group,
                                  context.l10n.common_loading,
                                ),
                                error: (err, _) => _buildStaticRow(
                                  context,
                                  context.l10n.websites_group,
                                  context.l10n.common_loadingFailed,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputRow(
                                context,
                                label: context.l10n.websites_port,
                                placeholder: '80',
                                controller: _portController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    context,
                    icon: TablerIcons.arrow_big_right_lines,
                    title: context.l10n.websites_proxySettings,
                    child: Column(
                      children: [
                        _buildProtocolPickerField(context),
                        const SizedBox(height: 12),
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_proxyAddress,
                          placeholder: _proxyProtocol.isEmpty
                              ? 'socks5://127.0.0.1:1080'
                              : '127.0.0.1:8080',
                          controller: _proxyAddressController,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    context,
                    icon: TablerIcons.shield_lock,
                    title: context.l10n.websites_sslAndAccess,
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          label: context.l10n.websites_enableSsl,
                          icon: TablerIcons.lock,
                          value: _enableSSL,
                          onChanged: (value) {
                            setState(() {
                              _enableSSL = value;
                              if (!value) _selectedSslId = null;
                            });
                          },
                        ),
                        if (_enableSSL) ...[
                          const SizedBox(height: 12),
                          acmeAccountsAsync.when(
                            data: (accounts) =>
                                _buildAcmePickerField(context, accounts),
                            loading: () => _buildStaticRow(
                              context,
                              context.l10n.websites_acmeAccount,
                              context.l10n.common_loading,
                            ),
                            error: (err, _) => _buildStaticRow(
                              context,
                              context.l10n.websites_acmeAccount,
                              context.l10n.common_loadingFailed,
                            ),
                          ),
                          const SizedBox(height: 12),
                          sslListAsync.when(
                            data: (certs) =>
                                _buildSslPickerField(context, certs),
                            loading: () => _buildStaticRow(
                              context,
                              context.l10n.websites_certificate,
                              context.l10n.common_loading,
                            ),
                            error: (err, _) => _buildStaticRow(
                              context,
                              context.l10n.websites_certificate,
                              context.l10n.common_loadingFailed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    context,
                    icon: TablerIcons.notes,
                    title: context.l10n.websites_otherInfo,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_remark,
                          placeholder: context.l10n.websites_optional,
                          controller: _remarkController,
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchRow(
                          context,
                          label: context.l10n.containers_enableIpv6,
                          icon: TablerIcons.network,
                          value: _enableIPv6,
                          onChanged: (value) =>
                              setState(() => _enableIPv6 = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Card ──────────────────────────────────────────────

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
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
          child,
        ],
      ),
    );
  }

  // ── Input Row ─────────────────────────────────────────────────

  Widget _buildInputRow(
    BuildContext context, {
    required String label,
    required String placeholder,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
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
        SizedBox(
          height: _formControlHeight,
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            keyboardType: keyboardType,
            autocorrect: false,
            enableSuggestions: false,
            minLines: 1,
            maxLines: 1,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(
                context,
              ).withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(10),
            ),
            style: TextStyle(fontSize: 14, color: AppColors.label(context)),
            placeholderStyle: TextStyle(
              fontSize: 14,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ),
      ],
    );
  }

  // ── Root Hint ─────────────────────────────────────────────────

  Widget _buildRootHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(
            TablerIcons.folder_root,
            size: 14,
            color: AppColors.tertiaryLabel(context),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Static Row ────────────────────────────────────────────────

  Widget _buildStaticRow(BuildContext context, String label, String value) {
    return _buildFieldShell(
      context,
      label: label,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryLabel(context),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Switch Row ────────────────────────────────────────────────

  Widget _buildSwitchRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final color = CupertinoColors.systemOrange.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.label(context),
              ),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── Field Shell ───────────────────────────────────────────────

  Widget _buildFieldShell(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
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
          height: _formControlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.tertiaryBackground(
              context,
            ).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ],
    );
  }

  // ── Protocol Picker ───────────────────────────────────────────

  List<AppPickerOption<String>> _protocolOptions(BuildContext context) => [
    const AppPickerOption(value: 'http://', label: 'http://'),
    const AppPickerOption(value: 'https://', label: 'https://'),
    AppPickerOption(value: '', label: context.l10n.websites_other),
  ];

  Widget _buildProtocolPickerField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_protocol,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<String>(
          value: _proxyProtocol,
          options: _protocolOptions(context),
          anchorHeight: _formControlHeight,
          onChanged: (value) => setState(() => _proxyProtocol = value),
        ),
      ],
    );
  }

  // ── Group Picker ──────────────────────────────────────────────

  Widget _buildGroupPickerField(
    BuildContext context, {
    required List<WebsiteGroupDto> groups,
    required int selectedId,
  }) {
    if (groups.isEmpty) {
      return _buildStaticRow(
        context,
        context.l10n.websites_group,
        context.l10n.websites_noGroups,
      );
    }
    final options = [
      for (final g in groups) AppPickerOption<int>(value: g.id, label: g.name),
    ];
    final effectiveId = groups.any((g) => g.id == selectedId)
        ? selectedId
        : (groups.isNotEmpty ? groups.first.id : selectedId);
    if (effectiveId != selectedId && groups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedGroupId = effectiveId);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_group,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<int>(
          value: effectiveId,
          options: options,
          enabled: options.isNotEmpty,
          anchorHeight: _formControlHeight,
          onChanged: (id) => setState(() => _selectedGroupId = id),
        ),
      ],
    );
  }

  // ── ACME Picker ───────────────────────────────────────────────

  String _acmePickerLabel(WebsiteAcmeAccountDto a) {
    if (a.id == 0) return a.email;
    final email = a.email;
    final type = a.type;
    if (email.isEmpty && type.isEmpty) return 'ACME #${a.id}';
    if (type.isEmpty) return email;
    if (email.isEmpty) return type;
    return '$email ($type)';
  }

  List<AppPickerOption<int>> _acmePickerOptions(
    List<WebsiteAcmeAccountDto> accounts,
  ) {
    final list = List<WebsiteAcmeAccountDto>.from(accounts);
    if (!list.any((a) => a.id == 0)) {
      list.insert(0, const WebsiteAcmeAccountDto.manual());
    }
    return [
      for (final a in list)
        AppPickerOption<int>(value: a.id, label: _acmePickerLabel(a)),
    ];
  }

  Widget _buildAcmePickerField(
    BuildContext context,
    List<WebsiteAcmeAccountDto> accounts,
  ) {
    final options = _acmePickerOptions(accounts);
    final value = options.any((o) => o.value == _selectedAcmeAccountId)
        ? _selectedAcmeAccountId
        : options.first.value;
    if (value != _selectedAcmeAccountId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedAcmeAccountId = value;
            _selectedSslId = null;
          });
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_acmeAccount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<int>(
          value: value,
          options: options,
          onChanged: (id) {
            setState(() {
              _selectedAcmeAccountId = id;
              _selectedSslId = null;
            });
          },
        ),
      ],
    );
  }

  // ── SSL Picker ────────────────────────────────────────────────

  String _certValidityDaysLabel(BuildContext context, String expireDate) {
    if (expireDate.isEmpty) return context.l10n.websites_validityUnknown;
    if (expireDate == '9999-12-31T00:00:00Z') {
      return context.l10n.websites_validityNeverExpires;
    }
    if (expireDate.startsWith('0001-')) {
      return context.l10n.websites_validityUnknown;
    }

    final expireAt = DateTime.tryParse(expireDate)?.toLocal();
    if (expireAt == null) {
      return context.l10n.websites_validityValue(expireDate);
    }

    final now = DateTime.now();
    if (!expireAt.isAfter(now)) return context.l10n.websites_validityExpired;

    final days = expireAt.difference(now).inDays;
    if (days >= 1) return context.l10n.websites_validityDays(days);
    return context.l10n.websites_validityLessThanOneDay;
  }

  String _certPickerLabel(BuildContext context, WebsiteSslDto c) {
    final domain = c.primaryDomain.isEmpty
        ? context.l10n.websites_certificateNumber(c.id)
        : c.primaryDomain;
    return '$domain · ${_certValidityDaysLabel(context, c.expireDate)}';
  }

  Widget _buildSslPickerField(BuildContext context, List<WebsiteSslDto> certs) {
    if (certs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.websites_certificate,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(
                context,
              ).withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.websites_noAvailableCertificate,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),
        ],
      );
    }

    final firstId = certs.first.id;
    var effectiveSslId = _selectedSslId;
    if (effectiveSslId == null || !certs.any((c) => c.id == effectiveSslId)) {
      effectiveSslId = firstId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSslId = firstId);
      });
    }

    final options = [
      for (final c in certs)
        AppPickerOption<int>(value: c.id, label: _certPickerLabel(context, c)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_certificate,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<int>(
          value: effectiveSslId,
          options: options,
          onChanged: (id) => setState(() => _selectedSslId = id),
        ),
      ],
    );
  }
}
