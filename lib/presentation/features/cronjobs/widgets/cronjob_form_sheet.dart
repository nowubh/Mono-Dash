import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/api/app_api.dart';
import '../../../../data/api/backup_api.dart';
import '../../../../data/api/container_api.dart';
import '../../../../data/api/cronjob_api.dart';
import '../../../../data/api/database_api.dart';
import '../../../../data/api/toolbox_api.dart';
import '../../../../data/api/website_api.dart';
import '../../../../data/dto/app/app_installed_search_req.dart';
import '../../../../data/dto/cronjob/cronjob_dto.dart';
import '../../../../data/dto/cronjob/cronjob_form_data_dto.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_picker.dart';
import '../../../common/components/file_browser_picker_sheet.dart';
import '../../server_detail/providers/active_server_provider.dart';

/// 打开计划任务创建/编辑表单。
Future<void> showCronjobFormSheet(
  BuildContext context, {
  CronjobDto? editItem,
  required Future<void> Function(CronjobCreateReq req) onSubmit,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (ctx) => _CronjobFormSheet(editItem: editItem, onSubmit: onSubmit),
  );
}

// ── 常量 ────────────────────────────────────────────────────

const _specTypes = [
  'perMonth',
  'perWeek',
  'perDay',
  'perHour',
  'perNDay',
  'perNHour',
  'perNMinute',
];

const _weekDays = [1, 2, 3, 4, 5, 6, 0];

const _dbTypes = [
  {'label': 'MySQL', 'value': 'mysql'},
  {'label': 'MySQL-Cluster', 'value': 'mysql-cluster'},
  {'label': 'MariaDB', 'value': 'mariadb'},
  {'label': 'PostgreSQL', 'value': 'postgresql'},
  {'label': 'PostgreSQL-Cluster', 'value': 'postgresql-cluster'},
  {'label': 'MongoDB', 'value': 'mongodb'},
];

const _mysqlArgs = ['--single-transaction', '--quick', '--skip-lock-tables'];

const _executorOptions = ['bash', 'sh', 'python', 'python2', 'python3'];
const _containerCommands = ['ash', 'bash', 'sh'];

const _themeColor = CupertinoColors.activeBlue;

// ── 辅助判断函数（与 1Panel 前端一致）────────────────────

bool _isBackup(String type) =>
    type == 'app' ||
    type == 'website' ||
    type == 'database' ||
    type == 'directory' ||
    type == 'snapshot' ||
    type == 'log';

bool _hasExclusionRules(String type, bool isDir) =>
    type == 'app' ||
    type == 'website' ||
    type == 'snapshot' ||
    (type == 'directory' && isDir);

bool _hasIgnore(String type) =>
    type == 'app' || type == 'website' || type == 'database';

bool _isWebsiteType(String type) =>
    type == 'website' || type == 'cutWebsiteLog';

// ── Widget ──────────────────────────────────────────────────

class _CronjobFormSheet extends ConsumerStatefulWidget {
  const _CronjobFormSheet({this.editItem, required this.onSubmit});

  final CronjobDto? editItem;
  final Future<void> Function(CronjobCreateReq req) onSubmit;

  @override
  ConsumerState<_CronjobFormSheet> createState() => _CronjobFormSheetState();
}

class _CronjobFormSheetState extends ConsumerState<_CronjobFormSheet> {
  // ── 基础字段 ──
  final _nameController = TextEditingController();
  final _specCustomController = TextEditingController();
  final _scriptController = TextEditingController();
  final _secretController = TextEditingController();
  final _retainCopiesController = TextEditingController(text: '7');
  final _retryTimesController = TextEditingController(text: '3');
  final _timeoutValueController = TextEditingController(text: '3600');

  String _type = 'shell';
  String _specType = 'perDay';
  int _weekDay = 1;
  int _day = 1;
  int _hour = 2;
  int _minute = 30;
  bool _specCustom = false;
  bool _isSubmitting = false;
  bool _anyPickerExpanded = false;
  bool _isLoadingOptions = true;

  // ── Shell 专属 ──
  bool _inContainer = false;
  String _executor = 'bash';
  bool _isCustomExecutor = false;
  String _scriptMode = 'input'; // input / library / select
  int? _scriptID;
  String _containerName = '';
  String _user = '';

  // ── 备份类型 ──
  List<String> _sourceAccountIDs = [];
  int _downloadAccountID = 0;

  // ── App ──
  List<String> _appIdList = [];

  // ── Website / cutWebsiteLog ──
  List<String> _websiteList = [];

  // ── Database ──
  String _dbType = 'mysql';
  List<String> _dbNameList = [];
  List<String> _argItems = [];

  // ── Directory ──
  bool _isDir = true;
  String _sourceDir = '';
  List<String> _files = [];

  // ── Curl ──
  List<String> _urlItems = [''];

  // ── Snapshot ──
  bool _withImage = false;
  List<int> _ignoreAppIDs = [];

  // ── Exclusion rules ──
  List<String> _ignoreFiles = [];

  // ── CleanLog ──
  List<String> _scopes = [];

  // ── 通用设置 ──
  int _retainCopies = 7;
  bool _ignoreErr = false;
  int _retryTimes = 3;
  int _timeoutValue = 3600;

  // ── 选项数据 ──
  List<BackupOptionDto> _backupOptions = [];
  List<WebsiteOptionDto> _websiteOptions = [];
  List<AppInstalledOption> _appOptions = [];
  List<ContainerOption> _containerOptions = [];
  List<String> _userOptions = [];
  List<ScriptOptionDto> _scriptOptions = [];
  List<DatabaseItemDto> _databaseItems = [];

  bool get _isEdit => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final serverId = ref.read(activeServerIdProvider);
    final client = await ref.read(dioClientProvider(serverId).future);
    final cronjobApi = CronjobApi(client);
    final backupApi = BackupApi(client);
    final websiteApi = WebsiteApi(client);
    final toolboxApi = ToolboxApi(client);
    final containerApi = ContainerApi(client);
    final databaseApi = DatabaseApi(client);
    final appApi = AppApi(client);

