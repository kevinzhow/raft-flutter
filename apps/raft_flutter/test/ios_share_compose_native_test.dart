import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native compose revalidates identity and limits, streams bytes and retries idempotently', () async {
    final root = await Directory.systemTemp.createTemp(
      'raft-share-compose-test-',
    );
    try {
      final binary = '${root.path}/compose-checks';
      final compile = await Process.run('xcrun', [
        'swiftc',
        '-parse-as-library',
        'ios/Shared/ShareInboxWriter.swift',
        'ios/Shared/ShareSessionVault.swift',
        'ios/Shared/ShareComposeClient.swift',
        'ios/ShareComposeTests/main.swift',
        '-o',
        binary,
      ]);
      expect(
        compile.exitCode,
        0,
        reason: '${compile.stdout}\n${compile.stderr}',
      );
      final result = await Process.run(binary, []);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('native compose checks passed:'));
    } finally {
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isMacOS);
}
