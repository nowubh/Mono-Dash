import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/snapshot/snapshot_dto.dart';
import '../../../../data/repositories_impl/backup_account_repository_impl.dart';
import '../../../../data/repositories_impl/setting_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/frosted_action_button.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../../common/components/skeleton_item.dart';
import '../../../common/components/thin_divider.dart';
import '../../server_detail/providers/active_server_provider.dart';

/// 导航至创建快照页面。
Future<void> navigateToSnapshotCreatePage(BuildContext context, int serverId) {
  return Navigator.of(context).push<void>(
    CupertinoPageRoute(
      builder: (_) => ProviderScope(
        overrides: [activeServerIdProvider.overrideWithValue(serverId)],
        child: SnapshotCreatePage(serverId: serverId),
      ),
    ),
  );
}

class SnapshotCreatePage extends ConsumerStatefulWidget {
  const SnapshotCreatePage({super.key, required this.serverId});

  final int serverId;

  @override
  ConsumerState<SnapshotCreatePage> createState() => _SnapshotCreatePageState();
}

class _SnapshotCreatePageState extends ConsumerState<SnapshotCreatePage> {
  // Step 1: accounts
  List<Map<String, dynamic>> _accountOptions = [];
  final Set<int> _selectedAccountIds = {};
  int _downloadAccountId = 0;

  // Step 2: data trees
  SnapshotData? _snapshotData;
  bool _loadingData = true;
  final Set<String> _selectedNodeIds = {};
  final Set<String> _expandedNodeIds = {};

  // Step 3: options
  bool _withDockerConf = true;
  bool _withOperationLog = false;
  bool _withLoginLog = false;
  bool _withSystemLog = false;
  bool _withTaskLog = false;
  bool _withMonitorData = false;

  // Step 4: advanced
  final _passwordController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _timeoutUnit = 'second';
  final _timeoutController = TextEditingController(text: '3600');

