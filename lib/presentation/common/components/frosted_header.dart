import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:inspire_blur/inspire_blur.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';

/// 带真实渐进模糊的透明导航栏。
///
/// 特点：
/// - GPU 渐进背景模糊，内容滚动时透过可见
/// - 底部渐变淡出（无硬边界）
/// - 独立悬浮返回按钮（自带小磨砂背景）
/// - 居中标题
class FrostedHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget Function(bool isDark, bool isOverlapping)? trailingBuilder;
  final double fadeOutDistance;
  final bool isOverlapping;
  final bool showBlur;
  final Color? titleColor;
  final bool useMiddleTruncate;
  final Widget? titleWidget;
  final double titleOpacity;

  const FrostedHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailingBuilder,
    this.fadeOutDistance = 12.0,
    this.isOverlapping = false,
    this.showBlur = true,
    this.titleColor,
    this.useMiddleTruncate = true,
    this.titleWidget,
    this.titleOpacity = 1,
  });

  static const double headerHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final contentHeight = statusBarHeight + headerHeight;
    // 渐变额外向下延伸，实现非常平滑的毛玻璃淡出效果
    final totalHeight = contentHeight + fadeOutDistance;

    // 标题必须以整条 header 为基准居中。左右操作区宽度可能不同，
    // 因此使用对称避让宽度，避免在不等宽区域内居中造成视觉偏移。
    final leftAvoidance = onBack != null ? 82.0 : 20.0;
    final rightAvoidance = trailingBuilder != null ? 102.0 : 20.0;
    final horizontalPadding = leftAvoidance > rightAvoidance
        ? leftAvoidance
        : rightAvoidance;

    // 根据重叠状态赋予样式
    final textColor = titleColor ?? AppColors.label(context);
    final textShadows = isOverlapping
        ? [
            Shadow(
              color: isDark
                  ? CupertinoColors.white.withValues(alpha: 0.7)
                  : CupertinoColors.black.withValues(alpha: 0.3),
              blurRadius: 12.0,
            ),
          ]
        : null;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 1. 与 Nezha-Dash 相同的 GPU 渐进背景模糊层。
          if (showBlur)
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: InspireBackdropBlur(
                    config: InspireBlurConfig.topToBottom(
                      sigma: 12,
                      fadeCurve: Curves.easeInSine,
                      extent: 1,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            (isDark
                                    ? CupertinoColors.black
                                    : CupertinoColors.white)
                                .withValues(alpha: 0.10),
                            (isDark
                                    ? CupertinoColors.black
                                    : CupertinoColors.white)
                                .withValues(alpha: 0),
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),

          // 2. 标题（居中，带避让）
          Positioned(
            left: 0,
            right: 0,
            top: statusBarHeight,
            height: headerHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Opacity(
                key: const ValueKey('frosted-small-title'),
                opacity: titleOpacity,
                child: Center(
                  child:
                      titleWidget ??
                      LayoutBuilder(
                        builder: (context, constraints) {
                          var displayTitle = title;
                          if (useMiddleTruncate) {
                            // 更保守的估算：考虑宽字符和内边距，平均每个字符预留 11 像素
                            final maxChars = (constraints.maxWidth / 11.0)
                                .floor();
                            displayTitle = truncateMiddle(title, maxChars);
                          }

                          return AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              letterSpacing: -0.4,
                              shadows: textShadows,
                            ),
                            child: Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                ),
              ),
            ),
          ),

          // 3. 独立现代感返回按钮（带侧滑进度弧线）
          if (onBack != null)
            Positioned(
              left: 10,
              top: statusBarHeight + (headerHeight - 34) / 2,
              child: _SwipeAwareBackButton(
                onTap: onBack!,
                isDark: isDark,
                isOverlapping: isOverlapping,
                foregroundColor: titleColor,
              ),
            ),

          // 4. 右侧自定义组件 (如 Connection Menu)
          if (trailingBuilder != null)
            Positioned(
              right: 16,
              top: statusBarHeight + (headerHeight - 34) / 2,
              child: trailingBuilder!(isDark, isOverlapping),
            ),
        ],
      ),
    );
  }
}

