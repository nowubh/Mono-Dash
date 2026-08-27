import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/localization/l10n_x.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/dto/website/website_create_req.dart';
import '../../../../../data/dto/website/website_group_dto.dart';
import '../../../server_detail/providers/active_server_provider.dart';
import '../../../../common/app_toast.dart';
import '../../../../common/components/app_picker.dart';
import '../../../../common/components/frosted_action_button.dart';
import '../../../../common/components/frosted_scaffold.dart';
import '../../providers/website_create_provider.dart';

class _StreamServerEntry {
  _StreamServerEntry() : serverController = TextEditingController();

  final TextEditingController serverController;
  int weight = 1;
  String flag = '';

  void dispose() {
    serverController.dispose();
  }
}

class WebsiteCreateTunnelPage extends StatelessWidget {
  const WebsiteCreateTunnelPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: const _WebsiteCreateTunnelForm(),
    );
  }
}

class _WebsiteCreateTunnelForm extends ConsumerStatefulWidget {
  const _WebsiteCreateTunnelForm();

  @override
  ConsumerState<_WebsiteCreateTunnelForm> createState() =>
      _WebsiteCreateTunnelPageState();
}

class _WebsiteCreateTunnelPageState
    extends ConsumerState<_WebsiteCreateTunnelForm> {
  static const double _formControlHeight = 40;

  final _aliasController = TextEditingController();
  final _streamPortsController = TextEditingController();
  final _remarkController = TextEditingController();

  bool _isSubmitting = false;
  int? _selectedGroupId;
  bool _enableUdp = false;
  String _selectedAlgorithm = 'default';
  final List<_StreamServerEntry> _servers = [_StreamServerEntry()];

  @override
  void dispose() {
    _aliasController.dispose();
    _streamPortsController.dispose();
    _remarkController.dispose();
    for (final s in _servers) {
      s.dispose();
    }
    super.dispose();
  }

  void _addServer() {
    setState(() => _servers.add(_StreamServerEntry()));
  }

  void _removeServer(int index) {
    if (_servers.length <= 1) return;
    setState(() {
      _servers[index].dispose();
      _servers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final metadata = ref.read(websiteCreateMetadataProvider).valueOrNull;
    final alias = _aliasController.text.trim();
    final streamPorts = _streamPortsController.text.trim();
    final groupId = _selectedGroupId ?? metadata?.defaultGroup?.id ?? 1;

    if (alias.isEmpty) {
      _showError(context.l10n.websites_aliasRequired);
      return;
    }
    if (streamPorts.isEmpty) {
      _showError(context.l10n.websites_streamPortsRequired);
      return;
    }
    if (_servers.isEmpty) {
      _showError(context.l10n.websites_backendServerRequired);
      return;
    }
    for (final s in _servers) {
      if (s.serverController.text.trim().isEmpty) {
        _showError(context.l10n.websites_serverAddressRequired);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final req = WebsiteCreateReq(
      alias: alias,
      type: 'stream',
      domains: const [],
      webSiteGroupID: groupId,
      remark: _remarkController.text.trim(),
      taskID: const Uuid().v4(),
      streamPorts: streamPorts,
      udp: _enableUdp,
      name: alias,
      algorithm: _selectedAlgorithm,
      servers: [
        for (final s in _servers)
          {
            'server': s.serverController.text.trim(),
            'weight': s.weight,
            'maxFails': 1,
            'maxConns': 0,
            'failTimeout': 30,
            'failTimeoutUnit': 's',
            'flag': s.flag,
          },
      ],
    );

    final success = await ref
        .read(websiteCreateControllerProvider.notifier)
        .createWebsite(req);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        showAppSuccessToast(
          context.l10n.websites_createSuccess,
          description: context.l10n.websites_tunnelSiteCreated(alias),
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

    return FrostedScaffold(
      title: context.l10n.websites_createTunnelSite,
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
                  // Basic configuration
                  _buildSectionCard(
                    context,
                    icon: TablerIcons.world_www,
                    title: context.l10n.websites_basicConfig,
                    child: Column(
                      children: [
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_alias,
                          placeholder: context
                              .l10n
                              .websites_loadBalancingNamePlaceholder,
                          controller: _aliasController,
                        ),
                        const SizedBox(height: 12),
                        metadataAsync.when(
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
                        const SizedBox(height: 12),
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_listeningPort,
                          placeholder:
                              context.l10n.websites_listeningPortPlaceholder,
                          controller: _streamPortsController,
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchRow(
                          context,
                          label: context.l10n.websites_udpMode,
                          icon: TablerIcons.network,
                          value: _enableUdp,
                          onChanged: (value) =>
                              setState(() => _enableUdp = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Load balancing
                  _buildSectionCard(
                    context,
                    icon: TablerIcons.arrows_split_2,
                    title: context.l10n.websites_loadBalancing,
                    child: Column(
                      children: [
                        _buildAlgorithmPickerField(context),
                        const SizedBox(height: 14),
                        ..._buildServerList(context),
                        const SizedBox(height: 10),
                        _buildAddServerButton(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Other information
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

  // ── Algorithm Picker ──────────────────────────────────────────

  List<AppPickerOption<String>> _algorithmOptions(BuildContext context) => [
    AppPickerOption(value: 'default', label: context.l10n.websites_roundRobin),
    AppPickerOption(
      value: 'least_conn',
      label: context.l10n.websites_leastConnections,
    ),
  ];

  List<AppPickerOption<String>> _flagOptions(BuildContext context) => [
    AppPickerOption(value: '', label: context.l10n.websites_statusNormal),
    AppPickerOption(value: 'down', label: context.l10n.websites_statusDown),
    AppPickerOption(value: 'backup', label: context.l10n.websites_statusBackup),
  ];

  Widget _buildAlgorithmPickerField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_loadBalancingAlgorithm,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<String>(
          value: _selectedAlgorithm,
          options: _algorithmOptions(context),
          anchorHeight: _formControlHeight,
          onChanged: (value) => setState(() => _selectedAlgorithm = value),
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

  // ── Server List ───────────────────────────────────────────────

  List<Widget> _buildServerList(BuildContext context) {
    return [
      for (int i = 0; i < _servers.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        _buildServerCard(context, i, _servers[i]),
      ],
    ];
  }

  Widget _buildServerCard(
    BuildContext context,
    int index,
    _StreamServerEntry server,
  ) {
    final canDelete = _servers.length > 1;
    final orange = CupertinoColors.systemOrange.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryBackground(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(TablerIcons.server_2, size: 16, color: orange),
              const SizedBox(width: 6),
              Text(
                context.l10n.websites_serverNumber(index + 1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
              const Spacer(),
              if (canDelete)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  onPressed: () => _removeServer(index),
                  child: Icon(
                    TablerIcons.trash,
                    size: 16,
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: server.serverController,
            placeholder: '127.0.0.1:3306',
            autocorrect: false,
            enableSuggestions: false,
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.websites_weight,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: CupertinoTextField(
                        controller: TextEditingController(
                          text: '${server.weight}',
                        ),
                        keyboardType: TextInputType.number,
                        autocorrect: false,
                        enableSuggestions: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryBackground(
                            context,
                          ).withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.label(context),
                        ),
                        placeholderStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        onChanged: (value) {
                          server.weight = int.tryParse(value) ?? 1;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.websites_status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppInlinePicker<String>(
                      value: server.flag.isEmpty ? '' : server.flag,
                      options: _flagOptions(context),
                      anchorHeight: 36,
                      onChanged: (value) => setState(() => server.flag = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Add Server Button ─────────────────────────────────────────

  Widget _buildAddServerButton(BuildContext context) {
    final color = CupertinoColors.systemOrange.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _addServer,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.plus, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              context.l10n.websites_addServer,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
