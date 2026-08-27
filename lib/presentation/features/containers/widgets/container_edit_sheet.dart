import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/container/container_info_dto.dart';
import '../../../../data/dto/container/container_limit_dto.dart';
import '../../../../data/dto/container/container_option_dto.dart';
import '../../../../data/dto/container/container_search_dto.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/task_log_sheet.dart';

Future<void> showContainerEditSheet({
  required BuildContext context,
  required ContainerItemDto container,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (context) => _ContainerEditSheet(container: container),
  );
}

class _ContainerEditSheet extends ConsumerStatefulWidget {
  const _ContainerEditSheet({required this.container});

  final ContainerItemDto container;

  @override
  ConsumerState<_ContainerEditSheet> createState() =>
      _ContainerEditSheetState();
}

class _ContainerEditSheetState extends ConsumerState<_ContainerEditSheet> {
  bool _loading = true;
  Object? _error;

  ContainerInfoDto? _info;
  ContainerLimitDto? _systemLimit;
  List<ContainerOptionDto> _allNetworks = [];
  List<ContainerOptionDto> _allVolumes = [];
  List<ContainerOptionDto> _allImages = [];

  // Controllers & Form State
  late final TextEditingController _nameController;
  String _selectedImage = '';
  bool _tty = false;
  bool _openStdin = false;
  bool _privileged = false;
  bool _autoRemove = false;

  bool _publishAllPorts = false;
  List<ContainerPortDto> _exposedPorts = [];

  late final TextEditingController _hostnameController;
  late final TextEditingController _domainNameController;
  List<String> _dns = [];
  List<ContainerNetworkDto> _networks = [];

  List<ContainerVolumeDto> _volumes = [];
  List<String> _extraHosts = [];

  late final TextEditingController _workingDirController;
  late final TextEditingController _userController;
  late final TextEditingController _cmdController;
  late final TextEditingController _entrypointController;

  late final TextEditingController _cpuSharesController;
  late final TextEditingController _cpuLimitController;
  late final TextEditingController _memoryController;

