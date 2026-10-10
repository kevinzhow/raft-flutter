import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_activity_flag.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }
  final pending = <Completer<dynamic>>[];
  final flags = <dynamic>[];
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<dynamic> post(String path, {dynamic data}) {
    expect(path, '/feature-flags/evaluate');
    flags.add(data);
    final result = Completer<dynamic>();
    pending.add(result);
    return result.future;
  }
}

Map<String, dynamic> value(bool enabled) => {
  'evaluations': [
    {'key': 'activity_sidebar_inbox_v0', 'enabled': enabled},
  ],
};
Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    '[N22a] unknown keeps legacy threshold; only actual evaluated receipt enables md',
    () async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': 'member'});
      final flag = DesktopActivityFlag(w);
      addTearDown(() {
        flag.dispose();
        w.dispose();
      });
      expect(flag.masterDetail(900), false);
      expect(flag.masterDetail(1024), true);
      expect(client.flags.single['keys'], ['activity_sidebar_inbox_v0']);
      client.pending.single.complete(value(true));
      await flush();
      expect(flag.masterDetail(768), true);
      expect(flag.masterDetail(767), false);
    },
  );
  test(
    'late old-server flag cannot replace accepted new-server result',
    () async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'a', 'role': 'owner'});
      final flag = DesktopActivityFlag(w);
      addTearDown(() {
        flag.dispose();
        w.dispose();
      });
      w.server = RaftRecord({'id': 'b', 'role': 'member'});
      w.notifyListeners();
      expect(client.pending, hasLength(2));
      client.pending[1].complete(value(false));
      await flush();
      client.pending[0].complete(value(true));
      await flush();
      expect(flag.masterDetail(900), false);
    },
  );
  test('same-generation role change revokes old evaluated presentation immediately', () async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'});
    final flag = DesktopActivityFlag(w);
    addTearDown(() {
      flag.dispose();
      w.dispose();
    });
    client.pending[0].complete(value(true));
    await flush();
    expect(flag.masterDetail(900), true);
    final generation = client.generation;
    w.server = RaftRecord({'id': 's', 'role': 'member'});
    w.notifyListeners();
    expect(client.generation, generation);
    expect(flag.masterDetail(900), false);
    client.pending[1].completeError(const RaftApiException('Denied'));
    await flush();
    expect(flag.masterDetail(900), false);
  });
  test(
    'server:updated re-evaluates without flipping the accepted presentation',
    () async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      final flag = DesktopActivityFlag(w);
      var notifications = 0;
      flag.addListener(() => notifications++);
      addTearDown(() {
        flag.dispose();
        w.dispose();
      });
      client.pending.single.complete(value(true));
      await flush();
      expect(flag.enabled, isTrue);
      notifications = 0;
      client.ingress.add(const RaftEvent('server:updated', {'id': 's'}));
      expect(client.pending, hasLength(2));
      // The Activity page is not switched to the legacy layout and back.
      expect(flag.enabled, isTrue);
      expect(notifications, 0);
      client.pending[1].complete(value(true));
      await flush();
      expect(flag.enabled, isTrue);
      expect(notifications, 0);
      client.ingress.add(const RaftEvent('server:updated', {'id': 's'}));
      client.pending[2].complete(value(false));
      await flush();
      expect(flag.enabled, isFalse);
      expect(notifications, 1);
    },
  );
}
