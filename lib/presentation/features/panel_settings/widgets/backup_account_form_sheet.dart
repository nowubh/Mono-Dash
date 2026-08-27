import 'dart:convert';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/backup_account_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_form_components.dart';

/// 显示添加/编辑备份账号的弹窗。
Future<void> showBackupAccountFormSheet(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) {
  return showActionSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _BackupAccountFormSheet(existing: existing),
  );
}

const _backupTypes = [
  _BackupTypeInfo('SFTP', TablerIcons.server, CupertinoColors.systemGreen),
  _BackupTypeInfo('OSS', TablerIcons.cloud, CupertinoColors.systemOrange),
  _BackupTypeInfo('COS', TablerIcons.cloud, CupertinoColors.systemBlue),
  _BackupTypeInfo('S3', TablerIcons.cloud, CupertinoColors.systemYellow),
  _BackupTypeInfo('MINIO', TablerIcons.database, CupertinoColors.systemRed),
  _BackupTypeInfo('KODO', TablerIcons.cloud, CupertinoColors.systemTeal),
  _BackupTypeInfo('UPYUN', TablerIcons.cloud, CupertinoColors.systemPink),
  _BackupTypeInfo('WebDAV', TablerIcons.world, CupertinoColors.systemIndigo),
  _BackupTypeInfo(
    'OneDrive',
    TablerIcons.brand_onedrive,
    CupertinoColors.systemBlue,
  ),
  _BackupTypeInfo(
    'GoogleDrive',
    TablerIcons.brand_google_drive,
    CupertinoColors.systemGreen,
  ),
  _BackupTypeInfo('ALIYUN', TablerIcons.cloud, CupertinoColors.activeBlue),
  _BackupTypeInfo('LOCAL', TablerIcons.folder, CupertinoColors.systemGrey),
];

