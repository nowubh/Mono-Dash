import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/languages/nginx.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/dto/file/file_item_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/defer_init.dart';
import '../../../common/components/frosted_header.dart';
import '../../../common/components/frosted_overlay_menu.dart';
import '../../../common/components/skeleton_item.dart';
import '../providers/file_editor_provider.dart';
import '../providers/files_provider.dart';

class FileEditorPage extends ConsumerStatefulWidget {
  const FileEditorPage({super.key, required this.path, required this.fileName});

  final String path;
  final String fileName;

  @override
  ConsumerState<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends ConsumerState<FileEditorPage> {
  late final CodeLineEditingController _controller;
  late final CodeFindController _findController;
  final FocusNode _editorFocusNode = FocusNode();
  bool _isSearchMode = false;
  bool _isReadOnly = false;
  bool _isDirty = false;
  bool _isSaving = false;
  bool _isOverlapping = false;
  bool _hasStartedLoadingContent = false;
  String _loadedContent = '';
  AsyncValue<FileItemDto> _fileState = const AsyncValue.loading();

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController();
    _findController = CodeFindController(_controller);

    _controller.addListener(_onChanged);
    _findController.findInputController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    _onSearchChanged(_findController.findInputController.text);
  }

  void _onChanged() {
    final isDirty = _controller.text != _loadedContent;
    if (isDirty != _isDirty) {
      setState(() => _isDirty = isDirty);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _findController.findInputController.removeListener(_onSearchInputChanged);
    _controller.dispose();
    _findController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final l10n = context.l10n;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(fileEditorControllerProvider(widget.path).notifier)
          .save(_controller.text);
      if (!mounted) return;
      showAppSuccessToast(l10n.files_editorSaveSuccess);
      setState(() {
        _loadedContent = _controller.text;
        _isDirty = false;
      });
      // 保存成功后静默刷新文件列表
      ref.read(filesControllerProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(l10n.files_editorSaveFailed, description: e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _findController.value = null;
      }
    });
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      _findController.value = null;
    } else {
      _findController.value = CodeFindValue(
        replaceMode: true,
        option: CodeFindOption(
          pattern: value,
          caseSensitive: false,
          regex: false,
        ),
      );
    }
  }

  Future<void> _loadContent() async {
    if (_hasStartedLoadingContent) return;
    _hasStartedLoadingContent = true;
    setState(() => _fileState = const AsyncValue.loading());

    try {
      final file = await ref.read(
        fileEditorControllerProvider(widget.path).future,
      );
      if (!mounted) return;

      final content = file.content;
      _controller.removeListener(_onChanged);
      _controller.text = content;
      final loadedContent = _controller.text;
      _controller.addListener(_onChanged);

      setState(() {
        _loadedContent = loadedContent;
        _isDirty = false;
        _fileState = AsyncData(file);
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _fileState = AsyncError(error, stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeferInit(
      builder: (context, isReady) {
        final asyncState = isReady
            ? _fileState
            : const AsyncValue<FileItemDto>.loading();
        final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

        if (isReady && !_hasStartedLoadingContent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadContent();
          });
        }

        return CupertinoPageScaffold(
          backgroundColor: AppColors.background(context),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        if (asyncState.hasValue)
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.depth == 0) {
                                final overlapping =
                                    notification.metrics.pixels > 0;
                                if (overlapping != _isOverlapping) {
                                  setState(() => _isOverlapping = overlapping);
                                }
                              }
                              return false;
                            },
                            child: CodeEditor(
                              controller: _controller,
                              toolbarController:
                                  appCodeSelectionToolbarController(
                                    readOnly: _isReadOnly,
                                  ),
                              findController: _findController,
                              focusNode: _editorFocusNode,
                              readOnly: _isReadOnly,
                              autofocus: true,
                              padding: EdgeInsets.only(
                                top:
                                    MediaQuery.paddingOf(context).top +
                                    FrostedHeader.headerHeight,
                              ),
                              style: CodeEditorStyle(
                                fontSize: 14,
                                fontFamilyFallback: const [
                                  'SF Mono',
                                  'Menlo',
                                  'monospace',
                                ],
                                textColor: AppColors.label(context),
                                cursorColor: CupertinoColors.activeBlue
                                    .resolveFrom(context),
                                selectionColor: CupertinoColors.activeBlue
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.22),
                                codeTheme: CodeHighlightTheme(
                                  languages: {
                                    'json': CodeHighlightThemeMode(
                                      mode: langJson,
                                    ),
                                    'yaml': CodeHighlightThemeMode(
                                      mode: langYaml,
                                    ),
                                    'nginx': CodeHighlightThemeMode(
                                      mode: langNginx,
                                    ),
                                  },
                                  theme: isDark
                                      ? atomOneDarkTheme
                                      : atomOneLightTheme,
                                ),
                                backgroundColor: CupertinoColors.transparent,
                              ),
                              indicatorBuilder:
                                  (
                                    context,
                                    controller,
                                    chunkController,
                                    notifier,
                                  ) {
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.tertiaryBackground(
                                              context,
                                            ).withValues(
                                              alpha: isDark ? 0.16 : 0.38,
                                            ),
                                        border: Border(
                                          right: BorderSide(
                                            color: AppColors.separator(
                                              context,
                                            ).withValues(alpha: 0.32),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DefaultCodeLineNumber(
                                            controller: controller,
                                            notifier: notifier,
                                            textStyle: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.tertiaryLabel(
                                                context,
                                              ),
                                              fontFamilyFallback: const [
                                                'SF Mono',
                                                'Menlo',
                                                'monospace',
                                              ],
                                            ),
                                            focusedTextStyle: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.secondaryLabel(
                                                context,
                                              ),
                                              fontFamilyFallback: const [
                                                'SF Mono',
                                                'Menlo',
                                                'monospace',
                                              ],
                                            ),
                                          ),
                                          DefaultCodeChunkIndicator(
                                            width: 10,
                                            controller: chunkController,
                                            notifier: notifier,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                            ),
                          )
                        else if (asyncState.isLoading)
                          _buildEditorSkeleton()
                        else if (asyncState.hasError)
                          Center(
                            child: Text(
                              context.l10n.files_editorLoadFailed(
                                asyncState.error.toString(),
                              ),
                            ),
                          ),

                        if (asyncState.isRefreshing || _isSaving)
                          Positioned.fill(
                            child: Container(
                              color: AppColors.background(
                                context,
                              ).withValues(alpha: 0.3),
                              child: const Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isSearchMode) _buildSearchPanel(isDark),
                ],
              ),
              FrostedHeader(
                title: widget.fileName,
                isOverlapping: _isOverlapping,
                onBack: () async {
                  if (_isDirty) {
                    final result = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text(context.l10n.common_discardChangesTitle),
                        content: Text(
                          context.l10n.common_unsavedChangesContent,
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: Text(context.l10n.common_cancel),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: Text(context.l10n.common_confirm),
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ),
                    );
                    if (result != true) return;
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                trailingBuilder: (isDark, isOverlapping) {
                  if (!asyncState.hasValue) {
                    return const SizedBox.shrink();
                  }

                  return FrostedOverlayMenuButton(
                    label: context.l10n.common_menu,
                    isDark: isDark,
                    isOverlapping: isOverlapping,
                    items: [
                      FrostedMenuItem(
                        text: context.l10n.common_save,
                        icon: TablerIcons.device_floppy,
                        action: _handleSave,
                      ),
                      FrostedMenuItem(
                        text: _isSearchMode
                            ? context.l10n.files_editorCloseSearch
                            : context.l10n.files_editorFindReplace,
                        icon: TablerIcons.search,
                        action: _toggleSearch,
                      ),
                      FrostedMenuItem(
                        text: _isReadOnly
                            ? context.l10n.files_editorEnableEditing
                            : context.l10n.files_editorReadOnlyMode,
                        icon: _isReadOnly ? TablerIcons.edit : TablerIcons.eye,
                        action: () =>
                            setState(() => _isReadOnly = !_isReadOnly),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorSkeleton() {
    final topPadding =
        MediaQuery.paddingOf(context).top + FrostedHeader.headerHeight + 20;
    final lineWidths = <double>[
      0.72,
      0.88,
      0.64,
      0.80,
      0.52,
      0.92,
      0.70,
      0.58,
      0.84,
      0.46,
      0.76,
      0.66,
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(18, topPadding, 18, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const rowHeight = 10.0;
          const rowGap = 14.0;
          const maxLineCount = 25;
          final lineCount =
              ((constraints.maxHeight + rowGap) / (rowHeight + rowGap))
                  .floor()
                  .clamp(0, maxLineCount);
          final textWidth = (constraints.maxWidth - 44).clamp(
            160.0,
            double.infinity,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lineCount; i++) ...[
                Row(
                  children: [
                    SkeletonItem(
                      width: i < 9 ? 14 : (i < 99 ? 20 : 26),
                      height: 10,
                      borderRadius: 3,
                    ),
                    const SizedBox(width: 18),
                    SkeletonItem(
                      width: textWidth * lineWidths[i % lineWidths.length],
                      height: 12,
                      borderRadius: 4,
                    ),
                  ],
                ),
                if (i < lineCount - 1) const SizedBox(height: rowGap),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchPanel(bool isDark) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final borderColor = AppColors.separator(context).withValues(alpha: 0.42);
    final panelColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.82)
        : CupertinoColors.systemBackground
              .resolveFrom(context)
              .withValues(alpha: 0.88);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: panelColor,
            border: Border(top: BorderSide(color: borderColor, width: 0.5)),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(
                  alpha: isDark ? 0.26 : 0.08,
                ),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding > 0 ? 6 : 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SearchPanelField(
                        controller: _findController.findInputController,
                        placeholder: context.l10n.files_editorFindPlaceholder,
                        prefixIcon: CupertinoIcons.search,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SearchIconButton(
                      icon: CupertinoIcons.chevron_up,
                      tooltip: context.l10n.files_editorPreviousMatch,
                      isDark: isDark,
                      onPressed: () => _findController.previousMatch(),
                    ),
                    const SizedBox(width: 6),
                    _SearchIconButton(
                      icon: CupertinoIcons.chevron_down,
                      tooltip: context.l10n.files_editorNextMatch,
                      isDark: isDark,
                      onPressed: () => _findController.nextMatch(),
                    ),
                    const SizedBox(width: 6),
                    _SearchIconButton(
                      icon: CupertinoIcons.xmark,
                      tooltip: context.l10n.common_close,
                      isDark: isDark,
                      onPressed: _toggleSearch,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _SearchPanelField(
                        controller: _findController.replaceInputController,
                        placeholder:
                            context.l10n.files_editorReplaceWithPlaceholder,
                        prefixIcon: CupertinoIcons.arrow_right_arrow_left,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SearchActionButton(
                      label: context.l10n.files_editorReplace,
                      isDark: isDark,
                      onPressed: () => _findController.replaceMatch(),
                    ),
                    const SizedBox(width: 6),
                    _SearchActionButton(
                      label: context.l10n.files_editorReplaceAll,
                      isDark: isDark,
                      onPressed: () => _findController.replaceAllMatches(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchPanelField extends StatelessWidget {
  const _SearchPanelField({
    required this.controller,
    required this.placeholder,
    required this.prefixIcon,
    required this.isDark,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData prefixIcon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark
        ? CupertinoColors.systemGrey6.darkColor.withValues(alpha: 0.48)
        : CupertinoColors.systemGrey6.color.withValues(alpha: 0.72);

    return CupertinoTextField(
      controller: controller,
      autocorrect: false,
      placeholder: placeholder,
      placeholderStyle: TextStyle(
        color: AppColors.tertiaryLabel(context),
        fontSize: 14,
      ),
      style: TextStyle(color: AppColors.label(context), fontSize: 14),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 10, right: 6),
        child: Icon(
          prefixIcon,
          size: 15,
          color: AppColors.tertiaryLabel(context),
        ),
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.26),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  const _SearchIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? CupertinoColors.systemGrey5.darkColor.withValues(alpha: 0.48)
        : CupertinoColors.systemGrey6.color.withValues(alpha: 0.78);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(32, 32),
      borderRadius: BorderRadius.circular(9),
      color: color,
      onPressed: onPressed,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Icon(icon, size: 17, color: AppColors.secondaryLabel(context)),
      ),
    );
  }
}

class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({
    required this.label,
    required this.isDark,
    required this.onPressed,
  });

  final String label;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    final backgroundColor = blue.withValues(alpha: isDark ? 0.24 : 0.12);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      minimumSize: const Size(42, 32),
      borderRadius: BorderRadius.circular(9),
      color: backgroundColor,
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: blue,
        ),
      ),
    );
  }
}
