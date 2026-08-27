import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/network/api_compatibility.dart';
import '../../../../core/network/one_panel_auth.dart';
import '../../../../core/network/web_socket_connector.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/storage_service.dart';
import '../frosted_header.dart';
import '../../../features/server_detail/providers/active_server_provider.dart';
import '../../../../core/router/app_router.dart';
import 'floating_terminal_controller.dart';

Future<void> showAppTerminal(
  BuildContext context, {
  required String containerId,
  String user = 'root',
  required String command,
  String source = 'container',
  String? databaseType,
  String? databaseName,
}) {
  final container = ProviderScope.containerOf(context);
  return Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: _AppTerminalScreen(
          containerId: containerId,
          user: user,
          command: command,
          source: source,
          databaseType: databaseType,
          databaseName: databaseName,
        ),
      ),
    ),
  );
}

/// 从悬浮状态恢复终端界面。
Future<void> restoreAppTerminal(
  BuildContext context,
  FloatingTerminalState floatingState,
) {
  final container = ProviderScope.containerOf(context);
  final route = CupertinoPageRoute(
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        overrides: [
          activeServerIdProvider.overrideWithValue(floatingState.serverId),
        ],
        child: _AppTerminalScreen(
          containerId: floatingState.containerId,
          user: floatingState.user,
          command: floatingState.command,
          source: floatingState.source,
          databaseType: floatingState.databaseType,
          databaseName: floatingState.databaseName,
          floatingState: floatingState,
        ),
      ),
    ),
  );

  final navigator = rootNavigatorKey.currentState;
  if (navigator != null) {
    return navigator.push(route);
  }
  return Navigator.of(context).push(route);
}

class _AppTerminalScreen extends ConsumerStatefulWidget {
  const _AppTerminalScreen({
    required this.containerId,
    required this.user,
    required this.command,
    required this.source,
    this.databaseType,
    this.databaseName,
    this.floatingState,
  });

  final String containerId;
  final String user;
  final String command;
  final String source;
  final String? databaseType;
  final String? databaseName;

  /// 非 null 时表示从悬浮状态恢复，使用已有的 terminal/channel。
  final FloatingTerminalState? floatingState;

  @override
  ConsumerState<_AppTerminalScreen> createState() => _AppTerminalScreenState();
}

