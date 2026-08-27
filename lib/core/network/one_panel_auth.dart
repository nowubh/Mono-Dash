import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'app_user_agent.dart';

class OnePanelAuth {
  const OnePanelAuth._();

  static Future<Map<String, String>> signedHeaders(String apiKey) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final token = sign(apiKey, timestamp);
    final userAgent = await AppUserAgent.value;
    return {
      '1Panel-Token': token,
      '1Panel-Timestamp': timestamp,
      HttpHeaders.userAgentHeader: userAgent,
    };
  }

  static String sign(String apiKey, String timestamp) {
    return md5.convert(utf8.encode('1panel$apiKey$timestamp')).toString();
  }
}
