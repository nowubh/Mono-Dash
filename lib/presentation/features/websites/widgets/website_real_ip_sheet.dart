import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:re_editor/re_editor.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/website_real_ip_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_picker.dart';
import '../providers/website_real_ip_provider.dart';
import 'website_modal_sheet.dart';

part 'realip/website_real_ip_sheet_form.part.dart';

void showWebsiteRealIpSheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteRealIpSheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteRealIpSheet extends ConsumerStatefulWidget {
  const _WebsiteRealIpSheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  ConsumerState<_WebsiteRealIpSheet> createState() =>
      _WebsiteRealIpSheetState();
}

class _WebsiteRealIpSheetState extends ConsumerState<_WebsiteRealIpSheet> {
  final _ipOtherController = TextEditingController();
  final _codeController = CodeLineEditingController();
  final _addIpController = TextEditingController();

  bool _open = false;
  List<String> _ipFromList = [];
  String _ipHeader = 'X-Forwarded-For';

  bool _isTextMode = false;
  bool _isAddingIp = false;
  bool _saving = false;
  bool _initialized = false;

  final List<String> _headerOptions = [
    'X-Forwarded-For',
    'X-Real-IP',
    'CF-Connecting-IP',
    'other',
  ];

  @override
  void dispose() {
    _ipOtherController.dispose();
    _codeController.dispose();
    _addIpController.dispose();
    super.dispose();
  }

  void _initFromDto(WebsiteRealIpDto dto) {
    if (_initialized) return;
    _open = dto.open;
    _ipHeader = dto.ipHeader.isEmpty ? 'X-Forwarded-For' : dto.ipHeader;
    _ipOtherController.text = dto.ipOther;

    _ipFromList = dto.ipFrom
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _codeController.text = dto.ipFrom;

    _initialized = true;
  }

  void _syncToTextMode() {
    _codeController.text = _ipFromList.join('\n');
  }

  void _syncFromTextMode() {
    _ipFromList = _codeController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (_isTextMode) {
      _syncFromTextMode();
    }

    if (_open && _ipFromList.isEmpty) {
      showAppWarningToast(context.l10n.websites_ipSourceRequired);
      return;
    }

    if (_open &&
        _ipHeader == 'other' &&
        _ipOtherController.text.trim().isEmpty) {
      showAppWarningToast(context.l10n.websites_customHeaderRequired);
      return;
    }

    setState(() => _saving = true);

    final req = WebsiteRealIpDto(
      websiteID: widget.websiteId,
      open: _open,
      ipFrom: _ipFromList.join('\n'),
      ipHeader: _ipHeader,
      ipOther: _ipOtherController.text.trim(),
    );

    try {
      await ref
          .read(websiteRealIpControllerProvider(widget.websiteId).notifier)
          .updateRealIp(req);
      if (mounted) {
        showAppSuccessToast(context.l10n.websites_realIpSaved);
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
    return WebsiteAsyncModalSheet<WebsiteRealIpDto>(
      provider: websiteRealIpControllerProvider(widget.websiteId),
      errorTitle: context.l10n.websites_loadRealIpConfigFailed,
      headerBuilder: (context, ref, async) => _Header(
        title: widget.title,
        onSave: _saving ? null : _save,
        saving: _saving,
      ),
      dataBuilder: (context, dto) {
        _initFromDto(dto);
        return _RealIpForm(
          open: _open,
          onOpenChanged: (v) => setState(() => _open = v),
          ipFromList: _ipFromList,
          isTextMode: _isTextMode,
          onModeChanged: (v) {
            if (v) {
              _syncToTextMode();
            } else {
              _syncFromTextMode();
            }
            setState(() => _isTextMode = v);
          },
          isAddingIp: _isAddingIp,
          onAddingChanged: (v) => setState(() => _isAddingIp = v),
          addIpController: _addIpController,
          onAddIp: () {
            final ip = _addIpController.text.trim();
            if (ip.isNotEmpty) {
              setState(() {
                if (!_ipFromList.contains(ip)) {
                  _ipFromList.insert(0, ip);
                }
                _addIpController.clear();
                _isAddingIp = false;
              });
            }
          },
          onRemoveIp: (ip) => setState(() => _ipFromList.remove(ip)),
          codeController: _codeController,
          ipHeader: _ipHeader,
          onIpHeaderChanged: (v) => setState(() => _ipHeader = v),
          ipOtherController: _ipOtherController,
          headerOptions: _headerOptions,
        );
      },
      onRetry: (ref) =>
          ref.invalidate(websiteRealIpControllerProvider(widget.websiteId)),
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
              color: CupertinoColors.systemGreen
                  .resolveFrom(context)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              TablerIcons.cloud_lock_open,
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
                  context.l10n.websites_realIp,
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
