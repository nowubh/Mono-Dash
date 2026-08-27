import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/container/container_search_dto.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/frosted_dialog.dart';

class ContainerUpgradeDialog extends ConsumerStatefulWidget {
  const ContainerUpgradeDialog({super.key, required this.container});

  final ContainerItemDto container;

  @override
  ConsumerState<ContainerUpgradeDialog> createState() =>
      _ContainerUpgradeDialogState();
}

class _ContainerUpgradeDialogState
    extends ConsumerState<ContainerUpgradeDialog> {
  late final TextEditingController _imageController;
  bool _forcePull = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _imageController = TextEditingController(text: widget.container.imageName);
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final image = _imageController.text.trim();
    if (image.isEmpty) {
      showAppErrorToast(context.l10n.containers_targetImageRequired);
      return;
    }

    setState(() => _submitting = true);
    final taskID = const Uuid().v4();

    try {
      final repo = await ref.read(containerRepositoryProvider.future);

      await repo.getContainersByImage(image);

      await repo.upgradeContainer(
        taskID: taskID,
        names: [widget.container.name],
        image: image,
        forcePull: _forcePull,
      );

      if (mounted) {
        Navigator.of(context).pop(taskID);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showAppErrorToast(
          context.l10n.containers_submitUpgradeFailed,
          description: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostedDialog(
      title: context.l10n.containers_upgradeContainer,
      icon: TablerIcons.package_export,
      onCancel: _submitting ? null : () => Navigator.of(context).pop(),
      onConfirm: _submitting ? null : _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.containers_targetImage,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _imageController,
            placeholder: context.l10n.containers_tagPlaceholder,
            autofocus: true,
            enabled: !_submitting,
            autocorrect: false,
            enableSuggestions: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.separator(context),
                width: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.containers_forcePullImage,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      context.l10n.containers_forcePullImageSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              AppToggleSwitch(
                value: _forcePull,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _forcePull = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CupertinoColors.systemOrange.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  TablerIcons.alert_triangle,
                  size: 16,
                  color: CupertinoColors.systemOrange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.containers_upgradeDataLossWarning,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: CupertinoColors.systemOrange.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_submitting) ...[
            const SizedBox(height: 16),
            const Center(child: CupertinoActivityIndicator()),
          ],
        ],
      ),
    );
  }
}
