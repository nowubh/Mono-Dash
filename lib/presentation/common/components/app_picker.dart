import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/l10n_x.dart';
import '../../../core/theme/app_theme.dart';
import 'overlay_menu_mixin.dart';

class AppPickerOption<T> {
  const AppPickerOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A shared anchor component for all picker variants.
/// Handles the consistent "Apple-like" tinted box with label and optional icon.
class AppPickerAnchor extends StatelessWidget {
  const AppPickerAnchor({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.enabled = true,
    this.backgroundColor,
    this.height = 42,
    this.isExpanded = false,
    this.placeholder,
    this.hasValue = true,
    this.chevronType = AppPickerChevronType.down,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? backgroundColor;
  final double height;
  final bool isExpanded;
  final String? placeholder;
  final bool hasValue;
  final AppPickerChevronType chevronType;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            AppColors.tertiaryBackground(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: enabled ? onTap : null,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.secondaryLabel(context)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                textAlign: textAlign,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasValue
                      ? AppColors.label(context)
                      : AppColors.secondaryLabel(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            _buildChevron(context),
          ],
        ),
      ),
    );
  }

  Widget _buildChevron(BuildContext context) {
    final color = enabled
        ? AppColors.secondaryLabel(context)
        : AppColors.tertiaryLabel(context);

    if (chevronType == AppPickerChevronType.right) {
      return Icon(TablerIcons.chevron_right, size: 16, color: color);
    }

    return AnimatedRotation(
      turns: isExpanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 200),
      child: Icon(TablerIcons.chevron_down, size: 16, color: color),
    );
  }
}

enum AppPickerChevronType { down, right }

class AppInlinePicker<T> extends StatefulWidget {
  const AppInlinePicker({
    super.key,
    required this.options,
    this.value,
    required this.onChanged,
    this.enabled = true,
    this.selectedColor,
    this.backgroundColor,
    this.anchorHeight = 42,
    this.itemHeight = 38,
    this.maxVisibleItems = 5,
    this.width,
    this.onExpandChanged,
    this.placeholder,
    this.textAlign = TextAlign.left,
  });

  final List<AppPickerOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final Color? selectedColor;
  final Color? backgroundColor;
  final double anchorHeight;
  final double itemHeight;
  final int maxVisibleItems;
  final double? width;
  final ValueChanged<bool>? onExpandChanged;
  final String? placeholder;
  final TextAlign textAlign;

  @override
  State<AppInlinePicker<T>> createState() => _AppInlinePickerState<T>();
}

