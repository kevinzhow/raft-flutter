import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
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
  Map<String, dynamic> row = {};
  Map<String, dynamic>? upgradeResponse;
  String? latest;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/machines')) {
      return {
        'machines': [Map<String, dynamic>.of(row)],
        'latestComputerVersion': ?latest,
      };
    }
    return [];
  }

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
    if (path.endsWith('/computer/upgrade')) return upgradeResponse ?? {};
    return <String, dynamic>{};
  }
}

final t0 = DateTime.utc(2026, 10, 21, 8);

Map<String, dynamic> pending({String id = 'r1', String target = '1.4.0'}) => {
  'id': id,
  'state': 'pending',
  'targetVersion': target,
  'requestedAt': t0.toIso8601String(),
  'observedVersion': null,
  'reason': null,
  'resolvedAt': null,
};

Map<String, dynamic> computer({
  String status = 'offline',
  Map<String, dynamic>? upgrade,
  String version = '1.3.0',
}) => {
  'id': 'm1',
  'name': 'Studio Mac',
  'isComputer': true,
  'status': status,
  'computerVersion': version,
  'lastHeartbeat': t0.add(const Duration(seconds: 5)).toIso8601String(),
  'upgradeRequest': ?upgrade,
};

void main() {
  late _Client client;
  late WorkspaceController w;
  late DateTime now;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    now = t0.add(const Duration(seconds: 30));
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
    w.services.entityDirectory.clock = () => now;
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
    await client.dispose();
  });

  Future<void> advance(WidgetTester t, Duration d) async {
    now = now.add(d);
    await t.pump(d);
  }

  Future<void> mount(WidgetTester t, Widget home, {Size? size}) async {
    t.view.physicalSize = size ?? const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(body: home),
      ),
    );
    // The reconnect card spins forever, so there is nothing to settle on.
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
  }

  // The directory's one-shot grace timer ends with the directory, which has
  // to be gone before the test body returns.
  void scenario(String name, Future<void> Function(WidgetTester t) body) =>
      testWidgets(name, (t) async {
        await body(t);
        await t.pumpWidget(const SizedBox.shrink());
        w.services.entityDirectory.dispose();
      });

  RaftComputerRow row(WidgetTester t) =>
      t.widget<RaftComputerRow>(find.byType(RaftComputerRow));

  group('sidebar rows', () {
    Widget sidebar() => SizedBox(
      width: 260,
      child: DesktopDirectoryView(
        controller: w,
        computers: true,
        onSelected: (_) {},
      ),
    );

    scenario('offline with a pending upgrade reads Upgrading with a cyan dot', (
      t,
    ) async {
      client.row = computer(upgrade: pending());
      await mount(t, sidebar());
      expect(row(t).runLabel, 'Upgrading…');
      expect(row(t).offline, isFalse);
      expect(row(t).dot, RaftComputerDot.upgrading);
      expect(find.text('Upgrading…'), findsOneWidget);
      expect(find.text('computer offline'), findsNothing);
    });

    scenario('after the 3 minute grace the row falls back to offline', (
      t,
    ) async {
      client.row = computer(upgrade: pending());
      await mount(t, sidebar());
      expect(row(t).dot, RaftComputerDot.upgrading);
      // lastHeartbeat + 3 min is 2.5 min away: still restarting.
      await advance(t, const Duration(minutes: 2));
      expect(row(t).dot, RaftComputerDot.upgrading);
      // No refresh, no socket event: the directory ends the window itself.
      await advance(t, const Duration(minutes: 1));
      expect(row(t).runLabel, 'computer offline');
      expect(row(t).offline, isTrue);
      expect(row(t).dot, RaftComputerDot.offline);
    });

    scenario('an offline Computer with no upgrade stays offline', (t) async {
      client.row = computer();
      await mount(t, sidebar());
      expect(row(t).runLabel, 'computer offline');
      expect(row(t).dot, RaftComputerDot.offline);
    });

    scenario('online keeps the version label and the online dot', (t) async {
      client.row = computer(status: 'online', upgrade: pending());
      await mount(t, sidebar());
      expect(row(t).runLabel, 'computer v1.3.0');
      expect(row(t).dot, RaftComputerDot.online);
    });

    scenario('a live online to offline event anchors the grace', (t) async {
      client.row = computer(status: 'online', upgrade: pending())
        ..['lastHeartbeat'] = t0.toIso8601String();
      await mount(t, sidebar());
      expect(row(t).dot, RaftComputerDot.online);
      // Two minutes later the Computer restarts for the upgrade.
      await advance(t, const Duration(minutes: 2));
      client.row = computer(status: 'offline', upgrade: pending())
        ..['lastHeartbeat'] = t0.toIso8601String();
      client.stream.add(
        RaftEvent('machine:status', {
          'machineId': 'm1',
          'status': 'offline',
          'statusVersion': 5,
        }),
      );
      await t.pump();
      expect(row(t).dot, RaftComputerDot.upgrading);
      // Measured from the disconnect, not from the request: 2.5 min after
      // the request is already past 3 min of the old anchor.
      await advance(t, const Duration(minutes: 2, seconds: 30));
      expect(row(t).dot, RaftComputerDot.upgrading);
      await advance(t, const Duration(minutes: 1));
      expect(row(t).dot, RaftComputerDot.offline);
    });

    scenario('the Computers list page shows the same state', (t) async {
      client.row = computer(upgrade: pending());
      await mount(
        t,
        FleetView(controller: w, computers: true),
        size: const Size(400, 900),
      );
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(row(t).runLabel, 'Upgrading…');
      expect(row(t).dot, RaftComputerDot.upgrading);
    });
  });

  group('detail page', () {
    Widget detail(Map<String, dynamic> m) => ComputerDetailPanel(
      controller: w,
      machine: m,
      remoteUpgradeV2: true,
      now: () => now,
    );

    scenario('restart for an upgrade replaces the offline recovery card', (
      t,
    ) async {
      await mount(t, detail(computer(upgrade: pending())));
      expect(find.text('Upgrading…'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
      expect(
        find.byKey(const ValueKey('computer-upgrade-reconnecting')),
        findsOneWidget,
      );
      expect(
        find.text(
          "Upgrading to v1.4.0. The Computer is restarting and will reconnect when it's done.",
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('computer-section-recovery-card')),
        findsNothing,
      );
    });

    scenario('past the grace the recovery card returns with a note', (t) async {
      await mount(t, detail(computer(upgrade: pending())));
      await advance(t, const Duration(minutes: 4));
      // The machine map is the parent's; a rebuild by the directory is enough.
      expect(find.text('Offline'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('computer-upgrade-reconnecting')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('computer-section-recovery-card')),
        findsOneWidget,
      );
      expect(
        find.text("It didn't reconnect after the upgrade to v1.4.0."),
        findsOneWidget,
      );
    });

    scenario('a plain outage keeps the recovery card and no note', (t) async {
      await mount(t, detail(computer()));
      expect(find.text('Offline'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('computer-section-recovery-card')),
        findsOneWidget,
      );
      expect(find.textContaining("didn't reconnect"), findsNothing);
    });

    scenario(
      'after the click the page keeps saying upgrading until the server settles it',
      (t) async {
        client.upgradeResponse = {'upgradeRequest': pending()};
        client.latest = '1.4.0';
        final m = computer(status: 'online')
          ..['computerUpgradeAvailable'] = true
          ..['remoteUpgradeSupported'] = true
          ..['computerBroadcastPolicy'] = {
            'eligibility': 'eligible',
            'targetVersion': '1.4.0',
            'policyRevision': 'p1',
            'reasonCode': 'ok',
          };
        client.row = m;
        await mount(t, detail(m));
        await t.tap(find.byKey(const ValueKey('computer-upgrade')));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));
        expect(
          client.writes.where((c) => c.$2.endsWith('/computer/upgrade')),
          hasLength(1),
        );
        // The refreshed row carries no pending request (a coalesced read):
        // the accepted click still holds the card.
        expect(find.text('Upgrading…'), findsOneWidget);
        expect(find.byKey(const ValueKey('computer-upgrade')), findsNothing);
        // The Computer drops offline for the restart: "Upgrading…" in the
        // header, not "Offline".
        client.stream.add(
          RaftEvent('machine:status', {
            'machineId': 'm1',
            'status': 'offline',
            'statusVersion': 9,
          }),
        );
        await t.pump();
        final dir = w.services.entityDirectory;
        final offline = Map<String, dynamic>.of(m)..['status'] = 'offline';
        expect(dir.upgradeReconnect(offline).reconnecting, isTrue);
      },
    );
  });
}