class _BackupTypeInfo {
  const _BackupTypeInfo(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}

class _BackupAccountFormSheet extends ConsumerStatefulWidget {
  const _BackupAccountFormSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_BackupAccountFormSheet> createState() =>
      _BackupAccountFormSheetState();
}

class _BackupAccountFormSheetState
    extends ConsumerState<_BackupAccountFormSheet> {
  final _nameController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final _credentialController = TextEditingController();
  final _endpointController = TextEditingController();
  final _regionController = TextEditingController();
  final _bucketController = TextEditingController();
  final _backupPathController = TextEditingController();
  final _addressController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _passphraseController = TextEditingController();
  final _domainController = TextEditingController();
  final _tokenController = TextEditingController();
  final _driveIdController = TextEditingController();

  String _type = 'SFTP';
  String _authMode = 'password';
  bool _testing = false;
  bool _saving = false;
  bool _isCN = false;
  List<dynamic> _buckets = [];
  bool _loadingBuckets = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.existing!;
      _nameController.text = (e['name'] as String?) ?? '';
      _type = (e['type'] as String?) ?? 'SFTP';
      _backupPathController.text = (e['backupPath'] as String?) ?? '';
      _bucketController.text = (e['bucket'] as String?) ?? '';

      final vars = e['varsJson'];
      final Map<String, dynamic> varsMap = vars is Map<String, dynamic>
          ? vars
          : {};

      _accessKeyController.text = (e['accessKey'] as String?) ?? '';
      _credentialController.text = (e['credential'] as String?) ?? '';
      _endpointController.text =
          (varsMap['endpointItem'] as String?) ??
          (varsMap['endpoint'] as String?) ??
          '';
      _regionController.text = (varsMap['region'] as String?) ?? '';
      _addressController.text = (varsMap['address'] as String?) ?? '';
      _portController.text = '${varsMap['port'] ?? 22}';
      _authMode = (varsMap['authMode'] as String?) ?? 'password';
      _passphraseController.text = (varsMap['passPhrase'] as String?) ?? '';
      _domainController.text = (varsMap['domain'] as String?) ?? '';
      _tokenController.text = (varsMap['refresh_token'] as String?) ?? '';
      _driveIdController.text = (varsMap['drive_id'] as String?) ?? '';
      _isCN = (varsMap['isCN'] == 'true');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accessKeyController.dispose();
    _credentialController.dispose();
    _endpointController.dispose();
    _regionController.dispose();
    _bucketController.dispose();
    _backupPathController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _passphraseController.dispose();
    _domainController.dispose();
    _tokenController.dispose();
    _driveIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      isFloating: true,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _isEdit ? TablerIcons.edit : TablerIcons.plus,
                  size: 24,
                  color: CupertinoColors.activeBlue,
                ),
                const SizedBox(width: 10),
                Text(
                  _isEdit
                      ? context.l10n.panelSettings_editBackupAccount
                      : context.l10n.panelSettings_addBackupAccount,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.label(context),
                  ),
                ),
              ],
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.l10n.common_cancel,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 基本信息 ──
          AppSectionHeader(
            title: context.l10n.panelSettings_basicInfo,
            icon: TablerIcons.info_circle,
          ),
          AppActionGroup(
            children: [
              _formField(
                TablerIcons.tag,
                context.l10n.panelSettings_name,
                _nameController,
                context.l10n.panelSettings_namePlaceholder,
              ),
              _buildTypePicker(),
            ],
          ),

          const SizedBox(height: 24),

          // ── 认证信息 ──
          AppSectionHeader(
            title: context.l10n.panelSettings_authInfo,
            icon: TablerIcons.key,
          ),
          AppActionGroup(children: _buildAuthFields()),

          const SizedBox(height: 24),

          // ── 存储设置 ──
          AppSectionHeader(
            title: context.l10n.panelSettings_storageSettings,
            icon: TablerIcons.folder,
          ),
          AppActionGroup(children: _buildStorageFields()),

          const SizedBox(height: 32),

          // Test connection and Save buttons
          if (_type != 'LOCAL') ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(14),
                color: CupertinoColors.systemTeal
                    .resolveFrom(context)
                    .withValues(alpha: 0.1),
                onPressed: _testing ? null : _testConnection,
                child: _testing
                    ? const CupertinoActivityIndicator(radius: 10)
                    : Text(
                        context.l10n.panelSettings_testConnection,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: CupertinoColors.systemTeal.resolveFrom(
                            context,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(14),
              onPressed: _saving ? null : _onSave,
              child: _saving
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : Text(
                      context.l10n.panelSettings_saveSettings,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Type picker ──

  Widget _buildTypePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            context.l10n.panelSettings_type,
            style: const TextStyle(fontSize: 15),
          ),
          const Spacer(),
          if (_isEdit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _typeColor(_type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _type,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _typeColor(_type),
                ),
              ),
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              onPressed: _showTypePicker,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _type,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _typeColor(_type),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    TablerIcons.chevron_down,
                    size: 16,
                    color: AppColors.secondaryLabel(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showTypePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: _backupTypes
            .map(
              (t) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() {
                    _type = t.name;
                    _buckets = [];
                    _bucketController.clear();
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text(t.name),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ),
    );
  }

  // ── Auth fields (dynamic per type) ──

  List<Widget> _buildAuthFields() {
    switch (_type) {
      case 'SFTP':
        return [
          _formField(
            TablerIcons.network,
            context.l10n.panelSettings_address,
            _addressController,
            context.l10n.panelSettings_serverAddress,
          ),
          _formField(
            TablerIcons.plug,
            context.l10n.panelSettings_panelPort,
            _portController,
            '22',
            keyboardType: TextInputType.number,
          ),
          _formField(
            TablerIcons.user,
            context.l10n.panelSettings_username,
            _accessKeyController,
            context.l10n.panelSettings_sshUsername,
          ),
          _buildAuthModePicker(),
          if (_authMode == 'password')
            _formField(
              TablerIcons.lock,
              context.l10n.panelSettings_password,
              _credentialController,
              context.l10n.panelSettings_sshPassword,
              obscure: true,
            )
          else ...[
            _formField(
              TablerIcons.key,
              context.l10n.panelSettings_privateKey,
              _credentialController,
              context.l10n.panelSettings_privateKeyPlaceholder,
              maxLines: 4,
            ),
            _formField(
              TablerIcons.lock,
              context.l10n.panelSettings_keyPassphrase,
              _passphraseController,
              context.l10n.panelSettings_keyPassphrasePlaceholder,
              obscure: true,
            ),
          ],
        ];
      case 'WebDAV':
        return [
          _formField(
            TablerIcons.network,
            context.l10n.panelSettings_address,
            _addressController,
            context.l10n.panelSettings_webdavAddress,
          ),
          _formField(
            TablerIcons.user,
            context.l10n.panelSettings_username,
            _accessKeyController,
            context.l10n.panelSettings_webdavUsername,
          ),
          _formField(
            TablerIcons.lock,
            context.l10n.panelSettings_password,
            _credentialController,
            context.l10n.panelSettings_webdavPassword,
            obscure: true,
          ),
        ];
      case 'UPYUN':
        return [
          _formField(
            TablerIcons.user,
            context.l10n.panelSettings_operator,
            _accessKeyController,
            context.l10n.panelSettings_upyunOperatorName,
          ),
          _formField(
            TablerIcons.lock,
            context.l10n.panelSettings_password,
            _credentialController,
            context.l10n.panelSettings_operatorPassword,
            obscure: true,
          ),
        ];
      case 'KODO':
        return [
          _formField(
            TablerIcons.key,
            'Access Key',
            _accessKeyController,
            'Access Key ID',
          ),
          _formField(
            TablerIcons.lock,
            'Secret Key',
            _credentialController,
            'Access Key Secret',
            obscure: true,
          ),
          _formField(
            TablerIcons.link,
            context.l10n.panelSettings_domain,
            _domainController,
            'http://example.com',
          ),
        ];
      case 'OneDrive':
      case 'GoogleDrive':
        return [
          _formField(
            TablerIcons.refresh,
            'Refresh Token',
            _tokenController,
            context.l10n.panelSettings_refreshTokenPlaceholder,
            maxLines: 2,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  context.l10n.panelSettings_cnRegion,
                  style: const TextStyle(fontSize: 15),
                ),
                const Spacer(),
                AppToggleSwitch(
                  value: _isCN,
                  onChanged: (v) => setState(() => _isCN = v),
                ),
              ],
            ),
          ),
        ];
      case 'ALIYUN':
        return [
          _formField(
            TablerIcons.refresh,
            'Refresh Token',
            _tokenController,
            context.l10n.panelSettings_aliyunRefreshToken,
            maxLines: 2,
          ),
          _formField(
            TablerIcons.database,
            'Drive ID',
            _driveIdController,
            context.l10n.panelSettings_driveIdPlaceholder,
          ),
        ];
      case 'LOCAL':
        return [];
      default:
        return [
          _formField(
            TablerIcons.key,
            'Access Key',
            _accessKeyController,
            'Access Key ID',
          ),
          _formField(
            TablerIcons.lock,
            'Secret Key',
            _credentialController,
            'Access Key Secret',
            obscure: true,
          ),
          _formField(
            TablerIcons.link,
            'Endpoint',
            _endpointController,
            _endpointPlaceholder,
          ),
          if (_type == 'COS' || _type == 'S3')
            _formField(
              TablerIcons.map,
              'Region',
              _regionController,
              'e.g. ap-guangzhou',
            ),
        ];
    }
  }

  Widget _formField(
    IconData icon,
    String label,
    TextEditingController controller,
    String placeholder, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AppFormItem(
        label: label,
        icon: icon,
        child: AppFormTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
        ),
      ),
    );
  }

  String get _endpointPlaceholder {
    switch (_type) {
      case 'OSS':
        return 'https://oss-cn-hangzhou.aliyuncs.com';
      case 'COS':
        return 'https://cos.ap-guangzhou.myqcloud.com';
      case 'S3':
        return 'https://s3.amazonaws.com';
      case 'MINIO':
        return 'http://minio.example.com:9000';
      default:
        return context.l10n.panelSettings_endpointWithScheme;
    }
  }

  Widget _buildAuthModePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            context.l10n.panelSettings_authMode,
            style: const TextStyle(fontSize: 15),
          ),
          const Spacer(),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: _authMode,
            children: {
              'password': Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  context.l10n.panelSettings_authPassword,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              'key': Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  context.l10n.panelSettings_authKey,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            },
            onValueChanged: (v) {
              if (v != null) setState(() => _authMode = v);
            },
          ),
        ],
      ),
    );
  }

  // ── Storage fields ──

  List<Widget> _buildStorageFields() {
    final fields = <Widget>[];

    if (_type != 'LOCAL' &&
        _type != 'SFTP' &&
        _type != 'WebDAV' &&
        _type != 'OneDrive' &&
        _type != 'GoogleDrive' &&
        _type != 'ALIYUN') {
      fields.add(_buildBucketRow());
    }

    fields.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: AppFormItem(
          label: context.l10n.panelSettings_backupPath,
          icon: TablerIcons.folder,
          child: AppFormTextField(
            controller: _backupPathController,
            placeholder: _type == 'SFTP'
                ? context.l10n.panelSettings_remoteBackupDirectory
                : context.l10n.panelSettings_optional,
          ),
        ),
      ),
    );

    return fields;
  }

  Widget _buildBucketRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            _type == 'UPYUN'
                ? context.l10n.panelSettings_serviceName
                : 'Bucket',
            style: const TextStyle(fontSize: 15),
          ),
          const Spacer(),
          if (_buckets.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              onPressed: _showBucketPicker,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _bucketController.text.isEmpty
                        ? context.l10n.panelSettings_selectBucket
                        : _bucketController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: _bucketController.text.isEmpty
                          ? AppColors.tertiaryLabel(context)
                          : AppColors.label(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    TablerIcons.chevron_down,
                    size: 16,
                    color: AppColors.secondaryLabel(context),
                  ),
                ],
              ),
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              onPressed: _loadingBuckets ? null : _loadBuckets,
              child: _loadingBuckets
                  ? const CupertinoActivityIndicator(radius: 8)
                  : Text(
                      context.l10n.panelSettings_loadBucket,
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  void _showBucketPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: _buckets
            .map(
              (b) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() {
                    _bucketController.text = b.toString();
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text(b.toString()),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ),
    );
  }

  // ── Actions ──

  Map<String, dynamic> _buildPayload() {
    final varsMap = <String, dynamic>{};

    switch (_type) {
      case 'SFTP':
        varsMap['address'] = _addressController.text.trim();
        varsMap['port'] = int.tryParse(_portController.text) ?? 22;
        varsMap['authMode'] = _authMode;
        if (_authMode == 'key') {
          varsMap['passPhrase'] = _passphraseController.text;
        }
        break;
      case 'WebDAV':
        varsMap['address'] = _addressController.text.trim();
        break;
      case 'KODO':
        varsMap['domain'] = _domainController.text.trim();
        break;
      case 'UPYUN':
        // 关键在于顶层 bucket 和 accessKey/credential 映射
        break;
      case 'OneDrive':
      case 'GoogleDrive':
        varsMap['refresh_token'] = _tokenController.text.trim();
        varsMap['isCN'] = _isCN ? 'true' : 'false';
        break;
      case 'ALIYUN':
        varsMap['refresh_token'] = _tokenController.text.trim();
        varsMap['drive_id'] = _driveIdController.text.trim();
        break;
      case 'LOCAL':
        break;
      default:
        varsMap['endpoint'] = _endpointController.text.trim();
        if (_regionController.text.isNotEmpty) {
          varsMap['region'] = _regionController.text.trim();
        }
    }

    final rawAccessKey = _accessKeyController.text.trim();
    final rawCredential = _credentialController.text;

    return {
      'name': _nameController.text.trim(),
      'type': _type,
      'accessKey': base64.encode(utf8.encode(rawAccessKey)),
      'credential': base64.encode(utf8.encode(rawCredential)),
      'bucket': _bucketController.text.trim(),
      'backupPath': _backupPathController.text.trim(),
      'vars': jsonEncode(varsMap),
      if (_isEdit) 'id': widget.existing!['id'],
    };
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final repo = await ref.read(backupAccountRepositoryProvider.future);
      await repo.checkConnection(_buildPayload());
      if (mounted) {
        showAppSuccessToast(context.l10n.panelSettings_connectionSucceeded);
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.panelSettings_connectionFailed,
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _loadBuckets() async {
    setState(() => _loadingBuckets = true);
    try {
      final repo = await ref.read(backupAccountRepositoryProvider.future);
      final buckets = await repo.listBuckets(_buildPayload());
      if (mounted) {
        setState(() => _buckets = buckets);
        if (buckets.isEmpty) {
          showAppWarningToast(context.l10n.panelSettings_bucketNotFound);
        }
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.common_loadingFailed,
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingBuckets = false);
    }
  }

  Future<void> _onSave() async {
    if (_nameController.text.trim().isEmpty) {
      showAppErrorToast(context.l10n.panelSettings_enterAccountName);
      return;
    }
    if (_type == 'OneDrive' || _type == 'GoogleDrive' || _type == 'ALIYUN') {
      if (_tokenController.text.trim().isEmpty) {
        showAppErrorToast(context.l10n.panelSettings_enterRefreshToken);
        return;
      }
    } else if (_type != 'LOCAL') {
      if (_accessKeyController.text.trim().isEmpty ||
          _credentialController.text.isEmpty) {
        showAppErrorToast(context.l10n.panelSettings_enterAuthInfo);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = await ref.read(backupAccountRepositoryProvider.future);
      final payload = _buildPayload();
      if (_isEdit) {
        await repo.updateAccount(payload);
      } else {
        await repo.createAccount(payload);
      }
      if (mounted) {
        showAppSuccessToast(
          _isEdit
              ? context.l10n.panelSettings_updated
              : context.l10n.panelSettings_added,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.panelSettings_saveFailed,
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _typeColor(String type) {
    return _backupTypes
            .where((t) => t.name == type)
            .map((t) => t.color)
            .firstOrNull ??
        CupertinoColors.systemGrey;
  }
}
