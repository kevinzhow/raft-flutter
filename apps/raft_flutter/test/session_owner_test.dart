import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/session_owner.dart';

SendPort? _registered() => IsolateNameServer.lookupPortByName(sessionOwnerName);

/// Stand-in for a dead guest: a registration whose isolate is gone.
void _registerDead() {
  final port = ReceivePort();
  expect(
    IsolateNameServer.registerPortWithName(port.sendPort, sessionOwnerName),
    isTrue,
  );
  port.close();
}

class _Store implements SessionStore {
  Session? stored;
  Completer<void>? slowWrite;
  int writes = 0;
  @override
  Future<Session?> read(String origin) async => stored;
  @override
  Future<void> write(String origin, Session? session) async {
    await slowWrite?.future;
    writes++;
    stored = session;
  }
}

Session _session(String token) =>
    Session(accessToken: token, refreshToken: token, cachedUser: {'id': 'a'});

void main() {
  tearDown(() {
    IsolateNameServer.removePortNameMapping(sessionOwnerName);
  });

  group('foreground claim', () {
    test('is synchronous and settled when nothing else is registered', () async {
      final ui = NativeSessionOwner(supported: true);
      addTearDown(ui.release);
      var settled = false;
      ui.claim().then((_) => settled = true);
      expect(ui.claimed, isTrue);
      expect(_registered(), isNotNull);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isTrue);
    });

    test('never waits for a hung guest: registered at once, settle is bounded', () async {
      final guestWork = Completer<void>(); // never completes: a stuck guest
      var preempts = 0;
      final guest = NativeSessionOwner(
        supported: true,
        onPreempt: () {
          preempts++;
          return guestWork.future;
        },
      );
      final ui = NativeSessionOwner(supported: true);
      addTearDown(guest.release);
      addTearDown(ui.release);
      expect(guest.registerGuest(), isTrue);
      final guestPort = _registered();

      final watch = Stopwatch()..start();
      final settled = ui.claim();
      // The foreground owns the registration before any guest answers.
      expect(ui.claimed, isTrue);
      expect(_registered(), isNot(guestPort));
      expect(watch.elapsedMilliseconds, lessThan(50));

      var settledDone = false;
      unawaited(settled.then((_) => settledDone = true));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(preempts, 1);
      expect(settledDone, isFalse, reason: 'only rotation waits, and bounded');
      await settled.timeout(guestSettleTimeout + const Duration(seconds: 1));
      expect(settledDone, isTrue);
    });

    test('guest confirms after draining; its release keeps the foreground registration', () async {
      final drained = Completer<void>();
      final guest = NativeSessionOwner(
        supported: true,
        onPreempt: () => drained.future,
      );
      final ui = NativeSessionOwner(supported: true);
      addTearDown(guest.release);
      addTearDown(ui.release);
      guest.registerGuest();
      final settled = ui.claim();
      var done = false;
      unawaited(settled.then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(done, isFalse);
      drained.complete();
      await settled;
      expect(done, isTrue);
      final mine = _registered();
      guest.release();
      expect(_registered(), mine);
    });

    test('replaces a stale registration of a dead isolate immediately', () async {
      _registerDead();
      final ui = NativeSessionOwner(supported: true);
      addTearDown(ui.release);
      final settled = ui.claim();
      expect(ui.claimed, isTrue);
      await settled.timeout(guestSettleTimeout + const Duration(seconds: 1));
    });

    test('claim is idempotent', () async {
      final ui = NativeSessionOwner(supported: true);
      addTearDown(ui.release);
      final first = ui.claim();
      final port = _registered();
      expect(identical(ui.claim(), first), isTrue);
      expect(_registered(), port);
    });
  });

  group('guest', () {
    test('never takes the session from a live foreground', () async {
      final ui = NativeSessionOwner(supported: true);
      final guest = NativeSessionOwner(supported: true);
      addTearDown(ui.release);
      addTearDown(guest.release);
      ui.claim();
      expect(guest.registerGuest(), isFalse);
      expect(ui.claimed, isTrue);
    });

    test('delegates polling to a live foreground, single-flight', () async {
      var polls = 0;
      final release = Completer<bool>();
      final ui = NativeSessionOwner(
        supported: true,
        poll: () {
          polls++;
          return release.future;
        },
      );
      addTearDown(ui.release);
      ui.claim();
      final a = NativeSessionOwner.probe();
      final b = NativeSessionOwner.probe();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      release.complete(true);
      expect(await a, (OwnerProbe.delegated, true));
      expect(await b, (OwnerProbe.delegated, true));
      expect(polls, 1);
    });

    test('a stale registration is reclaimed after one short probe', () async {
      _registerDead();
      final result = await NativeSessionOwner.probe(
        timeout: const Duration(milliseconds: 100),
      );
      expect(result.$1, OwnerProbe.none);
      expect(_registered(), isNull);
      final guest = NativeSessionOwner(supported: true);
      addTearDown(guest.release);
      expect(guest.registerGuest(), isTrue);
    });

    test('reports a live guest as busy instead of waiting for it', () async {
      final first = NativeSessionOwner(supported: true);
      addTearDown(first.release);
      first.registerGuest();
      final watch = Stopwatch()..start();
      final result = await NativeSessionOwner.probe();
      expect(result.$1, OwnerProbe.busy);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('guest credential writes', () {
    test('are dropped after preemption', () async {
      final inner = _Store()..stored = _session('a');
      final guest = GuestSessionStore(inner);
      await guest.read('o');
      await guest.write('o', _session('b'));
      expect(inner.stored!.refreshToken, 'b');
      await guest.preempt();
      await guest.write('o', _session('c'));
      expect(inner.stored!.refreshToken, 'b');
    });

    test('preempt drains an in-flight write before confirming', () async {
      final inner = _Store()
        ..stored = _session('a')
        ..slowWrite = Completer<void>();
      final guest = GuestSessionStore(inner);
      await guest.read('o');
      final write = guest.write('o', _session('b'));
      await Future<void>.delayed(Duration.zero);
      var drained = false;
      unawaited(guest.preempt().then((_) => drained = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(drained, isFalse);
      inner.slowWrite!.complete();
      await write;
      await Future<void>.delayed(Duration.zero);
      expect(drained, isTrue);
    });

    test('never overwrite credentials the foreground has since changed', () async {
      final inner = _Store()..stored = _session('a');
      final guest = GuestSessionStore(inner);
      await guest.read('o');
      inner.stored = _session('foreground-rotated');
      await guest.write('o', _session('stale-guest'));
      expect(inner.stored!.refreshToken, 'foreground-rotated');
      inner.stored = null; // logout
      await guest.write('o', _session('stale-guest'));
      expect(inner.stored, isNull);
    });
  });
}
