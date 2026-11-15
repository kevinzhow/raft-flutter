// Web v1.24 hooks/useServerRuntimeCatalog.ts `useRuntimeDeprecatedHere`:
// whether a runtime is deprecated is this server's answer (GET
// /servers/:id/runtimes), not the bundled catalog's. Antigravity is
// deprecated in the bundle but offered again where the server's OAR flag is
// on, so the agent profile (AgentProfileInfo.tsx:233, 832-836) shows neither
// "(deprecated)" nor the deprecated-runtime banner there. A server too old to
// answer falls back to the bundle.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }

  /// The server's runtime catalog; null answers 404 (a server too old).
  Map<String, dynamic>? catalog;
  final reads = <String>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    reads.add(path);
    if (path == '/agents') return [_agent];
    if (path == '/agents/a1' && method == 'GET') return _agent;
    if (path == '/servers/s/runtimes') {
      return catalog ??
          (throw const RaftApiException('Not found', status: 404));
    }
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'm1',
            'name': 'Box',
            'status': 'online',
            'runtimes': ['antigravity'],
          },
        ],
      };
    }
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    return [];
  }
}

const _agent = <String, dynamic>{
  'id': 'a1',
  'name': 'alpha',
  'displayName': 'Alpha',
  'status': 'online',
  'activity': 'online',
  'runtime': 'antigravity',
  'model': 'default',
  'machineId': 'm1',
  'creatorType': 'user',
  'creatorId': 'alice',
};

const _warning =
    'This agent uses a deprecated runtime. It can keep running, but new agents cannot select this runtime.';

Future<_Client> _show(WidgetTester t, Map<String, dynamic>? catalog) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(900, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = _Client()
    ..catalog = catalog
    ..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: FleetDetail(
          controller: w,
          computers: false,
          initial: _agent,
          onClose: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('a runtime this server offers again is not deprecated here', (
    t,
  ) async {
    final c = await _show(t, {
      'catalogVersion': 1,
      'runtimes': [
        {'id': 'antigravity', 'deprecated': false, 'experimental': false},
      ],
    });
    expect(c.reads, contains('/servers/s/runtimes'));
    expect(find.text('Antigravity CLI'), findsWidgets);
    expect(find.text('Antigravity CLI (deprecated)'), findsNothing);
    expect(find.text(_warning), findsNothing);
  });

  testWidgets('a server too old to answer keeps the bundled deprecation', (
    t,
  ) async {
    await _show(t, null);
    expect(find.text('Antigravity CLI (deprecated)'), findsWidgets);
    expect(find.text(_warning), findsOneWidget);
  });

  testWidgets('a server that still deprecates it shows the banner', (t) async {
    await _show(t, {
      'catalogVersion': 1,
      'runtimes': [
        {'id': 'antigravity', 'deprecated': true, 'experimental': false},
      ],
    });
    expect(find.text('Antigravity CLI (deprecated)'), findsWidgets);
    expect(find.text(_warning), findsOneWidget);
  });
}
