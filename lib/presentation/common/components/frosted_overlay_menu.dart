import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import 'overlay_menu_mixin.dart';

/// 磨砂浮层菜单项数据
class FrostedMenuItem {
  final String text;
  final IconData icon;
  final Widget? iconWidget;
  final Color iconColor;
  final VoidCallback action;
  final bool isDestructive;
  final List<FrostedMenuItem> children;

  const FrostedMenuItem({
    required this.text,
    this.icon = CupertinoIcons.circle,
    this.iconWidget,
    this.iconColor = CupertinoColors.activeBlue,
    required this.action,
    this.isDestructive = false,
    this.children = const [],
  });

  bool get hasSubmenu => children.isNotEmpty;
}

/// 磨砂玻璃风格的 Overlay 浮层菜单按钮
///
/// 与 FrostedHeader 的返回按钮视觉风格一致，
/// 点击后展开磨砂下拉菜单。适合用作 FrostedScaffold 的 trailingBuilder。
class FrostedOverlayMenuButton extends StatefulWidget {
  final String? label;
  final List<FrostedMenuItem> items;
  final bool isDark;
  final bool isOverlapping;
  final bool isActive;

  const FrostedOverlayMenuButton({
    super.key,
    this.label,
    required this.items,
    this.isDark = false,
    this.isOverlapping = false,
    this.isActive = false,
  });

  @override
  State<FrostedOverlayMenuButton> createState() =>
      _FrostedOverlayMenuButtonState();
}

