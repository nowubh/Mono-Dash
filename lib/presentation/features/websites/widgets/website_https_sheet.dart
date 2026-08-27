import 'dart:async';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:re_editor/re_editor.dart';

import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../data/dto/website/website_https_dto.dart';
import '../../../../data/dto/website/website_acme_account_dto.dart';
import '../../../../data/dto/website/website_ssl_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_picker.dart';
import '../providers/website_https_provider.dart';
import 'website_modal_sheet.dart';

part 'https/website_https_sheet_form.part.dart';

void showWebsiteHttpsSheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteHttpsSheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteHttpsSheet extends ConsumerStatefulWidget {
  const _WebsiteHttpsSheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  ConsumerState<_WebsiteHttpsSheet> createState() => _WebsiteHttpsSheetState();
}

class _WebsiteHttpsSheetState extends ConsumerState<_WebsiteHttpsSheet> {
  bool _initialized = false;
  bool _saving = false;

  // Form states
  bool _enable = false;
  String _httpConfig = 'HTTPToHTTPS';
  bool _hsts = true;
  bool _hstsIncludeSubDomains = false;
  bool _http3 = false;

  // SSL states
  String _sslType =
      'existed'; // Currently only existing certificates are supported.
  int _acmeAccountId = 0;
  int _websiteSslId = 0;

  // Protocol states
  List<String> _sslProtocols = ['TLSv1.2', 'TLSv1.3'];
  late final CodeLineEditingController _algorithmController;

  // Data
  List<WebsiteAcmeAccountDto> _acmeAccounts = [];
  List<WebsiteSslDto> _certificates = [];
  bool _loadingAccounts = false;
  bool _loadingCerts = false;

  @override
  void initState() {
    super.initState();
    _algorithmController = CodeLineEditingController();
    _algorithmController.text =
        'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:!aNULL:!eNULL:!EXPORT:!DSS:!DES:!RC4:!3DES:!MD5:!PSK:!KRB5:!SRP:!CAMELLIA:!SEED';
  }

  @override
  void dispose() {
    _algorithmController.dispose();
    super.dispose();
  }

