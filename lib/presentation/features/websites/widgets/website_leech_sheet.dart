import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/website_leech_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_picker.dart';
import '../providers/website_leech_provider.dart';
import 'website_modal_sheet.dart';

part 'leech/website_leech_sheet_form.part.dart';

void showWebsiteLeechSheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteLeechSheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteLeechSheet extends ConsumerStatefulWidget {
  const _WebsiteLeechSheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  ConsumerState<_WebsiteLeechSheet> createState() => _WebsiteLeechSheetState();
}

class _WebsiteLeechSheetState extends ConsumerState<_WebsiteLeechSheet> {
  final _domainController = TextEditingController();
  final _customExtController = TextEditingController();
  final _cacheTimeController = TextEditingController(text: '30');

  bool _enable = false;
  Set<String> _selectedExtensions = {};
  List<String> _allowedDomains = [];
  bool _noneRef = false;
  bool _blocked = false;
  String _returnCode = '403';
  bool _cache = false;
  String _cacheUint = 'd';
  bool _logEnable = true;

  bool _saving = false;
  bool _initialized = false;

  final List<String> _commonExtensions = [
    'js',
    'css',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'webm',
    'avif',
    'ico',
    'bmp',
    'swf',
    'eot',
    'svg',
    'ttf',
    'woff',
    'woff2',
  ];

  @override
  void dispose() {
    _domainController.dispose();
    _customExtController.dispose();
    _cacheTimeController.dispose();
    super.dispose();
  }

  void _initFromDto(WebsiteLeechDto dto) {
    if (_initialized) return;
    _enable = dto.enable;
    _noneRef = dto.noneRef;
    _blocked = dto.blocked;
    _returnCode = dto.returnCodeAlt.isNotEmpty
        ? dto.returnCodeAlt
        : (dto.returnCode.isNotEmpty ? dto.returnCode : '403');
    _cache = dto.cache;
    _cacheTimeController.text = dto.cacheTime > 0 ? '${dto.cacheTime}' : '30';
    _cacheUint = dto.cacheUint.isNotEmpty ? dto.cacheUint : 'd';
    _logEnable = dto.logEnable;
    _allowedDomains = List.from(dto.serverNames);

    final exts = (dto.extensions.isNotEmpty ? dto.extensions : dto.extendsName)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    _selectedExtensions = exts;

    _initialized = true;
  }

  Future<void> _save() async {
    if (_enable) {
      if (_selectedExtensions.isEmpty) {
        showAppWarningToast(context.l10n.websites_extensionRequired);
        return;
      }
      if (_allowedDomains.isEmpty) {
        showAppWarningToast(context.l10n.websites_allowedDomainRequired);
        return;
      }
    }

    final cacheTime = int.tryParse(_cacheTimeController.text.trim()) ?? 0;
    if (_cache && cacheTime <= 0) {
      showAppWarningToast(context.l10n.websites_cacheTimePositive);
      return;
    }

    setState(() => _saving = true);

    final req = WebsiteLeechUpdateReq(
      websiteID: widget.websiteId,
      enable: _enable,
      cache: _cache,
      cacheTime: cacheTime,
      cacheUint: _cacheUint,
      extensions: _selectedExtensions.join(','),
      returnCode: _returnCode,
      domains: _allowedDomains.join('\n'),
      noneRef: _noneRef,
      logEnable: _logEnable,
      blocked: _blocked,
      serverNames: _allowedDomains,
    );

    try {
      await ref
          .read(websiteLeechControllerProvider(widget.websiteId).notifier)
          .updateLeech(req);
      if (mounted) {
        showAppSuccessToast(context.l10n.websites_antiLeechSaved);
      }
    } on AppNetworkException catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.websites_saveFailed,
          description: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(context.l10n.websites_saveFailed, description: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebsiteAsyncModalSheet<WebsiteLeechDto>(
      provider: websiteLeechControllerProvider(widget.websiteId),
      errorTitle: context.l10n.websites_loadAntiLeechFailed,
      headerBuilder: (context, ref, async) => _Header(
        title: widget.title,
        onSave: _saving ? null : _save,
        saving: _saving,
      ),
      dataBuilder: (context, dto) {
        _initFromDto(dto);
        return _LeechForm(
          enable: _enable,
          onEnableChanged: (v) => setState(() => _enable = v),
          selectedExtensions: _selectedExtensions,
          commonExtensions: _commonExtensions,
          onExtensionToggle: (ext) {
            setState(() {
              if (_selectedExtensions.contains(ext)) {
                _selectedExtensions.remove(ext);
              } else {
                _selectedExtensions.add(ext);
              }
            });
          },
          customExtController: _customExtController,
          onAddCustomExt: () {
            final ext = _customExtController.text.trim().replaceAll('.', '');
            if (ext.isNotEmpty) {
              setState(() {
                _selectedExtensions.add(ext);
                _customExtController.clear();
              });
            }
          },
          allowedDomains: _allowedDomains,
          domainController: _domainController,
          onAddDomain: () {
            final domain = _domainController.text.trim();
            if (domain.isNotEmpty) {
              setState(() {
                if (!_allowedDomains.contains(domain)) {
                  _allowedDomains.add(domain);
                }
                _domainController.clear();
              });
            }
          },
          onRemoveDomain: (domain) {
            setState(() => _allowedDomains.remove(domain));
          },
          noneRef: _noneRef,
          onNoneRefChanged: (v) => setState(() => _noneRef = v),
          blocked: _blocked,
          onBlockedChanged: (v) => setState(() => _blocked = v),
          returnCode: _returnCode,
          onReturnCodeChanged: (v) => setState(() => _returnCode = v),
          cache: _cache,
          onCacheChanged: (v) => setState(() => _cache = v),
          cacheTimeController: _cacheTimeController,
          cacheUint: _cacheUint,
          onCacheUintChanged: (v) => setState(() => _cacheUint = v),
          logEnable: _logEnable,
          onLogEnableChanged: (v) => setState(() => _logEnable = v),
        );
      },
      onRetry: (ref) =>
          ref.invalidate(websiteLeechControllerProvider(widget.websiteId)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onSave,
    this.saving = false,
  });

  final String title;
  final VoidCallback? onSave;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.websites_antiLeech,
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
          if (saving)
            const CupertinoActivityIndicator()
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(8),
              onPressed: onSave,
              child: Text(
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
