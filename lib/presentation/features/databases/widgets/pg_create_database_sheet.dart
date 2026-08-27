import 'dart:convert';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/database_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_picker.dart';

/// 显示创建 PostgreSQL 数据库 Sheet。
Future<void> showPgCreateDatabaseSheet(
  BuildContext context, {
  required String dbType,
  required String dbName,
  required String dbFrom,
  VoidCallback? onSuccess,
}) async {
  await showActionSheet<void>(
    context: context,
    builder: (_) => _PgCreateDatabaseSheet(
      dbType: dbType,
      dbName: dbName,
      dbFrom: dbFrom,
      onSuccess: onSuccess,
    ),
  );
}

class _PgCreateDatabaseSheet extends ConsumerStatefulWidget {
  const _PgCreateDatabaseSheet({
    required this.dbType,
    required this.dbName,
    required this.dbFrom,
    this.onSuccess,
  });

  final String dbType;
  final String dbName;
  final String dbFrom;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<_PgCreateDatabaseSheet> createState() =>
      _PgCreateDatabaseSheetState();
}

class _PgCreateDatabaseSheetState
    extends ConsumerState<_PgCreateDatabaseSheet> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _descriptionController = TextEditingController();

  // PG 编码选项
  static const _encodingOptions = [
    'UTF8',
    'SQL_ASCII',
    'EUC_CN',
    'EUC_JP',
    'EUC_KR',
    'LATIN1',
    'LATIN2',
    'LATIN9',
    'WIN1250',
    'WIN1251',
    'WIN1252',
    'WIN1256',
    'WIN1258',
    'BIG5',
    'GBK',
    'JOHAB',
    'SHIFT_JIS',
  ];
  String _selectedEncoding = 'UTF8';

  bool _superUser = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _pickerExpanded = false;

  String _lastSyncedName = '';

  @override
  void initState() {
    super.initState();
    _passwordController.text = _generatePassword();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789-_';
    final random = Random.secure();
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void _syncUsername(String name) {
    if (_usernameController.text == _lastSyncedName ||
        _usernameController.text.isEmpty) {
      _usernameController.text = name;
      _lastSyncedName = name;
    }
  }

  String? _validate() {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final l10n = context.l10n;
    if (name.isEmpty) return l10n.databases_enterDatabaseName;
    if (name.contains(' ')) return l10n.databases_databaseNameNoSpaces;
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name)) {
      return l10n.databases_databaseNameAllowedChars;
    }

    if (username.isEmpty) return l10n.databases_enterUsername;
    if (password.isEmpty) return l10n.databases_enterPassword;
    if (password.contains(' ')) return l10n.databases_passwordNoSpaces;
    if (password.length < 6) return l10n.databases_passwordMinLength;

    return null;
  }

  Map<String, dynamic> _buildBody() {
    return {
      'name': _nameController.text.trim(),
      'from': widget.dbFrom,
      'database': widget.dbName,
      'format': _selectedEncoding,
      'username': _usernameController.text.trim(),
      'password': base64Encode(utf8.encode(_passwordController.text)),
      'superUser': _superUser,
      'description': _descriptionController.text.trim(),
    };
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
      await repo.createPgDatabase(_buildBody());

      if (mounted) {
        showAppSuccessToast(context.l10n.databases_created);
        widget.onSuccess?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.databases_createFailed,
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
      hasHorizontalPadding: true,
      contentPadding: EdgeInsets.zero,
      scrollPhysics: _pickerExpanded
          ? const NeverScrollableScrollPhysics()
          : null,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
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
            ),
            Text(
              context.l10n.databases_createDatabase,
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
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CupertinoActivityIndicator(radius: 10)
                    : Text(
                        context.l10n.common_create,
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
          // ── 基本信息 ──
          _SectionHeader(title: context.l10n.databases_basicInfo),
          _GroupedBox(
            children: [
              _FormTile(
                label: context.l10n.databases_databaseName,
                child: SizedBox(
                  height: 44,
                  child: CupertinoTextField(
                    controller: _nameController,
                    placeholder: context.l10n.databases_enterDatabaseName,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.label(context),
                    ),
                    decoration: const BoxDecoration(),
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: _syncUsername,
                  ),
                ),
              ),
              _FormTile(
                label: context.l10n.databases_username,
                child: SizedBox(
                  height: 44,
                  child: CupertinoTextField(
                    controller: _usernameController,
                    placeholder: context.l10n.databases_enterUsername,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.label(context),
                    ),
                    decoration: const BoxDecoration(),
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) => _lastSyncedName = '',
                  ),
                ),
              ),
              _FormTile(
                label: context.l10n.databases_password,
                isLast: true,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _passwordController,
                          placeholder: context.l10n.databases_enterPassword,
                          obscureText: _obscurePassword,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.label(context),
                          ),
                          decoration: const BoxDecoration(),
                          autocorrect: false,
                          enableSuggestions: false,
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        child: Icon(
                          _obscurePassword
                              ? TablerIcons.eye_off
                              : TablerIcons.eye,
                          size: 18,
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        onPressed: () => setState(
                          () => _passwordController.text = _generatePassword(),
                        ),
                        child: Icon(
                          TablerIcons.refresh,
                          size: 18,
                          color: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── 字符集 ──
          const SizedBox(height: 24),
          _SectionHeader(title: context.l10n.databases_charset),
          _GroupedBox(
            children: [
              _FormTile(
                label: context.l10n.databases_encoding,
                isLast: true,
                child: AppInlinePicker<String>(
                  value: _selectedEncoding,
                  anchorHeight: 44,
                  backgroundColor: Colors.transparent,
                  options: _encodingOptions
                      .map((e) => AppPickerOption(value: e, label: e))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedEncoding = v),
                  onExpandChanged: (expanded) =>
                      setState(() => _pickerExpanded = expanded),
                ),
              ),
            ],
          ),

          // ── 访问权限 ──
          const SizedBox(height: 24),
          _SectionHeader(title: context.l10n.databases_accessPermissions),
          _GroupedBox(
            children: [
              _FormTile(
                label: context.l10n.databases_superUser,
                isLast: true,
                child: Container(
                  height: 44,
                  alignment: Alignment.centerRight,
                  child: AppToggleSwitch(
                    value: _superUser,
                    onChanged: (v) => setState(() => _superUser = v),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              context.l10n.databases_superUserHint,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),

          // ── 描述 ──
          const SizedBox(height: 24),
          _SectionHeader(title: context.l10n.databases_descriptionOptional),
          _GroupedBox(
            children: [
              _FormTile(
                label: context.l10n.databases_description,
                isLast: true,
                child: SizedBox(
                  height: 44,
                  child: CupertinoTextField(
                    controller: _descriptionController,
                    placeholder: context.l10n.databases_optionalRemark,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.label(context),
                    ),
                    decoration: const BoxDecoration(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Apple 风格组件 ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryLabel(context),
        ),
      ),
    );
  }
}

class _GroupedBox extends StatelessWidget {
  const _GroupedBox({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.16),
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({
    required this.label,
    required this.child,
    this.isLast = false,
  });

  final String label;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 44,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.label(context),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 0.5,
              color: AppColors.separator(context).withValues(alpha: 0.24),
            ),
          ),
      ],
    );
  }
}
