import 'dart:convert';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/database_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_picker.dart';

const _mysqlVersions = ['8.x', '5.7', '5.6'];
const _mariadbVersions = ['10.x', '11.x'];
const _postgresqlVersions = ['18.x', '17.x', '16.x', '15.x', '14.x'];
const _redisVersions = ['8.x', '7.x', '6.x'];

const _defaultPorts = {
  'mysql': 3306,
  'mariadb': 3306,
  'postgresql': 5432,
  'redis': 6379,
};

/// 显示远程数据库编辑 Sheet。
Future<void> showDatabaseRemoteEditSheet(
  BuildContext context, {
  required int dbId,
  required String dbName,
  required String dbType,
}) async {
  await showActionSheet<void>(
    context: context,
    builder: (_) =>
        _DatabaseRemoteEditSheet(dbId: dbId, dbName: dbName, dbType: dbType),
  );
}

class _DatabaseRemoteEditSheet extends ConsumerStatefulWidget {
  const _DatabaseRemoteEditSheet({
    required this.dbId,
    required this.dbName,
    required this.dbType,
  });

  final int dbId;
  final String dbName;
  final String dbType;

  @override
  ConsumerState<_DatabaseRemoteEditSheet> createState() =>
      _DatabaseRemoteEditSheetState();
}

