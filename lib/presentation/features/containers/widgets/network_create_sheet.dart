import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/container/network_dtos.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_picker.dart';
import '../providers/network_provider.dart';
import '../../../../data/repositories_impl/dashboard_repository_impl.dart';

/// 显示创建网络 BottomSheet
void showNetworkCreateSheet(BuildContext context) {
  showActionSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => const _NetworkCreateSheet(),
  );
}

class _NetworkCreateSheet extends ConsumerStatefulWidget {
  const _NetworkCreateSheet();

  @override
  ConsumerState<_NetworkCreateSheet> createState() =>
      _NetworkCreateSheetState();
}

class _NetworkCreateSheetState extends ConsumerState<_NetworkCreateSheet> {
  final _nameController = TextEditingController();
  String _driver = 'bridge';

  // macvlan parent network card
  String _parentNic = '';
  List<String> _netOptions = [];

  // IPv4
  bool _ipv4 = false;
  final _subnetController = TextEditingController();
  final _gatewayController = TextEditingController();
  final _ipRangeController = TextEditingController();
  final List<_AuxEntry> _auxAddress = [];

  // IPv6
  bool _ipv6 = false;
  final _subnetV6Controller = TextEditingController();
  final _gatewayV6Controller = TextEditingController();
  final _ipRangeV6Controller = TextEditingController();
  final List<_AuxEntry> _auxAddressV6 = [];

