import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter/material.dart'
    show
        DefaultMaterialLocalizations,
        ReorderableDragStartListener,
        ReorderableListView;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/website/website_proxy_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/app_picker.dart';
import '../providers/website_proxy_provider.dart';
import 'website_modal_sheet.dart';

part 'proxy/website_proxy_sheet_list.part.dart';
part 'proxy/website_proxy_sheet_editor.part.dart';
part 'proxy/website_proxy_sheet_form.part.dart';

const _unitOptions = <String>['s', 'm', 'h', 'd', 'w', 'M', 'y'];
const _methodOptions = <String>[
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'HEAD',
  'OPTIONS',
  'TRACE',
  'CONNECT',
];

enum _BrowserCacheMode { noModify, enable, disable }

void showWebsiteProxySheet(
  BuildContext context, {
  required int websiteId,
  required String title,
}) {
  showWebsiteModalSheet<void>(
    context: context,
    child: _WebsiteProxySheet(websiteId: websiteId, title: title),
  );
}

class _WebsiteProxySheet extends StatelessWidget {
  const _WebsiteProxySheet({required this.websiteId, required this.title});

  final int websiteId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return WebsiteAsyncModalSheet<List<WebsiteProxyDto>>(
      provider: websiteProxyControllerProvider(websiteId),
      errorTitle: context.l10n.websites_loadReverseProxyFailed,
      headerBuilder: (context, ref, async) => _Header(
        title: title,
        onAdd: () => _openEditor(context, ref, websiteId, null),
      ),
      dataBuilder: (context, items) => Consumer(
        builder: (context, ref, _) => _ProxyList(
          websiteId: websiteId,
          items: items,
          onAdd: () => _openEditor(context, ref, websiteId, null),
          onEdit: (item) => _openEditor(context, ref, websiteId, item),
          onDelete: (item) => _deleteItem(context, ref, websiteId, item),
          onToggleStatus: (item) =>
              _toggleStatus(context, ref, websiteId, item),
          onViewSource: (item) => _openSource(context, ref, websiteId, item),
        ),
      ),
      onRetry: (ref) =>
          ref.invalidate(websiteProxyControllerProvider(websiteId)),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteProxyDto? item,
  ) async {
    await showActionSheet<void>(
      context: context,
      expand: true,
      useRootNavigator: true,
      builder: (context) =>
          _ProxyEditorSheet(websiteId: websiteId, initial: item),
    );
    ref.read(websiteProxyControllerProvider(websiteId).notifier).refresh();
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteProxyDto item,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.websites_deleteReverseProxy),
        content: Text(context.l10n.websites_deleteProxyConfirm(item.name)),
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
      await ref
          .read(websiteProxyControllerProvider(websiteId).notifier)
          .deleteProxy(item.name);
      if (context.mounted) {
        showAppSuccessToast(context.l10n.websites_deletedName(item.name));
      }
    } on AppNetworkException catch (error) {
      if (context.mounted) {
        showAppErrorToast(
          context.l10n.websites_operationFailedCopyDetails,
          description: error.message,
          copyText: error.message,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppErrorToast(
          context.l10n.websites_operationFailedCopyDetails,
          description: '$error',
          copyText: '$error',
        );
      }
    }
  }

  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteProxyDto item,
  ) async {
    final sourceTitle = context.l10n.websites_sourceContent;
    final savedMessage = context.l10n.websites_sourceContentSaved;
    await showAppCodeEditorSheet(
      context,
      title: sourceTitle,
      subtitle: item.name,
      initialContent: item.content,
      language: 'nginx',
      onSave: (content) async {
        await ref
            .read(websiteProxyControllerProvider(websiteId).notifier)
            .saveProxyFile(item.name, content);
        showAppSuccessToast(savedMessage);
        return true;
      },
    );
  }

  Future<void> _toggleStatus(
    BuildContext context,
    WidgetRef ref,
    int websiteId,
    WebsiteProxyDto item,
  ) async {
    try {
      await ref
          .read(websiteProxyControllerProvider(websiteId).notifier)
          .setStatus(item.name, !item.enable);
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
          context.l10n.websites_operationFailedCopyDetails,
          description: error.message,
          copyText: error.message,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppErrorToast(
          context.l10n.websites_operationFailedCopyDetails,
          description: '$error',
          copyText: '$error',
        );
      }
    }
  }
}
