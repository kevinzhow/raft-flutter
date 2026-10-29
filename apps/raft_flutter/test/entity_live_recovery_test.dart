import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

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
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
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
            'hostname': hostname,
            'status': 'online',
            'statusVersion': 3,
          },
        ],
      },
      _ => <dynamic>[],
    };
  }
}

Future<void> drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() async {
    c = _Client();
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
    await w.entityDirectory.preload();
    c.ingress.add(const RaftEvent('connected', null));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  tearDown(() async {
    w.dispose();
    await c.ingress.close();
    await c.dispose();
  });
  test(
    'reconnect recovers a missed Computer change in the shared directory',
    () async {
      final before = w.reads.where((p) => p.endsWith('/machines')).length;
      w.hostname = 'after reconnect';
      c.ingress.add(const RaftEvent('disconnected', null));
      c.ingress.add(const RaftEvent('connected', null));
      await drain();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(w.entityDirectory.computer('c')!['hostname'], 'after reconnect');
      expect(w.reads.where((p) => p.endsWith('/machines')).length, before + 1);
    },
  );
  test(
    'foreground recovery includes Computers without opening their page',
    () async {
      w.hostname = 'after foreground';
      w.resumeLiveSession();
      await drain();
      expect(w.entityDirectory.computer('c')!['hostname'], 'after foreground');
    },
  );
  test(
    '[BP-RT-034] legacy daemon status shares the versioned Computer state',
    () {
      final before = w.reads.length;
      c.ingress.add(
        const RaftEvent('daemon:status', {
          'daemonId': 'c',
          'status': 'offline',
          'statusVersion': 4,
        }),
      );
      expect(w.entityDirectory.computer('c')!['status'], 'offline');
      c.ingress.add(
        const RaftEvent('daemon:status', {
          'daemonId': 'c',
          'status': 'online',
          'statusVersion': 2,
        }),
      );
      expect(w.entityDirectory.computer('c')!['status'], 'offline');
      expect(
        w.reads.length,
        before,
        reason: 'The Web daemon alias patches only; no list reload.',
      );
    },
  );
}
