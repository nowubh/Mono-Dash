import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class ICloudKeyValueBridge {
  ICloudKeyValueBridge() {
    _installHandler();
  }

  static const _channel = MethodChannel('mono_dash/icloud_kvs');
  static final _remoteChanges = StreamController<String>.broadcast();
  static bool _handlerInstalled = false;

  Stream<String> get remoteChanges => _remoteChanges.stream;

  bool get _isSupportedPlatform => Platform.isIOS || Platform.isMacOS;

  /// True once a call has failed because the iCloud entitlement is missing.
  /// Unsigned and re-signed builds have no ubiquity-kvstore entitlement, so
  /// every call fails; remembering that keeps the app on local-only storage
  /// instead of retrying on each sync.
  static bool _isUnavailable = false;

  /// Whether iCloud key-value sync can be used in this build.
  bool get isUsable => _isSupportedPlatform && !_isUnavailable;

  Future<void> start() async {
    if (!isUsable) return;
    await _guard(() => _channel.invokeMethod<void>('start'));
  }

  Future<bool> isAvailable() async {
    if (!isUsable) return false;
    final value = await _guard(
      () => _channel.invokeMethod<bool>('isAvailable'),
    );
    return value ?? false;
  }

  Future<String?> getString(String key) async {
    if (!isUsable) return null;
    return _guard(() => _channel.invokeMethod<String>('getString', {'key': key}));
  }

  Future<void> setString(String key, String value) async {
    if (!isUsable) return;
    await _guard(
      () => _channel.invokeMethod<void>('setString', {
        'key': key,
        'value': value,
      }),
    );
  }

  /// Runs a channel call, swallowing the "iCloud is not configured" family of
  /// errors so callers can fall back to local storage. Latches [_isUnavailable]
  /// so later calls short-circuit.
  Future<T?> _guard<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      if (error.code == 'icloud_unavailable') {
        _isUnavailable = true;
        return null;
      }
      rethrow;
    } on MissingPluginException {
      _isUnavailable = true;
      return null;
    }
  }

  static void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'remoteValueChanged') return null;

      final arguments = call.arguments;
      final key = arguments is Map ? arguments['key'] as String? : null;
      if (key != null && key.isNotEmpty) {
        _remoteChanges.add(key);
      }
      return null;
    });
  }
}