  void _initFromState(WebsiteHttpsDto data) {
    if (_initialized) return;
    _enable = data.enable;
    if (data.httpConfig.isNotEmpty) _httpConfig = data.httpConfig;
    _hsts = data.hsts;
    _hstsIncludeSubDomains = data.hstsIncludeSubDomains;
    _http3 = data.http3;
    if (data.sslProtocol != null) _sslProtocols = List.from(data.sslProtocol!);
    if (data.algorithm.isNotEmpty) _algorithmController.text = data.algorithm;
    if (data.ssl != null && data.ssl!.id != 0) {
      _websiteSslId = data.ssl!.id;
      _acmeAccountId = data.ssl!.acmeAccountId;
    }
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAcmeAccounts();
    });
  }

  Future<void> _loadAcmeAccounts() async {
    if (!mounted) return;
    setState(() => _loadingAccounts = true);
    try {
      final accounts = await ref
          .read(websiteHttpsControllerProvider(widget.websiteId).notifier)
          .fetchAcmeAccounts();
      if (!mounted) return;
      setState(() {
        _acmeAccounts = accounts;
        _loadingAccounts = false;
      });
      if (_enable) {
        unawaited(_loadCertificates(_acmeAccountId));
      }
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(
        context.l10n.websites_loadAcmeAccountsFailed,
        description: '$e',
      );
      setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _loadCertificates(int accountId) async {
    if (!mounted) return;
    setState(() => _loadingCerts = true);
    try {
      final certs = await ref
          .read(websiteHttpsControllerProvider(widget.websiteId).notifier)
          .fetchCertificates(accountId);
      if (!mounted) return;
      setState(() {
        _certificates = certs;
        _loadingCerts = false;

        // Ensure websiteSSLId comes from the loaded certificate list.
        if (_certificates.isNotEmpty) {
          final exists = _certificates.any((c) => c.id == _websiteSslId);
          if (!exists) {
            _websiteSslId = _certificates.first.id;
          }
        } else {
          _websiteSslId = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(
        context.l10n.websites_loadCertificateListFailed,
        description: '$e',
      );
      setState(() => _loadingCerts = false);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final payload = {
        'acmeAccountID': _acmeAccountId,
        'enable': _enable,
        'websiteId': widget.websiteId,
        'websiteSSLId': _websiteSslId,
        'type': _sslType,
        'importType': _enable ? 'paste' : 'local',
        'privateKey': '',
        'certificate': '',
        'privateKeyPath': '',
        'certificatePath': '',
        'httpConfig': _httpConfig,
        'hsts': _hsts,
        'hstsIncludeSubDomains': _hstsIncludeSubDomains,
        'algorithm': _algorithmController.text,
        'SSLProtocol': _sslProtocols,
        'httpsPort':
            ref
                .read(websiteHttpsControllerProvider(widget.websiteId))
                .value
                ?.httpsPort ??
            '',
        'http3': _http3,
      };

      await ref
          .read(websiteHttpsControllerProvider(widget.websiteId).notifier)
          .updateHttps(payload);
      showAppSuccessToast(l10n.websites_httpsConfigUpdated);
    } on AppNetworkException catch (e) {
      showAppErrorToast(l10n.websites_saveFailed, description: e.message);
    } catch (e) {
      showAppErrorToast(l10n.websites_saveFailed, description: '$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebsiteAsyncModalSheet<WebsiteHttpsDto>(
      provider: websiteHttpsControllerProvider(widget.websiteId),
      errorTitle: context.l10n.websites_loadHttpsConfigFailed,
      headerBuilder: (context, ref, async) =>
          _Header(title: widget.title, onSave: _save, saving: _saving),
      dataBuilder: (context, data) {
        _initFromState(data);
        return _HttpsForm(
          enable: _enable,
          onEnableChanged: (v) {
            setState(() => _enable = v);
            if (v && _acmeAccounts.isEmpty) _loadAcmeAccounts();
          },
          httpConfig: _httpConfig,
          onHttpConfigChanged: (v) =>
              setState(() => _httpConfig = v ?? 'HTTPToHTTPS'),
          hsts: _hsts,
          onHstsChanged: (v) => setState(() => _hsts = v),
          hstsIncludeSubDomains: _hstsIncludeSubDomains,
          onHstsSubChanged: (v) => setState(() => _hstsIncludeSubDomains = v),
          http3: _http3,
          onHttp3Changed: (v) => setState(() => _http3 = v),
          sslType: _sslType,
          onSslTypeChanged: (v) => setState(() => _sslType = v ?? 'existed'),
          acmeAccountId: _acmeAccountId,
          onAcmeAccountChanged: (v) {
            setState(() => _acmeAccountId = v ?? 0);
            _loadCertificates(v ?? 0);
          },
          websiteSslId: _websiteSslId,
          onWebsiteSslChanged: (v) => setState(() => _websiteSslId = v ?? 0),
          sslProtocols: _sslProtocols,
          onSslProtocolsChanged: (v) => setState(() => _sslProtocols = v),
          algorithmController: _algorithmController,
          acmeAccounts: _acmeAccounts,
          certificates: _certificates,
          loadingAccounts: _loadingAccounts,
          loadingCerts: _loadingCerts,
          httpsPorts: data.httpsPort,
        );
      },
      onRetry: (ref) =>
          ref.invalidate(websiteHttpsControllerProvider(widget.websiteId)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onSave,
    required this.saving,
  });

  final String title;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.separator(context).withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen
                  .resolveFrom(context)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              TablerIcons.lock,
              size: 20,
              color: CupertinoColors.systemGreen.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HTTPS',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size.zero,
            color: CupertinoColors.activeBlue,
            borderRadius: BorderRadius.circular(8),
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    ),
                  )
                : Text(
                    context.l10n.common_save,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
