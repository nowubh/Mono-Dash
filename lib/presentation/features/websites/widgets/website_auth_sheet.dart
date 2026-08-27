import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../common/components/defer_init.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_empty_state.dart';
import '../providers/website_auth_provider.dart';
import '../../../../data/dto/website/website_auth_dto.dart';
import '../../../../data/dto/website/website_auth_req.dart';

part 'auth/website_auth_sheet_global.part.dart';
part 'auth/website_auth_sheet_path.part.dart';
part 'auth/website_auth_form_sheet.part.dart';

void showWebsiteAuthSheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showActionSheet<void>(
    context: context,
    builder: (context) => _WebsiteAuthSheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteAuthSheet extends StatefulWidget {
  const _WebsiteAuthSheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  State<_WebsiteAuthSheet> createState() => _WebsiteAuthSheetState();
}

class _WebsiteAuthSheetState extends State<_WebsiteAuthSheet> {
  int _selectedTab = 0; // 0: 全局, 1: 路径

  @override
  Widget build(BuildContext context) {
    return DeferInit(
      builder: (context, isReady) {
        if (!isReady) {
          return _buildShell(context, isLoading: true, enableBlur: false);
        }
        return Consumer(
          builder: (context, ref, _) {
            final globalAsync = ref.watch(
              websiteAuthControllerProvider(widget.websiteId),
            );
            final pathAsync = ref.watch(
              websitePathAuthControllerProvider(widget.websiteId),
            );

            final isLoading =
                (globalAsync.isLoading && globalAsync.valueOrNull == null) ||
                (pathAsync.isLoading && pathAsync.valueOrNull == null);

            return _buildShell(
              context,
              isLoading: isLoading,
              globalAsync: globalAsync,
              pathAsync: pathAsync,
              enableBlur: true,
            );
          },
        );
      },
    );
  }

  Widget _buildShell(
    BuildContext context, {
    required bool isLoading,
    AsyncValue<WebsiteAuthDto>? globalAsync,
    AsyncValue<List<WebsitePathAuthItemDto>>? pathAsync,
    required bool enableBlur,
  }) {
    final auth = globalAsync?.valueOrNull;

    return ActionSheetScaffold(
      enableBlur: enableBlur,
      maxHeightFactor: 0.88,
      panelHeader: _Header(
        title: widget.title,
        websiteId: widget.websiteId,
        auth: auth,
        selectedTab: _selectedTab,
        onTabChanged: (index) => setState(() => _selectedTab = index),
      ),
      child: _buildContent(context, isLoading, globalAsync, pathAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isLoading,
    AsyncValue<WebsiteAuthDto>? globalAsync,
    AsyncValue<List<WebsitePathAuthItemDto>>? pathAsync,
  ) {
    if (isLoading) return const _LoadingState();

    if (_selectedTab == 0) {
      return globalAsync?.when(
            data: (auth) =>
                _GlobalAuthTab(websiteId: widget.websiteId, auth: auth),
            loading: () => const _LoadingState(),
            error: (error, _) => _ErrorState(
              error: error,
              onRetry: () => ProviderScope.containerOf(
                context,
              ).invalidate(websiteAuthControllerProvider(widget.websiteId)),
            ),
          ) ??
          const _LoadingState();
    } else {
      return pathAsync?.when(
            data: (items) =>
                _PathAuthTab(websiteId: widget.websiteId, items: items),
            loading: () => const _LoadingState(),
            error: (error, _) => _ErrorState(
              error: error,
              onRetry: () => ProviderScope.containerOf(
                context,
              ).invalidate(websitePathAuthControllerProvider(widget.websiteId)),
            ),
          ) ??
          const _LoadingState();
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.title,
    required this.websiteId,
    required this.auth,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final String title;
  final int websiteId;
  final WebsiteAuthDto? auth;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = auth?.enable ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CupertinoColors.activeBlue
                      .resolveFrom(context)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  TablerIcons.lock,
                  size: 24,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.websites_passwordAccess,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              _AddButton(
                onPressed: () {
                  if (selectedTab == 0) {
                    _openGlobalEditor(context, ref, websiteId, null);
                  } else {
                    _openPathEditor(context, ref, websiteId, null);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.separator(context).withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEnabled ? TablerIcons.shield_check : TablerIcons.shield_off,
                  size: 18,
                  color: isEnabled
                      ? CupertinoColors.systemGreen.resolveFrom(context)
                      : AppColors.secondaryLabel(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.websites_passwordAuthStatus,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
                AppToggleSwitch(
                  value: isEnabled,
                  onChanged: (value) async {
                    final enabledMessage =
                        context.l10n.websites_passwordAccessEnabled;
                    final disabledMessage =
                        context.l10n.websites_passwordAccessDisabled;
                    final failedTitle = context.l10n.websites_operationFailed;
                    try {
                      await ref
                          .read(
                            websiteAuthControllerProvider(websiteId).notifier,
                          )
                          .setEnabled(value);
                      showAppSuccessToast(
                        value ? enabledMessage : disabledMessage,
                      );
                    } catch (e) {
                      showAppErrorToast(failedTitle, description: '$e');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CustomTabBar(selectedTab: selectedTab, onTabChanged: onTabChanged),
        ],
      ),
    );
  }

  Future<void> _openGlobalEditor(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteAuthItemDto? item,
  ) async {
    await showWebsiteAuthFormSheet(
      context,
      websiteId: websiteId,
      scope: 'root',
      initialAccount: item,
    );
    ref.read(websiteAuthControllerProvider(websiteId).notifier).refresh();
  }

  Future<void> _openPathEditor(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsitePathAuthItemDto? item,
  ) async {
    await showWebsiteAuthFormSheet(
      context,
      websiteId: websiteId,
      scope: 'path',
      initialPathAccount: item,
    );
    ref.read(websitePathAuthControllerProvider(websiteId).notifier).refresh();
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: CupertinoColors.activeBlue
              .resolveFrom(context)
              .withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          TablerIcons.plus,
          size: 18,
          color: CupertinoColors.activeBlue.resolveFrom(context),
        ),
      ),
    );
  }
}

class _CustomTabBar extends StatelessWidget {
  const _CustomTabBar({required this.selectedTab, required this.onTabChanged});

  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabItem(
            label: context.l10n.websites_globalAccess,
            selected: selectedTab == 0,
            onTap: () => onTabChanged(0),
          ),
          _TabItem(
            label: context.l10n.websites_pathAccess,
            selected: selectedTab == 1,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.background(context)
                : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppColors.label(context)
                  : AppColors.secondaryLabel(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: CupertinoActivityIndicator(),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: context.l10n.websites_loadAuthConfigFailed,
      error: error,
      onRetry: onRetry,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
    );
  }
}
