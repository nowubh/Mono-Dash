import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/website_redirect_dto.dart';
import '../../../../data/dto/website/website_detail_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_picker.dart';
import '../providers/website_redirect_provider.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/frosted_action_button.dart';
import 'website_modal_sheet.dart';

part 'redirect/website_redirect_sheet_list.part.dart';
part 'redirect/website_redirect_sheet_editor.part.dart';
part 'redirect/website_redirect_sheet_form.part.dart';

void showWebsiteRedirectSheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteRedirectSheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteRedirectSheet extends ConsumerWidget {
  const _WebsiteRedirectSheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WebsiteAsyncModalSheet<List<WebsiteRedirectDto>>(
      provider: websiteRedirectControllerProvider(websiteId),
      errorTitle: context.l10n.websites_loadRedirectRulesFailed,
      headerBuilder: (context, ref, async) => _Header(
        title: title,
        onAdd: () => _openEditor(context, ref, websiteId, null),
      ),
      dataBuilder: (context, items) => _RedirectList(
        websiteId: websiteId,
        items: items,
        onAdd: () => _openEditor(context, ref, websiteId, null),
        onEdit: (item) => _openEditor(context, ref, websiteId, item),
        onDelete: (item) => _deleteItem(context, ref, websiteId, item),
        onToggleStatus: (item) => _toggleStatus(context, ref, websiteId, item),
        onViewSource: (item) => _openSource(context, ref, websiteId, item),
      ),
      onRetry: (ref) =>
          ref.invalidate(websiteRedirectControllerProvider(websiteId)),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteRedirectDto? item,
  ) async {
    await showActionSheet<void>(
      context: context,
      expand: true,
      useRootNavigator: true,
      builder: (context) =>
          _RedirectEditorSheet(websiteId: websiteId, initial: item),
    );
    if (!context.mounted) return;
    await ref
        .read(websiteRedirectControllerProvider(websiteId).notifier)
        .refresh();
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteRedirectDto item,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.websites_deleteRedirect),
        content: Text(context.l10n.websites_deleteRedirectConfirm(item.name)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final req = item.toJson();
      req['operate'] = 'delete';
      await ref
          .read(websiteRedirectControllerProvider(websiteId).notifier)
          .updateRedirect(req);
      if (context.mounted) {
        showAppSuccessToast(context.l10n.websites_deletedName(item.name));
      }
    } on AppNetworkException catch (error) {
      if (context.mounted) {
        showAppErrorToast(
          context.l10n.websites_operationFailed,
          description: error.message,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppErrorToast(
          context.l10n.websites_operationFailed,
          description: '$error',
        );
      }
    }
  }

  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteRedirectDto item,
  ) async {
    final sourceTitle = context.l10n.websites_redirectSourceContent;
    final savedMessage = context.l10n.websites_redirectSourceSaved;
    await showAppCodeEditorSheet(
      context,
      title: sourceTitle,
      subtitle: item.name,
      initialContent: item.content,
      language: 'nginx',
      onSave: (content) async {
        await ref
            .read(websiteRedirectControllerProvider(websiteId).notifier)
            .saveRedirectFile(item.name, content);
        showAppSuccessToast(savedMessage);
        return true;
      },
    );
  }

  Future<void> _toggleStatus(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteRedirectDto item,
  ) async {
    try {
      final req = item.toJson();
      req['enable'] = !item.enable;
      req['operate'] = !item.enable ? 'enable' : 'disable';
      await ref
          .read(websiteRedirectControllerProvider(websiteId).notifier)
          .updateRedirect(req);
      if (context.mounted) {
        showAppSuccessToast(
          !item.enable
              ? context.l10n.websites_enabledName(item.name)
              : context.l10n.websites_disabledName(item.name),
        );
      }
    } on AppNetworkException catch (error) {
      if (context.mounted) {
        showAppErrorToast(
          context.l10n.websites_operationFailed,
          description: error.message,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppErrorToast(
          context.l10n.websites_operationFailed,
          description: '$error',
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.separator(context).withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue
                  .resolveFrom(context)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              TablerIcons.arrow_forward_up,
              size: 22,
              color: CupertinoColors.systemBlue.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.websites_redirect,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          FrostedActionButton(
            text: context.l10n.websites_add,
            icon: TablerIcons.plus,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}
