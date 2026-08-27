import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/website_cors_dto.dart';
import '../../../common/app_toast.dart';
import '../providers/website_cors_provider.dart';
import 'website_modal_sheet.dart';

part 'cors/website_cors_sheet_form.part.dart';

void showWebsiteCorsSheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteCorsSheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteCorsSheet extends ConsumerStatefulWidget {
  const _WebsiteCorsSheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  ConsumerState<_WebsiteCorsSheet> createState() => _WebsiteCorsSheetState();
}

class _WebsiteCorsSheetState extends ConsumerState<_WebsiteCorsSheet> {
  final _originsController = TextEditingController();
  final _headersController = TextEditingController();

  bool _cors = false;
  Set<String> _allowMethods = {};
  bool _allowCredentials = false;
  bool _preflight = false;

  bool _saving = false;
  bool _initialized = false;

  final List<String> _methodOptions = [
    'GET',
    'POST',
    'PUT',
    'DELETE',
    'PATCH',
    'OPTIONS',
    'HEAD',
    'CONNECT',
    'TRACE',
  ];

  @override
  void dispose() {
    _originsController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  void _initFromDto(WebsiteCorsDto dto) {
    if (_initialized) return;
    _cors = dto.cors;
    _originsController.text = dto.allowOrigins;
    _headersController.text = dto.allowHeaders;
    _allowCredentials = dto.allowCredentials;
    _preflight = dto.preflight;

    _allowMethods = dto.allowMethods
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    _initialized = true;
  }

  Future<void> _save() async {
    if (_cors) {
      if (_originsController.text.trim().isEmpty) {
        showAppWarningToast(context.l10n.websites_allowedOriginsRequired);
        return;
      }
    }

    setState(() => _saving = true);

    final req = WebsiteCorsDto(
      websiteID: widget.websiteId,
      cors: _cors,
      allowOrigins: _originsController.text.trim(),
      allowMethods: _allowMethods.join(','),
      allowHeaders: _headersController.text.trim(),
      allowCredentials: _allowCredentials,
      preflight: _preflight,
    );

    try {
      await ref
          .read(websiteCorsControllerProvider(widget.websiteId).notifier)
          .updateCors(req);
      if (mounted) {
        showAppSuccessToast(context.l10n.websites_corsSaved);
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
    return WebsiteAsyncModalSheet<WebsiteCorsDto>(
      provider: websiteCorsControllerProvider(widget.websiteId),
      errorTitle: context.l10n.websites_loadCorsConfigFailed,
      headerBuilder: (context, ref, async) => _Header(
        title: widget.title,
        onSave: _saving ? null : _save,
        saving: _saving,
      ),
      dataBuilder: (context, dto) {
        _initFromDto(dto);
        return _CorsForm(
          cors: _cors,
          onCorsChanged: (v) => setState(() => _cors = v),
          originsController: _originsController,
          headersController: _headersController,
          allowMethods: _allowMethods,
          methodOptions: _methodOptions,
          onMethodToggle: (method) {
            setState(() {
              if (_allowMethods.contains(method)) {
                _allowMethods.remove(method);
              } else {
                _allowMethods.add(method);
              }
            });
          },
          allowCredentials: _allowCredentials,
          onAllowCredentialsChanged: (v) =>
              setState(() => _allowCredentials = v),
          preflight: _preflight,
          onPreflightChanged: (v) => setState(() => _preflight = v),
        );
      },
      onRetry: (ref) =>
          ref.invalidate(websiteCorsControllerProvider(widget.websiteId)),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue
                  .resolveFrom(context)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              TablerIcons.arrows_exchange_2,
              size: 20,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.websites_corsAccess,
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
              minimumSize: const Size(32, 32),
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
