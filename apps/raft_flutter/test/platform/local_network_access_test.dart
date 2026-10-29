import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/local_network_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.raft/local-network');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  bool granted = true;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    granted = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return granted;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('classifies LAN IPv4, IPv6, and mapped addresses', () {
    for (final host in [
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.1.2',
      '169.254.1.2',
      '100.64.1.2',
      '100.127.255.254',
      '224.0.0.1',
      '255.255.255.255',
      'fc00::1',
      'fd12::1',
      'fe80::1',
      'ff02::1',
      '::ffff:192.168.1.2',
    ]) {
      expect(
        isLocalNetworkAddress(InternetAddress(host)),
        isTrue,
        reason: host,
      );
    }
    for (final host in [
      '127.0.0.1',
      '::1',
      '8.8.8.8',
      '172.15.0.1',
      '172.32.0.1',
      '100.63.255.254',
      '100.128.0.1',
      '2001:4860:4860::8888',
      '::ffff:8.8.8.8',
      '::ffff:127.0.0.1',
    ]) {
      expect(
        isLocalNetworkAddress(InternetAddress(host)),
        isFalse,
        reason: host,
      );
    }
  });

  test('passive LAN check does not request a system prompt', () async {
    await const LocalNetworkAccess().ensure('http://192.168.1.2:13041');
    expect(calls.single.method, 'ensure');
    expect(calls.single.arguments, {'request': false});
  });

  test('explicit connection requests access for IPv6 and mDNS', () async {
    for (final origin in ['http://[fd12::1]:13041', 'https://raft.local']) {
      calls.clear();
      await const LocalNetworkAccess().ensure(origin, request: true);
      expect(calls.single.arguments, {'request': true});
    }
  });

  test('permission denial surfaces an actionable connection error', () async {
    granted = false;
    await expectLater(
      const LocalNetworkAccess().ensure('http://10.1.2.3', request: true),
      throwsA(
        isA<RaftApiException>().having(
          (e) => e.message,
          'message',
          localNetworkPermissionError,
        ),
      ),
    );
  });

  test('public and loopback origins never request LAN permission', () async {
    for (final origin in [
      'https://8.8.8.8',
      'http://127.0.0.1',
      'http://[::1]',
      'http://localhost',
    ]) {
      await const LocalNetworkAccess().ensure(origin, request: true);
    }
    expect(calls, isEmpty);
  });

  test('non-Android platforms do not call the permission bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await const LocalNetworkAccess().ensure('http://10.1.2.3', request: true);
    expect(calls, isEmpty);
  });

  test(
    'fixture DNS supplies public addresses without a permission request',
    () async {
      final hosts = <String>[];
      final access = LocalNetworkAccess(
        lookup: (host) async {
          hosts.add(host);
          return [InternetAddress('203.0.113.1')];
        },
      );
      await access.ensure('https://fixture.invalid', request: true);
      expect(hosts, ['fixture.invalid']);
      expect(calls, isEmpty);
    },
  );

  test('a private DNS answer still requires the native permission', () async {
    final access = LocalNetworkAccess(
      lookup: (_) async => [
        InternetAddress('203.0.113.1'),
        InternetAddress('10.1.2.3'),
      ],
    );
    granted = false;
    await expectLater(
      access.ensure('https://fixture.invalid', request: true),
      throwsA(
        isA<RaftApiException>().having(
          (e) => e.message,
          'message',
          localNetworkPermissionError,
        ),
      ),
    );
    expect(calls.single.arguments, {'request': true});
    granted = true;
    await access.ensure('https://fixture.invalid', request: true);
    expect(calls, hasLength(2));
  });

  test('a failed DNS lookup leaves connection errors to the client', () async {
    final access = LocalNetworkAccess(
      lookup: (_) async => throw const SocketException('fixture lookup failed'),
    );
    await access.ensure('https://fixture.invalid', request: true);
    expect(calls, isEmpty);
  });

  testWidgets('a pending lookup keeps the existing five-second bound', (
    t,
  ) async {
    try {
      final held = Completer<List<InternetAddress>>();
      final access = LocalNetworkAccess(lookup: (_) => held.future);
      var complete = false;
      final checking = access
          .ensure('https://fixture.invalid', request: true)
          .then((_) => complete = true);
      await t.pump(const Duration(seconds: 4));
      expect(complete, isFalse);
      await t.pump(const Duration(seconds: 1));
      await checking;
      expect(complete, isTrue);
      expect(calls, isEmpty);
      held.complete([]);
      await t.pump();
    } finally {
      // testWidgets checks debug globals before the plain-test tearDown runs.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
