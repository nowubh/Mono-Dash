import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_form_components.dart';
import '../providers/purchase_provider.dart';
import '../services/testflight_application_service.dart';

Future<void> showTestFlightApplicationSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showActionSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _TestFlightApplicationSheet(),
  );
}

class _TestFlightApplicationSheet extends ConsumerStatefulWidget {
  const _TestFlightApplicationSheet();

  @override
  ConsumerState<_TestFlightApplicationSheet> createState() =>
      _TestFlightApplicationSheetState();
}

class _TestFlightApplicationSheetState
    extends ConsumerState<_TestFlightApplicationSheet> {
  final _emailController = TextEditingController();
  final _service = TestFlightApplicationService();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      isFloating: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.testflight_title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text(l10n.common_cancel),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.testflight_description,
            style: TextStyle(
              color: AppColors.secondaryLabel(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          AppFormItem(
            label: l10n.testflight_emailLabel,
            icon: CupertinoIcons.mail,
            child: AppFormTextField(
              controller: _emailController,
              placeholder: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 9),
            Text(
              _error!,
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: CupertinoButton.filled(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(14),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : Text(
                      l10n.testflight_submit,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = context.l10n.testflight_invalidEmail);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final customerId = await ref
          .read(purchaseControllerProvider.notifier)
          .revenueCatCustomerIdForTestFlight();
      final result = await _service.apply(
        email: email,
        revenueCatCustomerId: customerId,
      );
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(context.l10n.testflight_resultTitle),
          content: Text(
            result.status == 'invited'
                ? context.l10n.testflight_invited
                : context.l10n.testflight_pending,
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(context.l10n.common_confirm),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on TestFlightApplicationException catch (error) {
      if (mounted) setState(() => _error = _messageFor(error.code));
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.testflight_serviceUnavailable);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFor(String code) => switch (code) {
    'not_eligible' ||
    'customer_not_found' => context.l10n.testflight_notEligible,
    'already_applied' => context.l10n.testflight_alreadyApplied,
    'service_not_configured' => context.l10n.testflight_notConfigured,
    _ => context.l10n.testflight_serviceUnavailable,
  };
}
