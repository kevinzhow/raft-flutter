import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/native_sharing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('passes three staged pages in one ordered native share call', () async {
    const channel = MethodChannel('raft-selection-test');
    final sent = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sent.add(call);
          return null;
        });
    final sharing = NativeSharing(channel: channel, supported: true);
    addTearDown(sharing.dispose);
    final leases = [
      for (var i = 1; i <= 3; i++)
        SharedFileLease(
          File('/tmp/raft-test-lease-$i/page-$i.png'),
          staged: false,
        )..cancelExpiry(),
    ];
    await sharing.shareFiles(leases, 'image/png');
    expect(sent.single.method, 'share');
    expect(sent.single.arguments, {
      'paths': [for (final lease in leases) lease.file.path],
      'mimeType': 'image/png',
    });
  });
}
