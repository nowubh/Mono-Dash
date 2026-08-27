import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../../common/components/sub_menu_page.dart';
import '../providers/app_lock_provider.dart';
import '../widgets/app_passcode_pad.dart';

enum _PinSheetStep { create, confirm, biometric }

enum _ChangePinStep { current, next, confirm }

class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  ConsumerState<AppLockSettingsPage> createState() =>
      _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(appLockControllerProvider);

    return FrostedScaffold(
      title: l10n.settings_appLock_pageTitle,
      body: settingsAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.only(
            top: FrostedScaffold.contentTopPadding(context),
          ),
          child: const Center(child: CupertinoActivityIndicator()),
        ),
        error: (error, _) => Padding(
          padding: EdgeInsets.only(
            top: FrostedScaffold.contentTopPadding(context),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryLabel(context)),
              ),
            ),
          ),
        ),
        data: (settings) => ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            FrostedScaffold.contentTopPadding(context) + 18,
            16,
            132,
          ),
          children: [
            _buildSecurityCard(settings),
            const SizedBox(height: 12),
            _buildMischiefCard(settings),
            const SizedBox(height: 14),
            Text(
              l10n.settings_appLock_widgetNote,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMischiefCard(AppLockSettings settings) {
    final l10n = context.l10n;
    return SubMenuCard(
      title: l10n.settings_appLock_mischiefSectionTitle,
      children: [
        _SettingsLine(
          icon: TablerIcons.mood_wink,
          iconColor: CupertinoColors.systemGreen,
          title: l10n.settings_appLock_misleadingPinFeedbackTitle,
          subtitle: l10n.settings_appLock_misleadingPinFeedbackSubtitle,
          trailing: AppToggleSwitch(
            value: settings.misleadingPinFeedbackEnabled,
            onChanged: (value) => ref
                .read(appLockControllerProvider.notifier)
                .setMisleadingPinFeedbackEnabled(value),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard(AppLockSettings settings) {
    final l10n = context.l10n;
    final biometric = _biometricPresentation(context, settings);

    return Column(
      children: [
        SubMenuCard(
          title: l10n.settings_security_title,
          children: [
            _SettingsLine(
              icon: TablerIcons.lock,
              iconColor: CupertinoColors.activeBlue,
              title: l10n.settings_appLock_passwordSwitchTitle,
              subtitle: settings.enabled
                  ? l10n.settings_appLock_subtitleOn
                  : l10n.settings_appLock_subtitleOff,
              trailing: AppToggleSwitch(
                value: settings.enabled,
                onChanged: (value) =>
                    value ? _showSetPinSheet(settings) : _disableAppLock(),
              ),
            ),
            _SettingsLine(
              icon: TablerIcons.key,
              iconColor: CupertinoColors.systemOrange,
              title: l10n.settings_appLock_changePassword,
              subtitle: l10n.settings_appLock_changePasswordSubtitle,
              isEnabled: settings.enabled,
              onTap: settings.enabled
                  ? () => _showChangePinSheet(settings)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SubMenuCard(
          title: l10n.settings_appLock_biometricSectionTitle,
          children: [
            _SettingsLine(
              icon: biometric.icon,
              iconColor: CupertinoColors.systemPurple,
              title: biometric.title,
              subtitle: biometric.subtitle,
              isEnabled: settings.enabled && settings.biometricAvailable,
              trailing: AppToggleSwitch(
                value: settings.enabled && settings.biometricEnabled,
                onChanged: settings.enabled && settings.biometricAvailable
                    ? (value) => ref
                          .read(appLockControllerProvider.notifier)
                          .setBiometricEnabled(value)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showSetPinSheet(AppLockSettings settings) async {
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SetPinSheet(settings: settings),
    );
  }

  Future<void> _showChangePinSheet(AppLockSettings settings) async {
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangePinSheet(settings: settings),
    );
  }

  Future<void> _disableAppLock() async {
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DisableLockSheet(),
    );
  }
}

class _SetPinSheet extends ConsumerStatefulWidget {
  const _SetPinSheet({required this.settings});

  final AppLockSettings settings;

  @override
  ConsumerState<_SetPinSheet> createState() => _SetPinSheetState();
}

class _SetPinSheetState extends ConsumerState<_SetPinSheet> {
  _PinSheetStep _step = _PinSheetStep.create;
  String _pin = '';
  String _confirmPin = '';
  bool _enableBiometric = true;
  bool _isSaving = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final biometric = _biometricPresentation(context, widget.settings);

    return _PasscodeSheetScaffold(
      onCancel: _isSaving ? null : () => Navigator.of(context).pop(),
      child: switch (_step) {
        _PinSheetStep.create => _buildPasscodeStep(
          value: _pin,
          title: l10n.settings_appLock_createPinTitle,
          subtitle: l10n.settings_appLock_createPinSubtitle,
          onChanged: (value) => setState(() {
            _pin = value;
            _errorText = null;
          }),
          onPrimary: _continueToConfirm,
          primaryLabel: l10n.common_confirm,
        ),
        _PinSheetStep.confirm => _buildPasscodeStep(
          value: _confirmPin,
          title: l10n.settings_appLock_confirmPinTitle,
          subtitle: l10n.settings_appLock_confirmPinSubtitle,
          onChanged: (value) => setState(() {
            _confirmPin = value;
            _errorText = null;
          }),
          onPrimary: _continueAfterConfirm,
          primaryLabel: l10n.common_confirm,
          onSecondary: () => setState(() {
            _step = _PinSheetStep.create;
            _confirmPin = '';
            _errorText = null;
          }),
        ),
        _PinSheetStep.biometric => _buildBiometricStep(
          biometric: biometric,
          l10n: l10n,
        ),
      },
    );
  }

  Widget _buildPasscodeStep({
    required String value,
    required String title,
    required String subtitle,
    required ValueChanged<String> onChanged,
    required VoidCallback onPrimary,
    required String primaryLabel,
    VoidCallback? onSecondary,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPasscodePad(
          value: value,
          label: title,
          subtitle: subtitle,
          enabled: !_isSaving,
          maxLength: 6,
          misleadingFeedbackEnabled:
              widget.settings.misleadingPinFeedbackEnabled,
          onChanged: onChanged,
        ),
        _ErrorText(message: _errorText),
        const SizedBox(height: 22),
        _PrimarySheetButton(
          isLoading: _isSaving,
          label: primaryLabel,
          onPressed: _isSaving ? null : onPrimary,
        ),
        if (onSecondary != null) ...[
          const SizedBox(height: 8),
          CupertinoButton(
            onPressed: onSecondary,
            child: Text(l10n.common_cancel),
          ),
        ],
      ],
    );
  }

  Widget _buildBiometricStep({
    required _BiometricPresentation biometric,
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Icon(
          biometric.icon,
          size: 54,
          color: CupertinoColors.activeBlue.resolveFrom(context),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.settings_appLock_enableBiometricSheetTitle(biometric.title),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.label(context),
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settings_appLock_enableBiometricSheetSubtitle(biometric.title),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppColors.secondaryLabel(context),
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 28),
        _InlineSwitch(
          title: biometric.title,
          subtitle: l10n.settings_appLock_biometricSubtitle,
          value: _enableBiometric,
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _enableBiometric = value),
        ),
        const SizedBox(height: 22),
        _PrimarySheetButton(
          isLoading: _isSaving,
          label: l10n.common_save,
          onPressed: _isSaving ? null : _savePin,
        ),
      ],
    );
  }

  void _continueToConfirm() {
    final error = _validatePin(context, _pin);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() {
      _step = _PinSheetStep.confirm;
      _confirmPin = '';
      _errorText = null;
    });
  }

  void _continueAfterConfirm() {
    final l10n = context.l10n;
    final error = _validatePin(context, _confirmPin);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    if (_pin != _confirmPin) {
      HapticFeedback.mediumImpact();
      setState(() {
        _confirmPin = '';
        _errorText = l10n.settings_appLock_passwordMismatch;
      });
      return;
    }
    if (widget.settings.biometricAvailable) {
      setState(() {
        _step = _PinSheetStep.biometric;
        _errorText = null;
      });
    } else {
      _savePin();
    }
  }

  Future<void> _savePin() async {
    final l10n = context.l10n;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(appLockControllerProvider.notifier)
          .enablePassword(
            password: _pin,
            enableBiometric:
                widget.settings.biometricAvailable && _enableBiometric,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSuccessToast(l10n.settings_appLock_enabledToast);
    } on AppLockPasswordException catch (error) {
      HapticFeedback.mediumImpact();
      setState(() => _errorText = _messageFor(context, error.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ChangePinSheet extends ConsumerStatefulWidget {
  const _ChangePinSheet({required this.settings});

  final AppLockSettings settings;

  @override
  ConsumerState<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends ConsumerState<_ChangePinSheet> {
  _ChangePinStep _step = _ChangePinStep.current;
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  bool _isSaving = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PasscodeSheetScaffold(
      onCancel: _isSaving ? null : () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPasscodePad(
            value: switch (_step) {
              _ChangePinStep.current => _currentPin,
              _ChangePinStep.next => _newPin,
              _ChangePinStep.confirm => _confirmPin,
            },
            label: switch (_step) {
              _ChangePinStep.current => l10n.settings_appLock_currentPinTitle,
              _ChangePinStep.next => l10n.settings_appLock_newPinTitle,
              _ChangePinStep.confirm => l10n.settings_appLock_confirmPinTitle,
            },
            subtitle: switch (_step) {
              _ChangePinStep.current =>
                l10n.settings_appLock_currentPinSubtitle,
              _ChangePinStep.next => l10n.settings_appLock_newPinSubtitle,
              _ChangePinStep.confirm =>
                l10n.settings_appLock_confirmPinSubtitle,
            },
            enabled: !_isSaving,
            maxLength: 6,
            misleadingFeedbackEnabled:
                widget.settings.misleadingPinFeedbackEnabled,
            onChanged: (value) => setState(() {
              switch (_step) {
                case _ChangePinStep.current:
                  _currentPin = value;
                case _ChangePinStep.next:
                  _newPin = value;
                case _ChangePinStep.confirm:
                  _confirmPin = value;
              }
              _errorText = null;
            }),
          ),
          _ErrorText(message: _errorText),
          const SizedBox(height: 22),
          _PrimarySheetButton(
            isLoading: _isSaving,
            label: _step == _ChangePinStep.confirm
                ? l10n.common_save
                : l10n.common_confirm,
            onPressed: _isSaving ? null : _continue,
          ),
          if (_step != _ChangePinStep.current) ...[
            const SizedBox(height: 8),
            CupertinoButton(
              onPressed: _isSaving ? null : _goBack,
              child: Text(l10n.common_cancel),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _continue() async {
    final l10n = context.l10n;
    switch (_step) {
      case _ChangePinStep.current:
        final error = _validatePin(context, _currentPin);
        if (error != null) {
          setState(() => _errorText = error);
          return;
        }
        final ok = await ref
            .read(appLockControllerProvider.notifier)
            .verifyPassword(_currentPin);
        if (!mounted) return;
        if (!ok) {
          HapticFeedback.mediumImpact();
          setState(() {
            _currentPin = '';
            _errorText = l10n.settings_appLock_wrongPassword;
          });
          return;
        }
        setState(() {
          _step = _ChangePinStep.next;
          _newPin = '';
          _errorText = null;
        });
      case _ChangePinStep.next:
        final error = _validatePin(context, _newPin);
        if (error != null) {
          setState(() => _errorText = error);
          return;
        }
        setState(() {
          _step = _ChangePinStep.confirm;
          _confirmPin = '';
          _errorText = null;
        });
      case _ChangePinStep.confirm:
        await _saveNewPin();
    }
  }

  Future<void> _saveNewPin() async {
    final l10n = context.l10n;
    final error = _validatePin(context, _confirmPin);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    if (_newPin != _confirmPin) {
      HapticFeedback.mediumImpact();
      setState(() {
        _confirmPin = '';
        _errorText = l10n.settings_appLock_passwordMismatch;
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(appLockControllerProvider.notifier)
          .changePassword(currentPassword: _currentPin, newPassword: _newPin);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSuccessToast(l10n.settings_appLock_passwordUpdatedToast);
    } on AppLockPasswordException catch (error) {
      HapticFeedback.mediumImpact();
      setState(() => _errorText = _messageFor(context, error.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _goBack() {
    setState(() {
      if (_step == _ChangePinStep.next) {
        _step = _ChangePinStep.current;
        _currentPin = '';
        _newPin = '';
      } else {
        _step = _ChangePinStep.next;
        _confirmPin = '';
      }
      _errorText = null;
    });
  }
}

class _DisableLockSheet extends ConsumerStatefulWidget {
  const _DisableLockSheet();

  @override
  ConsumerState<_DisableLockSheet> createState() => _DisableLockSheetState();
}

class _DisableLockSheetState extends ConsumerState<_DisableLockSheet> {
  String _pin = '';
  bool _isSaving = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(appLockControllerProvider).valueOrNull;
    return _PasscodeSheetScaffold(
      onCancel: _isSaving ? null : () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPasscodePad(
            value: _pin,
            label: l10n.settings_appLock_disableVerifyTitle,
            subtitle: l10n.settings_appLock_disableVerifySubtitle,
            enabled: !_isSaving,
            maxLength: 6,
            misleadingFeedbackEnabled:
                settings?.misleadingPinFeedbackEnabled == true,
            onChanged: (value) => setState(() {
              _pin = value;
              _errorText = null;
            }),
          ),
          _ErrorText(message: _errorText),
          const SizedBox(height: 22),
          _PrimarySheetButton(
            isLoading: _isSaving,
            label: l10n.settings_appLock_disableAction,
            isDestructive: true,
            onPressed: _isSaving ? null : _verifyAndDisable,
          ),
        ],
      ),
    );
  }

  Future<void> _verifyAndDisable() async {
    final l10n = context.l10n;
    final error = _validatePin(context, _pin);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    setState(() => _isSaving = true);
    final ok = await ref
        .read(appLockControllerProvider.notifier)
        .verifyPassword(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.mediumImpact();
      setState(() {
        _pin = '';
        _isSaving = false;
        _errorText = l10n.settings_appLock_wrongPassword;
      });
      return;
    }

    try {
      await ref.read(appLockControllerProvider.notifier).disable();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSuccessToast(l10n.settings_appLock_disabledToast);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _PasscodeSheetScaffold extends StatelessWidget {
  const _PasscodeSheetScaffold({required this.child, required this.onCancel});

  final Widget child;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SheetHeader(onCancel: onCancel),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onCancel});

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CupertinoButton(
              minimumSize: const Size(44, 36),
              padding: EdgeInsets.zero,
              onPressed: onCancel,
              child: Text(
                context.l10n.common_cancel,
                style: TextStyle(
                  color: AppColors.secondaryLabel(context),
                  fontSize: 16,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimarySheetButton extends StatelessWidget {
  const _PrimarySheetButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      color:
          (isDestructive
                  ? CupertinoColors.systemRed
                  : CupertinoColors.activeBlue)
              .resolveFrom(context),
      disabledColor: CupertinoColors.systemGrey4.resolveFrom(context),
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(vertical: 14),
      onPressed: onPressed,
      child: isLoading
          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
          : Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
    );
  }
}

class _InlineSwitch extends StatelessWidget {
  const _InlineSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label(context),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          AppToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        child: message == null
            ? const SizedBox.shrink()
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemRed.resolveFrom(context),
                    letterSpacing: 0,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SettingsLine extends StatelessWidget {
  const _SettingsLine({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.isEnabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(iconColor, context);
    final contentOpacity = isEnabled ? 1.0 : 0.42;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isEnabled ? onTap : null,
      child: Opacity(
        opacity: contentOpacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label(context),
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(context),
                        letterSpacing: 0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onTap != null)
                Icon(
                  TablerIcons.chevron_right,
                  size: 15,
                  color: AppColors.tertiaryLabel(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

_BiometricPresentation _biometricPresentation(
  BuildContext context,
  AppLockSettings settings,
) {
  final l10n = context.l10n;
  final values = settings.availableBiometrics;
  if (values.contains(BiometricType.face)) {
    return _BiometricPresentation(
      title: l10n.settings_appLock_faceIdTitle,
      subtitle: settings.enabled
          ? l10n.settings_appLock_biometricSubtitle
          : l10n.settings_appLock_biometricRequiresPassword,
      icon: TablerIcons.face_id,
    );
  }
  if (values.contains(BiometricType.fingerprint)) {
    return _BiometricPresentation(
      title: l10n.settings_appLock_fingerprintTitle,
      subtitle: settings.enabled
          ? l10n.settings_appLock_biometricSubtitle
          : l10n.settings_appLock_biometricRequiresPassword,
      icon: TablerIcons.fingerprint,
    );
  }
  if (values.contains(BiometricType.iris)) {
    return _BiometricPresentation(
      title: l10n.settings_appLock_biometricTitle,
      subtitle: settings.enabled
          ? l10n.settings_appLock_biometricSubtitle
          : l10n.settings_appLock_biometricRequiresPassword,
      icon: TablerIcons.eye,
    );
  }
  return _BiometricPresentation(
    title: l10n.settings_appLock_biometricTitle,
    subtitle: settings.biometricAvailable
        ? l10n.settings_appLock_biometricSubtitle
        : l10n.settings_appLock_biometricUnavailable,
    icon: TablerIcons.fingerprint,
  );
}

class _BiometricPresentation {
  const _BiometricPresentation({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

String? _validatePin(BuildContext context, String pin) {
  final l10n = context.l10n;
  if (pin.length != 6) {
    return l10n.settings_appLock_passwordTooShort;
  }
  if (!RegExp(r'^\d+$').hasMatch(pin)) {
    return l10n.settings_appLock_passwordDigitsOnly;
  }
  return null;
}

String _messageFor(BuildContext context, AppLockPasswordError error) {
  final l10n = context.l10n;
  return switch (error) {
    AppLockPasswordError.tooShort => l10n.settings_appLock_passwordTooShort,
    AppLockPasswordError.notNumeric => l10n.settings_appLock_passwordDigitsOnly,
    AppLockPasswordError.wrongPassword => l10n.settings_appLock_wrongPassword,
  };
}
