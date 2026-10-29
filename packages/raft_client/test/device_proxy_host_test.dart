// Host side of the on-device proof (apps/raft_flutter/integration_test/
// proxy_probe_main.dart). Skipped unless RAFT_DEVICE_PROXY_PROBE is set:
//
//   RAFT_DEVICE_PROXY_PROBE=<seconds> RAFT_DEVICE_PROXY_PORT=<port> \
//     RAFT_DEVICE_WEB_PORT=<port> tool/flutter test \
//     packages/raft_client/test/device_proxy_host_test.dart
//
// Starts a plain web/socket.io server and a proxy on the host's loopback (the
// emulator reaches it as 10.0.2.2) and reports every request the proxy saw.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/test_proxy.dart';

void main() {
  final seconds = int.tryParse(
    Platform.environment['RAFT_DEVICE_PROXY_PROBE'] ?? '',
  );
  test(
    'device traffic arrives through the proxy',
    () async {
      final web = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        int.parse(Platform.environment['RAFT_DEVICE_WEB_PORT']!),
      );
      web.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          socket.add(
            '0{"sid":"eio1","upgrades":[],"pingInterval":25000,'
            '"pingTimeout":20000,"maxPayload":1000000}',
          );
          socket.listen((m) {
            if (m is String && m.startsWith('40')) socket.add('40{"sid":"s1"}');
          });
          return;
        }
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'path': request.uri.path}));
        await request.response.close();
      });
      final proxy = await TestProxy.start(
        hosts: {'api.test:${web.port}': web.port},
        port: int.parse(Platform.environment['RAFT_DEVICE_PROXY_PORT'] ?? '0'),
      );
      // ignore: avoid_print
      print('HOST web=${web.port} proxy=${proxy.port}');
      await Future<void>.delayed(Duration(seconds: seconds!));
      // ignore: avoid_print
      print('PROXY SAW ${proxy.seen.length}: ${proxy.seen.join(' | ')}');
      await proxy.close();
      await web.close(force: true);
      expect(proxy.seen, isNotEmpty);
    },
    skip: seconds == null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