    try {
      final results = await Future.wait([
        backupApi.loadBackupOptions(),
        websiteApi.getWebsiteOptions(),
        cronjobApi.loadScriptOptions(),
        toolboxApi.loadUsers(),
        _loadContainers(containerApi),
        _loadApps(appApi),
      ]);

      if (!mounted) return;
      _backupOptions = results[0] as List<BackupOptionDto>;
      _websiteOptions = results[1] as List<WebsiteOptionDto>;
      _scriptOptions = results[2] as List<ScriptOptionDto>;
      _userOptions = results[3] as List<String>;
      _containerOptions = results[4] as List<ContainerOption>;
      _appOptions = results[5] as List<AppInstalledOption>;

      // 加载默认数据库项
      await _loadDatabaseItems(databaseApi, 'mysql');

      if (_isEdit) {
        _initFromEditItem(client);
      }

      if (mounted) setState(() => _isLoadingOptions = false);
    } catch (e) {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  Future<List<ContainerOption>> _loadContainers(ContainerApi api) async {
    try {
      final result = await api.searchContainers(pageSize: 200);
      return result.items
          .map((c) => ContainerOption(name: c.name, state: c.state))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AppInstalledOption>> _loadApps(AppApi api) async {
    try {
      final result = await api.searchInstalledApps(
        const AppInstalledSearchReq(page: 1, pageSize: 200),
      );
      return result.items
          .map((a) => AppInstalledOption(id: a.id, name: a.name, key: a.appKey))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadDatabaseItems(DatabaseApi api, String dbType) async {
    try {
      _databaseItems = await api.loadDatabaseItems(dbType);
    } catch (_) {
      _databaseItems = [];
    }
  }

  void _initFromEditItem(dynamic client) {
    final item = widget.editItem!;
    _nameController.text = item.name;
    _type = item.type;
    _specCustom = item.specCustom;
    _specCustomController.text = item.spec;

    // Shell
    if (item.type == 'shell') {
      _scriptController.text = item.script ?? item.command ?? '';
      _scriptMode = item.scriptMode ?? 'input';
      _scriptID = item.scriptID;
      _executor = item.executor ?? 'bash';
      _isCustomExecutor = !_executorOptions.contains(_executor);
      _user = item.user ?? '';
      if (item.containerName != null && item.containerName!.isNotEmpty) {
        _inContainer = true;
        _containerName = item.containerName!;
        // 容器模式下 command 存的是容器内 shell
        _isCustomExecutor = !_containerCommands.contains(item.command);
        if (!_isCustomExecutor) _executor = item.command ?? 'sh';
      }
    }

    // Curl
    if (item.type == 'curl' && item.url != null) {
      _urlItems = item.url!.split(',').where((s) => s.isNotEmpty).toList();
      if (_urlItems.isEmpty) _urlItems = [''];
    }

    // App
    if (item.type == 'app' && item.appID != null) {
      _appIdList = item.appID!.split(',').where((s) => s.isNotEmpty).toList();
    }

    // Website / cutWebsiteLog
    if (_isWebsiteType(item.type) && item.website != null) {
      _websiteList = item.website!
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Database
    if (item.type == 'database') {
      _dbType = item.dbType ?? 'mysql';
      if (item.dbName != null) {
        _dbNameList = item.dbName!
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (item.args != null) {
        _argItems = item.args!.split(',').where((s) => s.isNotEmpty).toList();
      }
      _loadDatabaseItems(DatabaseApi(client), _dbType).then((_) {
        if (mounted) setState(() {});
      });
    }

    // Directory
    if (item.type == 'directory') {
      _isDir = item.isDir ?? true;
      _sourceDir = item.sourceDir ?? '';
      if (!_isDir && item.sourceDir != null) {
        _files = item.sourceDir!.split(',').where((s) => s.isNotEmpty).toList();
      }
    }

    // Snapshot
    if (item.type == 'snapshot' && item.snapshotRule != null) {
      _withImage = item.snapshotRule!.withImage;
      _ignoreAppIDs = List.from(item.snapshotRule!.ignoreAppIDs);
    }

    // Exclusion rules
    if (item.exclusionRules != null && item.exclusionRules!.isNotEmpty) {
      _ignoreFiles = item.exclusionRules!
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Backup accounts
    if (item.sourceAccountIDs != null) {
      _sourceAccountIDs = item.sourceAccountIDs!
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    _downloadAccountID = item.downloadAccountID ?? 0;

    // CleanLog scopes
    if (item.scopes != null) _scopes = List.from(item.scopes!);

    // 通用
    _retainCopies = item.retainCopies;
    _ignoreErr = item.ignoreErr;
    _retryTimes = item.retryTimes;
    _splitTimeout(item.timeout);
    _retainCopiesController.text = _retainCopies.toString();
    _retryTimesController.text = _retryTimes.toString();
    _timeoutValueController.text = _timeoutValue.toString();
    _secretController.text = item.secret;

    if (!item.specCustom) _parseSpec(item.spec);
  }

  void _splitTimeout(int seconds) {
    _timeoutValue = seconds;
  }

  int _mergeTimeout() {
    return int.tryParse(_timeoutValueController.text) ?? 3600;
  }

  void _parseSpec(String spec) {
    final parts = spec.split(' ');
    if (parts.length == 2) {
      if (parts[1].endsWith('m')) {
        _specType = 'perNMinute';
        _minute = int.tryParse(parts[1].replaceAll('m', '')) ?? 0;
        return;
      }
    }
    if (parts.length != 5) return;

    _minute = int.tryParse(parts[0]) ?? 0;
    if (parts[1] == '*') {
      _specType = 'perHour';
      return;
    }
    if (parts[1].startsWith('*/')) {
      _specType = 'perNHour';
      _hour = int.tryParse(parts[1].replaceAll('*/', '')) ?? 1;
      return;
    }
    _hour = int.tryParse(parts[1]) ?? 0;

    if (parts[2].startsWith('*/')) {
      _specType = 'perNDay';
      _day = int.tryParse(parts[2].replaceAll('*/', '')) ?? 1;
      return;
    }
    if (parts[2] != '*') {
      _specType = 'perMonth';
      _day = int.tryParse(parts[2]) ?? 1;
      return;
    }
    if (parts[4] != '*') {
      _specType = 'perWeek';
      _weekDay = int.tryParse(parts[4]) ?? 1;
      return;
    }
    _specType = 'perDay';
  }

  String _buildSpec() {
    if (_specCustom) return _specCustomController.text.trim();
    switch (_specType) {
      case 'perMonth':
        return '$_minute $_hour $_day * *';
      case 'perWeek':
        return '$_minute $_hour * * $_weekDay';
      case 'perNDay':
        return '$_minute $_hour */$_day * *';
      case 'perDay':
        return '$_minute $_hour * * *';
      case 'perNHour':
        return '$_minute */$_hour * * *';
      case 'perHour':
        return '$_minute * * * *';
      case 'perNMinute':
        return '@every ${_minute}m';
      default:
        return '$_minute $_hour * * *';
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final spec = _buildSpec();
    if (spec.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final req = CronjobCreateReq(
        id: _isEdit ? widget.editItem!.id : null,
        name: name,
        type: _type,
        spec: spec,
        specCustom: _specCustom,
        retainCopies: int.tryParse(_retainCopiesController.text) ?? 7,
        retryTimes: int.tryParse(_retryTimesController.text) ?? 3,
        timeout: _mergeTimeout(),
        ignoreErr: _hasIgnore(_type) ? _ignoreErr : null,
        secret: _needsSecret() ? _secretController.text.trim() : null,
        sourceAccountIDs: _isBackup(_type) ? _sourceAccountIDs.join(',') : null,
        downloadAccountID: _isBackup(_type) && _downloadAccountID > 0
            ? _downloadAccountID
            : null,
        // Shell
        executor: _type == 'shell' && !_inContainer ? _executor : null,
        scriptMode: _type == 'shell' ? _scriptMode : null,
        script: _type == 'shell' ? _scriptController.text.trim() : null,
        command: _type == 'shell' && _inContainer ? _executor : null,
        containerName: _type == 'shell' && _inContainer ? _containerName : null,
        user: _type == 'shell' ? _user : null,
        scriptID: _type == 'shell' && _scriptMode == 'library'
            ? _scriptID
            : null,
        // App
        appID: _type == 'app' ? _appIdList.join(',') : null,
        // Website / cutWebsiteLog
        website: _isWebsiteType(_type) ? _websiteList.join(',') : null,
        // Database
        dbType: _type == 'database' ? _dbType : null,
        dbName: _type == 'database' ? _dbNameList.join(',') : null,
        args: _type == 'database' ? _argItems.join(',') : null,
        // Directory
        isDir: _type == 'directory' ? _isDir : null,
        sourceDir: _type == 'directory'
            ? (_isDir ? _sourceDir : _files.join(','))
            : null,
        // Curl
        url: _type == 'curl'
            ? _urlItems.where((u) => u.isNotEmpty).join(',')
            : null,
        // Snapshot
        snapshotRule: _type == 'snapshot'
            ? SnapshotRuleDto(
                withImage: _withImage,
                ignoreAppIDs: _ignoreAppIDs,
              )
            : null,
        // Exclusion rules
        exclusionRules:
            _hasExclusionRules(_type, _isDir) && _ignoreFiles.isNotEmpty
            ? _ignoreFiles.join(',')
            : null,
        // CleanLog
        scopes: _type == 'cleanLog' ? _scopes : null,
      );
      await widget.onSubmit(req);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _needsSecret() {
    if (!_isBackup(_type)) return false;
    if (_type == 'database') return false;
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specCustomController.dispose();
    _scriptController.dispose();
    _secretController.dispose();
    _retainCopiesController.dispose();
    _retryTimesController.dispose();
    _timeoutValueController.dispose();
    super.dispose();
  }

  String get _formTitle => _isEdit
      ? context.l10n.cronjobs_formEditTitle
      : context.l10n.cronjobs_formCreateTitle;

  String _specTypeLabel(String value) {
    final l10n = context.l10n;
    return switch (value) {
      'perMonth' => l10n.cronjobs_specPerMonth,
      'perWeek' => l10n.cronjobs_specPerWeek,
      'perDay' => l10n.cronjobs_specPerDay,
      'perHour' => l10n.cronjobs_specPerHour,
      'perNDay' => l10n.cronjobs_specPerNDay,
      'perNHour' => l10n.cronjobs_specPerNHour,
      'perNMinute' => l10n.cronjobs_specPerNMinute,
      _ => value,
    };
  }

  String _weekDayLabel(int value) {
    final l10n = context.l10n;
    return switch (value) {
      0 => l10n.cronjobs_weekdaySun,
      1 => l10n.cronjobs_weekdayMon,
      2 => l10n.cronjobs_weekdayTue,
      3 => l10n.cronjobs_weekdayWed,
      4 => l10n.cronjobs_weekdayThu,
      5 => l10n.cronjobs_weekdayFri,
      6 => l10n.cronjobs_weekdaySat,
      _ => l10n.cronjobs_weekdayFallback('$value'),
    };
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOptions) {
      return ActionSheetScaffold(
        isAdaptive: true,
        showHandle: true,
        maxHeightFactor: 0.4,
        title: _formTitle,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CupertinoActivityIndicator(),
          ),
        ),
      );
    }

    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: true,
      maxHeightFactor: 0.9,
      scrollPhysics: _anyPickerExpanded
          ? const NeverScrollableScrollPhysics()
          : null,
      title: _formTitle,
      trailing: _isSubmitting
          ? const CupertinoActivityIndicator(radius: 10)
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _submit,
              child: Text(
                _isEdit ? context.l10n.common_save : context.l10n.common_create,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 基本信息 ──
          _sectionHeader(
            context.l10n.cronjobs_basicInfo,
            TablerIcons.info_circle,
          ),
          AppActionGroup(
            dividerPadding: const EdgeInsets.only(left: 16),
            children: [
              _buildInputRow(
                label: context.l10n.cronjobs_taskName,
                controller: _nameController,
                placeholder: context.l10n.cronjobs_taskName,
              ),
              if (!_isEdit) _buildTypeSelector(),
            ],
          ),
          const SizedBox(height: 20),

          // ── 类型专属配置 ──
          ..._buildTypeSection(),
          const SizedBox(height: 20),

          // ── 执行周期 ──
          _sectionHeader(context.l10n.cronjobs_schedule, TablerIcons.clock),
          AppActionGroup(
            dividerPadding: const EdgeInsets.only(left: 16),
            children: [
              if (!_specCustom) ...[
                _buildFrequencySelector(),
                if (_specType == 'perWeek') _buildWeekDayPickerRow(),
                if (_specType == 'perMonth' || _specType == 'perNDay')
                  _buildDayPickerRow(),
                if (_specType != 'perNMinute' && _specType != 'perHour')
                  _buildTimePickerRow(),
                if (_specType == 'perNMinute' || _specType == 'perNHour')
                  _buildIntervalPickerRow(),
              ],
              if (_specCustom)
                _buildInputRow(
                  label: context.l10n.cronjobs_cronExpression,
                  controller: _specCustomController,
                  placeholder: '30 2 * * *',
                ),
              _buildSwitchRow(
                label: context.l10n.cronjobs_customExpression,
                value: _specCustom,
                onChanged: (v) => setState(() => _specCustom = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 执行设置 ──
          _sectionHeader(
            context.l10n.cronjobs_executionSettings,
            TablerIcons.settings,
          ),
          AppActionGroup(
            dividerPadding: const EdgeInsets.only(left: 16),
            children: [
              _buildNumberInputRow(
                label: context.l10n.cronjobs_retainCopies,
                controller: _retainCopiesController,
              ),
              _buildNumberInputRow(
                label: context.l10n.cronjobs_retryTimes,
                controller: _retryTimesController,
              ),
              _buildTimeoutInputRow(),
              if (_hasIgnore(_type))
                _buildSwitchRow(
                  label: context.l10n.cronjobs_ignoreErrors,
                  value: _ignoreErr,
                  onChanged: (v) => setState(() => _ignoreErr = v),
                ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── 类型专属配置区域 ──────────────────────────────────────

  List<Widget> _buildTypeSection() {
    switch (_type) {
      case 'shell':
        return _buildShellSection();
      case 'app':
        return _buildAppSection();
      case 'website':
        return _buildWebsiteSection();
      case 'database':
        return _buildDatabaseSection();
      case 'directory':
        return _buildDirectorySection();
      case 'log':
        return _buildLogSection();
      case 'curl':
        return _buildCurlSection();
      case 'cutWebsiteLog':
        return _buildCutWebsiteLogSection();
      case 'snapshot':
        return _buildSnapshotSection();
      case 'cleanLog':
        return _buildCleanLogSection();
      // clean, ntp, syncIpGroup: 无额外配置
      default:
        return [];
    }
  }

  // ── Shell ──

  List<Widget> _buildShellSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_scriptConfig, TablerIcons.terminal),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _buildSwitchRow(
            label: context.l10n.cronjobs_runInContainer,
            value: _inContainer,
            onChanged: (v) {
              setState(() {
                _inContainer = v;
                if (v) {
                  _user = '';
                  _isCustomExecutor = !_containerCommands.contains(_executor);
                } else {
                  _containerName = '';
                  _isCustomExecutor = !_executorOptions.contains(_executor);
                }
              });
            },
          ),
          if (_inContainer) ...[
            _buildContainerSelector(),
            _buildCommandSelector(),
          ],
          if (!_inContainer) _buildExecutorSelector(),
          _buildUserSelector(),
          _buildScriptModeSelector(),
          if (_scriptMode == 'input') _buildScriptInput(),
          if (_scriptMode == 'library') _buildScriptLibrarySelector(),
          if (_scriptMode == 'select') _buildScriptFileSelector(),
        ],
      ),
    ];
  }

  Widget _buildContainerSelector() {
    return _RowWrapper(
      label: context.l10n.cronjobs_container,
      child: AppInlinePicker<String>(
        anchorHeight: 36,
        width: 180,
        options: _containerOptions
            .map(
              (c) => AppPickerOption(
                value: c.name,
                label: '${c.name} (${c.state})',
              ),
            )
            .toList(),
        value: _containerName.isEmpty ? null : _containerName,
        onChanged: (v) => setState(() => _containerName = v),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
        placeholder: context.l10n.cronjobs_chooseContainer,
      ),
    );
  }

  Widget _buildCommandSelector() {
    final isCustom =
        !_containerCommands.contains(_executor) || _isCustomExecutor;
    return Column(
      children: [
        _buildSwitchRow(
          label: context.l10n.cronjobs_customCommand,
          value: isCustom,
          onChanged: (v) {
            setState(() {
              _isCustomExecutor = v;
              if (!v) _executor = 'sh';
            });
          },
        ),
        if (!isCustom)
          _RowWrapper(
            label: context.l10n.cronjobs_command,
            child: AppInlinePicker<String>(
              anchorHeight: 36,
              width: 140,
              options: _containerCommands
                  .map((c) => AppPickerOption(value: c, label: '/bin/$c'))
                  .toList(),
              value: _executor,
              onChanged: (v) => setState(() => _executor = v),
              onExpandChanged: (expanded) =>
                  setState(() => _anyPickerExpanded = expanded),
            ),
          ),
        if (isCustom)
          _buildInputRow(
            label: context.l10n.cronjobs_command,
            controller: TextEditingController(text: _executor),
            placeholder: '/bin/sh',
            onChanged: (v) => _executor = v,
          ),
      ],
    );
  }

  Widget _buildExecutorSelector() {
    final isCustom = !_executorOptions.contains(_executor) || _isCustomExecutor;
    return Column(
      children: [
        _buildSwitchRow(
          label: context.l10n.cronjobs_customExecutor,
          value: isCustom,
          onChanged: (v) {
            setState(() {
              _isCustomExecutor = v;
              if (!v) _executor = 'bash';
            });
          },
        ),
        if (!isCustom)
          _RowWrapper(
            label: context.l10n.cronjobs_executor,
            child: AppInlinePicker<String>(
              anchorHeight: 36,
              width: 140,
              options: _executorOptions
                  .map((e) => AppPickerOption(value: e, label: e))
                  .toList(),
              value: _executor,
              onChanged: (v) => setState(() => _executor = v),
              onExpandChanged: (expanded) =>
                  setState(() => _anyPickerExpanded = expanded),
            ),
          ),
        if (isCustom)
          _buildInputRow(
            label: context.l10n.cronjobs_executor,
            controller: TextEditingController(text: _executor),
            placeholder: 'bash',
            onChanged: (v) => _executor = v,
          ),
      ],
    );
  }

  Widget _buildUserSelector() {
    return _RowWrapper(
      label: context.l10n.cronjobs_runUser,
      child: AppInlinePicker<String>(
        anchorHeight: 36,
        width: 140,
        options: (_userOptions.isEmpty ? ['root'] : _userOptions)
            .map((u) => AppPickerOption(value: u, label: u))
            .toList(),
        value: _user.isEmpty ? 'root' : _user,
        onChanged: (v) => setState(() => _user = v),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
      ),
    );
  }

  Widget _buildScriptModeSelector() {
    final modes = [
      {'v': 'input', 'l': context.l10n.cronjobs_scriptSourceManual},
      {'v': 'library', 'l': context.l10n.cronjobs_scriptSourceLibrary},
      {'v': 'select', 'l': context.l10n.cronjobs_scriptSourceFilePath},
    ];
    return _RowWrapper(
      label: context.l10n.cronjobs_scriptSource,
      child: AppInlinePicker<String>(
        anchorHeight: 36,
        width: 140,
        options: modes
            .map((m) => AppPickerOption(value: m['v']!, label: m['l']!))
            .toList(),
        value: _scriptMode,
        onChanged: (v) => setState(() {
          _scriptMode = v;
          _scriptController.text = '';
        }),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
      ),
    );
  }

  Widget _buildScriptInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.cronjobs_scriptContent,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              showAppCodeEditorSheet(
                context,
                title: context.l10n.cronjobs_editScript,
                language: 'bash',
                initialContent: _scriptController.text,
                onSave: (content) async {
                  _scriptController.text = content;
                  return true;
                },
              );
            },
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tertiaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _scriptController.text.isEmpty
                    ? context.l10n.cronjobs_tapToEditScript
                    : _scriptController.text,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: _scriptController.text.isEmpty
                      ? AppColors.tertiaryLabel(context)
                      : AppColors.label(context),
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptLibrarySelector() {
    return _RowWrapper(
      label: context.l10n.cronjobs_script,
      child: AppInlinePicker<int>(
        anchorHeight: 36,
        width: 180,
        options: _scriptOptions
            .map((s) => AppPickerOption(value: s.id, label: s.name))
            .toList(),
        value: _scriptID,
        onChanged: (v) => setState(() => _scriptID = v),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
        placeholder: context.l10n.cronjobs_chooseScript,
      ),
    );
  }

  Widget _buildScriptFileSelector() {
    return _buildPickerRow(
      label: context.l10n.cronjobs_scriptFile,
      value: _scriptController.text.isEmpty
          ? context.l10n.cronjobs_chooseFile
          : _scriptController.text,
      onTap: () async {
        final result = await FileBrowserPickerSheet.show(
          context,
          title: context.l10n.cronjobs_chooseScriptFile,
          selectionMode: FilePickerSelectionMode.files,
        );
        if (result != null) {
          setState(() => _scriptController.text = result.path);
        }
      },
    );
  }

  // ── App ──

  List<Widget> _buildAppSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeApp, TablerIcons.apps),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _buildMultiSelectRow(
            label: context.l10n.cronjobs_app,
            selected: _appIdList,
            allOptions: _appOptions.map((a) => a.id.toString()).toList(),
            displayForValue: (v) {
              final app = _appOptions.firstWhere(
                (a) => a.id.toString() == v,
                orElse: () => AppInstalledOption(id: 0, name: v, key: ''),
              );
              return app.name;
            },
            onChanged: (v) => setState(() => _appIdList = v),
            hasAll: true,
          ),
        ],
      ),
      ..._buildBackupSection(),
    ];
  }

  // ── Website ──

  List<Widget> _buildWebsiteSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeWebsite, TablerIcons.world),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _buildMultiSelectRow(
            label: context.l10n.cronjobs_website,
            selected: _websiteList,
            allOptions: _websiteOptions.map((w) => w.id.toString()).toList(),
            displayForValue: (v) {
              final w = _websiteOptions.firstWhere(
                (w) => w.id.toString() == v,
                orElse: () =>
                    WebsiteOptionDto(id: 0, primaryDomain: v, alias: ''),
              );
              return w.primaryDomain;
            },
            onChanged: (v) => setState(() => _websiteList = v),
            hasAll: true,
          ),
        ],
      ),
      ..._buildBackupSection(),
      if (_hasExclusionRules(_type, _isDir)) ..._buildExclusionSection(),
    ];
  }

  // ── cutWebsiteLog ──

  List<Widget> _buildCutWebsiteLogSection() {
    return [
      _sectionHeader(
        context.l10n.cronjobs_typeCutWebsiteLog,
        TablerIcons.scissors,
      ),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _buildMultiSelectRow(
            label: context.l10n.cronjobs_website,
            selected: _websiteList,
            allOptions: ['all', ..._websiteOptions.map((w) => w.id.toString())],
            displayForValue: (v) {
              if (v == 'all') return context.l10n.cronjobs_allWebsites;
              final w = _websiteOptions.firstWhere(
                (w) => w.id.toString() == v,
                orElse: () =>
                    WebsiteOptionDto(id: 0, primaryDomain: v, alias: ''),
              );
              return w.primaryDomain;
            },
            onChanged: (newList) {
              final oldList = _websiteList;
              List<String> nextList;
              if (newList.contains('all') && !oldList.contains('all')) {
                nextList = ['all'];
              } else if (newList.length > 1 && newList.contains('all')) {
                nextList = newList.where((v) => v != 'all').toList();
              } else {
                nextList = newList;
              }
              setState(() => _websiteList = nextList);
            },
          ),
        ],
      ),
    ];
  }