  bool _saving = false;
  bool _loadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadSnapshotData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _descriptionController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final repo = await ref.read(backupAccountRepositoryProvider.future);
      final result = await repo.searchAccounts(page: 1, pageSize: 100);
      if (!mounted) return;
      final items = result['items'];
      setState(() {
        _accountOptions = items is List
            ? items.whereType<Map<String, dynamic>>().toList()
            : [];
        _loadingAccounts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _loadSnapshotData() async {
    try {
      final repo = await ref.read(settingRepositoryProvider.future);
      final data = await repo.loadSnapshotData();
      if (!mounted) return;
      final snapshotData = SnapshotData.fromJson(data);
      setState(() {
        _snapshotData = snapshotData;
        _loadingData = false;
        // 初始勾选默认节点
        _initializeSelection(snapshotData.appData);
        _initializeSelection(snapshotData.panelData);
        _initializeSelection(snapshotData.backupData);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingData = false);
    }
  }

  void _initializeSelection(List<DataTree> trees) {
    for (final node in trees) {
      if (node.isCheck) _selectedNodeIds.add(node.id);
      _initializeSelection(node.children);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      title: context.l10n.panelSettings_createSnapshot,
      trailingBuilder: (isDark, isOverlapping) => FrostedActionButton(
        text: context.l10n.common_create,
        isLoading: _saving,
        isDark: isDark,
        isOverlapping: isOverlapping,
        onTap: _saving ? null : _onSave,
      ),
      body: _loadingAccounts || _loadingData
          ? _buildSkeleton()
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                FrostedScaffold.contentTopPadding(context) + 20,
                16,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基础配置
                  AppSectionHeader(
                    title: context.l10n.panelSettings_baseInfo,
                    icon: TablerIcons.info_circle,
                  ),
                  AppActionGroup(
                    children: [
                      _buildInlineInputRow(
                        label: context.l10n.panelSettings_remarkDescription,
                        placeholder: context.l10n.panelSettings_optional,
                        controller: _descriptionController,
                      ),
                      _buildInlineInputRow(
                        label: context.l10n.panelSettings_compressionPassword,
                        placeholder: context.l10n.panelSettings_optional,
                        controller: _passwordController,
                        obscureText: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 备份账号
                  AppSectionHeader(
                    title: context.l10n.panelSettings_storageAccounts,
                    icon: TablerIcons.cloud,
                  ),
                  _buildAccountSection(),
                  const SizedBox(height: 24),

                  // 数据选择
                  AppSectionHeader(
                    title: context.l10n.panelSettings_dataContent,
                    icon: TablerIcons.database,
                  ),
                  _buildDataSelectionSection(),
                  const SizedBox(height: 24),

                  // 附加选项
                  AppSectionHeader(
                    title: context.l10n.panelSettings_extraOptions,
                    icon: TablerIcons.checklist,
                  ),
                  AppActionGroup(
                    children: [
                      _buildSwitchRow(
                        context.l10n.panelSettings_dockerConfig,
                        _withDockerConf,
                        (v) => setState(() => _withDockerConf = v),
                        TablerIcons.brand_docker,
                        CupertinoColors.systemBlue,
                      ),
                      _buildSwitchRow(
                        context.l10n.panelSettings_monitorData,
                        _withMonitorData,
                        (v) => setState(() => _withMonitorData = v),
                        TablerIcons.chart_area_line,
                        CupertinoColors.systemTeal,
                      ),
                      _buildSwitchRow(
                        context.l10n.panelSettings_logFiles,
                        _isAnyLogEnabled,
                        _toggleAllLogs,
                        TablerIcons.file_text,
                        CupertinoColors.systemOrange,
                        trailing: Icon(
                          _expandedNodeIds.contains('logs_group')
                              ? TablerIcons.chevron_down
                              : TablerIcons.chevron_right,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                        onTap: () {
                          setState(() {
                            if (_expandedNodeIds.contains('logs_group')) {
                              _expandedNodeIds.remove('logs_group');
                            } else {
                              _expandedNodeIds.add('logs_group');
                            }
                          });
                        },
                      ),
                      if (_expandedNodeIds.contains('logs_group'))
                        Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: Column(
                            children: [
                              _buildSubSwitchRow(
                                context.l10n.panelSettings_operationLog,
                                _withOperationLog,
                                (v) => setState(() => _withOperationLog = v),
                              ),
                              _buildSubSwitchRow(
                                context.l10n.panelSettings_loginLog,
                                _withLoginLog,
                                (v) => setState(() => _withLoginLog = v),
                              ),
                              _buildSubSwitchRow(
                                context.l10n.panelSettings_systemLog,
                                _withSystemLog,
                                (v) => setState(() => _withSystemLog = v),
                              ),
                              _buildSubSwitchRow(
                                context.l10n.panelSettings_taskLog,
                                _withTaskLog,
                                (v) => setState(() => _withTaskLog = v),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 高级设置
                  AppSectionHeader(
                    title: context.l10n.panelSettings_advancedSettings,
                    icon: TablerIcons.settings,
                  ),
                  AppActionGroup(children: [_buildTimeoutRow()]),
                ],
              ),
            ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        FrostedScaffold.contentTopPadding(context) + 20,
        16,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: 基础信息
          const Row(
            children: [
              SkeletonItem(width: 16, height: 16),
              SizedBox(width: 8),
              SkeletonItem(width: 60, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SkeletonItem(width: 60, height: 14),
                      Spacer(),
                      SkeletonItem(width: 100, height: 14),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: ThinDivider(),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SkeletonItem(width: 60, height: 14),
                      Spacer(),
                      SkeletonItem(width: 80, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: 存储账号
          const Row(
            children: [
              SkeletonItem(width: 16, height: 16),
              SizedBox(width: 8),
              SkeletonItem(width: 60, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: List.generate(
                2,
                (index) => Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          SkeletonItem(width: 20, height: 20, borderRadius: 4),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonItem(width: 100, height: 14),
                              SizedBox(height: 6),
                              SkeletonItem(width: 40, height: 10),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (index == 0)
                      const Padding(
                        padding: EdgeInsets.only(left: 48),
                        child: ThinDivider(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: 数据内容
          const Row(
            children: [
              SkeletonItem(width: 16, height: 16),
              SizedBox(width: 8),
              SkeletonItem(width: 60, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: List.generate(
                3,
                (index) => Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          SkeletonItem(width: 28, height: 28, borderRadius: 6),
                          SizedBox(width: 12),
                          SkeletonItem(width: 80, height: 14),
                          Spacer(),
                          SkeletonItem(width: 40, height: 12),
                          SizedBox(width: 8),
                          SkeletonItem(width: 12, height: 12),
                        ],
                      ),
                    ),
                    if (index < 2)
                      const Padding(
                        padding: EdgeInsets.only(left: 56),
                        child: ThinDivider(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: 附加选项
          const Row(
            children: [
              SkeletonItem(width: 16, height: 16),
              SizedBox(width: 8),
              SkeletonItem(width: 60, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: List.generate(
                3,
                (index) => Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          SkeletonItem(width: 28, height: 28, borderRadius: 6),
                          SizedBox(width: 12),
                          SkeletonItem(width: 90, height: 14),
                          Spacer(),
                          SkeletonItem(width: 40, height: 20, borderRadius: 10),
                        ],
                      ),
                    ),
                    if (index < 2)
                      const Padding(
                        padding: EdgeInsets.only(left: 56),
                        child: ThinDivider(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    if (_accountOptions.isEmpty) {
      return AppActionGroup(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              context.l10n.panelSettings_addBackupAccountFirst,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),
        ],
      );
    }

    return AppActionGroup(
      children: [
        ..._accountOptions.map((acc) {
          final id = (acc['id'] as num?)?.toInt() ?? 0;
          final name = (acc['name'] as String?) ?? '';
          final type = (acc['type'] as String?) ?? '';
          final isSelected = _selectedAccountIds.contains(id);

          return CupertinoListTile(
            title: Text(
              name,
              style: TextStyle(fontSize: 15, color: AppColors.label(context)),
            ),
            subtitle: Text(
              type.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
            ),
            leading: Icon(
              isSelected ? TablerIcons.checkbox : TablerIcons.square,
              color: isSelected
                  ? CupertinoColors.activeBlue.resolveFrom(context)
                  : AppColors.tertiaryLabel(context),
              size: 20,
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedAccountIds.remove(id);
                  if (_downloadAccountId == id) {
                    _downloadAccountId = _selectedAccountIds.isNotEmpty
                        ? _selectedAccountIds.first
                        : 0;
                  }
                } else {
                  _selectedAccountIds.add(id);
                  if (_downloadAccountId == 0) _downloadAccountId = id;
                }
              });
            },
          );
        }),
        if (_selectedAccountIds.isNotEmpty)
          CupertinoListTile(
            title: Text(
              context.l10n.panelSettings_downloadNode,
              style: TextStyle(fontSize: 15, color: AppColors.label(context)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _downloadAccountName,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  TablerIcons.chevron_right,
                  size: 14,
                  color: AppColors.tertiaryLabel(context),
                ),
              ],
            ),
            onTap: _showDownloadAccountPicker,
          ),
      ],
    );
  }

  Widget _buildDataSelectionSection() {
    if (_snapshotData == null) return const SizedBox.shrink();

    return AppActionGroup(
      children: [
        if (_snapshotData!.appData.isNotEmpty)
          _buildTreeEntry(
            context.l10n.panelSettings_appData,
            _snapshotData!.appData,
            TablerIcons.apps,
            CupertinoColors.systemPink,
          ),
        if (_snapshotData!.panelData.isNotEmpty)
          _buildTreeEntry(
            context.l10n.panelSettings_panelData,
            _snapshotData!.panelData,
            TablerIcons.layout_dashboard,
            CupertinoColors.systemIndigo,
          ),
        if (_snapshotData!.backupData.isNotEmpty)
          _buildTreeEntry(
            context.l10n.panelSettings_backupData,
            _snapshotData!.backupData,
            TablerIcons.cloud_download,
            CupertinoColors.systemGreen,
          ),
      ],
    );
  }

  Widget _buildTreeEntry(
    String title,
    List<DataTree> trees,
    IconData icon,
    Color color,
  ) {
    final isExpanded = _expandedNodeIds.contains(title);
    final selectedCount = _countSelected(trees);
    final totalCount = _countTotal(trees);

    return Column(
      children: [
        CupertinoListTile(
          title: Text(
            title,
            style: TextStyle(fontSize: 15, color: AppColors.label(context)),
          ),
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$selectedCount / $totalCount',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isExpanded
                    ? TablerIcons.chevron_down
                    : TablerIcons.chevron_right,
                size: 14,
                color: AppColors.tertiaryLabel(context),
              ),
            ],
          ),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedNodeIds.remove(title);
              } else {
                _expandedNodeIds.add(title);
              }
            });
          },
        ),
        if (isExpanded)
          Container(
            color: AppColors.tertiaryBackground(context).withValues(alpha: 0.3),
            child: Column(
              children: trees.map((node) => _buildTreeNode(node, 0)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTreeNode(DataTree node, int depth) {
    final hasChildren = node.children.isNotEmpty;
    final isSelected = _selectedNodeIds.contains(node.id);
    final isExpanded = _expandedNodeIds.contains(node.id);

    return Column(
      children: [
        GestureDetector(
          onTap: node.isDisable
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedNodeIds.remove(node.id);
                      _toggleChildren(node.children, false);
                    } else {
                      _selectedNodeIds.add(node.id);
                      _toggleChildren(node.children, true);
                    }
                  });
                },
          child: Container(
            padding: EdgeInsets.fromLTRB(16.0 + depth * 16, 10, 16, 10),
            color: CupertinoColors.transparent,
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedNodeIds.remove(node.id);
                        } else {
                          _expandedNodeIds.add(node.id);
                        }
                      });
                    },
                    child: Icon(
                      isExpanded
                          ? TablerIcons.chevron_down
                          : TablerIcons.chevron_right,
                      size: 12,
                      color: AppColors.tertiaryLabel(context),
                    ),
                  )
                else
                  const SizedBox(width: 12),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? TablerIcons.checkbox : TablerIcons.square,
                  size: 18,
                  color: isSelected
                      ? CupertinoColors.activeBlue.resolveFrom(context)
                      : AppColors.tertiaryLabel(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    node.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: node.isDisable
                          ? AppColors.tertiaryLabel(context)
                          : AppColors.label(context),
                    ),
                  ),
                ),
                if (node.size > 0)
                  Text(
                    _formatSize(node.size),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          ...node.children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  void _toggleChildren(List<DataTree> children, bool select) {
    for (final child in children) {
      if (select) {
        _selectedNodeIds.add(child.id);
      } else {
        _selectedNodeIds.remove(child.id);
      }
      _toggleChildren(child.children, select);
    }
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
    Color color, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return CupertinoListTile(
      title: Text(
        label,
        style: TextStyle(fontSize: 15, color: AppColors.label(context)),
      ),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[trailing, const SizedBox(width: 8)],
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSubSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildInlineInputRow({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: AppColors.label(context)),
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              obscureText: obscureText,
              textAlign: TextAlign.end,
              decoration: null,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.secondaryLabel(context),
              ),
              placeholderStyle: TextStyle(
                fontSize: 15,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutRow() {
    return CupertinoListTile(
      title: Text(
        context.l10n.panelSettings_timeout,
        style: TextStyle(fontSize: 15, color: AppColors.label(context)),
      ),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          TablerIcons.clock,
          color: CupertinoColors.systemGrey,
          size: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            child: CupertinoTextField(
              controller: _timeoutController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              decoration: null,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showTimeoutUnitPicker,
            child: Row(
              children: [
                Text(
                  _timeoutUnitLabel,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                ),
                Icon(
                  TablerIcons.chevron_down,
                  size: 14,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _downloadAccountName {
    if (_downloadAccountId == 0) return context.l10n.common_noSelection;
    final acc = _accountOptions.firstWhere(
      (a) => (a['id'] as num?)?.toInt() == _downloadAccountId,
      orElse: () => {},
    );
    return (acc['name'] as String?) ?? context.l10n.common_unknown;
  }

  bool get _isAnyLogEnabled =>
      _withOperationLog || _withLoginLog || _withSystemLog || _withTaskLog;

  void _toggleAllLogs(bool value) {
    setState(() {
      _withOperationLog = value;
      _withLoginLog = value;
      _withSystemLog = value;
      _withTaskLog = value;
    });
  }

  int _countSelected(List<DataTree> trees) {
    int count = 0;
    for (final node in trees) {
      if (_selectedNodeIds.contains(node.id)) count++;
      count += _countSelected(node.children);
    }
    return count;
  }

  int _countTotal(List<DataTree> trees) {
    int count = 0;
    for (final node in trees) {
      count++;
      count += _countTotal(node.children);
    }
    return count;
  }

  void _showDownloadAccountPicker() {
    final options = _accountOptions.where((a) {
      final id = (a['id'] as num?)?.toInt() ?? 0;
      return _selectedAccountIds.contains(id);
    }).toList();

    if (options.isEmpty) {
      showAppErrorToast(
        context.l10n.panelSettings_chooseAtLeastOneSourceAccount,
      );
      return;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.panelSettings_chooseDownloadAccountTitle),
        actions: options.map((acc) {
          final id = (acc['id'] as num?)?.toInt() ?? 0;
          final name = (acc['name'] as String?) ?? '';
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _downloadAccountId = id);
              Navigator.of(ctx).pop();
            },
            child: Text(name),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ),
    );
  }

  void _showTimeoutUnitPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: ['second', 'minute', 'hour'].map((unit) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _timeoutUnit = unit);
              Navigator.of(ctx).pop();
            },
            child: Text(_timeoutUnitName(unit)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_selectedAccountIds.isEmpty) {
      showAppErrorToast(
        context.l10n.panelSettings_chooseAtLeastOneBackupAccount,
      );
      return;
    }
    if (_downloadAccountId == 0) {
      showAppErrorToast(context.l10n.panelSettings_chooseDownloadAccount);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = await ref.read(settingRepositoryProvider.future);

      // 构建数据树，根据勾选状态更新 isCheck
      List<Map<String, dynamic>> updateTree(List<DataTree> trees) {
        return trees.map((node) {
          final isSelected = _selectedNodeIds.contains(node.id);
          final children = updateTree(node.children);
          final json = node.toJson();
          json['isCheck'] = isSelected;
          json['children'] = children;
          return json;
        }).toList();
      }

      await repo.createSnapshot({
        'id': 0,
        'taskID': const Uuid().v4(),
        'sourceAccountIDs': _selectedAccountIds.join(','),
        'downloadAccountID': _downloadAccountId,
        'description': _descriptionController.text.trim(),
        'secret': _passwordController.text,
        'timeout': _getTimeoutInSeconds(),
        'appData': updateTree(_snapshotData?.appData ?? []),
        'panelData': updateTree(_snapshotData?.panelData ?? []),
        'backupData': updateTree(_snapshotData?.backupData ?? []),
        'withDockerConf': _withDockerConf,
        'withMonitorData': _withMonitorData,
        'withLoginLog': _withLoginLog,
        'withOperationLog': _withOperationLog,
        'withSystemLog': _withSystemLog,
        'withTaskLog': _withTaskLog,
        'ignoreFiles': <String>[],
      });

      if (mounted) {
        showAppSuccessToast(context.l10n.panelSettings_snapshotCreateStarted);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.panelSettings_createFailed,
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _getTimeoutInSeconds() {
    final value = int.tryParse(_timeoutController.text) ?? 3600;
    switch (_timeoutUnit) {
      case 'minute':
        return value * 60;
      case 'hour':
        return value * 3600;
      default:
        return value;
    }
  }

  String get _timeoutUnitLabel => _timeoutUnitName(_timeoutUnit);

  String _timeoutUnitName(String unit) {
    switch (unit) {
      case 'minute':
        return context.l10n.panelSettings_minute;
      case 'hour':
        return context.l10n.panelSettings_hour;
      default:
        return context.l10n.panelSettings_second;
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
