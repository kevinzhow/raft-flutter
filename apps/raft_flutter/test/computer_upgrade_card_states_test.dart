import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final writes = <(String, String, dynamic)>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/machines')
      ? {'machines': <dynamic>[], 'latestComputerVersion': '1.0.47'}
      : [];
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
    if (method == 'GET') return get(path, query: query);
    writes.add((method, path, data));
    return <String, dynamic>{};
  }
}

Map<String, dynamic> machine({
  String version = '1.0.46',
  bool supported = true,
  Map<String, dynamic>? policy,
  Map<String, dynamic>? request,
}) => {
  'id': 'm1',
  'name': 'Studio Mac',
  'isComputer': true,
  'status': 'online',
  'os': 'darwin',
  'computerVersion': version,
  'versionGate': null,
  'computerAttachedByCurrentUser': true,
  'remoteUpgradeSupported': supported,
  'computerUpgradeAvailable': true,
  'computerBroadcastPolicy':
      policy ?? {'eligibility': 'eligible', 'targetVersion': '1.0.47'},
  'upgradeRequest': ?request,
};

void main() {
  late _Client client;
  late WorkspaceController w;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'member', 'slug': 'fixture'});
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
    await client.dispose();
  });

  Future<void> mount(WidgetTester t, Map<String, dynamic> m) async {
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ComputerDetailPanel(controller: w, machine: m),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> leave(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    w.services.entityDirectory.dispose();
  }

  final status = find.byKey(const ValueKey('computer-upgrade-status'));
  String statusText(WidgetTester t) => t.widget<RaftCssText>(status).data ?? '';

  testWidgets('a draining Computer says how many agents it waits for', (
    t,
  ) async {
    await mount(
      t,
      machine(
        request: {
          'id': 'r1',
          'state': 'pending',
          'phase': 'draining',
          'drainingAgentIds': ['a', 'b'],
          'targetVersion': '1.0.47',
          'requestedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );
    expect(
      statusText(t),
      'Waiting for 2 agents on this server to finish their work, then upgrading to v1.0.47 (up to 10 min).',
    );
    expect(find.byKey(const ValueKey('computer-restart')), findsNothing);
    await leave(t);
  });

  testWidgets('Raft Desktop keeps its Computer current: a note, no button', (
    t,
  ) async {
    await mount(
      t,
      machine(
        policy: {
          'eligibility': 'eligible',
          'reasonCode': 'managed_by_desktop',
          'targetVersion': '1.0.47',
        },
      ),
    );
    expect(statusText(t), 'Raft Desktop keeps this Computer up to date.');
    expect(find.byKey(const ValueKey('computer-upgrade')), findsNothing);
    await leave(t);
  });

  testWidgets('the server says the web cannot upgrade it: the install line', (
    t,
  ) async {
    await mount(t, machine(supported: false));
    expect(
      statusText(t),
      "v1.0.47 is available. This computer can't be upgraded from the web; run this on that machine instead:",
    );
    expect(find.byKey(const ValueKey('computer-upgrade-manual')), findsOne);
    expect(find.byKey(const ValueKey('computer-upgrade')), findsNothing);
    await leave(t);
  });

  testWidgets('too old to upgrade from the web: points at the notice', (
    t,
  ) async {
    final m = machine(version: '1.0.30')
      ..['versionGate'] = {
        'reason': 'computer_version_unsupported',
        'minVersion': '1.0.47',
        'enforced': false,
      };
    await mount(t, m);
    expect(
      statusText(t),
      "This version can't be upgraded from the web. Reinstall it with the command at the top of this page.",
    );
    await leave(t);
  });

  for (final (name, version, target, text) in [
    (
      'an old Computer names both causes',
      '1.0.46',
      '1.0.47',
      'too old to report what happened',
    ),
    (
      'a current Computer says it plainly',
      '1.0.55',
      '1.0.60',
      'got no response from the Computer',
    ),
  ]) {
    testWidgets('no response from $name', (t) async {
      await mount(
        t,
        machine(
          version: version,
          request: {
            'id': 'r1',
            'state': 'no_response',
            'targetVersion': target,
          },
        ),
      );
      expect(find.textContaining(text), findsOneWidget);
      await leave(t);
    });
  }
}
