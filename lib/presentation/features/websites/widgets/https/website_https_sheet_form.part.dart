part of '../website_https_sheet.dart';

class _HttpsForm extends StatelessWidget {
  const _HttpsForm({
    required this.enable,
    required this.onEnableChanged,
    required this.httpConfig,
    required this.onHttpConfigChanged,
    required this.hsts,
    required this.onHstsChanged,
    required this.hstsIncludeSubDomains,
    required this.onHstsSubChanged,
    required this.http3,
    required this.onHttp3Changed,
    required this.sslType,
    required this.onSslTypeChanged,
    required this.acmeAccountId,
    required this.onAcmeAccountChanged,
    required this.websiteSslId,
    required this.onWebsiteSslChanged,
    required this.sslProtocols,
    required this.onSslProtocolsChanged,
    required this.algorithmController,
    required this.acmeAccounts,
    required this.certificates,
    required this.loadingAccounts,
    required this.loadingCerts,
    required this.httpsPorts,
  });

  final bool enable;
  final ValueChanged<bool> onEnableChanged;
  final String httpConfig;
  final ValueChanged<String?> onHttpConfigChanged;
  final bool hsts;
  final ValueChanged<bool> onHstsChanged;
  final bool hstsIncludeSubDomains;
  final ValueChanged<bool> onHstsSubChanged;
  final bool http3;
  final ValueChanged<bool> onHttp3Changed;
  final String sslType;
  final ValueChanged<String?> onSslTypeChanged;
  final int acmeAccountId;
  final ValueChanged<int?> onAcmeAccountChanged;
  final int websiteSslId;
  final ValueChanged<int?> onWebsiteSslChanged;
  final List<String> sslProtocols;
  final ValueChanged<List<String>> onSslProtocolsChanged;
  final CodeLineEditingController algorithmController;
  final List<WebsiteAcmeAccountDto> acmeAccounts;
  final List<WebsiteSslDto> certificates;
  final bool loadingAccounts;
  final bool loadingCerts;
  final String httpsPorts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        _FormSection(
          icon: TablerIcons.settings,
          title: l10n.websites_basicConfig,
          children: [
            _CompactSwitchTile(
              icon: TablerIcons.lock,
              title: l10n.websites_enableHttps,
              value: enable,
              onChanged: onEnableChanged,
            ),
            if (enable) ...[
              const SizedBox(height: 12),
              _FormInput(
                label: l10n.websites_listenPortsReadonly,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryBackground(
                      context,
                    ).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    httpsPorts,
                    style: TextStyle(color: AppColors.secondaryLabel(context)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FormInput(
                label: l10n.websites_httpOptions,
                child: AppInlinePicker<String>(
                  value: httpConfig,
                  options: [
                    AppPickerOption(
                      value: 'HTTPToHTTPS',
                      label: l10n.websites_httpRedirectToHttps,
                    ),
                    AppPickerOption(
                      value: 'HTTPAlso',
                      label: l10n.websites_httpAlsoAccessible,
                    ),
                    AppPickerOption(
                      value: 'HTTPSOnly',
                      label: l10n.websites_httpsOnly,
                    ),
                  ],
                  onChanged: onHttpConfigChanged,
                ),
              ),
              const SizedBox(height: 16),
              _CompactSwitchTile(
                icon: TablerIcons.shield_lock,
                title: l10n.websites_enableHsts,
                value: hsts,
                onChanged: onHstsChanged,
              ),
              const SizedBox(height: 8),
              _CompactSwitchTile(
                icon: TablerIcons.hierarchy_2,
                title: l10n.websites_enableHstsSubdomains,
                value: hstsIncludeSubDomains,
                onChanged: onHstsSubChanged,
              ),
              const SizedBox(height: 16),
              _CompactSwitchTile(
                icon: TablerIcons.bolt,
                title: l10n.websites_enableHttp3,
                subtitle: l10n.websites_http3Subtitle,
                value: http3,
                onChanged: onHttp3Changed,
              ),
            ],
          ],
        ),
        if (enable) ...[
          const SizedBox(height: 16),
          _FormSection(
            icon: TablerIcons.certificate,
            title: l10n.websites_certificateSettings,
            children: [
              _FormInput(
                label: l10n.websites_sslOptions,
                child: AppInlinePicker<String>(
                  value: sslType,
                  options: [
                    AppPickerOption(
                      value: 'existed',
                      label: l10n.websites_selectExistingCertificate,
                    ),
                  ],
                  onChanged: onSslTypeChanged,
                ),
              ),
              const SizedBox(height: 12),
              _FormInput(
                label: l10n.websites_acmeAccount,
                child: loadingAccounts
                    ? const CupertinoActivityIndicator()
                    : AppInlinePicker<int>(
                        value: acmeAccountId,
                        options: acmeAccounts
                            .map(
                              (a) => AppPickerOption(
                                value: a.id,
                                label: a.id == 0
                                    ? a.email
                                    : '${a.email} (${a.type})',
                              ),
                            )
                            .toList(),
                        onChanged: onAcmeAccountChanged,
                      ),
              ),
              const SizedBox(height: 12),
              _FormInput(
                label: l10n.websites_selectCertificate,
                child: loadingCerts
                    ? const CupertinoActivityIndicator()
                    : certificates.isEmpty
                    ? Text(
                        l10n.websites_noCertificatesForAccount,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.tertiaryLabel(context),
                        ),
                      )
                    : AppInlinePicker<int>(
                        value: websiteSslId,
                        options: certificates
                            .map(
                              (c) => AppPickerOption(
                                value: c.id,
                                label: c.displayName,
                              ),
                            )
                            .toList(),
                        onChanged: onWebsiteSslChanged,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: TablerIcons.shield_check,
            title: l10n.websites_sslProtocolSettings,
            children: [
              _FormInput(
                label: l10n.websites_supportedProtocolVersions,
                child: Column(
                  children: [
                    _ProtocolToggle(
                      label: 'TLS 1.0',
                      value: sslProtocols.contains('TLSv1'),
                      onChanged: (v) => _toggleProtocol('TLSv1'),
                      isUnsafe: true,
                    ),
                    _ProtocolToggle(
                      label: 'TLS 1.1',
                      value: sslProtocols.contains('TLSv1.1'),
                      onChanged: (v) => _toggleProtocol('TLSv1.1'),
                      isUnsafe: true,
                    ),
                    _ProtocolToggle(
                      label: 'TLS 1.2',
                      value: sslProtocols.contains('TLSv1.2'),
                      onChanged: (v) => _toggleProtocol('TLSv1.2'),
                    ),
                    _ProtocolToggle(
                      label: 'TLS 1.3',
                      value: sslProtocols.contains('TLSv1.3'),
                      onChanged: (v) => _toggleProtocol('TLSv1.3'),
                    ),
                    if (sslProtocols.contains('TLSv1') ||
                        sslProtocols.contains('TLSv1.1'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.alert_triangle,
                              size: 14,
                              color: CupertinoColors.systemOrange.resolveFrom(
                                context,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                l10n.websites_insecureTlsSelected,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.systemOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _FormInput(
                label: l10n.websites_cipherSuites,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.background(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.separator(
                        context,
                      ).withValues(alpha: 0.1),
                    ),
                  ),
                  child: CodeEditor(
                    controller: algorithmController,
                    style: CodeEditorStyle(
                      fontSize: 12,
                      textColor: AppColors.label(context),
                      backgroundColor: CupertinoColors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 20),
      ],
    );
  }

  void _toggleProtocol(String protocol) {
    final newList = List<String>.from(sslProtocols);
    if (newList.contains(protocol)) {
      newList.remove(protocol);
    } else {
      newList.add(protocol);
    }
    onSslProtocolsChanged(newList);
  }
}

class _ProtocolToggle extends StatelessWidget {
  const _ProtocolToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isUnsafe = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isUnsafe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? CupertinoColors.activeBlue
                    .resolveFrom(context)
                    .withValues(alpha: 0.1)
              : AppColors.tertiaryBackground(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              value ? TablerIcons.checkbox : TablerIcons.square,
              size: 16,
              color: value
                  ? CupertinoColors.activeBlue
                  : AppColors.tertiaryLabel(context),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                color: value
                    ? AppColors.label(context)
                    : AppColors.secondaryLabel(context),
              ),
            ),
            if (isUnsafe && value) ...[
              const Spacer(),
              Icon(
                TablerIcons.shield_off,
                size: 14,
                color: CupertinoColors.systemOrange.resolveFrom(context),
              ),
            ],
          ],
        ),
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
                color: CupertinoColors.systemGreen.resolveFrom(context),
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
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.label(context),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ),
              ],
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
