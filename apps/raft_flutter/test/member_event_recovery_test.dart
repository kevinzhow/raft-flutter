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
  final reads = <String>[];
  final server = RaftRecord({'id': 's', 'role': 'owner'});
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<List<RaftRecord>> accountServers() async {
    reads.add('/servers');
    return [server];
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    return switch (path) {
      '/servers' => [server.json],
      '/servers/s/machines' => {'machines': <dynamic>[]},
      _ => <dynamic>[],
    };
  }
}

void main() {
  late _Client c;
  late WorkspaceController w;
  setUp(() async {
    c = _Client();
    w = WorkspaceController(c)..server = c.server;
    await w.entityDirectory.preload();
    c.reads.clear();
  });
  tearDown(() async {
    w.dispose();
    await c.ingress.close();
    await c.dispose();
  });
  for (final (event, id) in [
    ('server:member-added', 'BP-RT-020'),
    ('server:member:left', 'BP-RT-069'),
    ('server:member-removed', 'BP-RT-070'),
  ]) {
    test('[$id] self $event refreshes membership, channels and DMs', () async {
      c.ingress.add(RaftEvent(event, {'serverId': 's', 'userId': 'alice'}));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(c.reads, containsAll(['/servers', '/channels', '/channels/dm']));
      expect(c.reads.where((p) => p == '/servers/s/members'), hasLength(1));
    });
  }
  test(
    'peer and foreign-server member events do not refresh own authority',
    () async {
      c.ingress.add(
        const RaftEvent('server:member-removed', {
          'serverId': 's',
          'userId': 'bob',
        }),
      );
      c.ingress.add(
        const RaftEvent('server:member:left', {
          'serverId': 'other',
          'userId': 'alice',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(c.reads, ['/servers/s/members']);
    },
  );
}
