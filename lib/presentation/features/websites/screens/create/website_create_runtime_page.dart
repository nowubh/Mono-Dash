import 'dart:convert';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/localization/l10n_x.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/dto/app/app_service_dto.dart';
import '../../../../../data/dto/runtime/runtime_dto.dart';
import '../../../../../data/dto/website/website_acme_account_dto.dart';
import '../../../../../data/dto/website/website_create_req.dart';
import '../../../../../data/dto/website/website_domain_req.dart';
import '../../../../../data/dto/website/website_group_dto.dart';
import '../../../../../data/dto/website/website_ssl_dto.dart';
import '../../../server_detail/providers/active_server_provider.dart';
import '../../../../common/app_toast.dart';
import '../../../../common/components/app_picker.dart';
import '../../../../common/components/frosted_action_button.dart';
import '../../../../common/components/frosted_scaffold.dart';
import '../../providers/website_create_provider.dart';

class WebsiteCreateRuntimePage extends StatelessWidget {
  const WebsiteCreateRuntimePage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: const _WebsiteCreateRuntimeForm(),
    );
  }
}

class _WebsiteCreateRuntimeForm extends ConsumerStatefulWidget {
  const _WebsiteCreateRuntimeForm();

  @override
  ConsumerState<_WebsiteCreateRuntimeForm> createState() =>
      _WebsiteCreateRuntimePageState();
}

