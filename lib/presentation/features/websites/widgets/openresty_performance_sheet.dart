import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../common/app_toast.dart';
import '../../../../data/dto/website/openresty_performance_dto.dart';
import '../providers/openresty_performance_provider.dart';
import 'website_modal_sheet.dart';

void showOpenRestyPerformanceSheet(BuildContext context) {
  showWebsiteModalSheet<void>(
    context: context,
    child: const _OpenRestyPerformanceSheet(),
  );
}

class _OpenRestyPerformanceSheet extends StatelessWidget {
  const _OpenRestyPerformanceSheet();

  @override
  Widget build(BuildContext context) {
    return WebsiteAsyncModalSheet<List<OpenRestyPerformanceItemDto>>(
      provider: openrestyPerformanceControllerProvider,
      errorTitle: context.l10n.websites_loadPerformanceSettingsFailed,
      headerBuilder: (context, ref, async) => const _PerformanceHeader(),
      dataBuilder: (context, data) => _PerformanceBody(data: data),
      onRetry: (ref) => ref.invalidate(openrestyPerformanceControllerProvider),
    );
  }
}

class _PerformanceHeader extends StatelessWidget {
  const _PerformanceHeader();

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
              color: CupertinoColors.systemOrange
                  .resolveFrom(context)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              TablerIcons.adjustments_horizontal,
              size: 22,
              color: CupertinoColors.systemOrange.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.websites_performanceTuning,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.websites_openRestyPerformanceSubtitle,
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

class _PerformanceBody extends ConsumerStatefulWidget {
  const _PerformanceBody({required this.data});

  final List<OpenRestyPerformanceItemDto> data;

  @override
  ConsumerState<_PerformanceBody> createState() => _PerformanceBodyState();
}

class _PerformanceBodyState extends ConsumerState<_PerformanceBody> {
  final Map<String, TextEditingController> _controllers = {};
  bool _gzip = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.data) {
      final value = item.params.isNotEmpty ? item.params.first : '';
      if (item.name == 'gzip') {
        _gzip = value == 'on';
      } else {
        // Strip units for editing if necessary, but the user didn't specify.
        // Actually, for consistency with the request, I'll parse out the numeric part.
        _controllers[item.name] = TextEditingController(
          text: _parseValue(item.name, value),
        );
      }
    }
  }

  String _parseValue(String name, String raw) {
    if (name.contains('size') || name.contains('length')) {
      return raw.replaceAll(RegExp(r'[a-zA-Z]'), '');
    }
    return raw;
  }

  String _formatValue(String name, String value) {
    if (name == 'client_header_buffer_size' || name == 'gzip_min_length') {
      return '${value}k';
    }
    if (name == 'client_max_body_size') {
      return '${value}m';
    }
    return value;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final Map<String, String> params = {'gzip': _gzip ? 'on' : 'off'};
      for (final entry in _controllers.entries) {
        params[entry.key] = _formatValue(entry.key, entry.value.text);
      }

      await ref
          .read(openrestyPerformanceControllerProvider.notifier)
          .save(params);
      if (mounted) {
        showAppSuccessToast(context.l10n.common_saved);
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
    return Column(
      children: [
        _SectionCard(
          icon: TablerIcons.server,
          title: context.l10n.websites_serverSettings,
          child: _buildField(
            'server_names_hash_bucket_size',
            context.l10n.websites_serverNamesHashBucketSize,
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: TablerIcons.network,
          title: context.l10n.websites_clientSettings,
          child: Column(
            children: [
              _buildField(
                'client_header_buffer_size',
                context.l10n.websites_clientHeaderBufferSize,
                unit: 'K',
              ),
              const SizedBox(height: 12),
              _buildField(
                'client_max_body_size',
                context.l10n.websites_maxUploadFile,
                unit: 'MB',
              ),
              const SizedBox(height: 12),
              _buildField(
                'keepalive_timeout',
                context.l10n.websites_keepaliveTimeout,
                unit: 's',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: TablerIcons.zip,
          title: context.l10n.websites_gzipCompression,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.websites_enableCompressionTransfer,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.label(context),
                      ),
                    ),
                  ),
                  AppToggleSwitch(
                    value: _gzip,
                    onChanged: (v) => setState(() => _gzip = v),
                  ),
                ],
              ),
              if (_gzip) ...[
                const SizedBox(height: 12),
                _buildField(
                  'gzip_min_length',
                  context.l10n.websites_minCompressionFile,
                  unit: 'KB',
                ),
                const SizedBox(height: 12),
                _buildField(
                  'gzip_comp_level',
                  context.l10n.websites_compressionLevel,
                  unit: '(1-9)',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SaveButton(saving: _saving, onPressed: _saving ? null : _save),
      ],
    );
  }

  Widget _buildField(String name, String label, {String? unit}) {
    final controller = _controllers[name];
    if (controller == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.tertiaryBackground(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: null,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.label(context),
                  ),
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.tertiaryLabel(context),
                    ),
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
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (saving)
              const CupertinoActivityIndicator()
            else
              Icon(
                TablerIcons.device_floppy,
                size: 18,
                color: color.withValues(alpha: active ? 1 : 0.4),
              ),
            const SizedBox(width: 8),
            Text(
              saving ? context.l10n.websites_saving : context.l10n.common_save,
              style: TextStyle(
                fontSize: 16,
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