  List<String> _labels = [];
  List<String> _env = [];
  String _restartPolicy = 'always';
  bool _showVolumePicker = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.container.name);
    _hostnameController = TextEditingController();
    _domainNameController = TextEditingController();
    _workingDirController = TextEditingController();
    _userController = TextEditingController();
    _cmdController = TextEditingController();
    _entrypointController = TextEditingController();
    _cpuSharesController = TextEditingController(text: '1024');
    _cpuLimitController = TextEditingController(text: '0');
    _memoryController = TextEditingController(text: '0');
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _domainNameController.dispose();
    _workingDirController.dispose();
    _userController.dispose();
    _cmdController.dispose();
    _entrypointController.dispose();
    _cpuSharesController.dispose();
    _cpuLimitController.dispose();
    _memoryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      final results = await Future.wait([
        repo.getContainerInfo(widget.container.name),
        repo.getContainerLimit(),
        repo.getNetworks(),
        repo.getVolumes(),
        repo.getImages(),
      ]);

      if (mounted) {
        setState(() {
          _info = results[0] as ContainerInfoDto;
          _systemLimit = results[1] as ContainerLimitDto;
          _allNetworks = results[2] as List<ContainerOptionDto>;
          _allVolumes = results[3] as List<ContainerOptionDto>;
          _allImages = results[4] as List<ContainerOptionDto>;

          // Init form from info
          _selectedImage = _info!.image;
          _tty = _info!.tty;
          _openStdin = _info!.openStdin;
          _privileged = _info!.privileged;
          _autoRemove = _info!.autoRemove;
          _publishAllPorts = _info!.publishAllPorts;
          _exposedPorts = List.from(_info!.exposedPorts);
          _hostnameController.text = _info!.hostname;
          _domainNameController.text = _info!.domainName;
          _dns = List.from(_info!.dns ?? []);
          _networks = List.from(_info!.networks);
          _volumes = List.from(_info!.volumes);
          _extraHosts = List.from(_info!.extraHosts ?? []);
          _workingDirController.text = _info!.workingDir;
          _userController.text = _info!.user;
          _cmdController.text = _info!.cmd?.join(' ') ?? '';
          _entrypointController.text = _info!.entrypoint?.join(' ') ?? '';
          _cpuSharesController.text = _info!.cpuShares.toString();
          _cpuLimitController.text = (_info!.nanoCPUs / 1000000000).toString();
          _memoryController.text = (_info!.memory / 1024 / 1024)
              .floor()
              .toString();
          _labels = List.from(_info!.labels);
          _env = List.from(_info!.env);
          _restartPolicy = _info!.restartPolicy;

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final taskID = const Uuid().v4();

    final cmdList = _cmdController.text
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    final entrypointList = _entrypointController.text
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();

    // Prepare payload
    final data = {
      'taskID': taskID,
      'name': _nameController.text,
      'image': _selectedImage,
      'imageInput': false,
      'forcePull': false,
      'tty': _tty,
      'openStdin': _openStdin,
      'privileged': _privileged,
      'autoRemove': _autoRemove,
      'publishAllPorts': _publishAllPorts,
      'exposedPorts': _exposedPorts
          .map(
            (e) => {
              ...e.toJson(),
              'host': e.hostPort.isNotEmpty ? '${e.hostIP}:${e.hostPort}' : '',
            },
          )
          .toList(),
      'hostname': _hostnameController.text,
      'domainName': _domainNameController.text,
      'dns': _dns,
      'networks': _networks.map((e) => e.toJson()).toList(),
      'volumes': _volumes.map((e) => e.toJson()).toList(),
      'extraHosts': _extraHosts,
      'workingDir': _workingDirController.text,
      'user': _userController.text,
      'cmd': cmdList,
      'cmdStr': _cmdController.text,
      'entrypoint': entrypointList,
      'entrypointStr': _entrypointController.text,
      'cpuShares': int.tryParse(_cpuSharesController.text) ?? 0,
      'nanoCPUs':
          ((double.tryParse(_cpuLimitController.text) ?? 0) * 1000000000)
              .toInt(),
      'memoryItem': int.tryParse(_memoryController.text) ?? 0,
      'memory': (int.tryParse(_memoryController.text) ?? 0) * 1024 * 1024,
      'memoryUnit': 'M',
      'labels': _labels,
      'env': _env,
      'restartPolicy': _restartPolicy,
    };

    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.updateContainer(data);
      if (mounted) {
        Navigator.pop(context);
        showTaskLogSheet(
          context,
          title: context.l10n.containers_updatingContainer(
            _nameController.text,
          ),
          taskID: taskID,
          reader: repo.readTaskLog,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = context.l10n.containers_updateRequestFailed('$e');
      showAppErrorToast(errorMsg);
      Clipboard.setData(ClipboardData(text: errorMsg));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      maxHeightFactor: 0.9,
      panelHeader: _buildHeader(),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _error != null
          ? _buildError()
          : _buildForm(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.l10n.common_cancel,
              style: TextStyle(
                color: AppColors.secondaryLabel(context),
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.l10n.containers_editContainer,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.label(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _loading || _error != null ? null : _submit,
            child: Text(
              context.l10n.containers_submit,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return AppErrorState(
      title: context.l10n.containers_loadConfigFailed,
      error: _error ?? context.l10n.common_unknown,
      onRetry: () {
        setState(() {
          _loading = true;
          _error = null;
        });
        _load();
      },
    );
  }

  Widget _buildForm() {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          if (widget.container.isFromApp) _buildAppWarning(),
          _buildBasicSection(),
          _buildPortsSection(),
          _buildNetworkSection(),
          _buildVolumesSection(),
          _buildHostsSection(),
          _buildCommandSection(),
          _buildResourcesSection(),
          _buildLabelsSection(),
          _buildEnvSection(),
          _buildRestartPolicySection(),
        ],
      ),
    );
  }

  Widget _buildAppWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            TablerIcons.alert_triangle,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.containers_appStoreWarning,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_basicInfo,
          TablerIcons.settings,
        ),
        _SectionCard(
          children: [
            _InputItem(
              label: context.l10n.containers_containerName,
              controller: _nameController,
              enabled: false,
              placeholder: context.l10n.containers_required,
            ),
            const _CardDivider(),
            _buildImagePicker(),
            const _CardDivider(),
            _OptionItem(
              label: 'TTY',
              subtitle: context.l10n.containers_ttySubtitle,
              value: _tty,
              onChanged: (v) => setState(() => _tty = v),
            ),
            const _CardDivider(),
            _OptionItem(
              label: context.l10n.containers_stdin,
              subtitle: context.l10n.containers_stdinSubtitle,
              value: _openStdin,
              onChanged: (v) => setState(() => _openStdin = v),
            ),
            const _CardDivider(),
            _OptionItem(
              label: context.l10n.containers_privilegedMode,
              subtitle: context.l10n.containers_privilegedSubtitle,
              value: _privileged,
              onChanged: (v) => setState(() => _privileged = v),
            ),
            const _CardDivider(),
            _OptionItem(
              label: context.l10n.containers_autoRemove,
              subtitle: context.l10n.containers_autoRemoveSubtitle,
              value: _autoRemove,
              onChanged: (v) => setState(() => _autoRemove = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final options = _allImages
        .map((e) => AppPickerOption(label: e.option, value: e.option))
        .toList();
    if (_selectedImage.isNotEmpty &&
        !options.any((o) => o.value == _selectedImage)) {
      options.insert(
        0,
        AppPickerOption(label: _selectedImage, value: _selectedImage),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 80,
              child: Text(
                context.l10n.containers_imageName,
                style: TextStyle(
                  color: AppColors.label(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppInlinePicker<String>(
              backgroundColor: AppColors.background(
                context,
              ).withValues(alpha: 0.4),
              options: options,
              value: _selectedImage,
              onChanged: (v) => setState(() => _selectedImage = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_portMappings,
          TablerIcons.network,
        ),
        _SectionCard(
          children: [
            _OptionItem(
              label: context.l10n.containers_publishAllPorts,
              subtitle: context.l10n.containers_publishAllPortsSubtitle,
              value: _publishAllPorts,
              onChanged: (v) => setState(() => _publishAllPorts = v),
            ),
            if (!_publishAllPorts) ...[
              const _CardDivider(),
              ..._exposedPorts.asMap().entries.map((entry) {
                final i = entry.key;
                final port = entry.value;
                return Column(
                  children: [
                    if (i > 0) const _CardDivider(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _CompactInput(
                                        placeholder: context
                                            .l10n
                                            .containers_hostIpOptional,
                                        initialValue: port.hostIP,
                                        onChanged: (v) =>
                                            _updatePort(i, hostIP: v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _CompactInput(
                                        placeholder:
                                            context.l10n.containers_hostPort,
                                        initialValue: port.hostPort,
                                        onChanged: (v) =>
                                            _updatePort(i, hostPort: v),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _CompactInput(
                                        placeholder: context
                                            .l10n
                                            .containers_containerPort,
                                        initialValue: port.containerPort,
                                        onChanged: (v) =>
                                            _updatePort(i, containerPort: v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 80,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryBackground(
                                          context,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _updatePort(
                                          i,
                                          protocol: port.protocol == 'tcp'
                                              ? 'udp'
                                              : 'tcp',
                                        ),
                                        child: Text(
                                          port.protocol.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(left: 12),
                            onPressed: () =>
                                setState(() => _exposedPorts.removeAt(i)),
                            child: const Icon(
                              TablerIcons.trash,
                              size: 20,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              _AddButton(
                label: context.l10n.containers_addPortMapping,
                onPressed: () => setState(
                  () => _exposedPorts.add(
                    const ContainerPortDto(
                      hostIP: '',
                      hostPort: '',
                      containerPort: '',
                      protocol: 'tcp',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _updatePort(
    int index, {
    String? hostIP,
    String? hostPort,
    String? containerPort,
    String? protocol,
  }) {
    setState(() {
      final old = _exposedPorts[index];
      _exposedPorts[index] = ContainerPortDto(
        hostIP: hostIP ?? old.hostIP,
        hostPort: hostPort ?? old.hostPort,
        containerPort: containerPort ?? old.containerPort,
        protocol: protocol ?? old.protocol,
      );
    });
  }

  Widget _buildNetworkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_networkSettings,
          TablerIcons.network,
        ),
        _SectionCard(
          children: [
            _InputItem(
              label: context.l10n.containers_hostname,
              controller: _hostnameController,
              placeholder: context.l10n.containers_hostnamePlaceholder,
            ),
            const _CardDivider(),
            _InputItem(
              label: context.l10n.containers_domainName,
              controller: _domainNameController,
              placeholder: context.l10n.containers_domainNamePlaceholder,
            ),
            const _CardDivider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.containers_dnsServers,
                    style: TextStyle(
                      color: AppColors.label(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._dns.asMap().entries.map((entry) {
                    final i = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompactInput(
                        placeholder: context.l10n.containers_dnsAddress,
                        initialValue: entry.value,
                        onChanged: (v) => setState(() => _dns[i] = v),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => _dns.removeAt(i)),
                          child: Icon(
                            TablerIcons.x,
                            size: 16,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ),
                    );
                  }),
                  _AddButton(
                    label: context.l10n.containers_addDns,
                    onPressed: () => setState(() => _dns.add('')),
                  ),
                ],
              ),
            ),
            const _CardDivider(),
            ..._networks.asMap().entries.map((entry) {
              final i = entry.key;
              final net = entry.value;
              return Column(
                children: [
                  if (i > 0) const _CardDivider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.containers_networkValue(
                                  net.network,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  setState(() => _networks.removeAt(i)),
                              child: const Icon(
                                TablerIcons.trash,
                                size: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _CompactInput(
                                placeholder:
                                    context.l10n.containers_ipv4Address,
                                initialValue: net.ipv4,
                                onChanged: (v) => _updateNetwork(i, ipv4: v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CompactInput(
                                placeholder:
                                    context.l10n.containers_ipv6Address,
                                initialValue: net.ipv6,
                                onChanged: (v) => _updateNetwork(i, ipv6: v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _CompactInput(
                          placeholder: context.l10n.containers_macAddress,
                          initialValue: net.macAddr,
                          onChanged: (v) => _updateNetwork(i, macAddr: v),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            _AddButton(
              label: context.l10n.containers_addNetwork,
              onPressed: _showAddNetworkPicker,
            ),
          ],
        ),
      ],
    );
  }

  void _updateNetwork(
    int index, {
    String? ipv4,
    String? ipv6,
    String? macAddr,
  }) {
    setState(() {
      final old = _networks[index];
      _networks[index] = ContainerNetworkDto(
        network: old.network,
        ipv4: ipv4 ?? old.ipv4,
        ipv6: ipv6 ?? old.ipv6,
        macAddr: macAddr ?? old.macAddr,
      );
    });
  }

  void _showAddNetworkPicker() {
    final available = _allNetworks
        .where((n) => !_networks.any((en) => en.network == n.option))
        .toList();
    if (available.isEmpty) {
      showAppErrorToast(context.l10n.containers_noMoreNetworks);
      return;
    }
    _showListPicker(
      title: context.l10n.containers_selectNetwork,
      items: available.map((e) => e.option).toList(),
      onSelected: (v) {
        setState(
          () => _networks.add(
            ContainerNetworkDto(network: v, ipv4: '', ipv6: '', macAddr: ''),
          ),
        );
      },
    );
  }

  Widget _buildVolumesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_mountedVolumes,
          TablerIcons.database,
        ),
        _SectionCard(
          children: [
            ..._volumes.asMap().entries.map((entry) {
              final i = entry.key;
              final vol = entry.value;
              return Column(
                children: [
                  if (i > 0) const _CardDivider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                vol.type.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  setState(() => _volumes.removeAt(i)),
                              child: const Icon(
                                TablerIcons.trash,
                                size: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _CompactInput(
                          placeholder: context.l10n.containers_hostDirOrVolume,
                          initialValue: vol.sourceDir,
                          onChanged: (v) => _updateVolume(i, sourceDir: v),
                        ),
                        const SizedBox(height: 8),
                        _CompactInput(
                          placeholder: context.l10n.containers_containerDir,
                          initialValue: vol.containerDir,
                          onChanged: (v) => _updateVolume(i, containerDir: v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.background(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _updateVolume(
                                    i,
                                    mode: vol.mode == 'rw' ? 'ro' : 'rw',
                                  ),
                                  child: Text(
                                    vol.mode == 'rw'
                                        ? context.l10n.containers_readWrite
                                        : context.l10n.containers_readOnly,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.background(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _showPropagationPicker(i),
                                  child: Text(
                                    _getPropagationLabel(vol.shared),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            if (_showVolumePicker) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: AppInlinePicker<String>(
                  backgroundColor: AppColors.background(
                    context,
                  ).withValues(alpha: 0.4),
                  options: [
                    AppPickerOption(
                      label: context.l10n.containers_customPath,
                      value: 'custom',
                    ),
                    ..._allVolumes.map(
                      (e) => AppPickerOption(label: e.option, value: e.option),
                    ),
                  ],
                  value: '',
                  onChanged: (v) {
                    setState(() {
                      if (v == 'custom') {
                        _volumes.add(
                          const ContainerVolumeDto(
                            type: 'bind',
                            sourceDir: '',
                            containerDir: '',
                            mode: 'rw',
                            shared: '',
                          ),
                        );
                      } else {
                        _volumes.add(
                          ContainerVolumeDto(
                            type: 'volume',
                            sourceDir: v,
                            containerDir: '',
                            mode: 'rw',
                            shared: '',
                          ),
                        );
                      }
                      _showVolumePicker = false;
                    });
                  },
                ),
              ),
              const _CardDivider(),
            ],
            _AddButton(
              label: context.l10n.containers_addMount,
              onPressed: () =>
                  setState(() => _showVolumePicker = !_showVolumePicker),
            ),
          ],
        ),
      ],
    );
  }

  void _updateVolume(
    int index, {
    String? sourceDir,
    String? containerDir,
    String? mode,
    String? shared,
  }) {
    setState(() {
      final old = _volumes[index];
      _volumes[index] = ContainerVolumeDto(
        type: old.type,
        sourceDir: sourceDir ?? old.sourceDir,
        containerDir: containerDir ?? old.containerDir,
        mode: mode ?? old.mode,
        shared: shared ?? old.shared,
      );
    });
  }

  String _getPropagationLabel(String value) {
    if (value.isEmpty) return context.l10n.containers_defaultPropagation;
    return _propagationOptions.firstWhere(
      (e) => e['value'] == value,
      orElse: () => {'label': value},
    )['label']!;
  }

  List<Map<String, String>> get _propagationOptions => [
    {
      'label': context.l10n.containers_propagationPrivate,
      'value': 'private',
      'desc': context.l10n.containers_propagationPrivateDesc,
    },
    {
      'label': context.l10n.containers_propagationRprivate,
      'value': 'rprivate',
      'desc': context.l10n.containers_propagationRprivateDesc,
    },
    {
      'label': context.l10n.containers_propagationShared,
      'value': 'shared',
      'desc': context.l10n.containers_propagationSharedDesc,
    },
    {
      'label': context.l10n.containers_propagationRshared,
      'value': 'rshared',
      'desc': context.l10n.containers_propagationRsharedDesc,
    },
    {
      'label': context.l10n.containers_propagationSlave,
      'value': 'slave',
      'desc': context.l10n.containers_propagationSlaveDesc,
    },
    {
      'label': context.l10n.containers_propagationRslave,
      'value': 'rslave',
      'desc': context.l10n.containers_propagationRslaveDesc,
    },
  ];

  void _showPropagationPicker(int index) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.containers_propagationType),
        message: Text(context.l10n.containers_propagationMessage),
        actions: _propagationOptions
            .map(
              (e) => CupertinoActionSheetAction(
                onPressed: () {
                  _updateVolume(index, shared: e['value']!);
                  Navigator.pop(context);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e['label']!, style: const TextStyle(fontSize: 16)),
                    Text(
                      e['desc']!,
                      style: TextStyle(
                        color: AppColors.secondaryLabel(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
      ),
    );
  }

  Widget _buildHostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_hostsMapping,
          TablerIcons.address_book,
        ),
        _SectionCard(
          children: [
            ..._extraHosts.asMap().entries.map((entry) {
              final i = entry.key;
              return Padding(
                padding: const EdgeInsets.all(8),
                child: _CompactInput(
                  placeholder: 'hostname:IP',
                  initialValue: entry.value,
                  onChanged: (v) => setState(() => _extraHosts[i] = v),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _extraHosts.removeAt(i)),
                    child: Icon(
                      TablerIcons.x,
                      size: 16,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ),
              );
            }),
            _AddButton(
              label: context.l10n.containers_addHost,
              onPressed: () => setState(() => _extraHosts.add('')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_commandSettings,
          TablerIcons.terminal_2,
        ),
        _SectionCard(
          children: [
            _InputItem(
              label: context.l10n.containers_workingDir,
              controller: _workingDirController,
              placeholder: 'e.g. /app',
            ),
            const _CardDivider(),
            _InputItem(
              label: context.l10n.containers_user,
              controller: _userController,
              placeholder: 'e.g. root',
            ),
            const _CardDivider(),
            _InputItem(
              label: context.l10n.containers_command,
              controller: _cmdController,
              placeholder: 'e.g. npm start',
            ),
            const _CardDivider(),
            _InputItem(
              label: context.l10n.containers_entrypoint,
              controller: _entrypointController,
              placeholder: 'e.g. /entrypoint.sh',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResourcesSection() {
    final maxCpu = _systemLimit?.cpu ?? 1;
    final maxMemMb = ((_systemLimit?.memory ?? 0) / 1024 / 1024).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_resourceLimits,
          TablerIcons.chart_bar,
        ),
        _SectionCard(
          children: [
            _InputItem(
              label: context.l10n.containers_cpuShares,
              subtitle: context.l10n.containers_cpuSharesSubtitle,
              controller: _cpuSharesController,
              keyboardType: TextInputType.number,
              width: 100,
              trailing: Text(
                'Shares',
                style: TextStyle(
                  color: AppColors.tertiaryLabel(context),
                  fontSize: 12,
                ),
              ),
            ),
            const _CardDivider(),
            _InputItem(
              label: context.l10n.containers_cpuLimit,
              subtitle: context.l10n.containers_unlimitedZero,
              controller: _cpuLimitController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              width: 100,
              trailing: Text(
                context.l10n.containers_cpuCoresMax('$maxCpu'),
                style: TextStyle(
                  color: AppColors.tertiaryLabel(context),
                  fontSize: 12,
                ),
              ),
            ),
            const _CardDivider(),
            _InputItem(
              label: context.l10n.containers_memoryLimit,
              subtitle: context.l10n.containers_unlimitedZero,
              controller: _memoryController,
              keyboardType: TextInputType.number,
              width: 100,
              trailing: Text(
                context.l10n.containers_memoryMbMax('$maxMemMb'),
                style: TextStyle(
                  color: AppColors.tertiaryLabel(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabelsSection() => _buildKeyValueSection(
    context.l10n.containers_labels,
    TablerIcons.tags,
    _labels,
    (v) => setState(() => _labels = v),
  );
  Widget _buildEnvSection() => _buildKeyValueSection(
    context.l10n.containers_envVars,
    TablerIcons.variable,
    _env,
    (v) => setState(() => _env = v),
  );

  Widget _buildKeyValueSection(
    String title,
    IconData icon,
    List<String> items,
    ValueChanged<List<String>> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, icon),
        _SectionCard(
          children: [
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              return Padding(
                padding: const EdgeInsets.all(8),
                child: _CompactInput(
                  placeholder: 'KEY=VALUE',
                  initialValue: entry.value,
                  onChanged: (v) {
                    items[i] = v;
                    onChanged(items);
                  },
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      items.removeAt(i);
                      onChanged(items);
                    },
                    child: Icon(
                      TablerIcons.x,
                      size: 16,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ),
              );
            }),
            _AddButton(
              label: context.l10n.containers_addItem(title),
              onPressed: () {
                items.add('');
                onChanged(items);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRestartPolicySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context.l10n.containers_restartPolicy,
          TablerIcons.rotate,
        ),
        _SectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppInlinePicker<String>(
                backgroundColor: AppColors.background(
                  context,
                ).withValues(alpha: 0.4),
                options: [
                  AppPickerOption(
                    label: context.l10n.containers_restartAlways,
                    value: 'always',
                  ),
                  AppPickerOption(
                    label: context.l10n.containers_restartNo,
                    value: 'no',
                  ),
                  AppPickerOption(
                    label: context.l10n.containers_restartOnFailure,
                    value: 'on-failure',
                  ),
                  AppPickerOption(
                    label: context.l10n.containers_restartUnlessStopped,
                    value: 'unless-stopped',
                  ),
                ],
                value: _restartPolicy,
                onChanged: (v) => setState(() => _restartPolicy = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showListPicker({
    required String title,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: items
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () {
                  onSelected(item);
                  Navigator.pop(context);
                },
                child: Text(item),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InputItem extends StatelessWidget {
  const _InputItem({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.placeholder,
    this.keyboardType,
    this.trailing,
    this.subtitle,
    this.width,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? placeholder;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final String? subtitle;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.tertiaryLabel(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: width ?? 160,
            child: CupertinoTextField(
              controller: controller,
              enabled: enabled,
              placeholder: placeholder,
              keyboardType: keyboardType,
              autocorrect: false,
              placeholderStyle: TextStyle(
                color: AppColors.tertiaryLabel(context),
                fontSize: 14,
              ),
              style: TextStyle(
                color: enabled
                    ? AppColors.label(context)
                    : AppColors.secondaryLabel(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.background(context).withValues(alpha: 0.4)
                    : CupertinoColors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            SizedBox(width: 80, child: trailing!),
          ],
        ],
      ),
    );
  }
}

class _CompactInput extends StatelessWidget {
  const _CompactInput({
    required this.placeholder,
    required this.initialValue,
    required this.onChanged,
    this.trailing,
  });

  final String placeholder;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              placeholder: placeholder,
              controller: TextEditingController(text: initialValue)
                ..selection = TextSelection.collapsed(
                  offset: initialValue.length,
                ),
              onChanged: onChanged,
              autocorrect: false,
              placeholderStyle: TextStyle(
                color: AppColors.tertiaryLabel(context),
                fontSize: 12,
              ),
              style: TextStyle(color: AppColors.label(context), fontSize: 12),
              decoration: null,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  const _OptionItem({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
              AppToggleSwitch(value: value, onChanged: onChanged),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.tertiaryLabel(context),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(TablerIcons.plus, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        height: 0.5,
        color: AppColors.separator(context).withValues(alpha: 0.12),
      ),
    );
  }
}