  // Advanced
  final _labelsController = TextEditingController();
  final _optionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNetOptions();
  }

  Future<void> _loadNetOptions() async {
    try {
      final dashboardRepo = await ref.read(dashboardRepositoryProvider.future);
      final options = await dashboardRepo.getMonitorNetOptions();
      if (mounted) {
        setState(() {
          _netOptions = options.where((o) => o != 'all').toList();
          if (_netOptions.isNotEmpty) {
            _parentNic = _netOptions.first;
          }
        });
      }
    } catch (_) {
      // ignore — netoptions not critical for non-macvlan
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subnetController.dispose();
    _gatewayController.dispose();
    _ipRangeController.dispose();
    _subnetV6Controller.dispose();
    _gatewayV6Controller.dispose();
    _ipRangeV6Controller.dispose();
    _labelsController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppErrorToast(context.l10n.containers_networkNameRequired);
      return;
    }

    // Parse labels and options from text
    final labels = _labelsController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final options = _optionsController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // macvlan: auto-append parent option
    if (_driver == 'macvlan' && _parentNic.isNotEmpty) {
      options.add('parent=$_parentNic');
    }

    // Filter out empty aux entries
    final aux4 = _auxAddress.where(
      (e) => e.key.isNotEmpty && e.value.isNotEmpty,
    );
    final aux6 = _auxAddressV6.where(
      (e) => e.key.isNotEmpty && e.value.isNotEmpty,
    );

    final req = NetworkCreateReq(
      name: name,
      driver: _driver,
      options: options,
      labels: labels,
      ipv4: _ipv4,
      subnet: _subnetController.text.trim(),
      gateway: _gatewayController.text.trim(),
      ipRange: _ipRangeController.text.trim(),
      auxAddress: aux4
          .map((e) => AuxAddress(key: e.key, value: e.value))
          .toList(),
      ipv6: _ipv6,
      subnetV6: _subnetV6Controller.text.trim(),
      gatewayV6: _gatewayV6Controller.text.trim(),
      ipRangeV6: _ipRangeV6Controller.text.trim(),
      auxAddressV6: aux6
          .map((e) => AuxAddress(key: e.key, value: e.value))
          .toList(),
    );

    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.createNetwork(req);

      if (!mounted) return;
      Navigator.pop(context);
      showAppSuccessToast(context.l10n.containers_networkCreated);
      ref.read(networkControllerProvider.notifier).refresh();
    } catch (e) {
      showAppErrorToast(
        context.l10n.databases_createFailed,
        description: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      maxHeightFactor: 0.78,
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      panelHeader: Padding(
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
                context.l10n.containers_createNetwork,
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
              onPressed: _submit,
              child: Text(
                context.l10n.common_create,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context.l10n.containers_basicInfo,
              TablerIcons.info_circle,
            ),
            const SizedBox(height: 12),
            _buildFormContainer([
              CupertinoTextField(
                controller: _nameController,
                placeholder:
                    context.l10n.containers_networkNameRequiredPlaceholder,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: null,
                style: TextStyle(color: AppColors.label(context), fontSize: 15),
              ),
              _buildDivider(),
              _buildLabel(context.l10n.containers_driverType),
              const SizedBox(height: 8),
              AppInlinePicker<String>(
                options: const [
                  AppPickerOption(value: 'bridge', label: 'Bridge'),
                  AppPickerOption(value: 'ipvlan', label: 'IPvlan'),
                  AppPickerOption(value: 'macvlan', label: 'Macvlan'),
                  AppPickerOption(value: 'overlay', label: 'Overlay'),
                ],
                value: _driver,
                onChanged: (v) => setState(() => _driver = v),
                maxVisibleItems: 4,
                backgroundColor: AppColors.tertiaryBackground(
                  context,
                ).withValues(alpha: 0.5),
              ),
            ]),
            if (_driver == 'macvlan' && _netOptions.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionTitle(
                context.l10n.containers_parentNic,
                TablerIcons.network,
              ),
              const SizedBox(height: 12),
              _buildFormContainer([
                _buildLabel(context.l10n.containers_selectParentNic),
                const SizedBox(height: 8),
                AppInlinePicker<String>(
                  options: _netOptions
                      .map((o) => AppPickerOption(value: o, label: o))
                      .toList(),
                  value: _parentNic,
                  onChanged: (v) => setState(() => _parentNic = v),
                  maxVisibleItems: 5,
                  backgroundColor: AppColors.tertiaryBackground(
                    context,
                  ).withValues(alpha: 0.5),
                ),
              ]),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle(
              context.l10n.containers_ipv4Config,
              TablerIcons.world,
            ),
            const SizedBox(height: 12),
            _buildFormContainer([
              _OptionItem(
                label: context.l10n.containers_enableIpv4,
                value: _ipv4,
                onChanged: (v) => setState(() => _ipv4 = v),
              ),
              if (_ipv4) ...[
                _buildDivider(),
                CupertinoTextField(
                  controller: _subnetController,
                  placeholder: context.l10n.containers_subnetExample,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: null,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 15,
                  ),
                ),
                _buildDivider(),
                CupertinoTextField(
                  controller: _gatewayController,
                  placeholder: context.l10n.containers_gatewayExample,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: null,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 15,
                  ),
                ),
                _buildDivider(),
                CupertinoTextField(
                  controller: _ipRangeController,
                  placeholder: context.l10n.containers_ipRangeOptional,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: null,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 15,
                  ),
                ),
                if (_auxAddress.isNotEmpty) ...[
                  _buildDivider(),
                  _buildLabel(context.l10n.containers_auxAddress),
                  const SizedBox(height: 8),
                  ..._auxAddress.asMap().entries.map((entry) {
                    final i = entry.key;
                    final aux = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              controller: aux.keyController,
                              placeholder: context.l10n.containers_name,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: null,
                              style: TextStyle(
                                color: AppColors.label(context),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoTextField(
                              controller: aux.valueController,
                              placeholder: context.l10n.containers_ipAddress,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: null,
                              style: TextStyle(
                                color: AppColors.label(context),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(left: 8),
                            minimumSize: Size.zero,
                            onPressed: () {
                              setState(() {
                                _auxAddress[i].dispose();
                                _auxAddress.removeAt(i);
                              });
                            },
                            child: Icon(
                              TablerIcons.x,
                              size: 16,
                              color: CupertinoColors.systemRed.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => setState(() => _auxAddress.add(_AuxEntry())),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        TablerIcons.plus,
                        size: 14,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.containers_addAuxAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context.l10n.containers_ipv6Config,
              TablerIcons.world_latitude,
            ),
            const SizedBox(height: 12),
            _buildFormContainer([
              _OptionItem(
                label: context.l10n.containers_enableIpv6,
                value: _ipv6,
                onChanged: (v) => setState(() => _ipv6 = v),
              ),
              if (_ipv6) ...[
                _buildDivider(),
                CupertinoTextField(
                  controller: _subnetV6Controller,
                  placeholder: context.l10n.containers_subnetV6Example,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: null,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 15,
                  ),
                ),
                _buildDivider(),
                CupertinoTextField(
                  controller: _gatewayV6Controller,
                  placeholder: context.l10n.containers_gateway,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: null,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 15,
                  ),
                ),
                _buildDivider(),
                CupertinoTextField(
                  controller: _ipRangeV6Controller,
                  placeholder: context.l10n.containers_ipRangeOptional,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: null,
                  style: TextStyle(
                    color: AppColors.label(context),
                    fontSize: 15,
                  ),
                ),
                if (_auxAddressV6.isNotEmpty) ...[
                  _buildDivider(),
                  _buildLabel(context.l10n.containers_auxAddress),
                  const SizedBox(height: 8),
                  ..._auxAddressV6.asMap().entries.map((entry) {
                    final i = entry.key;
                    final aux = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              controller: aux.keyController,
                              placeholder: context.l10n.containers_name,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: null,
                              style: TextStyle(
                                color: AppColors.label(context),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoTextField(
                              controller: aux.valueController,
                              placeholder: context.l10n.containers_ipv6Address,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: null,
                              style: TextStyle(
                                color: AppColors.label(context),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(left: 8),
                            minimumSize: Size.zero,
                            onPressed: () {
                              setState(() {
                                _auxAddressV6[i].dispose();
                                _auxAddressV6.removeAt(i);
                              });
                            },
                            child: Icon(
                              TablerIcons.x,
                              size: 16,
                              color: CupertinoColors.systemRed.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () =>
                      setState(() => _auxAddressV6.add(_AuxEntry())),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        TablerIcons.plus,
                        size: 14,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.containers_addAuxAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle(
              context.l10n.containers_advancedOptions,
              TablerIcons.adjustments,
            ),
            const SizedBox(height: 12),
            _buildFormContainer([
              CupertinoTextField(
                controller: _labelsController,
                placeholder: context.l10n.containers_labelsPlaceholder,
                maxLines: 3,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: null,
                style: TextStyle(color: AppColors.label(context), fontSize: 15),
              ),
              _buildDivider(),
              CupertinoTextField(
                controller: _optionsController,
                placeholder: context.l10n.containers_driverOptionsPlaceholder,
                maxLines: 3,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: null,
                style: TextStyle(color: AppColors.label(context), fontSize: 15),
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.separator(context).withValues(alpha: 0.15),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.secondaryLabel(context),
      ),
    );
  }
}

class _AuxEntry {
  _AuxEntry({String key = '', String value = ''})
    : keyController = TextEditingController(text: key),
      valueController = TextEditingController(text: value);

  final TextEditingController keyController;
  final TextEditingController valueController;

  String get key => keyController.text.trim();
  String get value => valueController.text.trim();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class _OptionItem extends StatelessWidget {
  const _OptionItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.label(context),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