class _AppTerminalScreenState extends ConsumerState<_AppTerminalScreen> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  final FocusNode _terminalFocusNode = FocusNode();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String _statusMessage = '';
  bool _floated = false;

  @override
  void initState() {
    super.initState();
    final fs = widget.floatingState;
    if (fs != null) {
      // 从悬浮状态恢复
      _terminal = fs.terminal;
      _terminalController = fs.terminalController;
      _channel = fs.channel;
      _subscription = fs.subscription;
      _isConnected = fs.isConnected;
      _statusMessage = fs.statusMessage;
    } else {
      // 正常创建新连接
      _terminal = Terminal(maxLines: 10000);
      _terminalController = TerminalController();
      _connect();
    }
  }

  Future<void> _connect() async {
    final l10n = ref.read(appLocalizationsProvider);
    try {
      final serverId = ref.read(activeServerIdProvider);
      final storage = ref.read(storageServiceProvider);
      final server = await storage.getServer(serverId);
      final apiKey = await storage.getApiKey(serverId) ?? '';

      if (server == null) {
        if (!mounted) return;
        setState(() {
          _statusMessage = l10n.terminal_serverInfoFailed;
        });
        return;
      }

      final baseUrl = server.baseUrl.toString();
      final uri = Uri.parse(baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';

      final isDatabase = widget.source == 'database';
      final isRedis =
          isDatabase && (widget.databaseType?.contains('redis') ?? false);
      final headers = await OnePanelAuth.signedHeaders(apiKey);
      final queryParameters = {
        'cols': _terminal.viewWidth.toString(),
        'rows': _terminal.viewHeight.toString(),
        if (isRedis) ...{
          'source': widget.databaseType ?? 'redis',
          'name': widget.databaseName ?? '',
          'from': 'local',
        } else if (isDatabase) ...{
          'source': 'database',
          'databaseType': widget.databaseType ?? '',
          'database': widget.databaseName ?? '',
        } else ...{
          'source': widget.source,
          'containerid': widget.containerId,
          'user': widget.user,
          'command': widget.command,
        },
        'operateNode': 'local',
      };

      _channel = await ApiCompatibility.tryVariants<WebSocketChannel>(
        _terminalPaths(widget.source)
            .map((path) {
              final wsUrl = Uri(
                scheme: wsScheme,
                host: uri.host,
                port: uri.port,
                path: '${uri.path}$path'.replaceAll('//', '/'),
                queryParameters: queryParameters,
              );
              return ApiEndpointVariant<WebSocketChannel>(
                name: path,
                call: () async {
                  await checkAppWebSocketAuth(
                    wsUrl,
                    headers: headers,
                    allowInsecureConnections: server.allowInsecureConnections,
                    currentNode: 'local',
                  );
                  return connectAppWebSocket(
                    wsUrl,
                    headers: headers,
                    allowInsecureConnections: server.allowInsecureConnections,
                  );
                },
              );
            })
            .toList(growable: false),
        cacheScope: serverId,
        cacheKey: widget.source == 'host'
            ? 'terminal.host'
            : 'terminal.container',
      );

      _subscription = _channel!.stream.listen(
        (data) {
          if (!_isConnected) {
            if (!mounted) return;
            setState(() {
              _isConnected = true;
              _statusMessage = '';
            });
          }

          try {
            final Map<String, dynamic> msg = jsonDecode(data.toString());
            final type = msg['type'];
            final payload = msg['data'];

            if (type == 'cmd' && payload is String) {
              final decoded = utf8.decode(
                base64Decode(payload),
                allowMalformed: true,
              );
              _terminal.write(decoded);
            }
          } catch (e) {
            // If not JSON or other error, fallback to raw write if it's a string
            if (data is String) {
              _terminal.write(data);
            }
          }
        },
        onError: (e) {
          _terminal.write(
            '\r\n${l10n.terminal_connectionErrorWithDetail('$e')}\r\n',
          );
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _statusMessage = l10n.terminal_connectionError;
          });
        },
        onDone: () {
          _terminal.write('\r\n${l10n.terminal_disconnectedOutput}\r\n');
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _statusMessage = l10n.terminal_disconnected;
          });
        },
      );

      _terminal.onOutput = (data) {
        if (_isConnected) {
          final payload = jsonEncode({
            'type': 'cmd',
            'data': base64Encode(utf8.encode(data)),
          });
          _channel?.sink.add(payload);
        }
      };

      _terminal.onResize = (w, h, pw, ph) {
        if (_isConnected) {
          final payload = jsonEncode({'type': 'resize', 'cols': w, 'rows': h});
          _channel?.sink.add(payload);
        }
      };
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = l10n.terminal_initializationFailed('$e');
      });
    }
  }

  List<String> _terminalPaths(String source) {
    if (source == 'host') {
      return const ['/api/v2/hosts/terminal/local', '/api/v2/hosts/terminal'];
    }
    return const [
      '/api/v2/hosts/terminal/container',
      '/api/v2/containers/exec',
    ];
  }

  @override
  void dispose() {
    if (!_floated) {
      _subscription?.cancel();
      _channel?.sink.close();
      _terminalController.dispose();
    }
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _floatTerminal() {
    final title = widget.source == 'host'
        ? context.l10n.terminal_hostTitle
        : widget.source == 'database'
        ? context.l10n.terminal_databaseTitle(widget.databaseName ?? '')
        : context.l10n.terminal_containerTitle(widget.containerId);

    final state = FloatingTerminalState(
      id: widget.floatingState?.id,
      bubbleSnapshot: widget.floatingState?.bubbleSnapshot,
      terminal: _terminal,
      terminalController: _terminalController,
      channel: _channel,
      subscription: _subscription,
      isConnected: _isConnected,
      statusMessage: _statusMessage,
      title: title,
      containerId: widget.containerId,
      user: widget.user,
      command: widget.command,
      source: widget.source,
      databaseType: widget.databaseType,
      databaseName: widget.databaseName,
      serverId: ref.read(activeServerIdProvider),
    );

    ref.read(floatingTerminalProvider).floatTerminal(state);
    _floated = true;
    Navigator.of(context).pop();
  }

  Future<void> _copySelectionOrAll() async {
    final selection = _terminalController.selection;
    final text = selection != null
        ? _terminal.buffer.getText(selection)
        : _terminal.buffer.getText();
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _terminal.paste(text);
  }

  void _sendTerminalKey(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    _terminalFocusNode.requestFocus();
    _terminal.keyInput(key, ctrl: ctrl, alt: alt, shift: shift);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    // 明亮模式下终端配色
    final brightTheme = TerminalTheme(
      cursor: const Color(0xFF000000),
      selection: const Color(0x44000000),
      foreground: const Color(0xFF000000),
      background: AppColors.background(context),
      black: const Color(0xFF000000),
      red: const Color(0xFFCD3131),
      green: const Color(0xFF0DBC79),
      yellow: const Color(0xFF949400),
      blue: const Color(0xFF0451A5),
      magenta: const Color(0xFFBC05BC),
      cyan: const Color(0xFF0598BC),
      white: const Color(0xFF555555),
      brightBlack: const Color(0xFF666666),
      brightRed: const Color(0xFFCD3131),
      brightGreen: const Color(0xFF14CE14),
      brightYellow: const Color(0xFFB5BA00),
      brightBlue: const Color(0xFF0451A5),
      brightMagenta: const Color(0xFFBC05BC),
      brightCyan: const Color(0xFF0598BC),
      brightWhite: const Color(0xFFA5A5A5),
      searchHitBackground: const Color(0xFFFFFF00),
      searchHitBackgroundCurrent: const Color(0xFFFF9600),
      searchHitForeground: const Color(0xFF000000),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background(context),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top:
                  MediaQuery.paddingOf(context).top +
                  FrostedHeader.headerHeight,
            ),
            child: Column(
              children: [
                if (!_isConnected && _statusMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: CupertinoColors.systemRed.withValues(alpha: 0.2),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: TerminalView(
                        _terminal,
                        controller: _terminalController,
                        focusNode: _terminalFocusNode,
                        textStyle: const TerminalStyle(
                          fontSize: 14,
                          fontFamily: 'Menlo',
                        ),
                        deleteDetection: true,
                        theme: isDark
                            ? TerminalThemes.defaultTheme
                            : brightTheme,
                      ),
                    ),
                  ),
                ),
                _TerminalShortcutToolbar(
                  enabled: _isConnected,
                  onKey: _sendTerminalKey,
                  onCopy: _copySelectionOrAll,
                  onPaste: _pasteFromClipboard,
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FrostedHeader(
              title: widget.source == 'host'
                  ? context.l10n.terminal_hostTitle
                  : widget.source == 'database'
                  ? context.l10n.terminal_databaseTitle(
                      widget.databaseName ?? '',
                    )
                  : context.l10n.terminal_containerTitle(widget.containerId),
              onBack: () => Navigator.of(context).maybePop(),
              trailingBuilder: (isDark, isOverlapping) => _FrostedFloatButton(
                onTap: _floatTerminal,
                isDark: isDark,
                isOverlapping: isOverlapping,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalShortcutToolbar extends StatelessWidget {
  const _TerminalShortcutToolbar({
    required this.enabled,
    required this.onKey,
    required this.onCopy,
    required this.onPaste,
  });

  final bool enabled;
  final void Function(TerminalKey key, {bool ctrl, bool alt, bool shift}) onKey;
  final VoidCallback onCopy;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : CupertinoColors.black.withValues(alpha: 0.08);
    final backgroundColor = AppColors.secondaryBackground(
      context,
    ).withValues(alpha: isDark ? 0.78 : 0.9);

    return SafeArea(
      top: false,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            _TerminalShortcutButton.icon(
              icon: CupertinoIcons.doc_on_doc,
              tooltip: context.l10n.terminal_copySelection,
              enabled: enabled,
              onPressed: onCopy,
            ),
            _TerminalShortcutButton.icon(
              icon: CupertinoIcons.doc_on_clipboard,
              tooltip: context.l10n.terminal_pasteToTerminal,
              enabled: enabled,
              onPressed: onPaste,
            ),
            _TerminalShortcutButton.text(
              label: 'Enter',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.enter),
            ),
            _TerminalShortcutButton.text(
              label: 'Esc',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.escape),
            ),
            _TerminalShortcutButton.text(
              label: 'Tab',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.tab),
            ),
            _TerminalShortcutButton.text(
              label: 'Ctrl+C',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.keyC, ctrl: true),
            ),
            _TerminalShortcutButton.text(
              label: 'Ctrl+D',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.keyD, ctrl: true),
            ),
            _TerminalShortcutButton.text(
              label: 'Ctrl+L',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.keyL, ctrl: true),
            ),
            _TerminalShortcutButton.icon(
              icon: CupertinoIcons.arrow_left,
              tooltip: 'Left',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowLeft),
            ),
            _TerminalShortcutButton.icon(
              icon: CupertinoIcons.arrow_down,
              tooltip: 'Down',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowDown),
            ),
            _TerminalShortcutButton.icon(
              icon: CupertinoIcons.arrow_up,
              tooltip: 'Up',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowUp),
            ),
            _TerminalShortcutButton.icon(
              icon: CupertinoIcons.arrow_right,
              tooltip: 'Right',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowRight),
            ),
            _TerminalShortcutButton.text(
              label: 'Home',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.home),
            ),
            _TerminalShortcutButton.text(
              label: 'End',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.end),
            ),
            _TerminalShortcutButton.text(
              label: 'Del',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalShortcutButton extends StatelessWidget {
  const _TerminalShortcutButton.text({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) : this._(
         label: label,
         tooltip: label,
         enabled: enabled,
         onPressed: onPressed,
       );

  const _TerminalShortcutButton.icon({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) : this._(
         icon: icon,
         tooltip: tooltip,
         enabled: enabled,
         onPressed: onPressed,
       );

  const _TerminalShortcutButton._({
    this.label,
    this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = enabled
        ? AppColors.label(context)
        : AppColors.tertiaryLabel(context);
    final backgroundColor = AppColors.tertiaryBackground(
      context,
    ).withValues(alpha: enabled ? 0.88 : 0.45);

    final child = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: label == null ? const Size(36, 36) : const Size(0, 36),
      borderRadius: BorderRadius.circular(8),
      color: backgroundColor,
      disabledColor: backgroundColor,
      onPressed: enabled ? onPressed : null,
      child: SizedBox(
        height: 36,
        width: label == null ? 36 : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
          child: Center(
            child: icon == null
                ? Text(
                    label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: foregroundColor,
                    ),
                  )
                : Icon(icon, size: 17, color: foregroundColor),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(message: tooltip, child: child),
    );
  }
}

class _FrostedFloatButton extends StatelessWidget {
  const _FrostedFloatButton({
    required this.onTap,
    required this.isDark,
    required this.isOverlapping,
  });

  final VoidCallback onTap;
  final bool isDark;
  final bool isOverlapping;

  @override
  Widget build(BuildContext context) {
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
        ? CupertinoColors.systemGrey6.darkColor.withValues(
            alpha: isOverlapping ? 0.6 : 0.35,
          )
        : CupertinoColors.systemGrey6.color.withValues(
            alpha: isOverlapping ? 0.7 : 0.5,
          );

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: glowShadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? CupertinoColors.white.withValues(
                          alpha: isOverlapping ? 0.3 : 0.15,
                        )
                      : CupertinoColors.black.withValues(
                          alpha: isOverlapping ? 0.15 : 0.05,
                        ),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.rectangle_on_rectangle,
                    size: 16,
                    color: AppColors.label(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.terminal_float,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: AppColors.label(context),
                    ),
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
