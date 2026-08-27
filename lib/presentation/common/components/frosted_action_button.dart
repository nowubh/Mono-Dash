import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../core/theme/app_theme.dart';

/// 磨砂玻璃风格的单一操作按钮。
///
/// 与 [FrostedHeader] 的按钮视觉保持一致，适合用作
/// `FrostedHeader.trailingBuilder` / `FrostedScaffold.trailingBuilder`。
class FrostedActionButton extends StatelessWidget {
  const FrostedActionButton({
    super.key,
    required this.text,
    this.icon,
    this.onTap,
    this.isDark = false,
    this.isOverlapping = false,
    this.isLoading = false,
    this.foregroundColor,
  });

  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isDark;
  final bool isOverlapping;
  final bool isLoading;
  final Color? foregroundColor;

  bool get _isEnabled => onTap != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final color =
        foregroundColor ??
        (_isEnabled
            ? AppColors.label(context)
            : AppColors.tertiaryLabel(context));

    final glowShadows = isOverlapping
        ? [
            BoxShadow(
              color: isDark
                  ? CupertinoColors.white.withValues(alpha: 0.5)
                  : CupertinoColors.black.withValues(alpha: 0.15),
              blurRadius: 12,
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

    if (text.isEmpty && icon != null && !isLoading) {
      return GlassButton(
        label: text,
        icon: Icon(icon),
        iconColor: color,
        iconSize: 16,
        width: 34,
        height: 34,
        settings: glassSettings,
        quality: GlassQuality.premium,
        useOwnLayer: true,
        stretch: 0.15,
        enabled: _isEnabled,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
      );
    }

    return GestureDetector(
      onTap: _isEnabled
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: glowShadows,
        ),
        child: LiquidGlassLayer(
          settings: glassSettings,
          child: AdaptiveGlass.grouped(
            quality: GlassQuality.premium,
            shape: const LiquidRoundedRectangle(borderRadius: 18),
            child: _buildBody(context, containerColor, color),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Color containerColor, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 34,
      width: text.isEmpty ? 34 : null,
      padding: EdgeInsets.symmetric(horizontal: text.isEmpty ? 0 : 14),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? CupertinoColors.white.withValues(alpha: 0.08)
              : CupertinoColors.black.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isEnabled ? 1 : 0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const CupertinoActivityIndicator(radius: 8)
            else ...[
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                if (text.isNotEmpty) const SizedBox(width: 4),
              ],
              if (text.isNotEmpty)
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: color,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
