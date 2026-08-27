import 'package:dio/dio.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/server_host_normalizer.dart';
import '../../../../data/repositories_impl/server_repository_impl.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/cupertino_grouped_form.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../purchases/widgets/purchase_prompt.dart';
import '../providers/servers_provider.dart';

class AddServerSheet extends ConsumerStatefulWidget {
  const AddServerSheet({super.key, this.server});

  final Server? server;

  static Future<void> show(BuildContext context) {
    return showActionSheet(
      context: context,
      expand: false,
      builder: (context) => const AddServerSheet(),
    );
  }

  static Future<void> edit(BuildContext context, Server server) {
    return showActionSheet(
      context: context,
      expand: false,
      builder: (context) => AddServerSheet(server: server),
    );
  }

  @override
  ConsumerState<AddServerSheet> createState() => _AddServerSheetState();
}

class _AddServerSheetState extends ConsumerState<AddServerSheet> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '10000');
  final _apiKeyController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _hostFocusNode = FocusNode();
  final _portFocusNode = FocusNode();
  final _apiKeyFocusNode = FocusNode();
  final _apiKeyFieldKey = GlobalKey();
  CancelToken? _connectionCancelToken;
  bool _isHttps = false;
  bool _allowInsecureConnections = false;
  bool _obscureApiKey = true;
  bool _isLoading = false;
  bool _isApiKeyLoading = false;

  bool get _isEditing => widget.server != null;

  @override
  void initState() {
    super.initState();
    _apiKeyFocusNode.addListener(_handleApiKeyFocusChange);
    final server = widget.server;
    if (server == null) return;
    _nameController.text = server.name ?? '';
    _hostController.text = server.host;
    _portController.text = server.port.toString();
    _isHttps = server.isHttps;
    _allowInsecureConnections = server.allowInsecureConnections;
    _loadApiKey(server.id);
  }

  @override
  void dispose() {
    _connectionCancelToken?.cancel('Sheet disposed');
    _apiKeyFocusNode.removeListener(_handleApiKeyFocusChange);
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _apiKeyController.dispose();
    _nameFocusNode.dispose();
    _hostFocusNode.dispose();
    _portFocusNode.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  void _cancel() {
    _connectionCancelToken?.cancel('User cancelled connection test');
    if (_isLoading) return;
    Navigator.of(context).pop();
  }

  Future<void> _loadApiKey(int serverId) async {
    setState(() => _isApiKeyLoading = true);
    try {
      final apiKey = await ref
          .read(serverRepositoryProvider)
          .getApiKey(serverId);
      if (!mounted) return;
      if (_apiKeyController.text.isEmpty) {
        _apiKeyController.text = apiKey ?? '';
      }
    } catch (error) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.servers_apiKeyReadFailed,
          description: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _isApiKeyLoading = false);
    }
  }

  void _handleApiKeyFocusChange() {
    if (!_apiKeyFocusNode.hasFocus) return;
    _ensureApiKeyVisible();
    Future.delayed(const Duration(milliseconds: 320), _ensureApiKeyVisible);
  }

  void _ensureApiKeyVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = _apiKeyFieldKey.currentContext;
      if (fieldContext == null) return;

      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final host = normalizeServerHostInput(_hostController.text);
    if (host.isEmpty || (!_isEditing && _apiKeyController.text.isEmpty)) {
      final l10n = context.l10n;
      showAppErrorToast(
        _isEditing
            ? l10n.servers_hostRequired
            : l10n.servers_hostApiKeyRequired,
      );
      return;
    }

    final cancelToken = CancelToken();
    _connectionCancelToken = cancelToken;
    setState(() => _isLoading = true);
    try {
      final port = int.tryParse(_portController.text) ?? 10000;
      final apiKey = _apiKeyController.text;
      final shouldTestConnection = !_isEditing || apiKey.isNotEmpty;
      if (shouldTestConnection) {
        await ref
            .read(serversNotifierProvider.notifier)
            .testConnection(
              host: host,
              port: port,
              apiKey: apiKey,
              isHttps: _isHttps,
              allowInsecureConnections: _allowInsecureConnections,
              cancelToken: cancelToken,
            );
      }

      if (cancelToken.isCancelled) return;

      final notifier = ref.read(serversNotifierProvider.notifier);
      if (_isEditing) {
        await notifier.updateServer(
          id: widget.server!.id,
          name: _nameController.text,
          host: host,
          port: port,
          apiKey: apiKey,
          isHttps: _isHttps,
          allowInsecureConnections: _allowInsecureConnections,
        );
      } else {
        await notifier.addServer(
          name: _nameController.text,
          host: host,
          port: port,
          apiKey: apiKey,
          isHttps: _isHttps,
          allowInsecureConnections: _allowInsecureConnections,
        );
      }

      if (mounted) {
        final l10n = context.l10n;
        showAppSuccessToast(
          _isEditing ? l10n.servers_saved : l10n.servers_added,
        );
        Navigator.of(context).pop();
      }
    } on ServerLimitReachedException catch (error) {
      if (mounted) {
        await showUnlimitedServersPurchasePrompt(
          context,
          ref,
          serverCount: error.serverCount,
        );
      }
    } catch (e) {
      if (cancelToken.isCancelled) return;
      if (mounted) {
        final l10n = context.l10n;
        showAppErrorToast(
          l10n.servers_connectionFailed,
          description: l10n.servers_connectionFailedDescription('$e'),
        );
      }
    } finally {
      if (identical(_connectionCancelToken, cancelToken)) {
        _connectionCancelToken = null;
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ActionSheetScaffold(
      showHandle: false,
      isAdaptive: true,
      isFloating: true,
      hasHorizontalPadding: true,
      contentPadding: EdgeInsets.zero,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _cancel,
                child: Text(
                  _isLoading ? l10n.servers_stop : l10n.common_cancel,
                  style: TextStyle(
                    color: _isLoading
                        ? CupertinoColors.systemRed.resolveFrom(context)
                        : AppColors.secondaryLabel(context),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Text(
              _isLoading
                  ? l10n.servers_connecting
                  : (_isEditing
                        ? l10n.servers_editPanel
                        : l10n.servers_addPanel),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
                letterSpacing: -0.4,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _isLoading || _isApiKeyLoading ? null : _submit,
                child: _isLoading || _isApiKeyLoading
                    ? const CupertinoActivityIndicator(radius: 10)
                    : Text(
                        _isEditing ? l10n.common_save : l10n.common_create,
                        style: TextStyle(
                          color: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCupertinoSectionHeader(title: l10n.servers_connectionSettings),
          AppCupertinoGroupedBox(
            children: [
              AppCupertinoFormTile(
                label: l10n.servers_name,
                child: _buildTextField(
                  controller: _nameController,
                  placeholder: l10n.servers_namePlaceholder,
                  focusNode: _nameFocusNode,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _hostFocusNode.requestFocus(),
                ),
              ),
              AppCupertinoFormTile(
                label: l10n.servers_host,
                child: _buildTextField(
                  controller: _hostController,
                  placeholder: l10n.servers_hostPlaceholder,
                  focusNode: _hostFocusNode,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _portFocusNode.requestFocus(),
                ),
              ),
              AppCupertinoFormTile(
                label: l10n.servers_port,
                child: _buildTextField(
                  controller: _portController,
                  placeholder: '10000',
                  keyboardType: TextInputType.number,
                  focusNode: _portFocusNode,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              AppCupertinoFormTile(
                label: 'HTTPS',
                isLast: !_isHttps,
                child: _buildHttpsSwitch(),
              ),
              if (_isHttps)
                _SwitchTile(
                  title: l10n.settings_network_allowInsecureTitle,
                  subtitle: l10n.settings_network_allowInsecureSubtitle,
                  value: _allowInsecureConnections,
                  onChanged: _setAllowInsecureConnections,
                  isLast: true,
                ),
            ],
          ),

          const SizedBox(height: 24),

          AppCupertinoSectionHeader(title: l10n.servers_securityAuth),
          AppCupertinoGroupedBox(
            children: [
              AppCupertinoFormTile(
                key: _apiKeyFieldKey,
                label: 'API Key',
                isLast: true,
                child: _buildApiKeyField(),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              l10n.servers_apiKeyHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      height: 44,
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscureText,
        keyboardType: keyboardType,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        inputFormatters: inputFormatters,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(fontSize: 15, color: AppColors.label(context)),
        decoration: const BoxDecoration(),
        autocorrect: false,
        enableSuggestions: !obscureText,
      ),
    );
  }

  Widget _buildHttpsSwitch() {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppToggleSwitch(
            value: _isHttps,
            onChanged: (val) => setState(() {
              _isHttps = val;
              if (!val) {
                _allowInsecureConnections = false;
              }
            }),
          ),
        ],
      ),
    );
  }

  void _setAllowInsecureConnections(bool value) {
    if (!value) {
      setState(() => _allowInsecureConnections = false);
      return;
    }

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.settings_insecure_confirmTitle),
        content: Text(context.l10n.settings_insecure_confirmContent),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _allowInsecureConnections = true);
            },
            child: Text(context.l10n.settings_insecure_enable),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyField() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _apiKeyController,
              placeholder: _isApiKeyLoading
                  ? context.l10n.servers_reading
                  : context.l10n.servers_required,
              obscureText: _obscureApiKey,
              focusNode: _apiKeyFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(fontSize: 15, color: AppColors.label(context)),
              decoration: const BoxDecoration(),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            onPressed: _isApiKeyLoading
                ? null
                : () => setState(() => _obscureApiKey = !_obscureApiKey),
            child: Icon(
              _obscureApiKey ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              size: 20,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.label(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppToggleSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 0.5,
              color: AppColors.separator(context).withValues(alpha: 0.1),
            ),
          ),
      ],
    );
  }
}