/// 侧滑感知的返回按钮包装器
/// 通过监听路由过渡动画，将侧滑进度传递给实际的按钮绘制
class _SwipeAwareBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final bool isOverlapping;
  final Color? foregroundColor;

  const _SwipeAwareBackButton({
    required this.onTap,
    required this.isDark,
    this.isOverlapping = false,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;

    if (animation == null) {
      return _FrostedBackButton(
        onTap: onTap,
        isDark: isDark,
        isOverlapping: isOverlapping,
        swipeProgress: 0.0,
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // forward = push 进入页面，不应显示。
        // pop / 侧滑返回时才显示。判断条件：动画反转，或正处于返回手势中。
        final isPopping =
            animation.status == AnimationStatus.reverse ||
            (route?.navigator?.userGestureInProgress ?? false);
        final progress = isPopping
            ? (1.0 - animation.value).clamp(0.0, 1.0)
            : 0.0;
        return _FrostedBackButton(
          onTap: onTap,
          isDark: isDark,
          isOverlapping: isOverlapping,
          swipeProgress: progress,
          foregroundColor: foregroundColor,
        );
      },
    );
  }
}

/// 重新设计的极简玻璃态返回按钮
class _FrostedBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final bool isOverlapping;
  final double swipeProgress;
  final Color? foregroundColor;

  const _FrostedBackButton({
    required this.onTap,
    required this.isDark,
    this.isOverlapping = false,
    this.swipeProgress = 0.0,
    this.foregroundColor,
  });

  static const double _borderRadius = 18.0;
  static const double _height = 34.0;

  @override
  Widget build(BuildContext context) {
    // 根据重叠状态调整颜色和发光
    final color = foregroundColor ?? AppColors.label(context);
    final glowShadows = isOverlapping
        ? [
            BoxShadow(
              color: isDark
                  ? CupertinoColors.white.withValues(alpha: 0.5)
                  : CupertinoColors.black.withValues(alpha: 0.15),
              blurRadius: 12.0,
            ),
          ]
        : null;

    final containerColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.15)
        : CupertinoColors.white.withValues(alpha: 0.5);
    final glassSettings = LiquidGlassSettings.figma(
      refraction: 42,
      depth: 26,
      dispersion: 5,
      frost: 1,
      glassColor: isDark
          ? const Color(0xFF2C2C2E).withValues(alpha: 0.42)
          : const Color(0xFFE5E5EA).withValues(alpha: 0.54),
      lightIntensity: 76,
    );

    final progressColor = CupertinoColors.activeBlue.resolveFrom(context);

    // 使用更高纯度的模糊与强调色设计
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: glowShadows,
        ),
        child: LiquidGlassLayer(
          settings: glassSettings,
          child: AdaptiveGlass.grouped(
            quality: GlassQuality.premium,
            shape: const LiquidRoundedRectangle(borderRadius: _borderRadius),
            child: CustomPaint(
              foregroundPainter: swipeProgress > 0.01
                  ? _SwipeProgressPainter(
                      progress: swipeProgress,
                      color: progressColor,
                      borderRadius: _borderRadius,
                      strokeWidth: 2.0,
                    )
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _height,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(_borderRadius),
                  border: Border.all(
                    color: isDark
                        ? CupertinoColors.white.withValues(alpha: 0.08)
                        : CupertinoColors.black.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.chevron_back, size: 18, color: color),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.common_back,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 沿圆角矩形边框绘制进度弧线的 CustomPainter
class _SwipeProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderRadius;
  final double strokeWidth;

  _SwipeProgressPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // 稍微内缩，避免发光线条被 ClipRRect 裁掉。
    final rect = (Offset.zero & size).deflate(strokeWidth / 2 + 0.5);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 单一连续渐变光带。之前用多段 stroke + blur 叠加，会在端点和圆角处
    // 形成脏点；这里改为 shader 控制颜色分布，避免分段痕迹。
    final sweep = progress.clamp(0.0, 1.0);
    final gradient = SweepGradient(
      transform: GradientRotation((sweep * 2 * 3.141592653589793) - 1.5708),
      colors: [
        const Color(0x00000000),
        color.withValues(alpha: 0.00),
        color.withValues(alpha: 0.10),
        color.withValues(alpha: 0.36),
        color.withValues(alpha: 0.86),
        color.withValues(alpha: 0.28),
        const Color(0x00000000),
      ],
      stops: const [0.00, 0.56, 0.70, 0.82, 0.90, 0.96, 1.00],
    );
    final glowGradient = SweepGradient(
      transform: GradientRotation((sweep * 2 * 3.141592653589793) - 1.5708),
      colors: [
        const Color(0x00000000),
        color.withValues(alpha: 0.00),
        color.withValues(alpha: 0.08),
        color.withValues(alpha: 0.22),
        color.withValues(alpha: 0.12),
        const Color(0x00000000),
      ],
      stops: const [0.00, 0.60, 0.76, 0.88, 0.96, 1.00],
    );
    final glowPaint = Paint()
      ..shader = glowGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.6
      ..strokeCap = StrokeCap.butt
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    final corePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, corePaint);
  }

  @override
  bool shouldRepaint(_SwipeProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
