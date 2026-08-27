import 'dart:async';
import 'dart:convert';
import 'dart:io' hide HttpException;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'network_exceptions.dart';

WebSocketChannel connectAppWebSocket(
  Uri url, {
  Map<String, dynamic>? headers,
  bool allowInsecureConnections = false,
}) {
  final client = allowInsecureConnections
      ? (HttpClient()..badCertificateCallback = (_, _, _) => true)
      : null;

  final socket = WebSocket.connect(
    url.toString(),
    headers: headers,
    customClient: client,
  ).whenComplete(() => client?.close(force: true));

  return IOWebSocketChannel(socket);
}

Future<void> checkAppWebSocketAuth(
  Uri url, {
  Map<String, dynamic>? headers,
  bool allowInsecureConnections = false,
  String? currentNode,
  Duration timeout = const Duration(seconds: 5),
  bool allowPlainHttpHandshakeError = true,
}) async {
  final httpUrl = url.replace(scheme: url.scheme == 'wss' ? 'https' : 'http');
  final client = HttpClient();
  client.badCertificateCallback = (_, _, _) => allowInsecureConnections;

  try {
    final request = await client.getUrl(httpUrl).timeout(timeout);
    request.headers.set(HttpHeaders.acceptLanguageHeader, 'zh');
    if (currentNode != null && currentNode.isNotEmpty) {
      request.headers.set('CurrentNode', Uri.encodeComponent(currentNode));
    }
    headers?.forEach((key, value) {
      request.headers.set(key, value.toString());
    });

    final response = await request.close().timeout(timeout);
    final statusCode = response.statusCode;
    final contentType = response.headers.contentType?.mimeType ?? '';
    final body = contentType == 'application/json'
        ? await utf8.decoder.bind(response).join()
        : '';
    if (contentType != 'application/json') {
      await response.drain<void>();
    }

    if (statusCode == 401) {
      throw AuthException('WebSocket 认证失败', statusCode: statusCode);
    }
    if (statusCode == 404 || statusCode == 405) {
      throw HttpException(
        'HTTP Status code $statusCode',
        statusCode: statusCode,
      );
    }
    if (allowPlainHttpHandshakeError &&
        _isPlainHttpHandshakeError(statusCode) &&
        body.isEmpty) {
      return;
    }
    if (statusCode >= 400) {
      throw HttpException(
        'HTTP Status code $statusCode${body.isEmpty ? '' : ': $body'}',
        statusCode: statusCode,
      );
    }
    if (body.isEmpty) return;

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final code = decoded['code'];
      if (code is int && code != 200) {
        final message =
            decoded['message']?.toString() ??
            decoded['msg']?.toString() ??
            'WebSocket 预检失败';
        throw ApiBusinessException(code, message);
      }
    }
  } on SocketException catch (error) {
    throw NetworkConnectionException('WebSocket 预检失败: $error');
  } on TimeoutException catch (error) {
    throw NetworkConnectionException('WebSocket 预检超时: $error');
  } finally {
    client.close(force: true);
  }
}

bool _isPlainHttpHandshakeError(int statusCode) {
  return statusCode == HttpStatus.badRequest ||
      statusCode == HttpStatus.upgradeRequired;
}
