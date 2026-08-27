import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../../../core/theme/app_theme.dart';
import 'sheet_panel.dart';
import 'sheet_handle.dart';

/// 通用的 ActionSheet 骨架布局，保证了不同模块操作菜单的视觉一致性。
class ActionSheetScaffold extends StatelessWidget {
  const ActionSheetScaffold({
    super.key,
    this.infoCard,
    this.header,
    this.panelHeader,
    this.panelOverlay,
    required this.child,
    this.enableBlur = true,
    this.maxHeightFactor = 0.9,
    this.minBodyHeightFactor,
    this.backgroundAlpha,
    this.backgroundColor,
    this.isAdaptive = false,
    this.showHandle = true,
    this.isFloating = false,
    this.hasHorizontalPadding = true,
    this.contentPadding,
    this.title,
    this.trailing,
    this.scrollPhysics,
    this.useModalScrollController = true,
  });

  /// 面板标题
  final String? title;

  /// 右侧附加组件
  final Widget? trailing;

  /// 列表内容区域的内边距覆盖
  final EdgeInsetsGeometry? contentPadding;

  /// 传统的顶部信息卡片区域 (Panel 外部)
  final Widget? infoCard;

  /// 更通用的顶部区域 (Panel 外部)，如果提供则替代 infoCard
  final Widget? header;

  /// 面板内部头部区域 (Handle 下方，Scrollable 上方)
  final Widget? panelHeader;

  /// 面板内部悬浮层 (覆盖在滚动内容上方)
  final Widget? panelOverlay;

  /// 列表内容
  final Widget child;

  /// 是否启用背景模糊
  final bool enableBlur;

  /// 整体最大高度占屏幕比例
  final double maxHeightFactor;

  /// 面板内容的最小高度占屏幕比例 (website 模块需求)
  final double? minBodyHeightFactor;

  /// 面板背景透明度覆盖
  final double? backgroundAlpha;

  /// 面板背景颜色覆盖
  final Color? backgroundColor;

  /// 是否根据内容自适应高度 (默认 false，即默认占满最大高度)
  final bool isAdaptive;

  /// 是否显示顶部的拖拽手柄
  final bool showHandle;

  /// 是否为悬浮样式 (距底部有间距且全圆角)
  final bool isFloating;

  /// 是否有左右间距 (默认有)
  final bool hasHorizontalPadding;

  /// 自定义滚动物理，用于控制滚动行为
  final ScrollPhysics? scrollPhysics;

  /// 是否使用 modal_bottom_sheet 提供的滚动控制器联动拖拽。
  final bool useModalScrollController;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topArea = header ?? infoCard;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = keyboardPadding > 0
        ? keyboardPadding
        : (isFloating ? (bottomPadding > 0 ? bottomPadding : 20.0) : 0.0);
    final availableHeight = (screenHeight - keyboardPadding)
        .clamp(0.0, screenHeight)
        .toDouble();
    final baseContentPadding =
        contentPadding ??
        EdgeInsets.fromLTRB(
          16,
          panelHeader != null ? 4 : 14,
          16,
          isFloating ? 20 : bottomPadding + 20,
        );
    final borderRadius = isFloating
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: Radius.circular(24));

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hasHorizontalPadding ? 14 : 0,
          0,
          hasHorizontalPadding ? 14 : 0,
          bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: availableHeight * maxHeightFactor,
          ),
          child: Column(
            mainAxisSize: isAdaptive ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (topArea != null) ...[topArea, const SizedBox(height: 10)],
              Flexible(
                child: ActionSheetPanel(
                  enableBlur: enableBlur,
                  backgroundAlpha: backgroundAlpha,
                  backgroundColor: backgroundColor,
                  borderRadius: borderRadius,
                  child: Container(
                    decoration: isFloating
                        ? BoxDecoration(
                            borderRadius: borderRadius,
                            border: Border.all(
                              color: AppColors.separator(
                                context,
                              ).withValues(alpha: 0.12),
                              width: 0.5,
                            ),
                          )
                        : null,
                    constraints: minBodyHeightFactor != null
                        ? BoxConstraints(
                            minHeight: screenHeight * minBodyHeightFactor!,
                          )
                        : null,
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: isAdaptive
                              ? MainAxisSize.min
                              : MainAxisSize.max,
                          children: [
                            if (showHandle) const ActionSheetHandle(bottom: 0),
                            if (title != null || trailing != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (title != null)
                                      Center(
                                        child: Text(
                                          title!,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.label(context),
                                            letterSpacing: -0.4,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    if (trailing != null)
                                      Positioned(right: 0, child: trailing!),
                                  ],
                                ),
                              ),
                            ?panelHeader,
                            Flexible(
                              child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                controller:
                                    useModalScrollController &&
                                        scrollPhysics
                                            is! NeverScrollableScrollPhysics
                                    ? ModalScrollController.of(context)
                                    : null,
                                physics:
                                    scrollPhysics ??
                                    const BouncingScrollPhysics(),
                                padding: baseContentPadding,
                                child: child,
                              ),
                            ),
                          ],
                        ),
                        ?panelOverlay,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
