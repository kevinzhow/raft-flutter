import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  final gets = <String>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    gets.add(path);
    if (path == '/servers/s/setup-projection') {
      return {
        'phase': 'in_progress',
        'surface': 'computer_runtime',
        'blocksChat': true,
        'computerStatus': 'online',
        'runtimeStatus': 'missing',
      };
    }
    return <dynamic>[];
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final paths = <String>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    paths.add(path);
    return switch (path) {
      '/agents' => [
        {
          'id': 'a',
          'name': 'Source Agent',
          'description': 'Ships the release',
          'status': 'active',
          'runtime': 'codex',
          'model': 'gpt-6',
          'machineId': 'c',
          'activity': 'online',
        },
      ],
      '/servers/s/machines' => {
        'machines': [
          {
            'id': 'c',
            'name': 'Source Computer',
            'status': 'online',
            'statusVersion': 3,
            'hostname': 'build-host',
            'runtimes': ['codex'],
          },
        ],
      },
      '/servers/s/members' => [
        {'userId': 'u', 'name': 'Source Human', 'role': 'member'},
      ],
      _ => <dynamic>[],
    };
  }
}

/// Every visible row: identity, text and geometry.
List<String> _rows(WidgetTester t, Finder rows) => [
  for (final element in rows.evaluate())
    [
      element.widget.key,
      for (final text
          in find
              .descendant(
                of: find.byWidget(element.widget),
                matching: find.byType(Text),
              )
              .evaluate())
        (text.widget as Text).data ??
            (text.widget as Text).textSpan?.toPlainText(),
      t.getRect(find.byWidget(element.widget)),
    ].join('|'),
];

/// Presence, session, activity heartbeat and capability frames that fire
/// constantly in a live workspace. None of them changes a visible fact here.
const _heartbeats = [
  RaftEvent('agent:activity', {
    'agentId': 'a',
    'activity': 'online',
    'isHeartbeat': true,
  }),
  RaftEvent('agent:seen', {
    'agentId': 'a',
    'lastSeenAt': '2026-10-10T10:00:00.000Z',
  }),
  RaftEvent('agent:session', {'agentId': 'a', 'sessionId': 'session-2'}),
  RaftEvent('machine:capabilities', {
    'machineId': 'c',
    'runtimes': ['codex', 'claude'],
    'hostname': 'build-host',
  }),
  RaftEvent('machine:status', {
    'machineId': 'c',
    'status': 'online',
    'statusVersion': 3,
  }),
];

void main() {
  late _Client client;
  late _Workspace w;
  Future<void> setUpWorkspace(WidgetTester t) async {
    client = _Client();
    w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    // A previous visit (or the workspace boot) already accepted the lists.
    await w.entityDirectory.preload();
  }

  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: SizedBox(width: child is FleetView ? 640 : 320, child: child),
    ),
  );

  Future<void> expectStableThroughHeartbeats(
    WidgetTester t,
    Finder rows,
    List<String> first,
  ) async {
    final reads = w.paths.length;
    for (final event in _heartbeats) {
      client.stream.add(event);
      for (var frame = 0; frame < 4; frame++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(_rows(t, rows), first, reason: '${event.name} frame $frame');
        expect(find.text('Loading...'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }
    }
    await t.pump(const Duration(milliseconds: 400));
    expect(_rows(t, rows), first);
    expect(w.paths.length, reads, reason: 'heartbeats never touch HTTP');
  }

  for (final computers in [false, true]) {
    testWidgets(
      'desktop ${computers ? 'Computers' : 'Members'} column paints rows at the first frame on revisit and stays identical through status events',
      (t) async {
        await setUpWorkspace(t);
        final reads = w.paths.length;
        Widget view() => DesktopDirectoryView(
          controller: w,
          computers: computers,
          onSelected: (_) {},
        );
        final rows = find.byType(RaftNavItem);
        for (var visit = 0; visit < 2; visit++) {
          await t.pumpWidget(host(view()));
          // First frame: final rows, no loading shell, no request.
          expect(find.text('Loading...'), findsNothing);
          expect(
            find.text(computers ? 'Source Computer' : 'Source Agent'),
            findsOneWidget,
          );
          if (!computers) expect(find.text('Source Human'), findsOneWidget);
          final first = _rows(t, rows);
          expect(first, isNotEmpty);
          await t.pump();
          expect(_rows(t, rows), first);
          expect(w.paths.length, reads);
          await expectStableThroughHeartbeats(t, rows, first);
          await t.pumpWidget(const SizedBox.shrink());
        }
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'fleet ${computers ? 'computer' : 'agent'} list paints rows at the first frame on revisit and stays identical through status events',
      (t) async {
        await setUpWorkspace(t);
        final reads = w.paths.length;
        final rows = find.byType(ListTile);
        for (var visit = 0; visit < 2; visit++) {
          await t.pumpWidget(
            host(FleetView(controller: w, computers: computers)),
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(
            find.byKey(ValueKey('fleet-${computers ? 'c' : 'a'}')),
            findsOneWidget,
          );
          final first = _rows(t, rows);
          expect(first, hasLength(1));
          expect(w.paths.length, reads);
          await expectStableThroughHeartbeats(t, rows, first);
          await t.pumpWidget(const SizedBox.shrink());
        }
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a real machine transition patches only its row in place, then one recovery read converges',
    (t) async {
      await setUpWorkspace(t);
      await t.pumpWidget(host(FleetView(controller: w, computers: true)));
      expect(find.textContaining('online · build-host'), findsOneWidget);
      final reads = w.paths.length;
      client.stream.add(
        const RaftEvent('machine:status', {
          'machineId': 'c',
          'status': 'offline',
          'statusVersion': 4,
        }),
      );
      await t.pump();
      expect(find.textContaining('offline · build-host'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(w.paths.length, reads);
      await t.pump(const Duration(milliseconds: 200));
      // Source machineStatus recovery: machines and agents, never members.
      expect(
        w.paths.sublist(reads),
        unorderedEquals(['/servers/s/machines', '/agents']),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'setup gate re-reads the projection only when machines or the agent set change',
    (t) async {
      await setUpWorkspace(t);
      await t.pumpWidget(
        host(ServerSetupGate(controller: w, child: const Text('Chat'))),
      );
      await t.pump();
      expect(find.text('Set up your workspace'), findsOneWidget);
      int projections() =>
          client.gets.where((p) => p.endsWith('/setup-projection')).length;
      expect(projections(), 1);
      for (final event in [
        ..._heartbeats.where((e) => e.name != 'machine:capabilities'),
        const RaftEvent('agent:updated', {'agentId': 'a'}),
        const RaftEvent('server:member-added', {
          'serverId': 's',
          'userId': 'v',
        }),
      ]) {
        client.stream.add(event);
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(projections(), 1, reason: 'no setup read on heartbeat events');
      // A newly detected runtime is what this step is waiting for.
      client.stream.add(
        const RaftEvent('machine:capabilities', {
          'machineId': 'c',
          'runtimes': ['codex', 'claude'],
        }),
      );
      await t.pump(const Duration(milliseconds: 300));
      expect(projections(), 2);
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    },
  );
}
