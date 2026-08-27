import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/one_panel_auth.dart';
import '../../../../core/network/web_socket_connector.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../data/repositories_impl/file_repository_impl.dart';
import '../../../common/components/wave_progress_item.dart';
import '../../server_detail/providers/active_server_provider.dart';

class WgetProcessInfo {
  WgetProcessInfo({
    required this.name,
    this.total = 0,
    this.written = 0,
    this.percent = 0.0,
    this.speed = 0.0,
  });

  final String name;
  final int total;
  final int written;
  final double percent;
  final double speed;

  factory WgetProcessInfo.fromJson(
    Map<String, dynamic> json, {
    double speed = 0.0,
  }) {
    return WgetProcessInfo(
      name: json['name'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      written: (json['written'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      speed: speed,
    );
  }
}

class WgetTaskTracker extends ConsumerStatefulWidget {
  const WgetTaskTracker({super.key, this.onActiveTasksChanged});

  final ValueChanged<bool>? onActiveTasksChanged;

  @override
  ConsumerState<WgetTaskTracker> createState() => WgetTaskTrackerState();
}

class WgetTaskTrackerState extends ConsumerState<WgetTaskTracker> {
  List<String> _keys = [];
  Map<String, WgetProcessInfo> _processes = {};

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _timer;
  bool _isConnected = false;
  String _completedName = '';

  @override
  void initState() {
    super.initState();
    _initAndConnect();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _completedName = context.l10n.remoteDownload_completedName;
  }

  Future<void> _initAndConnect() async {
    try {
      final repo = await ref.read(fileRepositoryProvider.future);
      final initialKeys = await repo.wgetProcessKeys();
      if (!mounted) return;

      setState(() {
        _keys = initialKeys;
      });

      widget.onActiveTasksChanged?.call(_keys.isNotEmpty);

      if (_keys.isNotEmpty) {
        _connectWebSocket();
      }
    } catch (_) {}
  }

  Future<void> _connectWebSocket() async {
    _timer?.cancel();
    _subscription?.cancel();
    await _channel?.sink.close();

    try {
      final serverId = ref.read(activeServerIdProvider);
      final storage = ref.read(storageServiceProvider);
      final server = await storage.getServer(serverId);
      final apiKey = await storage.getApiKey(serverId) ?? '';

      if (server == null) return;

      final baseUrl = server.baseUrl.toString();
      final uri = Uri.parse(baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final headers = await OnePanelAuth.signedHeaders(apiKey);

      final wsUrl = Uri(
        scheme: wsScheme,
        host: uri.host,
        port: uri.port,
        path: '${uri.path}/api/v2/files/wget/process'.replaceAll('//', '/'),
        queryParameters: {'operateNode': 'local'},
      );

      await checkAppWebSocketAuth(
        wsUrl,
        headers: headers,
        allowInsecureConnections: server.allowInsecureConnections,
        currentNode: 'local',
      );
      final channel = connectAppWebSocket(
        wsUrl,
        headers: headers,
        allowInsecureConnections: server.allowInsecureConnections,
      );

      _channel = channel;

      _subscription = channel.stream.listen(
        (data) {
          try {
            final raw = data.toString();
            final Map<String, WgetProcessInfo> nextProcesses = Map.from(
              _processes,
            );

            if (raw == 'null' || raw.isEmpty) {
              for (final key in _keys) {
                if (nextProcesses[key] == null ||
                    nextProcesses[key]!.percent < 100.0) {
                  nextProcesses[key] = WgetProcessInfo(
                    name: _processes[key]?.name ?? _completedName,
                    percent: 100.0,
                    total: _processes[key]?.total ?? 0,
                    written: _processes[key]?.total ?? 0,
                  );
                }
              }
            } else {
              final decoded = jsonDecode(raw);
              List<dynamic> msg = [];
              if (decoded is List) {
                msg = decoded;
              } else if (decoded is Map && decoded['data'] is List) {
                msg = decoded['data'];
              }

              for (int i = 0; i < msg.length && i < _keys.length; i++) {
                final key = _keys[i];
                if (msg[i] != null) {
                  final newWritten = (msg[i]['written'] as num?)?.toInt() ?? 0;
                  final oldWritten = _processes[key]?.written ?? 0;
                  final currentSpeed = (newWritten - oldWritten).toDouble();

                  nextProcesses[key] = WgetProcessInfo.fromJson(
                    msg[i],
                    speed: currentSpeed,
                  );
                } else {
                  nextProcesses[key] = WgetProcessInfo(
                    name: _processes[key]?.name ?? _completedName,
                    percent: 100.0,
                    total: _processes[key]?.total ?? 0,
                    written: _processes[key]?.total ?? 0,
                    speed: 0,
                  );
                }
              }
            }

            if (mounted) {
              setState(() {
                _processes = nextProcesses;
              });

              final completedKeys = nextProcesses.entries
                  .where((e) => e.value.percent >= 100.0)
                  .map((e) => e.key)
                  .toList();

              if (completedKeys.isNotEmpty) {
                for (final k in completedKeys) {
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted && _keys.contains(k)) {
                      setState(() {
                        _keys.remove(k);
                        _processes.remove(k);
                        widget.onActiveTasksChanged?.call(_keys.isNotEmpty);
                      });
                      if (_keys.isEmpty) _closeConnection();
                    }
                  });
                }
              }
            }
          } catch (e) {
            debugPrint('Wget WebSocket Parse Error: $e');
          }
        },
        onError: (e) {
          debugPrint('Wget WebSocket Error: $e');
          if (mounted) setState(() => _isConnected = false);
        },
        onDone: () {
          if (mounted) setState(() => _isConnected = false);
        },
      );

      await channel.ready.timeout(const Duration(seconds: 15));
      if (!mounted || _channel != channel) {
        channel.sink.close();
        return;
      }

      setState(() => _isConnected = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isConnected && _keys.isNotEmpty) {
          final payload = jsonEncode({'type': 'wget', 'keys': _keys});
          _channel?.sink.add(payload);
        }
      });
    } catch (_) {}
  }

  void refreshKeys() {
    _initAndConnect();
  }

  Future<void> _stopTask(String key) async {
    try {
      final repo = await ref.read(fileRepositoryProvider.future);
      await repo.wgetStop(key);
      if (mounted) {
        setState(() {
          _keys.remove(key);
          _processes.remove(key);
          widget.onActiveTasksChanged?.call(_keys.isNotEmpty);
        });
        if (_keys.isEmpty) _closeConnection();
      }
    } catch (_) {}
  }

  void _closeConnection() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  @override
  void dispose() {
    _closeConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                TablerIcons.activity,
                size: 18,
                color: AppColors.secondaryLabel(context),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.remoteDownload_progressCenterTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              const Spacer(),
              if (_isConnected && _keys.isNotEmpty)
                const CupertinoActivityIndicator(radius: 6),
            ],
          ),
        ),
        if (_keys.isEmpty)
          _buildEmptyState()
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.separator(context).withValues(alpha: 0.1),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _keys.map((key) {
                final process = _processes[key];
                final isLast = key == _keys.last;
                return Column(
                  children: [
                    _WgetTaskItem(
                      key: ValueKey(key),
                      keyString: key,
                      process: process,
                      onStop: () => _stopTask(key),
                    ),
                    if (!isLast)
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.only(left: 56),
                        color: AppColors.separator(
                          context,
                        ).withValues(alpha: 0.1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 12, top: 14, bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondaryLabel(context).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              TablerIcons.cloud_download,
              color: AppColors.tertiaryLabel(context).withValues(alpha: 0.5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.remoteDownload_emptyTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.remoteDownload_emptySubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 独立的任务项组件（简化为 StatelessWidget，波浪动画由 WaveProgressLayer 管理）
class _WgetTaskItem extends StatelessWidget {
  const _WgetTaskItem({
    super.key,
    required this.keyString,
    this.process,
    required this.onStop,
  });

  final String keyString;
  final WgetProcessInfo? process;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final percent = process?.percent ?? 0.0;
    final name = process?.name ?? context.l10n.remoteDownload_resolvingName;
    final total = process?.total ?? 0;
    final written = process?.written ?? 0;
    final isDone = percent >= 100.0;

    final accentColor = CupertinoColors.systemGreen.resolveFrom(context);

    return Stack(
      children: [
        Positioned.fill(
          child: WaveProgressLayer(
            progress: percent / 100.0,
            color: accentColor.withValues(alpha: 0.12),
            smoothDuration: const Duration(seconds: 1),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(
            left: 16,
            right: 12,
            top: 14,
            bottom: 14,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDone
                      ? CupertinoIcons.checkmark_circle_fill
                      : TablerIcons.cloud_download,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.label(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                        if (process != null && process!.speed > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatByteRate(process!.speed.toInt()),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.systemOrange.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          total > 0
                              ? '${formatBytes(written)} / ${formatBytes(total)}'
                              : formatBytes(written),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isDone)
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  minSize: 0,
                  onPressed: onStop,
                  child: Icon(
                    TablerIcons.x,
                    size: 18,
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
