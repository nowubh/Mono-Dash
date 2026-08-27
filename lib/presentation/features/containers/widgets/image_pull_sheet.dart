import 'package:flutter/cupertino.dart';
import 'package:mono_dash/core/widgets/app_toggle_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/container/image_dtos.dart';
import '../../../../data/repositories_impl/container_repository_impl.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_picker.dart';
import '../providers/image_list_provider.dart';

void showImagePullSheet(BuildContext context) {
  showActionSheet(
    context: context,
    builder: (context) => const _ImagePullSheet(),
  );
}

class _ImagePullSheet extends ConsumerStatefulWidget {
  const _ImagePullSheet();

  @override
  ConsumerState<_ImagePullSheet> createState() => _ImagePullSheetState();
}

class _ImagePullSheetState extends ConsumerState<_ImagePullSheet> {
  final _imageController = TextEditingController();
  bool _useRegistry = true;
  List<ImageRepoDto> _repos = [];
  ImageRepoDto? _selectedRepo;
  bool _loadingRepos = true;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadRepos() async {
    try {
      final repo = await ref.read(containerRepositoryProvider.future);
      final repos = await repo.listImageRepos();
      if (!mounted) return;

      setState(() {
        _repos = repos;
        // Default logic: match name "Docker Hub" and downloadUrl "docker.io"
        _selectedRepo = repos.cast<ImageRepoDto?>().firstWhere(
          (r) => r?.name == 'Docker Hub' && r?.downloadUrl == 'docker.io',
          orElse: () => repos.isNotEmpty ? repos.first : null,
        );
        _loadingRepos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRepos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      isFloating: false,
      showHandle: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                TablerIcons.cloud_download,
                size: 22,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.containers_pullImage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            label: context.l10n.containers_pullFromRepo,
            trailing: AppToggleSwitch(
              value: _useRegistry,
              onChanged: (val) => setState(() => _useRegistry = val),
            ),
          ),

          if (_useRegistry) ...[
            const SizedBox(height: 16),
            _buildSection(
              label: context.l10n.containers_selectRepo,
              child: _loadingRepos
                  ? const CupertinoActivityIndicator()
                  : _repos.isEmpty
                  ? Text(
                      context.l10n.containers_noRepoConfigured,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryLabel(context),
                      ),
                    )
                  : AppInlinePicker<ImageRepoDto>(
                      options: _repos
                          .map((r) => AppPickerOption(value: r, label: r.name))
                          .toList(),
                      value: _selectedRepo!,
                      onChanged: (r) => setState(() => _selectedRepo = r),
                      backgroundColor: AppColors.tertiaryBackground(
                        context,
                      ).withValues(alpha: 0.5),
                    ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            context.l10n.containers_imageName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.label(context),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _imageController,
            placeholder: context.l10n.containers_tagPlaceholder,
            maxLines: 1,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tertiaryBackground(
                context,
              ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(fontSize: 14, color: AppColors.label(context)),
            prefix: _useRegistry && _selectedRepo != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '${_selectedRepo!.downloadUrl}/',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _submit,
              child: Text(context.l10n.containers_pullNow),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String label,
    Widget? child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (child != null) ...[const SizedBox(height: 8), child],
      ],
    );
  }

  void _submit() {
    final rawInput = _imageController.text.trim();
    if (rawInput.isEmpty) return;

    final repoID = _useRegistry ? (_selectedRepo?.id ?? 0) : 0;

    ref
        .read(imageListControllerProvider.notifier)
        .pullImage(context: context, repoID: repoID, imageNames: [rawInput]);
  }
}