class _FrostedOverlayMenuButtonState extends State<FrostedOverlayMenuButton>
    with SingleTickerProviderStateMixin, OverlayMenuMixin {
  int? _activeSubmenuIndex;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    isOverlayMenuOpen ? _closeMenu() : _openMenu();
  }

  void _openMenu() {
    if (isOverlayMenuOpen || !mounted) return;

    _activeSubmenuIndex = null;

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    showOverlayMenu(
      contentBuilder: (ctx) {
        const mainMenuWidth = 220.0;
        const submenuWidth = 174.0;
        const gap = 8.0;
        const rowHeight = 43.0;
        final menuTop = offset.dy + size.height + 12;
        final menuRight = screenWidth - offset.dx - size.width;
        final mainLeft = screenWidth - menuRight - mainMenuWidth;
        final activeSubmenuIndex = _activeSubmenuIndex;
        final submenuItem = activeSubmenuIndex == null
            ? null
            : widget.items[activeSubmenuIndex];
        final showSubmenu = submenuItem?.hasSubmenu ?? false;
        final submenuLeft = mainLeft >= submenuWidth + gap
            ? mainLeft - submenuWidth - gap
            : mainLeft + mainMenuWidth + gap;
        final clampedSubmenuLeft = submenuLeft.clamp(
          8.0,
          screenWidth - submenuWidth - 8,
        );

        return [
          Positioned(
            top: menuTop,
            right: menuRight,
            child: FadeTransition(
              opacity: _animationController,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOutBack,
                    reverseCurve: Curves.easeIn,
                  ),
                ),
                child: _buildMenuPanel(widget.items),
              ),
            ),
          ),
          if (showSubmenu)
            Positioned(
              top:
                  menuTop + (activeSubmenuIndex! * rowHeight).clamp(0.0, 220.0),
              left: clampedSubmenuLeft,
              child: FadeTransition(
                opacity: _animationController,
                child: ScaleTransition(
                  alignment: Alignment.topRight,
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeIn,
                    ),
                  ),
                  child: _buildMenuPanel(
                    submenuItem!.children,
                    width: submenuWidth,
                    isSubmenu: true,
                  ),
                ),
              ),
            ),
        ];
      },
      onOverlayBuilt: () {
        setState(() {});
        _animationController.forward();
      },
      dismissBuilder: (ctx, onDismiss) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closeMenu,
        ),
      ),
    );
  }

  void _closeMenu() {
    if (!isOverlayMenuOpen || !mounted) return;

    hideOverlayMenu(animationController: _animationController).then((_) {
      if (mounted) {
        setState(() => _activeSubmenuIndex = null);
      }
    });
  }

  Widget _buildMenuPanel(
    List<FrostedMenuItem> items, {
    double width = 220,
    bool isSubmenu = false,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: widget.isDark
            ? CupertinoColors.systemBackground.darkColor.withValues(alpha: 0.65)
            : CupertinoColors.systemBackground.color.withValues(alpha: 0.75),
        border: Border.all(
          color: widget.isDark
              ? CupertinoColors.white.withValues(alpha: 0.15)
              : CupertinoColors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(
              alpha: widget.isDark ? 0.3 : 0.1,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _FrostedMenuItemWidget(
                  item: items[i],
                  isDark: widget.isDark,
                  isSubmenuActive: !isSubmenu && _activeSubmenuIndex == i,
                  onTap: () {
                    if (!isSubmenu && items[i].hasSubmenu) {
                      setState(() => _activeSubmenuIndex = i);
                      rebuildOverlay();
                      return;
                    }
                    _closeMenu();
                    items[i].action();
                  },
                ),
                if (i < items.length - 1)
                  Container(
                    height: 0.5,
                    color: widget.isDark
                        ? CupertinoColors.white.withValues(alpha: 0.1)
                        : CupertinoColors.black.withValues(alpha: 0.08),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glowShadows = widget.isOverlapping
        ? [
            BoxShadow(
              color: widget.isDark
                  ? CupertinoColors.white.withValues(alpha: 0.5)
                  : CupertinoColors.black.withValues(alpha: 0.15),
              blurRadius: 12.0,
            ),
          ]
        : null;

    final containerColor = widget.isDark
        ? CupertinoColors.white.withValues(alpha: 0.15)
        : CupertinoColors.white.withValues(alpha: 0.5);
    final glassSettings = LiquidGlassSettings.figma(
      refraction: 42,
      depth: 26,
      dispersion: 5,
      frost: 1,
      glassColor: widget.isDark
          ? const Color(0xFF2C2C2E).withValues(alpha: 0.42)
          : const Color(0xFFE5E5EA).withValues(alpha: 0.54),
      lightIntensity: 76,
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _toggleMenu();
      },
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
            child: Builder(
              builder: (context) {
                Widget button = AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: widget.isDark
                          ? CupertinoColors.white.withValues(alpha: 0.08)
                          : CupertinoColors.black.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label ?? context.l10n.common_menu,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: AppColors.label(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isOverlayMenuOpen ? -0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          size: 14,
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                );

                if (isOverlayMenuOpen || widget.isActive) {
                  button = button
                      .animate(onPlay: (c) => c.repeat())
                      .custom(
                        duration: 2000.ms,
                        builder: (context, value, child) {
                          return CustomPaint(
                            foregroundPainter: _FlowingBorderPainter(
                              value * 2 * math.pi,
                              widget.isDark,
                            ),
                            child: child,
                          );
                        },
                      );
                }

                return button;
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 菜单项组件（带按压状态和触感反馈）
class _FrostedMenuItemWidget extends StatefulWidget {
  final FrostedMenuItem item;
  final bool isDark;
  final bool isSubmenuActive;
  final VoidCallback onTap;

  const _FrostedMenuItemWidget({
    required this.item,
    required this.isDark,
    this.isSubmenuActive = false,
    required this.onTap,
  });

  @override
  State<_FrostedMenuItemWidget> createState() => _FrostedMenuItemWidgetState();
}

class _FrostedMenuItemWidgetState extends State<_FrostedMenuItemWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.isDark
        ? CupertinoColors.white
        : CupertinoColors.black;
    final textColor = widget.item.isDestructive
        ? CupertinoColors.destructiveRed
        : defaultColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        color: _isPressed
            ? (widget.isDark
                  ? CupertinoColors.white.withValues(alpha: 0.1)
                  : CupertinoColors.black.withValues(alpha: 0.1))
            : widget.isSubmenuActive
            ? (widget.isDark
                  ? CupertinoColors.white.withValues(alpha: 0.08)
                  : CupertinoColors.black.withValues(alpha: 0.06))
            : const Color(0x00000000),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            widget.item.iconWidget ??
                Icon(
                  widget.item.icon,
                  size: 18,
                  color: widget.item.isDestructive
                      ? CupertinoColors.destructiveRed
                      : widget.item.iconColor,
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.item.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: widget.item.isDestructive
                      ? FontWeight.w500
                      : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
            if (widget.item.hasSubmenu) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: AppColors.tertiaryLabel(context).withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 流光边框绘制器
class _FlowingBorderPainter extends CustomPainter {
  final double rotation;
  final bool isDark;

  _FlowingBorderPainter(this.rotation, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(18),
    ).deflate(0.75);

    final gradient = SweepGradient(
      transform: GradientRotation(rotation),
      colors: [
        const Color(0x00000000),
        isDark ? const Color(0xFF00E5FF) : CupertinoColors.activeBlue,
        isDark ? const Color(0xFFFF007F) : CupertinoColors.activeOrange,
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.4, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_FlowingBorderPainter oldDelegate) {
    return rotation != oldDelegate.rotation || isDark != oldDelegate.isDark;
  }
}
