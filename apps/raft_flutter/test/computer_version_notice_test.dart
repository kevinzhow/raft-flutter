import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/computer_version_tier.dart';
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
  String? version = '1.0.46',
  Map<String, dynamic>? gate = const {
    'reason': 'computer_version_unsupported',
    'minVersion': '1.0.47',
    'enforced': false,
  },
  bool mine = true,
  bool upgradable = true,
}) => {
  'id': 'm1',
  'name': 'Studio Mac',
  'isComputer': true,
  'status': 'online',
  'os': 'darwin',
  'computerVersion': ?version,
  'versionGate': gate,
  'computerAttachedByCurrentUser': mine,
  'remoteUpgradeSupported': true,
  'computerUpgradeAvailable': upgradable,
  'computerBroadcastPolicy': upgradable
      ? {'eligibility': 'eligible', 'targetVersion': '1.0.47'}
      : null,
};

Finder _inDialog(String label) => find
    .descendant(of: find.byType(RaftConfirmDialog), matching: find.text(label))
    .last;

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
    t.view.physicalSize = const Size(900, 1600);
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

  final notice = find.byKey(const ValueKey('computer-version-notice'));

  group('computerVersionTier', () {
    test('judges the server gate; a server without one gets the floor', () {
      expect(
        computerVersionTier(machine(gate: null)).kind,
        ComputerTierKind.none,
      );
      expect(computerVersionTier(machine()).kind, ComputerTierKind.upgrade);
      expect(
        computerVersionTier(machine(version: '1.0.30')).kind,
        ComputerTierKind.reinstall,
      );
      expect(
        computerVersionTier(machine(version: null)).kind,
        ComputerTierKind.unreported,
      );
      final bare = machine()..remove('versionGate');
      expect(computerVersionTier(bare).kind, ComputerTierKind.upgrade);
    });
  });

  testWidgets('below the floor: Upgrade soon, one click, behind a confirm', (
    t,
  ) async {
    await mount(t, machine());
    expect(notice, findsOneWidget);
    expect(find.text('Upgrade soon'), findsOneWidget);
    expect(
      find.text('v1.0.46 is out of date. Please upgrade to v1.0.47 or later.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('computer-version-notice-upgrade')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('computer-upgrade-confirm')), findsOne);
    expect(
      find.textContaining('restarts into v1.0.47, which disconnects it'),
      findsOneWidget,
    );
    expect(client.writes, isEmpty, reason: 'asking posts nothing');
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 300));
    expect(client.writes, isEmpty);
    await t.tap(find.byKey(const ValueKey('computer-version-notice-upgrade')));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(_inDialog('Upgrade'));
    await t.pump(const Duration(milliseconds: 300));
    expect(client.writes.map((c) => c.$2), [
      '/servers/s/machines/m1/computer/upgrade',
    ]);
    await leave(t);
  });

  testWidgets('too old to upgrade from here: reinstall with the command', (
    t,
  ) async {
    await mount(t, machine(version: '1.0.30', upgradable: false));
    expect(find.text('This version needs a reinstall'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('computer-version-notice-upgrade')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('computer-version-notice-reinstall')),
      findsOneWidget,
    );
    expect(find.text('Install guide'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('computer-version-notice-reinstall')),
        matching: find.byType(RaftCopyableCode),
      ),
      findsOneWidget,
    );
    await leave(t);
  });

  testWidgets('a member who cannot manage is told to ask an admin', (t) async {
    await mount(t, machine(mine: false, upgradable: false));
    expect(find.text('Ask an admin to upgrade it.'), findsOneWidget);
    expect(find.text('Install guide'), findsNothing);
    await leave(t);
  });

  testWidgets('no notice at or above the floor', (t) async {
    await mount(t, machine(version: '1.0.47', gate: null));
    expect(notice, findsNothing);
    await leave(t);
  });

  testWidgets(
    'online without a version waits 20 s, then asks for a reinstall',
    (t) async {
      await mount(t, machine(version: null, upgradable: false));
      expect(notice, findsNothing);
      await t.pump(unreportedVersionGrace - const Duration(seconds: 1));
      expect(notice, findsNothing);
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 100));
      expect(notice, findsOneWidget);
      expect(
        find.text("This computer doesn't report its version"),
        findsOneWidget,
      );
      await leave(t);
    },
  );

  testWidgets('Restart asks first and posts only once confirmed', (t) async {
    await mount(t, machine(gate: null, version: '1.0.47', upgradable: false));
    await t.ensureVisible(find.byKey(const ValueKey('computer-restart')));
    await t.tap(find.byKey(const ValueKey('computer-restart')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('computer-restart-confirm')), findsOne);
    expect(client.writes, isEmpty);
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 300));
    expect(client.writes, isEmpty);
    await t.tap(find.byKey(const ValueKey('computer-restart')));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(_inDialog('Restart'));
    await t.pump(const Duration(milliseconds: 300));
    expect(client.writes.map((c) => c.$2), [
      '/servers/s/machines/m1/computer/restart',
    ]);
    await t.pump(const Duration(seconds: 61));
    await leave(t);
  });
}
