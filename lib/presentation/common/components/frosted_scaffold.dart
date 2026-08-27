import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_theme.dart';
import 'frosted_header.dart';

/// 带磨砂玻璃导航栏的通用页面骨架
///
/// 将 Stack + 滚动监听 + FrostedHeader 的模式封装为一行可用的组件。
/// 适用于设置页、列表页等常规滚动页面。
class FrostedScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final bool showBackButton;
  final Widget Function(bool isDark, bool isOverlapping)? trailingBuilder;
  final double fadeOutDistance;
  final bool showBlur;
  final Color? titleColor;
  final bool useMiddleTruncate;
  final Widget? titleWidget;
  final bool largeTitle;

  const FrostedScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBackButton = true,
    this.trailingBuilder,
    this.fadeOutDistance = 12.0,
    this.showBlur = true,
    this.titleColor,
    this.useMiddleTruncate = false,
    this.titleWidget,
    this.largeTitle = false,
  });

  /// 内容顶部 padding（状态栏 + 导航栏高度，不含渐变）
  static double contentTopPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top + FrostedHeader.headerHeight;
  }

  /// 内容顶部 padding（含渐变区域，用于 WebView 等非滚动内容，确保完全不被遮挡）
  static double contentTopPaddingFull(
    BuildContext context, {
    double fadeOutDistance = 12.0,
  }) {
    return MediaQuery.paddingOf(context).top +
        FrostedHeader.headerHeight +
        fadeOutDistance;
  }

  @override
  State<FrostedScaffold> createState() => _FrostedScaffoldState();
}

class _FrostedScaffoldState extends State<FrostedScaffold> {
  bool _isOverlapping = false;
  double _scrollOffset = 0;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final overlapping = notification.metrics.pixels > 0;
      final offset = notification.metrics.pixels
          .clamp(0, double.infinity)
          .toDouble();
      if (overlapping != _isOverlapping ||
          (widget.largeTitle && (offset - _scrollOffset).abs() > 0.5)) {
        setState(() {
          _isOverlapping = overlapping;
          _scrollOffset = offset;
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final collapseProgress = widget.largeTitle
        ? (_scrollOffset / 52).clamp(0.0, 1.0)
        : 1.0;
    final largeTitleTop = FrostedScaffold.contentTopPadding(context) + 8;
    final largeTitleOpacity = Curves.easeIn.transform(
      (1 - collapseProgress).clamp(0.0, 1.0),
    );
    final compactTitleOpacity = Curves.easeOut.transform(
      ((collapseProgress - 0.5) / 0.5).clamp(0.0, 1.0),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(context),
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: widget.body,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FrostedHeader(
              title: widget.title,
              isOverlapping: _isOverlapping,
              onBack: widget.showBackButton
                  ? () => Navigator.of(context).pop()
                  : null,
              fadeOutDistance: widget.fadeOutDistance,
              trailingBuilder: widget.trailingBuilder,
              showBlur: widget.showBlur,
              titleColor: widget.titleColor,
              useMiddleTruncate: widget.useMiddleTruncate,
              titleWidget: widget.titleWidget,
              titleOpacity: widget.largeTitle ? compactTitleOpacity : 1,
            ),
          ),
          if (widget.largeTitle)
            Positioned(
              top: largeTitleTop - _scrollOffset,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: Opacity(
                  key: const ValueKey('frosted-large-title'),
                  opacity: largeTitleOpacity,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CupertinoTheme.of(
                      context,
                    ).textTheme.navLargeTitleTextStyle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