class _DatabaseRemoteEditSheetState
    extends ConsumerState<_DatabaseRemoteEditSheet> {
  final _addressController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _initialDBController = TextEditingController();
  final _timeoutController = TextEditingController(text: '30');
  final _descriptionController = TextEditingController();
  final _clientKeyController = TextEditingController();
  final _clientCertController = TextEditingController();
  final _rootCertController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;
  bool _isTesting = false;
  bool _testPassed = false;
  String? _testError;
  bool _obscurePassword = true;
  bool _sslEnabled = false;
  bool _hasCA = false;
  bool _skipVerify = false;

  late String _selectedVersion;
  String _createdAt = '';

  bool get _isMysqlFamily =>
      widget.dbType == 'mysql' || widget.dbType == 'mariadb';

  @override
  void initState() {
    super.initState();
    _selectedVersion = _versionsForType(widget.dbType).first;
    _loadExisting();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _initialDBController.dispose();
    _timeoutController.dispose();
    _descriptionController.dispose();
    _clientKeyController.dispose();
    _clientCertController.dispose();
    _rootCertController.dispose();
    super.dispose();
  }

  List<String> _versionsForType(String type) {
    switch (type) {
      case 'mysql':
        return _mysqlVersions;
      case 'mariadb':
        return _mariadbVersions;
      case 'postgresql':
        return _postgresqlVersions;
      case 'redis':
        return _redisVersions;
      default:
        return const [];
    }
  }

  Future<void> _loadExisting() async {
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      final raw = await repo.getDatabase(widget.dbName);
      if (!mounted) return;

      setState(() {
        _addressController.text = (raw['address'] as String?) ?? '';
        _portController.text =
            '${raw['port'] ?? _defaultPorts[widget.dbType] ?? 3306}';
        _usernameController.text = (raw['username'] as String?) ?? '';
        _passwordController.text = (raw['password'] as String?) ?? '';
        _initialDBController.text = (raw['initialDB'] as String?) ?? '';
        _timeoutController.text = '${raw['timeout'] ?? 30}';
        _descriptionController.text = (raw['description'] as String?) ?? '';
        _createdAt = (raw['createdAt'] as String?) ?? '';

        final version = (raw['version'] as String?) ?? '';
        final versions = _versionsForType(widget.dbType);
        _selectedVersion = versions.contains(version)
            ? version
            : versions.first;

        if (_isMysqlFamily) {
          _sslEnabled = raw['ssl'] == true;
          _skipVerify = raw['skipVerify'] == true;
          _hasCA = raw['hasCA'] == true;
          if (_sslEnabled) {
            _clientKeyController.text = _tryDecodeBase64(raw['clientKey']);
            _clientCertController.text = _tryDecodeBase64(raw['clientCert']);
            _rootCertController.text = _tryDecodeBase64(raw['rootCert']);
          }
        }

        _isFetching = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
        showAppErrorToast(
          context.l10n.databases_loadConnectionInfoFailed,
          description: '$e',
        );
      }
    }
  }

  String _tryDecodeBase64(dynamic value) {
    if (value is! String || value.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(value));
    } catch (_) {
      return value;
    }
  }

  void _invalidateTest() {
    if (_testPassed || _testError != null) {
      setState(() {
        _testPassed = false;
        _testError = null;
      });
    }
  }

  String? _validate() {
    final address = _addressController.text.trim();
    final port = _portController.text.trim();
    final username = _usernameController.text.trim();

    final l10n = context.l10n;

    if (address.isEmpty) return l10n.databases_enterAddress;
    if (port.isEmpty) return l10n.databases_enterPort;
    final portNum = int.tryParse(port);
    if (portNum == null || portNum < 1 || portNum > 65535) {
      return l10n.databases_portRange;
    }
    if (widget.dbType != 'redis' && username.isEmpty) {
      return l10n.databases_enterUsername;
    }

    final timeout = _timeoutController.text.trim();
    if (timeout.isNotEmpty) {
      final t = int.tryParse(timeout);
      if (t == null || t < 1 || t > 600) return l10n.databases_timeoutRange;
    }

    if (_isMysqlFamily && _sslEnabled) {
      if (_clientKeyController.text.trim().isEmpty) {
        return l10n.databases_sslClientKeyRequired;
      }
      if (_clientCertController.text.trim().isEmpty) {
        return l10n.databases_sslClientCertRequired;
      }
      if (_hasCA && _rootCertController.text.trim().isEmpty) {
        return l10n.databases_sslCaCertRequired;
      }
    }

    return null;
  }

  Map<String, dynamic> _buildBody() {
    final body = <String, dynamic>{
      'id': widget.dbId,
      'createdAt': _createdAt,
      'name': widget.dbName,
      'type': widget.dbType,
      'from': 'remote',
      'version': _selectedVersion,
      'address': _addressController.text.trim(),
      'port': int.parse(_portController.text.trim()),
      'username': widget.dbType == 'redis'
          ? '-'
          : _usernameController.text.trim(),
      'password': _passwordController.text,
      'timeout': int.tryParse(_timeoutController.text.trim()) ?? 30,
      'description': _descriptionController.text.trim(),
    };

    if (widget.dbType == 'postgresql') {
      body['initialDB'] = _initialDBController.text.trim();
    }

    if (_isMysqlFamily) {
      body['ssl'] = _sslEnabled;
      body['skipVerify'] = _skipVerify;
      body['hasCA'] = _hasCA;
      if (_sslEnabled) {
        body['clientKey'] = base64Encode(
          utf8.encode(_clientKeyController.text),
        );
        body['clientCert'] = base64Encode(
          utf8.encode(_clientCertController.text),
        );
        body['rootCert'] = _hasCA
            ? base64Encode(utf8.encode(_rootCertController.text))
            : '';
      } else {
        body['clientKey'] = '';
        body['clientCert'] = '';
        body['rootCert'] = '';
      }
    }

    return body;
  }

  Future<void> _testConnection() async {
    final error = _validate();
    if (error != null) {
      showAppWarningToast(error);
      return;
    }

    setState(() {
      _isTesting = true;
      _testPassed = false;
      _testError = null;
    });
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      final body = _buildBody();
      final ok = await repo.checkRemoteConnection(body);
      if (mounted) {
        if (ok) {
          setState(() => _testPassed = true);
        } else {
          setState(() => _testError = context.l10n.databases_connectionFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _testError = context.l10n.databases_connectionTimeoutOrError,
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      showAppWarningToast(error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = await ref.read(databaseRepositoryProvider.future);
      await repo.updateRemoteDatabase(_buildBody());
      if (mounted) {
        showAppSuccessToast(context.l10n.databases_connectionUpdated);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.databases_updateFailed,
          description: '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.databases_editRemoteConnection,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.l10n.common_cancel,
                style: TextStyle(
                  color: AppColors.secondaryLabel(context),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
      child: _isFetching
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildFormFields(),
                const SizedBox(height: 24),
                // 测试连接
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: AppColors.secondaryBackground(
                      context,
                    ).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    onPressed: _isTesting ? null : _testConnection,
                    child: _isTesting
                        ? const CupertinoActivityIndicator()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _testPassed
                                    ? TablerIcons.circle_check_filled
                                    : (_testError != null
                                          ? TablerIcons.circle_x_filled
                                          : TablerIcons.plug_connected),
                                size: 18,
                                color: _testPassed
                                    ? CupertinoColors.systemGreen.resolveFrom(
                                        context,
                                      )
                                    : (_testError != null
                                          ? CupertinoColors.systemRed
                                                .resolveFrom(context)
                                          : AppColors.label(context)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _testPassed
                                    ? context.l10n.databases_connectionSucceeded
                                    : (_testError ??
                                          context
                                              .l10n
                                              .databases_testConnection),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _testPassed
                                      ? CupertinoColors.systemGreen.resolveFrom(
                                          context,
                                        )
                                      : (_testError != null
                                            ? CupertinoColors.systemRed
                                                  .resolveFrom(context)
                                            : AppColors.label(context)),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                    borderRadius: BorderRadius.circular(14),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : Text(
                            context.l10n.common_save,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildFormFields() {
    final fields = <Widget>[];
    final l10n = context.l10n;

    // 名称（只读）
    fields.add(
      _buildReadOnlyField(
        label: l10n.databases_name,
        icon: TablerIcons.database,
        value: widget.dbName,
      ),
    );
    fields.add(const SizedBox(height: 16));

    // 版本
    final versions = _versionsForType(widget.dbType);
    fields.add(
      _FormItem(
        label: l10n.databases_version,
        icon: TablerIcons.versions,
        child: AppInlinePicker<String>(
          value: _selectedVersion,
          anchorHeight: 46,
          backgroundColor: AppColors.secondaryBackground(
            context,
          ).withValues(alpha: 0.5),
          options: [
            for (final v in versions) AppPickerOption(value: v, label: v),
          ],
          onChanged: (v) {
            setState(() => _selectedVersion = v);
            _invalidateTest();
          },
        ),
      ),
    );
    fields.add(const SizedBox(height: 16));

    // 地址
    fields.add(
      _buildTextField(
        label: l10n.databases_address,
        icon: TablerIcons.world,
        controller: _addressController,
        placeholder: l10n.databases_ipOrDomain,
      ),
    );
    fields.add(const SizedBox(height: 16));

    // 端口
    fields.add(
      _buildTextField(
        label: l10n.databases_port,
        icon: TablerIcons.plug,
        controller: _portController,
        placeholder: '${_defaultPorts[widget.dbType] ?? 3306}',
        keyboardType: TextInputType.number,
      ),
    );

    // PostgreSQL: initialDB
    if (widget.dbType == 'postgresql') {
      fields.add(const SizedBox(height: 16));
      fields.add(
        _buildTextField(
          label: l10n.databases_initialDatabase,
          icon: TablerIcons.database,
          controller: _initialDBController,
          placeholder: l10n.databases_initialDatabasePlaceholder,
        ),
      );
    }

    // 用户名 (非 Redis)
    if (widget.dbType != 'redis') {
      fields.add(const SizedBox(height: 16));
      fields.add(
        _buildTextField(
          label: l10n.databases_username,
          icon: TablerIcons.user,
          controller: _usernameController,
          placeholder: l10n.databases_databaseUsernamePlaceholder,
        ),
      );
    }

    // 密码
    fields.add(const SizedBox(height: 16));
    fields.add(
      _FormItem(
        label: widget.dbType == 'redis'
            ? l10n.databases_passwordOptional
            : l10n.databases_password,
        icon: TablerIcons.key,
        child: SizedBox(
          height: 46,
          child: CupertinoTextField(
            controller: _passwordController,
            placeholder: widget.dbType == 'redis'
                ? l10n.databases_noPasswordPlaceholder
                : l10n.databases_enterPassword,
            obscureText: _obscurePassword,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(fontSize: 17, color: AppColors.label(context)),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (_) => _invalidateTest(),
            autocorrect: false,
            enableSuggestions: false,
            suffix: CupertinoButton(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? TablerIcons.eye_off : TablerIcons.eye,
                size: 20,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
        ),
      ),
    );

    // SSL section (MySQL/MariaDB only)
    if (_isMysqlFamily) {
      fields.add(const SizedBox(height: 16));
      fields.add(
        _buildSwitchRow(
          label: 'SSL',
          icon: TablerIcons.lock,
          value: _sslEnabled,
          onChanged: (v) {
            setState(() => _sslEnabled = v);
            _invalidateTest();
          },
        ),
      );

      if (_sslEnabled) {
        fields.add(const SizedBox(height: 12));
        fields.add(
          _buildSwitchRow(
            label: l10n.databases_skipCertVerify,
            icon: TablerIcons.shield_off,
            value: _skipVerify,
            onChanged: (v) {
              setState(() => _skipVerify = v);
              _invalidateTest();
            },
          ),
        );
        fields.add(const SizedBox(height: 12));
        fields.add(
          _buildSwitchRow(
            label: l10n.databases_hasCaCert,
            icon: TablerIcons.certificate,
            value: _hasCA,
            onChanged: (v) {
              setState(() => _hasCA = v);
              _invalidateTest();
            },
          ),
        );

        fields.add(const SizedBox(height: 16));
        fields.add(
          _buildMultilineField(
            label: l10n.databases_clientPrivateKey,
            icon: TablerIcons.key,
            controller: _clientKeyController,
            placeholder: '-----BEGIN PRIVATE KEY-----',
          ),
        );
        fields.add(const SizedBox(height: 16));
        fields.add(
          _buildMultilineField(
            label: l10n.databases_clientCertificate,
            icon: TablerIcons.file_certificate,
            controller: _clientCertController,
            placeholder: '-----BEGIN CERTIFICATE-----',
          ),
        );

        if (_hasCA) {
          fields.add(const SizedBox(height: 16));
          fields.add(
            _buildMultilineField(
              label: l10n.databases_caCertificate,
              icon: TablerIcons.shield_check,
              controller: _rootCertController,
              placeholder: '-----BEGIN CERTIFICATE-----',
            ),
          );
        }
      }
    }

    // 超时
    fields.add(const SizedBox(height: 16));
    fields.add(
      _buildTextField(
        label: l10n.databases_timeoutSeconds,
        icon: TablerIcons.clock,
        controller: _timeoutController,
        placeholder: '30',
        keyboardType: TextInputType.number,
      ),
    );

    // 描述
    fields.add(const SizedBox(height: 16));
    fields.add(
      _buildTextField(
        label: l10n.databases_descriptionOptional,
        icon: TablerIcons.note,
        controller: _descriptionController,
        placeholder: l10n.databases_remarkInfo,
      ),
    );

    return fields;
  }

  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return _FormItem(
      label: label,
      icon: icon,
      child: Container(
        width: double.infinity,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 17,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
  }) {
    return _FormItem(
      label: label,
      icon: icon,
      child: SizedBox(
        height: 46,
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: 17, color: AppColors.label(context)),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          onChanged: (_) => _invalidateTest(),
          autocorrect: false,
          enableSuggestions: false,
        ),
      ),
    );
  }

  Widget _buildMultilineField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String placeholder,
  }) {
    return _FormItem(
      label: label,
      icon: icon,
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLines: 4,
        minLines: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        style: TextStyle(fontSize: 14, color: AppColors.label(context)),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        onChanged: (_) => _invalidateTest(),
        autocorrect: false,
        enableSuggestions: false,
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: AppColors.label(context)),
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FormItem extends StatelessWidget {
  const _FormItem({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.secondaryLabel(context)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
