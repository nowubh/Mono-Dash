import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iCloud payload includes and restores API keys', () async {
    final source = await File(
      'lib/core/storage/storage_service.dart',
    ).readAsString();

    expect(source, contains('_applyApiKeysFromPayload(remotePayload'));
    expect(source, contains('includeApiKeys: true'));
    expect(source, isNot(contains('synchronizable: true')));
  });
}