class _AppInlinePickerState<T> extends State<AppInlinePicker<T>>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final ScrollController _listController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _listController = ScrollController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled || widget.options.isEmpty) return;
    setState(() {
      _expanded = !_expanded;
      widget.onExpandChanged?.call(_expanded);
      if (_expanded) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        widget.selectedColor ?? CupertinoColors.activeBlue.resolveFrom(context);
    final hasOptions = widget.options.isNotEmpty;
    final current = hasOptions
        ? widget.options.cast<AppPickerOption<T>?>().firstWhere(
            (option) => option?.value == widget.value,
            orElse: () => null,
          )
        : null;
    final maxHeight = widget.itemHeight * widget.maxVisibleItems + 8;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPickerAnchor(
          label:
              current?.label ??
              widget.placeholder ??
              (hasOptions
                  ? context.l10n.common_noSelection
                  : context.l10n.common_noOptions),
          icon: current?.icon,
          onTap: _toggle,
          enabled: widget.enabled && hasOptions,
          backgroundColor: widget.backgroundColor,
          height: widget.anchorHeight,
          isExpanded: _expanded,
          hasValue: current != null,
          textAlign: widget.textAlign,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded && widget.enabled && hasOptions
              ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            widget.backgroundColor ??
                            AppColors.tertiaryBackground(
                              context,
                            ).withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: CupertinoScrollbar(
                            controller: _listController,
                            child: ListView.separated(
                              controller: _listController,
                              primary: false,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: widget.options.length,
                              separatorBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Container(
                                  height: 0.5,
                                  color: AppColors.separator(
                                    context,
                                  ).withValues(alpha: 0.16),
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final option = widget.options[index];
                                final selected = option.value == widget.value;
                                return CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    widget.onChanged(option.value);
                                    _fadeController.reverse().then((_) {
                                      if (mounted) {
                                        setState(() {
                                          _expanded = false;
                                          widget.onExpandChanged?.call(false);
                                        });
                                      }
                                    });
                                  },
                                  child: SizedBox(
                                    height: widget.itemHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          if (option.icon != null) ...[
                                            Icon(
                                              option.icon,
                                              size: 16,
                                              color: selected
                                                  ? selectedColor
                                                  : AppColors.secondaryLabel(
                                                      context,
                                                    ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          Expanded(
                                            child: Text(
                                              option.label,
                                              textAlign: widget.textAlign,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? selectedColor
                                                    : AppColors.label(context),
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Icon(
                                              TablerIcons.check,
                                              size: 16,
                                              color: selectedColor,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: content);
    }
    return content;
  }
}

class AppInlineMultiPicker<T> extends StatefulWidget {
  const AppInlineMultiPicker({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.enabled = true,
    this.selectedColor,
    this.backgroundColor,
    this.anchorHeight = 42,
    this.itemHeight = 38,
    this.maxVisibleItems = 5,
    this.width,
    this.onExpandChanged,
    this.placeholder,
    this.displayForValues,
    this.textAlign = TextAlign.left,
  });

  final List<AppPickerOption<T>> options;
  final List<T> selectedValues;
  final ValueChanged<List<T>> onChanged;
  final bool enabled;
  final Color? selectedColor;
  final Color? backgroundColor;
  final double anchorHeight;
  final double itemHeight;
  final int maxVisibleItems;
  final double? width;
  final ValueChanged<bool>? onExpandChanged;
  final String? placeholder;
  final String Function(List<T>)? displayForValues;
  final TextAlign textAlign;

  @override
  State<AppInlineMultiPicker<T>> createState() =>
      _AppInlineMultiPickerState<T>();
}

class _AppInlineMultiPickerState<T> extends State<AppInlineMultiPicker<T>>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final ScrollController _listController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _listController = ScrollController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled || widget.options.isEmpty) return;
    setState(() {
      _expanded = !_expanded;
      widget.onExpandChanged?.call(_expanded);
      if (_expanded) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        widget.selectedColor ?? CupertinoColors.activeBlue.resolveFrom(context);
    final hasOptions = widget.options.isNotEmpty;

    String label;
    if (widget.displayForValues != null) {
      label = widget.displayForValues!(widget.selectedValues);
    } else {
      if (widget.selectedValues.isEmpty) {
        label =
            widget.placeholder ??
            (hasOptions
                ? context.l10n.common_noSelection
                : context.l10n.common_noOptions);
      } else if (widget.selectedValues.length == 1) {
        final opt = widget.options.firstWhere(
          (o) => o.value == widget.selectedValues.first,
          orElse: () => AppPickerOption(
            value: widget.selectedValues.first,
            label: widget.selectedValues.first.toString(),
          ),
        );
        label = opt.label;
      } else {
        label = context.l10n.common_selectedCount(widget.selectedValues.length);
      }
    }

    final maxHeight = widget.itemHeight * widget.maxVisibleItems + 8;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPickerAnchor(
          label: label,
          onTap: _toggle,
          enabled: widget.enabled && hasOptions,
          backgroundColor: widget.backgroundColor,
          height: widget.anchorHeight,
          isExpanded: _expanded,
          hasValue: widget.selectedValues.isNotEmpty,
          textAlign: widget.textAlign,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded && widget.enabled && hasOptions
              ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            widget.backgroundColor ??
                            AppColors.tertiaryBackground(
                              context,
                            ).withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: CupertinoScrollbar(
                            controller: _listController,
                            child: ListView.separated(
                              controller: _listController,
                              primary: false,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: widget.options.length,
                              separatorBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Container(
                                  height: 0.5,
                                  color: AppColors.separator(
                                    context,
                                  ).withValues(alpha: 0.16),
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final option = widget.options[index];
                                final selected = widget.selectedValues.contains(
                                  option.value,
                                );
                                return CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    final newList = List<T>.from(
                                      widget.selectedValues,
                                    );
                                    if (selected) {
                                      newList.remove(option.value);
                                    } else {
                                      newList.add(option.value);
                                    }
                                    widget.onChanged(newList);
                                  },
                                  child: SizedBox(
                                    height: widget.itemHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          if (option.icon != null) ...[
                                            Icon(
                                              option.icon,
                                              size: 16,
                                              color: selected
                                                  ? selectedColor
                                                  : AppColors.secondaryLabel(
                                                      context,
                                                    ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          Expanded(
                                            child: Text(
                                              option.label,
                                              textAlign: widget.textAlign,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? selectedColor
                                                    : AppColors.label(context),
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Icon(
                                              TablerIcons.check,
                                              size: 16,
                                              color: selectedColor,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: content);
    }
    return content;
  }
}

class AppOverlayPicker<T> extends StatefulWidget {
  const AppOverlayPicker({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.selectedColor,
    this.backgroundColor,
    this.height = 40,
    this.width,
    this.maxListHeight = 160,
    this.placeholder,
  });

  final List<AppPickerOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final Color? selectedColor;
  final Color? backgroundColor;
  final double height;
  final double? width;
  final double maxListHeight;
  final String? placeholder;

  @override
  State<AppOverlayPicker<T>> createState() => _AppOverlayPickerState<T>();
}

class _AppOverlayPickerState<T> extends State<AppOverlayPicker<T>>
    with TickerProviderStateMixin, OverlayMenuMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  late final ScrollController _listController;
  late final AnimationController _overlayAnimController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _listController = ScrollController();
    _overlayAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _overlayAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _overlayAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  bool get _expanded => isOverlayMenuOpen;

  void _toggleOverlay() {
    if (!widget.enabled || widget.options.isEmpty) return;
    if (_expanded) {
      hideOverlayMenu(animationController: _overlayAnimController);
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final box = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size(widget.width ?? 132, widget.height);
    final selectedColor =
        widget.selectedColor ?? CupertinoColors.activeBlue.resolveFrom(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final boxGlobalPos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final spaceBelow = screenHeight - (boxGlobalPos.dy + size.height);
    final showAbove =
        spaceBelow < widget.maxListHeight + 20 && boxGlobalPos.dy > spaceBelow;

    showOverlayMenu(
      animationController: _overlayAnimController,
      contentBuilder: (ctx) => [
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: showAbove ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: showAbove ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(0, showAbove ? -6 : 6),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: showAbove
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: Container(
                width: size.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryBackground(
                          ctx,
                        ).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.separator(
                            ctx,
                          ).withValues(alpha: 0.22),
                          width: 0.6,
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: widget.maxListHeight,
                        ),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: CupertinoScrollbar(
                            controller: _listController,
                            child: ListView.separated(
                              controller: _listController,
                              primary: false,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: widget.options.length,
                              separatorBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Container(
                                  height: 0.5,
                                  color: AppColors.separator(
                                    context,
                                  ).withValues(alpha: 0.16),
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final option = widget.options[index];
                                final selected = option.value == widget.value;
                                return CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    widget.onChanged(option.value);
                                    hideOverlayMenu(
                                      animationController:
                                          _overlayAnimController,
                                    );
                                  },
                                  child: SizedBox(
                                    height: 36,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          if (option.icon != null) ...[
                                            Icon(
                                              option.icon,
                                              size: 16,
                                              color: selected
                                                  ? selectedColor
                                                  : AppColors.secondaryLabel(
                                                      context,
                                                    ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          Expanded(
                                            child: Text(
                                              option.label,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? selectedColor
                                                    : AppColors.label(context),
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Icon(
                                              TablerIcons.check,
                                              size: 16,
                                              color: selectedColor,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      dismissBuilder: (ctx, onDismiss) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onDismiss,
        ),
      ),
    );
    _overlayAnimController.forward(from: 0);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _listController.dispose();
    _overlayAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasOptions = widget.options.isNotEmpty;
    final current = hasOptions
        ? widget.options.cast<AppPickerOption<T>?>().firstWhere(
            (option) => option?.value == widget.value,
            orElse: () => null,
          )
        : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        key: _targetKey,
        width: widget.width,
        child: AppPickerAnchor(
          label:
              current?.label ??
              widget.placeholder ??
              (hasOptions
                  ? context.l10n.common_noSelection
                  : context.l10n.common_noOptions),
          icon: current?.icon,
          onTap: _toggleOverlay,
          enabled: widget.enabled && hasOptions,
          backgroundColor: widget.backgroundColor,
          height: widget.height,
          isExpanded: _expanded,
          hasValue: current != null,
          chevronType: AppPickerChevronType.down,
        ),
      ),
    );
  }
}
