import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../purchases/providers/purchase_provider.dart';
import '../../purchases/widgets/testflight_application_sheet.dart';
import '../providers/servers_provider.dart';

const _privacyPolicyUrl =
    'https://github.com/bin64/Mono-Dash/blob/main/PRIVACY.md';
const _termsOfUseUrl = 'https://github.com/bin64/Mono-Dash/blob/main/TERMS.md';

class PremiumPurchasePage extends ConsumerStatefulWidget {
  final bool isFromLimitPrompt;

  const PremiumPurchasePage({super.key, this.isFromLimitPrompt = false});

  @override
  ConsumerState<PremiumPurchasePage> createState() =>
      _PremiumPurchasePageState();
}

class _PremiumPurchasePageState extends ConsumerState<PremiumPurchasePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final purchaseState = ref.read(purchaseControllerProvider).valueOrNull;
      if (purchaseState?.isUnlocked ?? false) return;
      unawaited(ref.read(purchaseControllerProvider.notifier).loadOfferings());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final purchaseAsync = ref.watch(purchaseControllerProvider);
    final serverCount =
        ref.watch(serversNotifierProvider).valueOrNull?.length ?? 0;
    final purchaseState = purchaseAsync.valueOrNull;
    final isUnlocked = purchaseState?.isUnlocked ?? false;
    final purchaseError = _purchaseError(purchaseAsync, purchaseState);

    return FrostedScaffold(
      title: 'Mono Dash',
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: FrostedScaffold.contentTopPadding(context)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 32),
                _buildHeroSection(context, l10n),
                const SizedBox(height: 48),
                _buildBenefitsGrid(
                  context,
                  ref,
                  l10n,
                  serverCount,
                  isUnlocked,
                  widget.isFromLimitPrompt,
                ),
                const SizedBox(height: 48),
                if (!isUnlocked) ...[
                  if (purchaseError != null) ...[
                    _buildPurchaseErrorState(context, ref, purchaseError, l10n),
                    const SizedBox(height: 18),
                  ],
                  _buildPurchaseButton(context, ref, purchaseAsync, l10n),
                  const SizedBox(height: 16),
                  _buildRestoreButton(context, ref, purchaseAsync, l10n),
                ] else
                  _buildUnlockedStatus(
                    context,
                    purchaseState,
                    serverCount,
                    l10n,
                  ),
                const SizedBox(height: 64),
                _buildLegalSection(context, l10n),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        const Icon(
          CupertinoIcons.infinite,
          size: 72,
          color: CupertinoColors.activeBlue,
        ),
        const SizedBox(height: 16),
        Text(
          'Mono Dash Unlimited',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.label(context),
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.premium_heroSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsGrid(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int serverCount,
    bool isUnlocked,
    bool showHint,
  ) {
    return Column(
      children: [
        _BenefitItem(
          icon: CupertinoIcons.layers_fill,
          iconColor: CupertinoColors.systemOrange,
          title: l10n.premium_unlimitedTitle,
          description: l10n.premium_unlimitedDescription,
          hint: (showHint && !isUnlocked)
              ? l10n.premium_currentServerCount(serverCount)
              : null,
          hintColor: CupertinoColors.systemOrange.resolveFrom(context),
        ),
        const SizedBox(height: 24),
        _BenefitItem(
          icon: CupertinoIcons.app_badge_fill,
          iconColor: CupertinoColors.systemBlue,
          title: l10n.premium_moreFeaturesTitle,
          description: l10n.premium_desktopWidgetsFeature,
          hint: l10n.premium_desktopWidgetsFreeHint,
          hintColor: CupertinoColors.systemBlue.resolveFrom(context),
          suffix: l10n.premium_moreFeaturesDescription,
        ),
        const SizedBox(height: 24),
        _BenefitItem(
          icon: CupertinoIcons.airplane,
          iconColor: CupertinoColors.systemTeal,
          title: l10n.premium_testflightTitle,
          description: l10n.premium_testflightDescription,
          hint: isUnlocked ? l10n.premium_testflightApplyHint : null,
          hintColor: CupertinoColors.activeBlue.resolveFrom(context),
          onTap: isUnlocked
              ? () => showTestFlightApplicationSheet(context, ref)
              : null,
        ),
        const SizedBox(height: 24),
        _BenefitItem(
          icon: CupertinoIcons.heart_fill,
          iconColor: CupertinoColors.systemPink,
          title: l10n.premium_supportTitle,
          description: l10n.premium_supportDescription,
        ),
      ],
    );
  }

  Widget _buildPurchaseButton(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PurchaseState> purchaseAsync,
    AppLocalizations l10n,
  ) {
    final purchaseState = purchaseAsync.valueOrNull;
    final isLoading = purchaseAsync.isLoading;
    final canPurchase =
        !isLoading &&
        (purchaseState?.isConfigured ?? false) &&
        (purchaseState?.hasPackage ?? false);
    final price = purchaseState?.priceText ?? l10n.premium_loading;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            color: CupertinoColors.activeBlue,
            borderRadius: BorderRadius.circular(16),
            onPressed: canPurchase
                ? () => _purchaseUnlimitedServers(ref)
                : null,
            child: isLoading
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : Text(
                    l10n.premium_unlockNow(price),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.premium_oneTime,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.tertiaryLabel(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRestoreButton(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PurchaseState> purchaseAsync,
    AppLocalizations l10n,
  ) {
    final canRestore =
        !purchaseAsync.isLoading && RevenueCatConfig.apiKey != null;
    return CupertinoButton(
      onPressed: canRestore ? () => _restorePurchases(ref) : null,
      child: Text(
        l10n.premium_restore,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryLabel(context),
        ),
      ),
    );
  }

  Object? _purchaseError(
    AsyncValue<PurchaseState> purchaseAsync,
    PurchaseState? purchaseState,
  ) {
    if (purchaseAsync.hasError) return purchaseAsync.error;
    if (purchaseAsync.isLoading) return null;
    return purchaseState?.message;
  }

  Widget _buildPurchaseErrorState(
    BuildContext context,
    WidgetRef ref,
    Object error,
    AppLocalizations l10n,
  ) {
    return AppErrorState(
      title: l10n.common_loadingFailed,
      error: error,
      padding: EdgeInsets.zero,
      onRetry: () => _retryPurchaseState(ref),
    );
  }

  Widget _buildUnlockedStatus(
    BuildContext context,
    PurchaseState? purchaseState,
    int serverCount,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.checkmark_seal_fill,
            color: CupertinoColors.systemGreen,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.premium_unlockedTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
                Text(
                  l10n.premium_unlockedDescription(serverCount),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalLink(
              label: l10n.premium_terms,
              onTap: () => _openLegalLink(context, _termsOfUseUrl),
            ),
            Container(
              width: 1,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.separator(context),
            ),
            _LegalLink(
              label: l10n.premium_privacy,
              onTap: () => _openLegalLink(context, _privacyPolicyUrl),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.premium_legalAgreement,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openLegalLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showAppErrorToast(context.l10n.settings_contact_openFailed);
    }
  }

  Future<void> _purchaseUnlimitedServers(WidgetRef ref) async {
    try {
      final result = await ref
          .read(purchaseControllerProvider.notifier)
          .purchaseUnlimitedServers();
      final l10n = ref.read(appLocalizationsProvider);
      if (result.isUnlocked) {
        showAppSuccessToast(l10n.premium_unlockedToast);
      } else {
        showAppWarningToast(l10n.premium_purchaseIncomplete);
      }
    } catch (error) {
      showAppErrorToast(
        ref.read(appLocalizationsProvider).premium_purchaseFailed,
        description: '$error',
      );
    }
  }

  Future<void> _restorePurchases(WidgetRef ref) async {
    try {
      final result = await ref
          .read(purchaseControllerProvider.notifier)
          .restorePurchases();
      final l10n = ref.read(appLocalizationsProvider);
      if (result.isUnlocked) {
        showAppSuccessToast(l10n.premium_restoredToast);
      } else {
        showAppWarningToast(l10n.premium_restoreNotFound);
      }
    } catch (error) {
      showAppErrorToast(
        ref.read(appLocalizationsProvider).premium_restoreFailed,
        description: '$error',
      );
    }
  }

  Future<void> _retryPurchaseState(WidgetRef ref) async {
    try {
      await ref
          .read(purchaseControllerProvider.notifier)
          .loadOfferings(force: true);
    } catch (error) {
      showAppErrorToast(
        ref.read(appLocalizationsProvider).common_loadingFailed,
        description: '$error',
      );
    }
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? hint;
  final Color? hintColor;
  final String? suffix;
  final VoidCallback? onTap;

  const _BenefitItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.hint,
    this.hintColor,
    this.suffix,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 24, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: description),
                    if (hint != null)
                      TextSpan(
                        text: hint,
                        style: TextStyle(
                          color: hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (suffix != null) TextSpan(text: suffix),
                  ],
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryLabel(context),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryLabel(context),
        ),
      ),
    );
  }
}
