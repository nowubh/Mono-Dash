import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories_impl/setting_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_confirm_sheet.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../widgets/edit_setting_value_sheet.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: const _SecurityContent(),
    );
  }
}

class _SecurityContent extends ConsumerStatefulWidget {
  const _SecurityContent();

  @override
  ConsumerState<_SecurityContent> createState() => _SecurityContentState();
}

class _SecurityContentState extends ConsumerState<_SecurityContent> {
  Map<String, dynamic> _coreSettings = {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final repo = await ref.read(settingRepositoryProvider.future);
      final settings = await repo.searchCoreSettings();
      if (!mounted) return;
      setState(() {
        _coreSettings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _get(String key) {
    final lowerKey = key.substring(0, 1).toLowerCase() + key.substring(1);
    return (_coreSettings[lowerKey] as String?) ?? '';
  }

  bool _getBool(String key) => _get(key) == 'Enable';

  Future<void> _update(String key, String value) async {
    try {
      final repo = await ref.read(settingRepositoryProvider.future);
      await repo.updateCoreSetting(key: key, value: value);
      if (!mounted) return;
      final lowerKey = key.substring(0, 1).toLowerCase() + key.substring(1);
      setState(() => _coreSettings[lowerKey] = value);
      showAppSuccessToast(context.l10n.panelSettings_settingUpdated);
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(
        context.l10n.panelSettings_updateFailed,
        description: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FrostedScaffold(
      title: l10n.panelSettings_security,
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _error != null
          ? AppErrorState(
              title: l10n.common_loadingFailed,
              error: _error!,
              onRetry: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadSettings();
              },
            )
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: FrostedScaffold.contentTopPadding(context) + 8,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                  sliver: SliverList.list(
                    children: [
                      // ── 访问控制 ──
                      AppSectionHeader(
                        title: l10n.panelSettings_accessControl,
                        icon: TablerIcons.shield_lock,
                      ),
                      AppActionGroup(
                        children: [
                          AppActionRow(
                            icon: TablerIcons.plug,
                            iconColor: CupertinoColors.systemBlue,
                            title: l10n.panelSettings_panelPort,
                            subtitle: Text(_get('serverPort')),
                            onTap: () async {
                              final result = await showEditValueSheet(
                                context,
                                title: l10n.panelSettings_panelPort,
                                initialValue: _get('serverPort'),
                                placeholder: l10n.panelSettings_portPlaceholder,
                                keyboardType: TextInputType.number,
                              );
                              if (result != null) {
                                final port = int.tryParse(result);
                                if (port != null) {
                                  await _update('ServerPort', result);
                                }
                              }
                            },
                          ),
                          AppActionRow(
                            icon: TablerIcons.network,
                            iconColor: CupertinoColors.systemTeal,
                            title: l10n.panelSettings_bindAddress,
                            subtitle: Text(
                              _get('BindAddress').isEmpty
                                  ? '0.0.0.0'
                                  : _get('BindAddress'),
                            ),
                            onTap: () async {
                              final result = await showEditValueSheet(
                                context,
                                title: l10n.panelSettings_bindAddress,
                                initialValue: _get('BindAddress'),
                                placeholder: '0.0.0.0',
                              );
                              if (result != null) {
                                await _update('BindAddress', result);
                              }
                            },
                          ),
                          AppActionRow(
                            icon: TablerIcons.door,
                            iconColor: CupertinoColors.systemOrange,
                            title: l10n.panelSettings_securityEntrance,
                            subtitle: Text(
                              _get('SecurityEntrance').isEmpty
                                  ? l10n.panelSettings_notSet
                                  : _get('SecurityEntrance'),
                            ),
                            onTap: () async {
                              final result = await showEditValueSheet(
                                context,
                                title: l10n.panelSettings_securityEntrance,
                                initialValue: _get('SecurityEntrance'),
                                placeholder: l10n
                                    .panelSettings_securityEntrancePlaceholder,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9]'),
                                  ),
                                ],
                                validator: (value) {
                                  if (value.length < 5 || value.length > 116) {
                                    return l10n
                                        .panelSettings_securityEntranceLengthError;
                                  }
                                  return null;
                                },
                              );
                              if (result != null) {
                                await _update('SecurityEntrance', result);
                              }
                            },
                          ),
                          AppActionRow(
                            icon: TablerIcons.shield_check,
                            iconColor: CupertinoColors.systemGreen,
                            title: l10n.panelSettings_ipWhitelist,
                            subtitle: Text(
                              _get('allowIPs').isEmpty
                                  ? l10n.panelSettings_unrestricted
                                  : _get('allowIPs'),
                            ),
                            onTap: () async {
                              final result = await showEditValueSheet(
                                context,
                                title: l10n.panelSettings_ipWhitelist,
                                initialValue: _get('allowIPs'),
                                placeholder:
                                    l10n.panelSettings_ipWhitelistPlaceholder,
                                maxLines: 5,
                              );
                              if (result != null) {
                                await _update('AllowIPs', result);
                              }
                            },
                          ),
                          AppActionRow(
                            icon: TablerIcons.world,
                            iconColor: CupertinoColors.systemIndigo,
                            title: l10n.panelSettings_bindDomain,
                            subtitle: Text(
                              _get('bindDomain').isEmpty
                                  ? l10n.panelSettings_notSet
                                  : _get('bindDomain'),
                            ),
                            onTap: () async {
                              final result = await showEditValueSheet(
                                context,
                                title: l10n.panelSettings_bindDomain,
                                initialValue: _get('bindDomain'),
                                placeholder: 'example.com',
                              );
                              if (result != null) {
                                await _update('BindDomain', result);
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── SSL ──
                      const AppSectionHeader(
                        title: 'HTTPS',
                        icon: TablerIcons.lock,
                      ),
                      AppActionGroup(
                        children: [
                          AppActionRow(
                            icon: TablerIcons.lock,
                            iconColor: CupertinoColors.systemGreen,
                            title: l10n.panelSettings_panelSsl,
                            subtitle: Text(
                              _get('ssl') == 'Enable'
                                  ? l10n.panelSettings_enabled
                                  : l10n.panelSettings_disabled,
                            ),
                            trailing: AppToggleSwitch(
                              value: _get('ssl') == 'Enable',
                              onChanged: (v) async {
                                if (!v) {
                                  final confirmed = await showActionSheet<bool>(
                                    context: context,
                                    useRootNavigator: true,
                                    builder: (ctx) => AppConfirmSheet(
                                      title: l10n.panelSettings_closeSsl,
                                      content:
                                          l10n.panelSettings_closeSslContent,
                                      icon: TablerIcons.lock_open,
                                      iconColor: CupertinoColors.systemRed,
                                    ),
                                  );
                                  if (confirmed == true && mounted) {
                                    try {
                                      final repo = await ref.read(
                                        settingRepositoryProvider.future,
                                      );
                                      await repo.updateSSL({
                                        'ssl': 'Disable',
                                        'sslType': _get('sslType'),
                                      });
                                      if (mounted) {
                                        setState(
                                          () =>
                                              _coreSettings['ssl'] = 'Disable',
                                        );
                                        showAppSuccessToast(
                                          l10n.panelSettings_sslDisabled,
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        showAppErrorToast(
                                          l10n.panelSettings_operationFailed,
                                          description: e.toString(),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── 安全策略 ──
                      AppSectionHeader(
                        title: l10n.panelSettings_securityPolicy,
                        icon: TablerIcons.shield,
                      ),
                      AppActionGroup(
                        children: [
                          AppActionRow(
                            icon: TablerIcons.clock,
                            iconColor: CupertinoColors.systemRed,
                            title: l10n.panelSettings_passwordExpiration,
                            subtitle: Text(
                              _get('expirationDays').isEmpty ||
                                      _get('expirationDays') == '0'
                                  ? l10n.panelSettings_neverExpires
                                  : l10n.panelSettings_daysValue(
                                      _get('expirationDays'),
                                    ),
                            ),
                            onTap: () async {
                              final result = await showEditValueSheet(
                                context,
                                title:
                                    l10n.panelSettings_passwordExpirationDays,
                                initialValue: _get('expirationDays'),
                                placeholder: l10n
                                    .panelSettings_passwordExpirationPlaceholder,
                                keyboardType: TextInputType.number,
                              );
                              if (result != null) {
                                await _update('ExpirationDays', result);
                              }
                            },
                          ),
                          AppActionRow(
                            icon: TablerIcons.password,
                            iconColor: CupertinoColors.systemOrange,
                            title: l10n.panelSettings_passwordComplexity,
                            subtitle: Text(
                              l10n.panelSettings_passwordComplexitySubtitle,
                            ),
                            trailing: AppToggleSwitch(
                              value: _getBool('complexityVerification'),
                              onChanged: (v) => _update(
                                'ComplexityVerification',
                                v ? 'Enable' : 'Disable',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── MFA ──
                      AppSectionHeader(
                        title: l10n.panelSettings_mfa,
                        icon: TablerIcons.device_mobile,
                      ),
                      AppActionGroup(
                        children: [
                          AppActionRow(
                            icon: TablerIcons.qrcode,
                            iconColor: CupertinoColors.systemBlue,
                            title: l10n.panelSettings_mfaTwoFactor,
                            subtitle: Text(
                              _get('mfaStatus') == 'Enable'
                                  ? l10n.panelSettings_enabled
                                  : l10n.panelSettings_disabled,
                            ),
                            trailing: AppToggleSwitch(
                              value: _get('mfaStatus') == 'Enable',
                              onChanged: (v) async {
                                if (!v) {
                                  final confirmed = await showActionSheet<bool>(
                                    context: context,
                                    useRootNavigator: true,
                                    builder: (ctx) => AppConfirmSheet(
                                      title: l10n.panelSettings_closeMfa,
                                      content:
                                          l10n.panelSettings_closeMfaContent,
                                      icon: TablerIcons.qrcode,
                                      iconColor: CupertinoColors.systemOrange,
                                    ),
                                  );
                                  if (confirmed == true && mounted) {
                                    await _update('MFAStatus', 'Disable');
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── 未认证响应 ──
                      AppSectionHeader(
                        title: l10n.panelSettings_other,
                        icon: TablerIcons.settings,
                      ),
                      AppActionGroup(
                        children: [
                          AppActionRow(
                            icon: TablerIcons.arrow_back,
                            iconColor: CupertinoColors.systemGrey,
                            title: l10n.panelSettings_noAuthResponseCode,
                            subtitle: Text(
                              _get('noAuthSetting').isEmpty
                                  ? '200'
                                  : _get('noAuthSetting'),
                            ),
                            onTap: () async {
                              final result = await _showResponseCodePicker(
                                context,
                                current: _get('noAuthSetting').isEmpty
                                    ? '200'
                                    : _get('noAuthSetting'),
                              );
                              if (result != null) {
                                await _update('NoAuthSetting', result);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<String?> _showResponseCodePicker(
    BuildContext context, {
    required String current,
  }) {
    const codes = [
      '200',
      '400',
      '401',
      '403',
      '404',
      '408',
      '416',
      '444',
      '500',
    ];
    return showActionSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => ActionSheetScaffold(
        isAdaptive: true,
        showHandle: false,
        isFloating: true,
        title: context.l10n.panelSettings_noAuthResponseCode,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in codes)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.label(context),
                          ),
                        ),
                      ),
                      if (code == current)
                        Icon(
                          TablerIcons.check,
                          size: 20,
                          color: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
