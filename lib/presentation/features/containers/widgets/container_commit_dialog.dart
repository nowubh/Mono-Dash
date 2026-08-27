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

class ContainerCommitDialog extends ConsumerStatefulWidget {
  const ContainerCommitDialog({super.key, required this.container});

  final ContainerItemDto container;

  @override
  ConsumerState<ContainerCommitDialog> createState() =>
      _ContainerCommitDialogState();
}

class _ContainerCommitDialogState extends ConsumerState<ContainerCommitDialog> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  final _authorController = TextEditingController();
  bool _pause = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppErrorToast(context.l10n.containers_enterNewImageName);
      return;
    }

    final regex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9:@/.\-_]{0,255}$');
    if (!regex.hasMatch(name)) {
      showAppErrorToast(
        context.l10n.containers_imageNameInvalid,
        description: context.l10n.containers_imageNameInvalidDescription,
      );
      return;
    }

    setState(() => _submitting = true);
    final taskID = const Uuid().v4();

    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      await repo.commitContainer(
        containerID: widget.container.containerID,
        containerName: widget.container.name,
        newImageName: name,
        comment: _commentController.text.trim(),
        author: _authorController.text.trim(),
        pause: _pause,
        taskID: taskID,
      );

      if (mounted) {
        Navigator.of(context).pop(taskID);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showAppErrorToast(
          context.l10n.containers_submitFailed,
          description: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrostedDialog(
      title: context.l10n.containers_commitImage,
      icon: TablerIcons.photo_up,
      onCancel: _submitting ? null : () => Navigator.of(context).pop(),
      onConfirm: _submitting ? null : _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(
            label: context.l10n.containers_newImageName,
            hint: context.l10n.containers_newImageNamePlaceholder,
            controller: _nameController,
            required: true,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: context.l10n.containers_commitInfo,
            hint: context.l10n.containers_optionalDescription,
            controller: _commentController,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: context.l10n.containers_author,
            hint: context.l10n.containers_optionalAuthor,
            controller: _authorController,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.containers_pauseDuringCommit,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      context.l10n.containers_pauseDuringCommitSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              AppToggleSwitch(
                value: _pause,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _pause = v),
              ),
            ],
          ),
          if (_submitting) ...[
            const SizedBox(height: 16),
            const Center(child: CupertinoActivityIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool required = false,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryLabel(context),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          placeholder: hint,
          enabled: !_submitting,
          autofocus: autofocus,
          autocorrect: false,
          enableSuggestions: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.tertiaryBackground(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.separator(context), width: 0.5),
          ),
        ),
      ],
    );
  }
}
