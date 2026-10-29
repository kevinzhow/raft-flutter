// Debug-only entrypoint that proves the system-proxy path on a device
// (docs/system-proxy.md). It starts the real proxy bootstrap, shows the real
// Settings > Network page, and sends one API-style request, one attachment-style
// request and one Socket.IO WebSocket handshake to HOST (a name only the test
// proxy can resolve). Results are printed as `PROXYPROBE {json}` lines for
// `adb logcat`; the host side is packages/raft_client/test/device_proxy_host_test.dart.
//
//   tool/flutter build apk --debug --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/proxy_probe_main.dart \
//     --dart-define=PROBE_HOST=api.test:PORT
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/network_settings.dart';
import 'package:raft_flutter/platform/attachment_http.dart';
import 'package:raft_flutter/platform/system_proxy_bootstrap.dart';
import 'package:raft_ui/raft_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:socket_io_client/socket_io_client.dart' as sio;

const _host = String.fromEnvironment('PROBE_HOST', defaultValue: 'api.test:1');

void _emit(String step, Map<String, Object?> data) =>
    // ignore: avoid_print
    print('PROXYPROBE ${jsonEncode({'step': step, ...data})}');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevicePreferences.load();
  await startSystemProxy(
    preferences: DevicePreferences.current,
    origins: ['http://$_host'],
  );
  runApp(
    MaterialApp(
      theme: raftTheme(),
      home: const Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: NetworkSettingsPage(origin: 'http://$_host'),
          ),
        ),
      ),
    ),
  );
  unawaited(_probe());
}

Future<void> _probe() async {
  final url = Uri.parse('http://$_host/');
  final proxy = SystemProxy.instance;
  final snapshot = proxy.snapshotOrNull;
  _emit('snapshot', {
    'mode': snapshot?.mode.name,
    'http': snapshot?.http?.authority,
    'https': snapshot?.https?.authority,
    'socksOnly': snapshot?.socksOnly,
    'findProxy': proxy.findProxy(url),
    'status': '${proxy.status(url)}',
  });
  try {
    final api = RaftClient(
      origin: 'http://$_host',
      sessionStore: MemorySessionStore(),
    );
    final r = await api.http.get<dynamic>('/ping');
    _emit('api', {'ok': true, 'status': r.statusCode});
  } catch (error) {
    _emit('api', {'ok': false, 'error': '$error'});
  }
  try {
    final r = await AttachmentHttp.create().get<dynamic>('http://$_host/file');
    _emit('attachment', {'ok': true, 'status': r.statusCode});
  } catch (error) {
    _emit('attachment', {'ok': false, 'error': '$error'});
  }
  final connected = Completer<String>();
  final socket = sio.io(
    'http://$_host',
    applyProxyTransport(sio.OptionBuilder().setTransports(['websocket']))
        .disableAutoConnect()
        .enableForceNew()
        .build(),
  );
  socket.onConnect((_) => connected.complete('connected'));
  socket.onConnectError((e) {
    if (!connected.isCompleted) connected.complete('error: $e');
  });
  socket.connect();
  _emit('websocket', {
    'result': await connected.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => 'timeout',
    ),
  });
  socket.dispose();
  _emit('done', {});
}