  // ── Database ──

  List<Widget> _buildDatabaseSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeDatabase, TablerIcons.database),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _RowWrapper(
            label: context.l10n.cronjobs_databaseType,
            child: AppInlinePicker<String>(
              anchorHeight: 36,
              width: 180,
              options: _dbTypes
                  .map(
                    (d) =>
                        AppPickerOption(value: d['value']!, label: d['label']!),
                  )
                  .toList(),
              value: _dbType,
              onChanged: (v) async {
                setState(() {
                  _dbType = v;
                  _dbNameList = [];
                });
                final serverId = ref.read(activeServerIdProvider);
                final client = await ref.read(
                  dioClientProvider(serverId).future,
                );
                await _loadDatabaseItems(DatabaseApi(client), v);
                if (mounted) setState(() {});
              },
              onExpandChanged: (expanded) =>
                  setState(() => _anyPickerExpanded = expanded),
            ),
          ),
          _buildMultiSelectRow(
            label: context.l10n.cronjobs_database,
            selected: _dbNameList,
            allOptions: _databaseItems.map((d) => d.id.toString()).toList(),
            displayForValue: (v) {
              final d = _databaseItems.firstWhere(
                (d) => d.id.toString() == v,
                orElse: () =>
                    DatabaseItemDto(id: 0, name: v, from: '', database: ''),
              );
              return d.name;
            },
            onChanged: (v) => setState(() => _dbNameList = v),
            hasAll: true,
          ),
          if (_dbType == 'mysql' || _dbType == 'mysql-cluster')
            _buildMysqlArgsSelector(),
        ],
      ),
      ..._buildBackupSection(excludeSecret: true),
    ];
  }

  Widget _buildMysqlArgsSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.cronjobs_backupArgs,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mysqlArgs.map((arg) {
              final selected = _argItems.contains(arg);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _argItems.remove(arg);
                    } else {
                      _argItems.add(arg);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? _themeColor.withValues(alpha: 0.1)
                        : AppColors.tertiaryBackground(
                            context,
                          ).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? _themeColor
                          : AppColors.separator(context).withValues(alpha: 0.1),
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Text(
                    arg,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? _themeColor : AppColors.label(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.cronjobs_mysqlArgsHelp,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Directory ──

  List<Widget> _buildDirectorySection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeDirectory, TablerIcons.folder),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _RowWrapper(
            label: context.l10n.cronjobs_backupType,
            child: AppInlinePicker<bool>(
              anchorHeight: 36,
              width: 100,
              options: [
                AppPickerOption(
                  value: true,
                  label: context.l10n.cronjobs_directory,
                ),
                AppPickerOption(
                  value: false,
                  label: context.l10n.cronjobs_file,
                ),
              ],
              value: _isDir,
              onChanged: (v) => setState(() {
                _isDir = v;
                _sourceDir = '';
                _files = [];
              }),
              onExpandChanged: (expanded) =>
                  setState(() => _anyPickerExpanded = expanded),
            ),
          ),
          if (_isDir)
            _buildPickerRow(
              label: context.l10n.cronjobs_backupDirectory,
              value: _sourceDir.isEmpty
                  ? context.l10n.cronjobs_chooseDirectory
                  : _sourceDir,
              onTap: () async {
                final result = await FileBrowserPickerSheet.show(
                  context,
                  title: context.l10n.cronjobs_chooseDirectory,
                  initialPath: _sourceDir.isNotEmpty ? _sourceDir : '/',
                  selectionMode: FilePickerSelectionMode.directories,
                );
                if (result != null) {
                  setState(() => _sourceDir = result.path);
                }
              },
            ),
          if (!_isDir) ...[
            _buildPickerRow(
              label: context.l10n.cronjobs_addFile,
              value: '',
              onTap: () async {
                final result = await FileBrowserPickerSheet.show(
                  context,
                  title: context.l10n.cronjobs_chooseFile,
                  selectionMode: FilePickerSelectionMode.files,
                );
                if (result != null && !_files.contains(result.path)) {
                  setState(() => _files.add(result.path));
                }
              },
            ),
            if (_files.isNotEmpty)
              ..._files.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.label(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _files.removeAt(e.key)),
                        child: const Icon(
                          TablerIcons.x,
                          size: 16,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
      ..._buildBackupSection(),
      if (_hasExclusionRules(_type, _isDir)) ..._buildExclusionSection(),
    ];
  }

  // ── Log ──

  List<Widget> _buildLogSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeLog, TablerIcons.file_text),
      ..._buildBackupSection(),
    ];
  }

  // ── Curl ──

  List<Widget> _buildCurlSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeCurl, TablerIcons.link),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          ..._urlItems.asMap().entries.map((e) => _buildUrlRow(e.key)),
          _buildActionRow(
            label: context.l10n.cronjobs_addUrl,
            icon: TablerIcons.plus,
            onTap: () => setState(() => _urlItems.add('')),
          ),
        ],
      ),
    ];
  }

  Widget _buildUrlRow(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: TextEditingController(text: _urlItems[index]),
              placeholder: 'https://example.com',
              padding: EdgeInsets.zero,
              decoration: null,
              style: TextStyle(fontSize: 15, color: AppColors.label(context)),
              placeholderStyle: TextStyle(
                fontSize: 15,
                color: AppColors.tertiaryLabel(context),
              ),
              onChanged: (v) => _urlItems[index] = v,
            ),
          ),
          if (_urlItems.length > 1)
            CupertinoButton(
              padding: const EdgeInsets.only(left: 8),
              onPressed: () => setState(() => _urlItems.removeAt(index)),
              child: const Icon(
                TablerIcons.x,
                size: 16,
                color: CupertinoColors.systemRed,
              ),
            ),
        ],
      ),
    );
  }

  // ── Snapshot ──

  List<Widget> _buildSnapshotSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeSnapshot, TablerIcons.camera),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _buildSwitchRow(
            label: context.l10n.cronjobs_includeImages,
            value: _withImage,
            onChanged: (v) => setState(() => _withImage = v),
          ),
          _buildMultiSelectRow(
            label: context.l10n.cronjobs_excludeApps,
            selected: _ignoreAppIDs.map((id) => id.toString()).toList(),
            allOptions: _appOptions.map((a) => a.id.toString()).toList(),
            displayForValue: (v) {
              final app = _appOptions.firstWhere(
                (a) => a.id.toString() == v,
                orElse: () => AppInstalledOption(id: 0, name: v, key: ''),
              );
              return app.name;
            },
            onChanged: (v) => setState(
              () => _ignoreAppIDs = v.map((s) => int.tryParse(s) ?? 0).toList(),
            ),
          ),
        ],
      ),
      ..._buildBackupSection(),
      ..._buildExclusionSection(),
    ];
  }

  // ── CleanLog ──

  List<Widget> _buildCleanLogSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_typeCleanLog, TablerIcons.trash),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _buildMultiSelectRow(
            label: context.l10n.cronjobs_cleanScope,
            selected: _scopes,
            allOptions: const ['website'],
            displayForValue: (v) =>
                v == 'website' ? context.l10n.cronjobs_websiteLogs : v,
            onChanged: (v) => setState(() => _scopes = v),
          ),
        ],
      ),
    ];
  }

  // ── 备份公共区域 ──

  List<Widget> _buildBackupSection({bool excludeSecret = false}) {
    return [
      _sectionHeader(
        context.l10n.cronjobs_backupSettings,
        TablerIcons.cloud_upload,
      ),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          _buildBackupAccountSelector(),
          if (_sourceAccountIDs.isNotEmpty) _buildDownloadAccountSelector(),
          if (!excludeSecret && _needsSecret())
            _buildInputRow(
              label: context.l10n.cronjobs_compressionPassword,
              controller: _secretController,
              placeholder: context.l10n.cronjobs_emptyMeansNoEncryption,
            ),
        ],
      ),
    ];
  }

  Widget _buildBackupAccountSelector() {
    final selectable = _backupOptions.where((b) => b.type != 'LOCAL').toList();

    return _RowWrapper(
      label: context.l10n.cronjobs_backupAccount,
      child: AppInlineMultiPicker<String>(
        anchorHeight: 36,
        width: 180,
        placeholder: context.l10n.cronjobs_chooseBackupAccount,
        options: selectable
            .map((b) => AppPickerOption(value: b.id.toString(), label: b.name))
            .toList(),
        selectedValues: _sourceAccountIDs,
        onChanged: (selected) {
          setState(() {
            _sourceAccountIDs = selected;
            if (!_sourceAccountIDs.contains(_downloadAccountID.toString())) {
              _downloadAccountID = _sourceAccountIDs.isNotEmpty
                  ? int.tryParse(_sourceAccountIDs.first) ?? 0
                  : 0;
            }
          });
        },
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
      ),
    );
  }

  Widget _buildDownloadAccountSelector() {
    final options = _backupOptions
        .where((b) => _sourceAccountIDs.contains(b.id.toString()))
        .toList();

    return _RowWrapper(
      label: context.l10n.cronjobs_downloadAccount,
      child: AppInlinePicker<int>(
        anchorHeight: 36,
        width: 180,
        options: options
            .map((b) => AppPickerOption(value: b.id, label: b.name))
            .toList(),
        value: _downloadAccountID > 0 ? _downloadAccountID : null,
        onChanged: (v) => setState(() => _downloadAccountID = v),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
        placeholder: context.l10n.cronjobs_chooseDownloadAccount,
      ),
    );
  }

  // ── Exclusion rules ──

  List<Widget> _buildExclusionSection() {
    return [
      _sectionHeader(context.l10n.cronjobs_exclusionRules, TablerIcons.filter),
      AppActionGroup(
        dividerPadding: const EdgeInsets.only(left: 16),
        children: [
          ..._ignoreFiles.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.label(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _ignoreFiles.removeAt(e.key)),
                    child: const Icon(
                      TablerIcons.x,
                      size: 16,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildActionRow(
            label: context.l10n.cronjobs_addExclusionRule,
            icon: TablerIcons.plus,
            onTap: _showAddExclusionDialog,
          ),
        ],
      ),
    ];
  }

  void _showAddExclusionDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.cronjobs_addExclusionRule),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: context.l10n.cronjobs_exclusionRulePlaceholder,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.common_cancel),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                setState(() => _ignoreFiles.add(val));
              }
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.common_create),
          ),
        ],
      ),
    );
  }

  // ── 通用 UI 组件 ──────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryLabel(context),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            maxLines: maxLines,
            padding: EdgeInsets.zero,
            decoration: null,
            style: TextStyle(fontSize: 16, color: AppColors.label(context)),
            placeholderStyle: TextStyle(
              fontSize: 16,
              color: AppColors.tertiaryLabel(context),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: AppColors.label(context)),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _themeColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: _themeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.cronjobs_taskType,
                style: TextStyle(fontSize: 16, color: AppColors.label(context)),
              ),
            ),
          ),
          AppInlinePicker<String>(
            anchorHeight: 36,
            width: 160,
            options: [
              AppPickerOption(
                value: 'shell',
                label: context.l10n.cronjobs_typeShell,
                icon: TablerIcons.terminal,
              ),
              AppPickerOption(
                value: 'app',
                label: context.l10n.cronjobs_typeApp,
                icon: TablerIcons.apps,
              ),
              AppPickerOption(
                value: 'website',
                label: context.l10n.cronjobs_typeWebsite,
                icon: TablerIcons.world,
              ),
              AppPickerOption(
                value: 'database',
                label: context.l10n.cronjobs_typeDatabase,
                icon: TablerIcons.database,
              ),
              AppPickerOption(
                value: 'directory',
                label: context.l10n.cronjobs_typeDirectory,
                icon: TablerIcons.folder,
              ),
              AppPickerOption(
                value: 'log',
                label: context.l10n.cronjobs_typeLog,
                icon: TablerIcons.file_text,
              ),
              AppPickerOption(
                value: 'curl',
                label: context.l10n.cronjobs_typeCurl,
                icon: TablerIcons.link,
              ),
              AppPickerOption(
                value: 'cutWebsiteLog',
                label: context.l10n.cronjobs_typeCutWebsiteLog,
                icon: TablerIcons.scissors,
              ),
              AppPickerOption(
                value: 'clean',
                label: context.l10n.cronjobs_typeClean,
                icon: TablerIcons.eraser,
              ),
              AppPickerOption(
                value: 'snapshot',
                label: context.l10n.cronjobs_typeSnapshot,
                icon: TablerIcons.camera,
              ),
              AppPickerOption(
                value: 'ntp',
                label: context.l10n.cronjobs_typeNtp,
                icon: TablerIcons.clock,
              ),
              AppPickerOption(
                value: 'syncIpGroup',
                label: context.l10n.cronjobs_typeSyncIpGroup,
                icon: TablerIcons.shield,
              ),
              AppPickerOption(
                value: 'cleanLog',
                label: context.l10n.cronjobs_typeCleanLog,
                icon: TablerIcons.trash,
              ),
            ],
            value: _type,
            onChanged: (v) => setState(() => _type = v),
            onExpandChanged: (expanded) =>
                setState(() => _anyPickerExpanded = expanded),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.cronjobs_frequency,
                style: TextStyle(fontSize: 16, color: AppColors.label(context)),
              ),
            ),
          ),
          AppInlinePicker<String>(
            anchorHeight: 36,
            width: 140,
            options: _specTypes
                .map(
                  (t) => AppPickerOption<String>(
                    value: t,
                    label: _specTypeLabel(t),
                  ),
                )
                .toList(),
            value: _specType,
            onChanged: (v) => setState(() => _specType = v),
            onExpandChanged: (expanded) =>
                setState(() => _anyPickerExpanded = expanded),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDayPickerRow() {
    return _RowWrapper(
      label: context.l10n.cronjobs_chooseWeekday,
      child: AppInlinePicker<int>(
        anchorHeight: 36,
        width: 100,
        options: _weekDays
            .map((d) => AppPickerOption(value: d, label: _weekDayLabel(d)))
            .toList(),
        value: _weekDay,
        onChanged: (v) => setState(() => _weekDay = v),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
      ),
    );
  }

  Widget _buildDayPickerRow() {
    return _RowWrapper(
      label: _specType == 'perMonth'
          ? context.l10n.cronjobs_chooseDate
          : context.l10n.cronjobs_intervalDays,
      child: AppInlinePicker<int>(
        anchorHeight: 36,
        width: 100,
        options: List.generate(
          31,
          (i) => AppPickerOption(value: i + 1, label: '${i + 1}'),
        ),
        value: _day,
        onChanged: (v) => setState(() => _day = v),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
      ),
    );
  }

  Widget _buildTimePickerRow() {
    return _buildPickerRow(
      label: context.l10n.cronjobs_executionTime,
      value:
          '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
      onTap: _showTimePicker,
    );
  }

  void _showTimePicker() {
    int tempHour = _hour;
    int tempMinute = _minute;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            _buildPickerHeader(
              ctx,
              context.l10n.cronjobs_chooseTime,
              onDone: () {
                setState(() {
                  _hour = tempHour;
                  _minute = tempMinute;
                });
                Navigator.pop(ctx);
              },
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(
                        initialItem: _hour,
                      ),
                      onSelectedItemChanged: (i) => tempHour = i,
                      children: List.generate(
                        24,
                        (i) =>
                            Center(child: Text(i.toString().padLeft(2, '0'))),
                      ),
                    ),
                  ),
                  const Text(':', style: TextStyle(fontSize: 20)),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(
                        initialItem: _minute,
                      ),
                      onSelectedItemChanged: (i) => tempMinute = i,
                      children: List.generate(
                        60,
                        (i) =>
                            Center(child: Text(i.toString().padLeft(2, '0'))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalPickerRow() {
    final isMinute = _specType == 'perNMinute';
    final max = isMinute ? 60 : 24;
    return _RowWrapper(
      label: isMinute
          ? context.l10n.cronjobs_intervalMinutes
          : context.l10n.cronjobs_intervalHours,
      child: AppInlinePicker<int>(
        anchorHeight: 36,
        width: 100,
        options: List.generate(
          max,
          (i) => AppPickerOption(value: i + 1, label: '${i + 1}'),
        ),
        value: _minute,
        onChanged: (v) => setState(() => _minute = v),
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
      ),
    );
  }

  Widget _buildTimeoutInputRow() {
    return _RowWrapper(
      label: context.l10n.cronjobs_timeout,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: CupertinoTextField(
              controller: _timeoutValueController,
              placeholder: '3600',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: BoxDecoration(
                color: AppColors.tertiaryBackground(
                  context,
                ).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.cronjobs_seconds,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputRow({
    required String label,
    required TextEditingController controller,
  }) {
    return _RowWrapper(
      label: label,
      child: SizedBox(
        width: 80,
        child: CupertinoTextField(
          controller: controller,
          placeholder: '0',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: BoxDecoration(
            color: AppColors.tertiaryBackground(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.label(context),
          ),
        ),
      ),
    );
  }

  // ── Multi-select ──

  Widget _buildMultiSelectRow({
    required String label,
    required List<String> selected,
    required List<String> allOptions,
    required String Function(String) displayForValue,
    required ValueChanged<List<String>> onChanged,
    bool hasAll = false,
  }) {
    return _RowWrapper(
      label: label,
      child: AppInlineMultiPicker<String>(
        anchorHeight: 36,
        width: 180,
        placeholder: context.l10n.cronjobs_selectLabel(label),
        options: allOptions
            .map((o) => AppPickerOption(value: o, label: displayForValue(o)))
            .toList(),
        selectedValues: selected,
        onChanged: onChanged,
        onExpandChanged: (expanded) =>
            setState(() => _anyPickerExpanded = expanded),
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return _RowWrapper(
      label: label,
      child: SizedBox(
        width: 180,
        child: AppPickerAnchor(
          height: 36,
          label: value,
          onTap: onTap,
          chevronType: AppPickerChevronType.right,
        ),
      ),
    );
  }

  Widget _buildPickerHeader(
    BuildContext context,
    String title, {
    VoidCallback? onDone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.separator(context).withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.label(context),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onDone ?? () => Navigator.pop(context),
            child: Text(context.l10n.common_done),
          ),
        ],
      ),
    );
  }
}

// ── 内部辅助组件 ──────────────────────────────────────────

class _RowWrapper extends StatelessWidget {
  const _RowWrapper({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              height: 36, // Match standard anchorHeight
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(fontSize: 16, color: AppColors.label(context)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}

// ── 简单数据类 ────────────────────────────────────────────

class ContainerOption {
  const ContainerOption({required this.name, required this.state});
  final String name;
  final String state;
}

class AppInstalledOption {
  const AppInstalledOption({
    required this.id,
    required this.name,
    required this.key,
  });
  final int id;
  final String name;
  final String key;
}
