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
}