class _WebsiteCreateRuntimePageState
    extends ConsumerState<_WebsiteCreateRuntimeForm> {
  static const double _formControlHeight = 40;

  static const _runtimeTypeOptions = [
    AppPickerOption(value: 'php', label: 'PHP'),
    AppPickerOption(value: 'node', label: 'Node.js'),
    AppPickerOption(value: 'java', label: 'Java'),
    AppPickerOption(value: 'go', label: 'Go'),
    AppPickerOption(value: 'python', label: 'Python'),
    AppPickerOption(value: 'dotnet', label: '.NET'),
  ];

  static const _proxyTypeOptions = [
    AppPickerOption(value: 'tcp', label: 'TCP'),
    AppPickerOption(value: 'unix', label: 'Unix Socket'),
  ];

  static const _dbTypeOptions = [
    AppPickerOption(value: 'mysql', label: 'MySQL'),
    AppPickerOption(value: 'mariadb', label: 'MariaDB'),
    AppPickerOption(value: 'postgresql', label: 'PostgreSQL'),
  ];

  final _aliasController = TextEditingController();
  final _domainController = TextEditingController();
  final _portController = TextEditingController(text: '80');
  final _runtimePortController = TextEditingController(text: '9000');
  final _remarkController = TextEditingController();
  final _ftpUserController = TextEditingController();
  final _ftpPasswordController = TextEditingController();
  final _dbNameController = TextEditingController();
  final _dbUserController = TextEditingController();
  final _dbPasswordController = TextEditingController();

  bool _isSubmitting = false;
  int? _selectedGroupId;
  bool _enableSSL = false;
  int _selectedAcmeAccountId = 0;
  int? _selectedSslId;
  bool _enableIPv6 = false;
  bool _enableFtp = false;

  String _selectedRuntimeType = 'php';
  RuntimeDto? _selectedRuntime;
  String _proxyType = 'tcp';
  int? _selectedPort;

  bool _createDb = false;
  String _selectedDbType = 'mysql';
  String? _selectedDbHost;
  String _selectedDbFormat = 'utf8mb4';

  bool get _isPhpLocal =>
      _selectedRuntimeType == 'php' && _selectedRuntime?.resource == 'local';

  List<AppPickerOption<String>> get _dbFormatOptions {
    if (_selectedDbType == 'postgresql') {
      return const [
        AppPickerOption(value: 'UTF8', label: 'UTF8'),
        AppPickerOption(value: 'LATIN1', label: 'LATIN1'),
        AppPickerOption(value: 'SQL_ASCII', label: 'SQL_ASCII'),
      ];
    }
    return const [
      AppPickerOption(value: 'utf8mb4', label: 'utf8mb4'),
      AppPickerOption(value: 'utf-8', label: 'utf-8'),
      AppPickerOption(value: 'gbk', label: 'gbk'),
      AppPickerOption(value: 'big5', label: 'big5'),
    ];
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _domainController.dispose();
    _portController.dispose();
    _runtimePortController.dispose();
    _remarkController.dispose();
    _ftpUserController.dispose();
    _ftpPasswordController.dispose();
    _dbNameController.dispose();
    _dbUserController.dispose();
    _dbPasswordController.dispose();
    super.dispose();
  }

  void _onRuntimeTypeChanged(String type) {
    setState(() {
      _selectedRuntimeType = type;
      _selectedRuntime = null;
      _selectedPort = null;
      _proxyType = 'tcp';
      _runtimePortController.text = '9000';
    });
  }

  void _onRuntimeChanged(RuntimeDto runtime) {
    setState(() {
      _selectedRuntime = runtime;
      _selectedPort = null;
      _proxyType = 'tcp';
      _runtimePortController.text = '9000';

      if (runtime.type != 'php' || runtime.resource != 'local') {
        final ports = runtime.port
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .where((p) => p != null && p > 0)
            .cast<int>()
            .toList();
        if (ports.length == 1) {
          _selectedPort = ports.first;
        }
      }
    });
  }

  void _onDbTypeChanged(String type) {
    setState(() {
      _selectedDbType = type;
      _selectedDbHost = null;
      _selectedDbFormat = type == 'postgresql' ? 'UTF8' : 'utf8mb4';
    });
  }

  Future<void> _submit() async {
    final metadata = ref.read(websiteCreateMetadataProvider).valueOrNull;
    final alias = _aliasController.text.trim();
    final domain = _domainController.text.trim();
    final httpPort = int.tryParse(_portController.text.trim()) ?? 80;
    final groupId = _selectedGroupId ?? metadata?.defaultGroup?.id ?? 1;
    final sslId = _selectedSslId ?? 0;

    if (alias.isEmpty || domain.isEmpty) {
      _showError(context.l10n.websites_primaryDomainAliasRequired);
      return;
    }
    if (_selectedRuntime == null) {
      _showError(context.l10n.websites_selectRuntime);
      return;
    }
    if (_enableSSL && sslId == 0) {
      _showError(context.l10n.websites_sslCertificateRequired);
      return;
    }
    if (_enableFtp && _ftpUserController.text.trim().isEmpty) {
      _showError(context.l10n.websites_ftpAccountRequired);
      return;
    }

    int runtimePort;
    if (_isPhpLocal && _proxyType == 'tcp') {
      runtimePort = int.tryParse(_runtimePortController.text.trim()) ?? 9000;
    } else if (!_isPhpLocal && _selectedPort != null) {
      runtimePort = _selectedPort!;
    } else if (!_isPhpLocal && _selectedPort == null) {
      _showError(context.l10n.websites_selectPort);
      return;
    } else {
      runtimePort = 0;
    }

    if (_createDb) {
      if (_selectedDbHost == null || _selectedDbHost!.isEmpty) {
        _showError(context.l10n.websites_selectDatabaseService);
        return;
      }
      if (_dbNameController.text.trim().isEmpty) {
        _showError(context.l10n.websites_databaseNameRequired);
        return;
      }
      if (_dbUserController.text.trim().isEmpty) {
        _showError(context.l10n.websites_databaseUsernameRequired);
        return;
      }
      if (_dbPasswordController.text.isEmpty) {
        _showError(context.l10n.websites_databasePasswordRequired);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final req = WebsiteCreateReq(
      alias: alias,
      type: 'runtime',
      domains: [WebsiteDomainReq(domain: domain, host: domain, port: httpPort)],
      webSiteGroupID: groupId,
      remark: _remarkController.text.trim(),
      taskID: const Uuid().v4(),
      runtimeID: _selectedRuntime!.id,
      proxyType: _isPhpLocal ? _proxyType : 'tcp',
      port: runtimePort,
      enableSSL: _enableSSL,
      websiteSSLID: _enableSSL ? sslId : 0,
      acmeAccountID: _enableSSL ? _selectedAcmeAccountId : 0,
      ipv6: _enableIPv6,
      enableFtp: _enableFtp,
      ftpUser: _ftpUserController.text.trim(),
      ftpPassword: _enableFtp
          ? base64Encode(utf8.encode(_ftpPasswordController.text))
          : '',
      createDb: _createDb,
      dbName: _dbNameController.text.trim(),
      dbUser: _dbUserController.text.trim(),
      dbPassword: _createDb ? _dbPasswordController.text : '',
      dbHost: _selectedDbHost ?? '',
      dbFormat: _selectedDbFormat,
      dbType: _selectedDbType,
    );

    final success = await ref
        .read(websiteCreateControllerProvider.notifier)
        .createWebsite(req);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        showAppSuccessToast(
          context.l10n.websites_createSuccess,
          description: context.l10n.websites_runtimeSiteCreated(alias, domain),
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

  String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789-_';
    final random = Random.secure();
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(websiteCreateMetadataProvider);
    final runtimesAsync = ref.watch(
      websiteRuntimesProvider(_selectedRuntimeType),
    );
    final acmeAccountsAsync = _enableSSL
        ? ref.watch(websiteAcmeAccountsProvider)
        : const AsyncValue<List<WebsiteAcmeAccountDto>>.data([]);
    final sslListAsync = _enableSSL
        ? ref.watch(websiteSslListProvider(_selectedAcmeAccountId))
        : const AsyncValue<List<WebsiteSslDto>>.data([]);
    final dbInstancesAsync = _createDb
        ? ref.watch(websiteDbInstancesProvider(_selectedDbType))
        : const AsyncValue<List<AppServiceDto>>.data([]);

    return FrostedScaffold(
      title: context.l10n.websites_createRuntimeSite,
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
                  _buildSectionCard(
                    context,
                    icon: TablerIcons.world_www,
                    title: context.l10n.websites_basicConfig,
                    child: Column(
                      children: [
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_primaryDomain,
                          placeholder: 'example.com',
                          controller: _domainController,
                        ),
                        const SizedBox(height: 12),
                        _buildInputRow(
                          context,
                          label: context.l10n.websites_alias,
                          placeholder: context.l10n.websites_aliasPlaceholder,
                          controller: _aliasController,
                        ),
                        metadataAsync.maybeWhen(
                          data: (metadata) => _buildRootHint(
                            context,
                            context.l10n.websites_relativeToRoot(
                              metadata.sitesRootDir,
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: metadataAsync.when(
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
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputRow(
                                context,
                                label: context.l10n.websites_httpPort,
                                placeholder: '80',
                                controller: _portController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    context,
                    icon: TablerIcons.code,
                    title: context.l10n.websites_runtime,
                    child: Column(
                      children: [
                        _buildRuntimeTypePickerField(context),
                        const SizedBox(height: 12),
                        runtimesAsync.when(
                          data: (runtimes) =>
                              _buildRuntimePickerField(context, runtimes),
                          loading: () => _buildStaticRow(
                            context,
                            context.l10n.websites_runtime,
                            context.l10n.common_loading,
                          ),
                          error: (err, _) => _buildStaticRow(
                            context,
                            context.l10n.websites_runtime,
                            context.l10n.common_loadingFailed,
                          ),
                        ),
                        if (_isPhpLocal) ...[
                          const SizedBox(height: 12),
                          _buildProxyTypePickerField(context),
                          if (_proxyType == 'tcp') ...[
                            const SizedBox(height: 12),
                            _buildInputRow(
                              context,
                              label: context.l10n.websites_port,
                              placeholder: '9000',
                              controller: _runtimePortController,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ],
                        if (!_isPhpLocal && _selectedRuntime != null) ...[
                          const SizedBox(height: 12),
                          _buildRuntimePortSection(context),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    context,
                    icon: TablerIcons.database,
                    title: context.l10n.databases_management,
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          label: context.l10n.websites_createDatabase,
                          icon: TablerIcons.database_plus,
                          value: _createDb,
                          onChanged: (value) =>
                              setState(() => _createDb = value),
                        ),
                        if (_createDb) ...[
                          const SizedBox(height: 12),
                          _buildDbTypePickerField(context),
                          const SizedBox(height: 12),
                          dbInstancesAsync.when(
                            data: (instances) =>
                                _buildDbHostPickerField(context, instances),
                            loading: () => _buildStaticRow(
                              context,
                              context.l10n.websites_databaseService,
                              context.l10n.common_loading,
                            ),
                            error: (err, _) => _buildStaticRow(
                              context,
                              context.l10n.websites_databaseService,
                              context.l10n.common_loadingFailed,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInputRow(
                            context,
                            label: context.l10n.websites_databaseName,
                            placeholder: 'my_database',
                            controller: _dbNameController,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildInputRow(
                                  context,
                                  label: context.l10n.databases_username,
                                  placeholder: 'db_user',
                                  controller: _dbUserController,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputRow(
                                  context,
                                  label: context.l10n.databases_password,
                                  placeholder: context.l10n.databases_password,
                                  controller: _dbPasswordController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDbFormatPickerField(context),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    context,
                    icon: TablerIcons.shield_lock,
                    title: context.l10n.websites_sslAndAccess,
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          label: context.l10n.websites_enableSsl,
                          icon: TablerIcons.lock,
                          value: _enableSSL,
                          onChanged: (value) {
                            setState(() {
                              _enableSSL = value;
                              if (!value) _selectedSslId = null;
                            });
                          },
                        ),
                        if (_enableSSL) ...[
                          const SizedBox(height: 12),
                          acmeAccountsAsync.when(
                            data: (accounts) =>
                                _buildAcmePickerField(context, accounts),
                            loading: () => _buildStaticRow(
                              context,
                              context.l10n.websites_acmeAccount,
                              context.l10n.common_loading,
                            ),
                            error: (err, _) => _buildStaticRow(
                              context,
                              context.l10n.websites_acmeAccount,
                              context.l10n.common_loadingFailed,
                            ),
                          ),
                          const SizedBox(height: 12),
                          sslListAsync.when(
                            data: (certs) =>
                                _buildSslPickerField(context, certs),
                            loading: () => _buildStaticRow(
                              context,
                              context.l10n.websites_certificate,
                              context.l10n.common_loading,
                            ),
                            error: (err, _) => _buildStaticRow(
                              context,
                              context.l10n.websites_certificate,
                              context.l10n.common_loadingFailed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    context,
                    icon: TablerIcons.server,
                    title: 'FTP',
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          context,
                          label: context.l10n.websites_enableFtp,
                          icon: TablerIcons.folder_share,
                          value: _enableFtp,
                          onChanged: (value) {
                            setState(() {
                              _enableFtp = value;
                              if (value &&
                                  _ftpPasswordController.text.isEmpty) {
                                _ftpPasswordController.text =
                                    _generatePassword();
                              }
                            });
                          },
                        ),
                        if (_enableFtp) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildInputRow(
                                  context,
                                  label: context.l10n.websites_account,
                                  placeholder: context
                                      .l10n
                                      .websites_ftpAccountPlaceholder,
                                  controller: _ftpUserController,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputRow(
                                  context,
                                  label: context.l10n.databases_password,
                                  placeholder: context
                                      .l10n
                                      .websites_ftpPasswordPlaceholder,
                                  controller: _ftpPasswordController,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                        const SizedBox(height: 12),
                        _buildSwitchRow(
                          context,
                          label: context.l10n.containers_enableIpv6,
                          icon: TablerIcons.network,
                          value: _enableIPv6,
                          onChanged: (value) =>
                              setState(() => _enableIPv6 = value),
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

  // ── Root Hint ─────────────────────────────────────────────────

  Widget _buildRootHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(
            TablerIcons.folder_root,
            size: 14,
            color: AppColors.tertiaryLabel(context),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

  // ── Runtime Type Picker ───────────────────────────────────────

  Widget _buildRuntimeTypePickerField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_runtimeType,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<String>(
          value: _selectedRuntimeType,
          options: _runtimeTypeOptions,
          anchorHeight: _formControlHeight,
          onChanged: _onRuntimeTypeChanged,
        ),
      ],
    );
  }

  // ── Runtime Picker ────────────────────────────────────────────

  String _runtimePickerLabel(BuildContext context, RuntimeDto r) {
    final resource = r.resource == 'local'
        ? context.l10n.websites_local
        : context.l10n.websites_container;
    return '${r.name} [$resource]';
  }

  Widget _buildRuntimePickerField(
    BuildContext context,
    List<RuntimeDto> runtimes,
  ) {
    if (runtimes.isEmpty) {
      return _buildStaticRow(
        context,
        context.l10n.websites_runtime,
        context.l10n.websites_noAvailableRuntime,
      );
    }

    final options = [
      for (final r in runtimes)
        AppPickerOption<int>(
          value: r.id,
          label: _runtimePickerLabel(context, r),
        ),
    ];

    final effectiveId =
        _selectedRuntime != null &&
            runtimes.any((r) => r.id == _selectedRuntime!.id)
        ? _selectedRuntime!.id
        : runtimes.first.id;

    if (_selectedRuntime == null ||
        !runtimes.any((r) => r.id == _selectedRuntime!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final runtime = runtimes.firstWhere((r) => r.id == effectiveId);
          _onRuntimeChanged(runtime);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_runtime,
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
          onChanged: (id) {
            final runtime = runtimes.firstWhere((r) => r.id == id);
            _onRuntimeChanged(runtime);
          },
        ),
      ],
    );
  }

  // ── Proxy Type Picker (PHP local) ─────────────────────────────

  Widget _buildProxyTypePickerField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_connectionType,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<String>(
          value: _proxyType,
          options: _proxyTypeOptions,
          anchorHeight: _formControlHeight,
          onChanged: (value) => setState(() {
            _proxyType = value;
            if (value == 'tcp') {
              _runtimePortController.text = '9000';
            }
          }),
        ),
      ],
    );
  }

  // ── Runtime Port Section (non-PHP) ────────────────────────────

  Widget _buildRuntimePortSection(BuildContext context) {
    final runtime = _selectedRuntime!;
    final ports = runtime.port
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .where((p) => p != null && p > 0)
        .cast<int>()
        .toList();

    if (ports.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed
              .resolveFrom(context)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              TablerIcons.alert_triangle,
              size: 18,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.websites_runtimeNoExposedPorts,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final options = [
      for (final p in ports) AppPickerOption<int>(value: p, label: '$p'),
    ];

    if (ports.length == 1 && _selectedPort == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedPort = ports.first);
      });
    }

    final effectivePort = _selectedPort ?? ports.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_port,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<int>(
          value: effectivePort,
          options: options,
          anchorHeight: _formControlHeight,
          onChanged: (port) => setState(() => _selectedPort = port),
        ),
      ],
    );
  }

  // ── DB Type Picker ────────────────────────────────────────────

  Widget _buildDbTypePickerField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_databaseType,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<String>(
          value: _selectedDbType,
          options: _dbTypeOptions,
          anchorHeight: _formControlHeight,
          onChanged: _onDbTypeChanged,
        ),
      ],
    );
  }

  // ── DB Host Picker ────────────────────────────────────────────

  Widget _buildDbHostPickerField(
    BuildContext context,
    List<AppServiceDto> services,
  ) {
    if (services.isEmpty) {
      return _buildStaticRow(
        context,
        context.l10n.websites_databaseService,
        context.l10n.websites_noAvailableService,
      );
    }

    final options = [
      for (final s in services)
        AppPickerOption<String>(value: s.value, label: s.label),
    ];

    final effectiveHost =
        _selectedDbHost != null &&
            options.any((o) => o.value == _selectedDbHost)
        ? _selectedDbHost!
        : options.first.value;

    if (_selectedDbHost == null ||
        !options.any((o) => o.value == _selectedDbHost)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDbHost = effectiveHost);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_databaseService,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<String>(
          value: effectiveHost,
          options: options,
          onChanged: (host) => setState(() => _selectedDbHost = host),
        ),
      ],
    );
  }

  // ── DB Format Picker ──────────────────────────────────────────

  Widget _buildDbFormatPickerField(BuildContext context) {
    final options = _dbFormatOptions;
    final effectiveFormat = options.any((o) => o.value == _selectedDbFormat)
        ? _selectedDbFormat
        : options.first.value;
    if (effectiveFormat != _selectedDbFormat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDbFormat = effectiveFormat);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_charset,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<String>(
          value: effectiveFormat,
          options: options,
          anchorHeight: _formControlHeight,
          onChanged: (format) => setState(() => _selectedDbFormat = format),
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

  // ── ACME Picker ───────────────────────────────────────────────

  String _acmePickerLabel(WebsiteAcmeAccountDto a) {
    if (a.id == 0) return a.email;
    final email = a.email;
    final type = a.type;
    if (email.isEmpty && type.isEmpty) return 'ACME #${a.id}';
    if (type.isEmpty) return email;
    if (email.isEmpty) return type;
    return '$email ($type)';
  }

  List<AppPickerOption<int>> _acmePickerOptions(
    List<WebsiteAcmeAccountDto> accounts,
  ) {
    final list = List<WebsiteAcmeAccountDto>.from(accounts);
    if (!list.any((a) => a.id == 0)) {
      list.insert(0, const WebsiteAcmeAccountDto.manual());
    }
    return [
      for (final a in list)
        AppPickerOption<int>(value: a.id, label: _acmePickerLabel(a)),
    ];
  }

  Widget _buildAcmePickerField(
    BuildContext context,
    List<WebsiteAcmeAccountDto> accounts,
  ) {
    final options = _acmePickerOptions(accounts);
    final value = options.any((o) => o.value == _selectedAcmeAccountId)
        ? _selectedAcmeAccountId
        : options.first.value;
    if (value != _selectedAcmeAccountId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedAcmeAccountId = value;
            _selectedSslId = null;
          });
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_acmeAccount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<int>(
          value: value,
          options: options,
          onChanged: (id) {
            setState(() {
              _selectedAcmeAccountId = id;
              _selectedSslId = null;
            });
          },
        ),
      ],
    );
  }

  // ── SSL Picker ────────────────────────────────────────────────

  String _certValidityDaysLabel(BuildContext context, String expireDate) {
    if (expireDate.isEmpty) return context.l10n.websites_validityUnknown;
    if (expireDate == '9999-12-31T00:00:00Z') {
      return context.l10n.websites_validityNeverExpires;
    }
    if (expireDate.startsWith('0001-')) {
      return context.l10n.websites_validityUnknown;
    }

    final expireAt = DateTime.tryParse(expireDate)?.toLocal();
    if (expireAt == null) {
      return context.l10n.websites_validityValue(expireDate);
    }

    final now = DateTime.now();
    if (!expireAt.isAfter(now)) return context.l10n.websites_validityExpired;

    final days = expireAt.difference(now).inDays;
    if (days >= 1) return context.l10n.websites_validityDays(days);
    return context.l10n.websites_validityLessThanOneDay;
  }

  String _certPickerLabel(BuildContext context, WebsiteSslDto c) {
    final domain = c.primaryDomain.isEmpty
        ? context.l10n.websites_certificateNumber(c.id)
        : c.primaryDomain;
    return '$domain · ${_certValidityDaysLabel(context, c.expireDate)}';
  }

  Widget _buildSslPickerField(BuildContext context, List<WebsiteSslDto> certs) {
    if (certs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.websites_certificate,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(
                context,
              ).withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.websites_noAvailableCertificate,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),
        ],
      );
    }

    final firstId = certs.first.id;
    var effectiveSslId = _selectedSslId;
    if (effectiveSslId == null || !certs.any((c) => c.id == effectiveSslId)) {
      effectiveSslId = firstId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSslId = firstId);
      });
    }

    final options = [
      for (final c in certs)
        AppPickerOption<int>(value: c.id, label: _certPickerLabel(context, c)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.websites_certificate,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: 7),
        AppInlinePicker<int>(
          value: effectiveSslId,
          options: options,
          onChanged: (id) => setState(() => _selectedSslId = id),
        ),
      ],
    );
  }
}
