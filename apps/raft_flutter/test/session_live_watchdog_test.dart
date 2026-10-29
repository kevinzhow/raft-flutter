import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/live_session_recovery.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  int connects = 0;
  bool live = true;
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  bool get connected => live;
  @override
  void connect() => connects++;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        '/servers' => [
          {'id': 's', 'role': 'owner', 'name': 'Fixture'},
        ],
        _ => <dynamic>[],
      };
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final reads = <String>[];
  String hostname = 'before';
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    return switch (path) {
      '/servers/s/machines' => {
        'machines': [
          {
            'id': 'c',
            'name': 'Computer',
            'status': 'online',
            'hostname': hostname,
          },
        ],
      },
      _ => <dynamic>[],
    };
  }
}

void main() {
  late DateTime at;
  late _Client c;
  late _Workspace w;
  setUp(() async {
    at = DateTime.utc(2026, 10, 23);
    c = _Client();
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
    w.services.liveConnection!.clock = () => at;
    await w.entityDirectory.preload();
    c.ingress.add(const RaftEvent('connected', null));
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    w.dispose();
    await c.ingress.close();
    await c.dispose();
  });
  test('[BP-RT-044] silence requires both windows and reconnects once while pending', () {
    at = at.add(const Duration(seconds: 110));
    w.services.liveConnection!.check();
    expect(c.connects, 0);
    at = at.add(const Duration(seconds: 20));
    c.ingress.add(
      const RaftEvent('agent:session', {
        'agentId': 'a',
        'sessionId': 'fresh-inbound',
      }),
    );
    w.services.liveConnection!.check();
    expect(
      c.connects,
      0,
      reason: 'Recent inbound traffic keeps the socket alive.',
    );
    at = at.add(const Duration(seconds: 121));
    w.services.liveConnection!.check();
    expect(c.connects, 1);
    w.services.liveConnection!.check();
    expect(c.connects, 1);
  });
  testWidgets(
    '[BP-RT-049] visible status recovery is bounded and pauses while hidden',
    (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final recovery = LiveSessionRecovery(clock: () => at)..bind(w);
      addTearDown(recovery.dispose);
      final agents = w.reads.where((p) => p == '/agents').length;
      final computers = w.reads.where((p) => p.endsWith('/machines')).length;
      final members = w.reads.where((p) => p.endsWith('/members')).length;
      w.hostname = 'after safety reconcile';
      for (var i = 0; i < 60; i++) {
        at = at.add(const Duration(seconds: 10));
        c.ingress.add(const RaftEvent('heartbeat', {}));
        await t.pump(const Duration(seconds: 10));
      }
      expect(c.connects, 0);
      expect(w.reads.where((p) => p == '/agents').length, agents + 1);
      expect(
        w.reads.where((p) => p.endsWith('/machines')).length,
        computers + 1,
      );
      expect(w.reads.where((p) => p.endsWith('/members')).length, members);
      expect(
        w.entityDirectory.computer('c')!['hostname'],
        'after safety reconcile',
      );
      final before = w.reads.length;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      at = at.add(const Duration(minutes: 20));
      await t.pump(const Duration(minutes: 20));
      expect(w.reads.length, before);
      expect(c.connects, 0);
      recovery.bind(null);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(minutes: 20));
      expect(w.reads.length, before);
      expect(c.connects, 0);
    },
  );
  testWidgets('watchdog starts on connect and stops while disconnected', (
    t,
  ) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    c.live = false;
    final recovery = LiveSessionRecovery(clock: () => at)..bind(w);
    addTearDown(recovery.dispose);
    at = at.add(const Duration(minutes: 20));
    await t.pump(const Duration(minutes: 20));
    expect(c.connects, 0);
    c.live = true;
    c.ingress.add(const RaftEvent('connected', null));
    at = at.add(const Duration(seconds: 121));
    await t.pump(const Duration(seconds: 10));
    expect(c.connects, 1);
    c.live = false;
    c.ingress.add(const RaftEvent('disconnected', null));
    at = at.add(const Duration(seconds: 121));
    await t.pump(const Duration(seconds: 10));
    expect(c.connects, 1);
    c.live = true;
    c.ingress.add(const RaftEvent('connected', null));
    at = at.add(const Duration(seconds: 121));
    await t.pump(const Duration(seconds: 10));
    expect(c.connects, 2);
    recovery.dispose();
  });
}
