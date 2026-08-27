import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/file/file_favorite_dto.dart';
import '../../../../data/repositories_impl/file_repository_impl.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../providers/files_provider.dart';
import '../screens/file_editor_page.dart';

class FileFavoritesSheet extends ConsumerStatefulWidget {
  const FileFavoritesSheet({super.key, required this.serverId});

  final int serverId;

  static Future<void> show(
    BuildContext context, {
    ProviderContainer? providerContainer,
  }) {
    final container = providerContainer ?? ProviderScope.containerOf(context);
    final serverId = container.read(activeServerIdProvider);
    return showActionSheet(
      context: context,
      providerContainer: container,
      builder: (context) => FileFavoritesSheet(serverId: serverId),
    );
  }

  @override
  ConsumerState<FileFavoritesSheet> createState() => _FileFavoritesSheetState();
}

class _FileFavoritesSheetState extends ConsumerState<FileFavoritesSheet> {
  late Future<List<FileFavoriteDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FileFavoriteDto>> _load() async {
    final repo = await ref.read(fileRepositoryProvider.future);
    return repo.searchFavorites();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileFavoriteDto>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <FileFavoriteDto>[];
        return ActionSheetScaffold(
          isAdaptive: true,
          showHandle: false,
          panelHeader: _Header(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
          ),
          child: snapshot.hasError
              ? _Message(
                  icon: TablerIcons.alert_triangle,
                  text: context.l10n.common_loadingFailed,
                )
              : snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(
                  height: 160,
                  child: Center(child: CupertinoActivityIndicator()),
                )
              : items.isEmpty
              ? _Message(
                  icon: TablerIcons.star_off,
                  text: context.l10n.files_favoritesEmpty,
                )
              : Column(
                  children: [
                    for (final item in items)
                      _FavoriteItem(
                        item: item,
                        isLast: item == items.last,
                        onDeleted: _refresh,
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          const Icon(
            TablerIcons.star,
            size: 24,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(width: 10),
          Text(
            context.l10n.files_favoritesTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.label(context),
            ),
          ),
          const Spacer(),
          if (isLoading) const CupertinoActivityIndicator(radius: 9),
        ],
      ),
    );
  }
}

class _FavoriteItem extends ConsumerWidget {
  const _FavoriteItem({
    required this.item,
    required this.isLast,
    required this.onDeleted,
  });

  final FileFavoriteDto item;
  final bool isLast;
  final VoidCallback onDeleted;

  String get _parentPath {
    final index = item.path.lastIndexOf('/');
    if (index <= 0) return '/';
    return item.path.substring(0, index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = item.isDir ? TablerIcons.folder : TablerIcons.file;
    final name = item.name.isEmpty ? item.path.split('/').last : item.name;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.separator(context).withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
              onPressed: () {
                final navigator = Navigator.of(context);
                final files = ref.read(filesControllerProvider.notifier);
                if (item.isDir) {
                  navigator.pop();
                  files.navigateTo(item.path);
                  return;
                }
                if (item.isTxt) {
                  final container = ProviderScope.containerOf(context);
                  navigator.pop();
                  navigator.push(
                    CupertinoPageRoute(
                      builder: (context) => UncontrolledProviderScope(
                        container: container,
                        child: FileEditorPage(
                          path: item.path,
                          fileName: item.name,
                        ),
                      ),
                    ),
                  );
                  return;
                }
                navigator.pop();
                files.navigateTo(_parentPath);
              },
              child: Row(
                children: [
                  Icon(icon, size: 28, color: CupertinoColors.activeBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.label(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.path,
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
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minimumSize: Size.zero,
            onPressed: () async {
              final removedMessage = context.l10n.files_favoriteRemoved;
              final failedMessage = context.l10n.files_favoriteFailed;
              try {
                final repo = await ref.read(fileRepositoryProvider.future);
                await repo.deleteFavorite(item.id);
                if (context.mounted) {
                  showAppSuccessToast(removedMessage);
                  onDeleted();
                }
              } catch (_) {
                showAppErrorToast(failedMessage);
              }
            },
            child: Icon(
              TablerIcons.trash,
              size: 20,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.tertiaryLabel(context)),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
