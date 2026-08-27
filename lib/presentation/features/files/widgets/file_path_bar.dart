import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/files_provider.dart';

/// 模仿 [FrostedFilterBar] 设计的路径导航栏。
class FilePathBar extends ConsumerStatefulWidget {
  const FilePathBar({super.key, this.overlaps = false});

  final bool overlaps;

  @override
  ConsumerState<FilePathBar> createState() => _FilePathBarState();
}

class _FilePathBarState extends ConsumerState<FilePathBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听路径变化，仅在进入更深层目录时自动滚动到末尾
    ref.listen(filesControllerProvider, (previous, next) {
      final nextPath = next.valueOrNull?.currentPath ?? '';
      final prevPath = previous?.valueOrNull?.currentPath ?? '';

      if (nextPath != prevPath && nextPath.length > prevPath.length) {
        _scrollToEnd();
      }
    });

    final viewState = ref.watch(filesControllerProvider).valueOrNull;
    if (viewState == null) return const SizedBox.shrink();

    final segments = viewState.pathSegments;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final glassSettings = LiquidGlassSettings.figma(
      refraction: 42,
      depth: 35,
      dispersion: 5,
      frost: 1,
      glassColor: isDark
          ? const Color(0xFF2C2C2E).withValues(alpha: 0.42)
          : const Color(0xFFE5E5EA).withValues(alpha: 0.55),
      lightIntensity: 76,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: widget.overlaps
              ? [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: LiquidGlassLayer(
          settings: glassSettings,
          child: AdaptiveGlass.grouped(
            quality: GlassQuality.premium,
            shape: const LiquidRoundedRectangle(borderRadius: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3A3A3C).withValues(alpha: 0.78)
                            : const Color(0xFFFFFFFF).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? CupertinoColors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE8E8E8),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                  ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    itemCount: segments.length,
                    itemBuilder: (context, index) {
                      final segment = segments[index];
                      final isLast = index == segments.length - 1;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PathSegmentButton(
                            label: segment.name == '/'
                                ? context.l10n.files_rootDirectory
                                : segment.name,
                            isActive: isLast,
                            onPressed: () {
                              if (!isLast) {
                                final scrollController =
                                    PrimaryScrollController.of(context);
                                final offset = scrollController.hasClients
                                    ? scrollController.offset
                                    : null;
                                ref
                                    .read(filesControllerProvider.notifier)
                                    .navigateTo(
                                      segment.fullPath,
                                      currentOffset: offset,
                                    );
                              } else {
                                ref
                                    .read(filesControllerProvider.notifier)
                                    .refresh();
                              }
                            },
                          ),
                          if (!isLast)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                CupertinoIcons.chevron_right,
                                size: 10,
                                color: AppColors.tertiaryLabel(context),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathSegmentButton extends StatelessWidget {
  const _PathSegmentButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? CupertinoColors.activeBlue.resolveFrom(context)
        : AppColors.secondaryLabel(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.1)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
