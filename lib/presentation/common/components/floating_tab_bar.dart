import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_theme.dart';

class FloatingTabItemData {
  const FloatingTabItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.nativeSymbol,
    this.showDot = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? nativeSymbol;
  final bool showDot;
}

class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    this.maxWidth = 600,
    this.horizontalMargin = 24,
    this.itemSpacing = 25,
    this.contentHorizontalPadding = 20,
    this.expandItems = false,
  });

  final List<FloatingTabItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double maxWidth;
  final double horizontalMargin;
  final double itemSpacing;
  final double contentHorizontalPadding;
  final bool expandItems;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
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

    return Center(
      child: Container(
        width: expandItems ? double.infinity : null,
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.fromLTRB(
          horizontalMargin,
          8,
          horizontalMargin,
          bottomInset > 0 ? bottomInset : 32,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? CupertinoColors.black.withValues(alpha: 0.25)
                    : const Color(0x0C000000),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: isDark
                    ? CupertinoColors.black.withValues(alpha: 0.15)
                    : const Color(0x04000000),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: LiquidGlassLayer(
            settings: glassSettings,
            child: AdaptiveGlass.grouped(
              quality: GlassQuality.premium,
              shape: const LiquidRoundedRectangle(borderRadius: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: isDark
                                ? const Color(
                                    0xFF3A3A3C,
                                  ).withValues(alpha: 0.78)
                                : const Color(
                                    0xFFFFFFFF,
                                  ).withValues(alpha: 0.65),
                            border: Border.all(
                              color: isDark
                                  ? CupertinoColors.white.withValues(
                                      alpha: 0.08,
                                    )
                                  : const Color(0xFFE8E8E8),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: contentHorizontalPadding,
                      ),
                      child: expandItems
                          ? Row(
                              mainAxisSize: MainAxisSize.max,
                              children: _buildTabChildren(expandItems: true),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildTabChildren(expandItems: false),
                              ),
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

  List<Widget> _buildTabChildren({required bool expandItems}) {
    return [
      for (int index = 0; index < items.length; index++) ...[
        if (expandItems)
          Expanded(child: _buildTabItem(index))
        else
          _buildTabItem(index),
        if (!expandItems && index < items.length - 1)
          SizedBox(width: itemSpacing),
      ],
    ];
  }

  Widget _buildTabItem(int index) {
    return _FloatingTabItem(
      icon: items[index].icon,
      activeIcon: items[index].activeIcon,
      label: items[index].label,
      showDot: items[index].showDot,
      isSelected: selectedIndex == index,
      onTap: () => onTabSelected(index),
    );
  }
}

class _FloatingTabItem extends StatelessWidget {
  const _FloatingTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? CupertinoColors.activeBlue.resolveFrom(context)
        : AppColors.secondaryLabel(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child:
                        Icon(
                              isSelected ? activeIcon : icon,
                              color: color,
                              size: 22,
                            )
                            .animate(target: isSelected ? 1 : 0)
                            .scaleXY(
                              begin: 1,
                              end: 1.15,
                              duration: 250.ms,
                              curve: Curves.easeOutBack,
                            ),
                  ),
                  if (showDot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.white,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
