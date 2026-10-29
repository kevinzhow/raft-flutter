import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/session_persistence.dart';

class DelayedStore implements SessionStore {
  final MemorySessionStore memory = MemorySessionStore();
  Completer<void>? nextWrite;
  @override
  Future<Session?> read(String origin) => memory.read(origin);
  @override
  Future<void> write(String origin, Session? session) async {
    final delay = nextWrite;
    nextWrite = null;
    if (delay != null) await delay.future;
    await memory.write(origin, session);
  }
}

Session session(String marker) =>
    Session(accessToken: marker, refreshToken: marker);
void main() {
  test(
    'a superseded distinct candidate cannot persist after its response arrives',
    () async {
      final store = SessionPersistence(MemorySessionStore());
      var attempt = 1;
      final first = store.guarded(() => attempt == 1);
      final second = store.guarded(() => attempt == 2);
      attempt = 2;
      await second.write('https://fixture.invalid', session('new-fixture'));
      await first.write('https://fixture.invalid', session('old-fixture'));
      expect(
        (await store.read('https://fixture.invalid'))!.accessToken,
        'new-fixture',
      );
    },
  );
  test(
    'logout follows an already running write; later stale writes stay rejected',
    () async {
      final delegate = DelayedStore(), gate = Completer<void>();
      delegate.nextWrite = gate;
      final store = SessionPersistence(delegate);
      var selected = true;
      final candidate = store.guarded(() => selected);
      final running = candidate.write(
        'https://fixture.invalid',
        session('fixture'),
      );
      await Future<void>.delayed(Duration.zero);
      selected = false;
      final clear = store.write('https://fixture.invalid', null);
      final late = candidate.write(
        'https://fixture.invalid',
        session('late-fixture'),
      );
      gate.complete();
      await Future.wait([running, clear, late]);
      expect(await store.read('https://fixture.invalid'), isNull);
    },
  );
  test('a new login after logout persists after the queued clear', () async {
    final store = SessionPersistence(MemorySessionStore());
    final clear = store.write('https://fixture.invalid', null);
    final login = store
        .guarded(() => true)
        .write('https://fixture.invalid', session('new-fixture'));
    await Future.wait([clear, login]);
    expect(
      (await store.read('https://fixture.invalid'))!.accessToken,
      'new-fixture',
    );
  });

  test(
    'logout queues before a new login while the worker owns credentials',
    () async {
      const origin = 'https://fixture.invalid';
      final delegate = MemorySessionStore();
      final store = SessionPersistence(delegate), ownership = Completer<void>();
      await delegate.write(origin, session('old-fixture'));
      final clear = store.clearAfter(origin, ownership.future);
      final login = store.write(origin, session('new-login-fixture'));
      // A different engine completes rotation before handing off ownership.
      await delegate.write(origin, session('rotated-fixture'));
      ownership.complete();
      expect((await clear)?.refreshToken, 'rotated-fixture');
      await login;
      expect((await store.read(origin))?.refreshToken, 'new-login-fixture');
    },
  );

  test(
    'logout cannot clear another principal stored by the previous owner',
    () async {
      const origin = 'https://fixture.invalid';
      final store = SessionPersistence(MemorySessionStore());
      final bob = Session(
        accessToken: 'bob-fixture',
        refreshToken: 'bob-fixture',
        cachedUser: {'id': 'bob'},
      );
      await store.write(origin, bob);
      expect(
        await store.clearAfter(
          origin,
          Future<void>.value(),
          principal: 'alice',
        ),
        isNull,
      );
      expect((await store.read(origin))?.cachedUser?['id'], 'bob');
    },
  );
}
