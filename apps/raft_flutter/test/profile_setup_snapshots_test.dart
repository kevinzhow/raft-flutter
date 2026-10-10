import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_migration_view.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
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
  Completer<void>? gate;
  String detail = 'Computer is offline';
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    gets.add(path);
    await gate?.future;
    if (path == '/servers/s/setup-projection') {
      return {
        'phase': 'in_progress',
        'surface': 'computer_runtime',
        'blocksChat': true,
        'computerStatus': detail,
        'runtimeStatus': 'missing',
      };
    }
    return <dynamic>[];
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  Completer<void>? gate;
  final paths = <String>[];
  String email = 'bob@example.test';
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    paths.add(path);
    await gate?.future;
    return switch (path) {
      '/servers/s/members/u/profile' => {
        'name': 'bob',
        'displayName': 'Bob Builder',
        'role': 'member',
        'email': email,
        'createdAgents': [
          {'id': 'a1', 'name': 'helper'},
        ],
      },
      '/servers/s/members/v/profile' => {
        'name': 'vera',
        'role': 'member',
        'email': 'vera@example.test',
      },
      '/agents/a1' => {
        'id': 'a1',
        'name': 'Fixture agent',
        'creatorType': 'user',
        'creatorId': 'alice',
        'runtime': 'codex',
        'machineId': 'c1',
      },
      '/agents/a1/migration' => {
        'migration': {
          'migrationRef': 'ref-1',
          'revision': 2,
          'state': 'in_transit',
          'sourceMachineId': 'c1',
          'targetMachineId': 'c2',
        },
      },
      '/servers/s/machines' => {
        'machines': [
          {'id': 'c1', 'name': 'Source'},
          {'id': 'c2', 'name': 'Target', 'status': 'online'},
        ],
      },
      _ => <dynamic>[],
    };
  }
}

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);

/// Email values break after every character (`breakAll`).
Finder _email(String value) => find.byWidgetPredicate(
  (w) => w is Text && w.data?.replaceAll('\u200b', '') == value,
);

Finder get _spinner => find.byWidgetPredicate(
  (w) => w is CircularProgressIndicator || w is RaftSpinner,
);

void main() {
  late _Client client;
  late _Workspace w;
  setUp(() {
    client = _Client();
    w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
    await client.dispose();
  });

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> leave(WidgetTester t) async {
    await t.pumpWidget(_host(const SizedBox()));
    await t.pump();
  }

  void release(Completer<void> gate) => gate.complete();

  testWidgets(
    'member profile revisit shows the accepted detail at the first frame',
    (t) async {
      Widget page(String id) =>
          _host(MemberProfileView(controller: w, userId: id, onClose: () {}));
      await t.pumpWidget(page('u'));
      await settle(t);
      expect(_email('bob@example.test'), findsOneWidget);
      await leave(t);

      w.email = 'bob@new.test';
      final gate = Completer<void>();
      w.gate = gate;
      await t.pumpWidget(page('u'));
      // First frame: detail-only fields from the snapshot, no loading panel.
      expect(_email('bob@example.test'), findsOneWidget);
      expect(find.text('helper'), findsOneWidget);
      expect(_spinner, findsNothing);
      release(gate);
      w.gate = null;
      await settle(t);
      expect(_email('bob@new.test'), findsOneWidget);
      expect(_email('bob@example.test'), findsNothing);

      // Another member is cold, and coming back to the first is instant.
      final held = Completer<void>();
      w.gate = held;
      await t.pumpWidget(page('v'));
      await t.pump();
      expect(_email('bob@new.test'), findsNothing);
      expect(_email('vera@example.test'), findsNothing);
      release(held);
      w.gate = null;
      await settle(t);
      expect(_email('vera@example.test'), findsOneWidget);
      final again = Completer<void>();
      w.gate = again;
      await t.pumpWidget(page('u'));
      expect(_email('bob@new.test'), findsOneWidget);
      release(again);
      w.gate = null;
      await settle(t);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('member profile snapshot never crosses a role change', (t) async {
    Widget page() =>
        _host(MemberProfileView(controller: w, userId: 'u', onClose: () {}));
    await t.pumpWidget(page());
    await settle(t);
    await leave(t);
    w.server = RaftRecord({'id': 's', 'role': 'member'});
    final gate = Completer<void>();
    w.gate = gate;
    await t.pumpWidget(page());
    expect(_email('bob@example.test'), findsNothing);
    release(gate);
    w.gate = null;
    await settle(t);
  });

  testWidgets(
    'agent migration revisit shows the accepted page at the first frame',
    (t) async {
      Widget page() => _host(AgentMigrationView(controller: w, agentId: 'a1'));
      await t.pumpWidget(page());
      expect(_spinner, findsOneWidget, reason: 'true cold load');
      await settle(t);
      expect(find.text('Fixture agent'), findsOneWidget);
      await leave(t);

      final gate = Completer<void>();
      w.gate = gate;
      final reads = w.paths.length;
      await t.pumpWidget(page());
      expect(find.text('Fixture agent'), findsOneWidget);
      expect(find.textContaining('in_transit'), findsOneWidget);
      expect(_spinner, findsNothing);
      final rect = t.getRect(find.text('Fixture agent'));
      await t.pump();
      expect(
        w.paths.length,
        reads + 3,
        reason: 'revalidates in the background',
      );
      release(gate);
      w.gate = null;
      await settle(t);
      expect(t.getRect(find.text('Fixture agent')), rect);
      expect(_spinner, findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('server setup gate revisit blocks at the first frame', (t) async {
    Widget gate() =>
        _host(ServerSetupGate(controller: w, child: const Text('Chat')));
    await t.pumpWidget(gate());
    expect(find.text('Chat'), findsOneWidget, reason: 'unknown until read');
    await settle(t);
    expect(find.text('Set up your workspace'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    await t.pumpWidget(_host(const SizedBox()));
    await t.pump();

    final hold = Completer<void>();
    client.gate = hold;
    await t.pumpWidget(gate());
    // First frame: setup is still owed; chat never flashes.
    expect(find.text('Set up your workspace'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    hold.complete();
    client.gate = null;
    await settle(t);
    expect(find.text('Set up your workspace'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    expect(t.takeException(), isNull);
  });

  testWidgets('setup invalidation is scoped to its own workspace controller', (
    t,
  ) async {
    final otherClient = _Client();
    final other = _Workspace(otherClient)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    addTearDown(() async {
      other.dispose();
      await otherClient.stream.close();
      await otherClient.dispose();
    });
    await t.pumpWidget(
      _host(ServerSetupGate(controller: w, child: const Text('Chat'))),
    );
    await settle(t);
    int reads() =>
        client.gets.where((p) => p.endsWith('/setup-projection')).length;
    final before = reads();
    refreshServerSetup(other);
    await settle(t);
    expect(reads(), before, reason: 'another controller never reloads this');
    refreshServerSetup(w);
    await settle(t);
    expect(reads(), before + 1);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
