import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';

import 'app_global_server_selector_test.dart' show RootCache;
import 'desktop_window_broker_test.dart' show Peer, owner, alpha, beta;
import 'message_presentation_test.dart' show MessageAdapter;

class ExitPeer extends Peer {
  ExitPeer(super.broker, super.id);
  int preparations = 0, cancellations = 0;
  bool accepts = true, sealed = false, fails = false;
  Completer<void>? entered, release, cancelRelease;

  void hold() {
    entered = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<bool> prepareClose() async {
    preparations++;
    sealed = true;
    if (entered?.isCompleted == false) entered!.complete();
    await release?.future;
    if (fails) throw StateError('fixture save failed');
    return accepts;
  }

  @override
  Future<void> cancelClose() async {
    cancellations++;
    await cancelRelease?.future;
    sealed = false;
  }
}

class ExitFixture {
  ExitFixture(this.client, this.api) {
    clients.add(client);
    broker = DesktopSessionBroker(
      createWindow: (binding, server, _) async {
        final peer = ExitPeer(broker, binding);
        peers.add(peer);
        if (createEntered?.isCompleted == false) createEntered!.complete();
        await createRelease?.future;
        return peer;
      },
      focusPrimary: () async => primaryFocuses++,
    );
    bind();
  }

  final RaftClient client;
  final MessageAdapter api;
  final clients = <RaftClient>[], peers = <ExitPeer>[];
  late final DesktopSessionBroker broker;
  int primaryFocuses = 0, primaryPreparations = 0;
  bool primaryAccepts = true;
  Completer<void>? createEntered, createRelease;

  static Future<ExitFixture> create() async {
    final (client, api) = await owner();
    final fixture = ExitFixture(client, api);
    addTearDown(fixture.close);
    return fixture;
  }

  void bind({RaftClient? replacement, String? server}) => broker.bind(
    replacement ?? client,
    server,
    cache: RootCache(),
    prepareClose: () async {
      primaryPreparations++;
      return primaryAccepts;
    },
  );

  Future<void> close() async {
    for (final peer in peers) {
      for (final gate in [peer.release, peer.cancelRelease]) {
        if (gate?.isCompleted == false) gate!.complete();
      }
    }
    if (createRelease?.isCompleted == false) createRelease!.complete();
    await broker.dispose();
    for (final client in clients) {
      await client.dispose();
    }
    await Future<void>.delayed(Duration.zero);
    for (final peer in peers) {
      await peer.stream.close();
    }
  }
}

Future<bool> rejected(Future<void> operation) async {
  try {
    await operation;
    return false;
  } on RaftApiException catch (error) {
    expect(error.staleScope, isTrue);
    return true;
  }
}

void main() {
  for (final route in ['primary', 'child to primary', 'existing child']) {
    test('global close blocks $route open, then a veto allows retry', () async {
      final f = await ExitFixture.create();
      if (route == 'child to primary') f.bind(server: beta.id);
      await f.broker.openServer(alpha);
      final first = f.peers.single..hold();
      final closing = f.broker.prepareExit();
      await first.entered!.future;
      final blocked = await rejected(
        route == 'child to primary'
            ? f.broker.openFromWindow(first.id, beta)
            : f.broker.openServer(route == 'existing child' ? alpha : beta),
      );
      first.accepts = false;
      first.release!.complete();
      expect(await closing, isFalse);
      expect(blocked, isTrue);
      expect(f.peers, hasLength(1));
      expect(f.primaryFocuses, 0);
      expect(first.focuses, 1);
      expect(first.sealed, isFalse);
      if (route == 'child to primary') {
        await f.broker.openFromWindow(first.id, beta);
        expect(f.primaryFocuses, 1);
      } else {
        await f.broker.openServer(beta);
        expect(f.peers, hasLength(2));
      }
    });
  }

  test('concurrent exits prepare once and keep opens blocked until rollback finishes', () async {
    final f = await ExitFixture.create();
    await f.broker.openServer(alpha);
    final peer = f.peers.single..hold();
    final first = f.broker.prepareExit();
    final second = f.broker.prepareExit();
    await peer.entered!.future;
    peer.release!.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(peer.preparations, 1);
    expect(f.primaryPreparations, 1);
    expect(await rejected(f.broker.openServer(beta)), isTrue);
    peer.cancelRelease = Completer<void>();
    f.broker.cancelClose();
    expect(await f.broker.prepareExit(), isFalse);
    expect(await rejected(f.broker.openServer(beta)), isTrue);
    peer.cancelRelease!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(peer.sealed, isFalse);
    await f.broker.openServer(beta);
    expect(await f.broker.prepareExit(), isTrue);
    expect(f.peers.every((p) => p.sealed), isTrue);
  });

  test(
    'a directory read started before close cannot create a late child',
    () async {
      final f = await ExitFixture.create();
      await f.broker.openServer(alpha);
      final first = f.peers.single..hold();
      final directory = Completer<dynamic>(), requested = Completer<void>();
      f.api.routes['GET /servers'] = (_) {
        if (!requested.isCompleted) requested.complete();
        return directory.future;
      };
      final opening = rejected(f.broker.openServer(beta));
      await requested.future;
      final closing = f.broker.prepareExit();
      await first.entered!.future;
      directory.complete([alpha.json, beta.json]);
      final blocked = await opening;
      first.release!.complete();
      expect(await closing, isTrue);
      expect(blocked, isTrue);
      expect(f.peers, hasLength(1));
    },
  );

  test('a child still being created vetoes exit and stays usable when creation finishes', () async {
    final f = await ExitFixture.create();
    f.createEntered = Completer<void>();
    f.createRelease = Completer<void>();
    final opening = f.broker.openServer(beta);
    await f.createEntered!.future;
    final accepted = await f.broker.prepareExit();
    f.createRelease!.complete();
    await opening;
    expect(accepted, isFalse);
    expect(f.peers.single.focuses, 1);
    expect(f.peers.single.closes, 0);
    expect(await f.broker.prepareExit(), isTrue);
    expect(f.peers.single.preparations, 1);
  });

  test(
    'explicit cancellation waits for the held save, unseals, and permits retry',
    () async {
      final f = await ExitFixture.create();
      await f.broker.openServer(alpha);
      final peer = f.peers.single..hold();
      final closing = f.broker.prepareExit();
      await peer.entered!.future;
      f.broker.cancelClose();
      final blocked = await rejected(f.broker.openServer(beta));
      peer.release!.complete();
      expect(await closing, isFalse);
      expect(blocked, isTrue);
      expect(peer.sealed, isFalse);
      await f.broker.openServer(beta);
      expect(await f.broker.prepareExit(), isTrue);
    },
  );

  test('an old exit cannot approve a replacement login or cancel its prepared child', () async {
    final f = await ExitFixture.create();
    await f.broker.openServer(alpha);
    final old = f.peers.single..hold();
    final closing = f.broker.prepareExit();
    await old.entered!.future;
    final (replacement, _) = await owner();
    f.clients.add(replacement);
    f.bind(replacement: replacement);
    await f.broker.openServer(beta);
    final fresh = f.peers.last..hold();
    final currentClosing = f.broker.prepareExit();
    await fresh.entered!.future;
    old.release!.complete();
    final oldAccepted = await closing;
    final newCancellations = fresh.cancellations;
    fresh.release!.complete();
    expect(await currentClosing, isTrue);
    expect(oldAccepted, isFalse);
    expect(newCancellations, 0);
    expect(fresh.sealed, isTrue);
  });

  test('a new login on the same client invalidates a held exit before root rebinds', () async {
    final f = await ExitFixture.create();
    await f.broker.openServer(alpha);
    final peer = f.peers.single..hold();
    final closing = f.broker.prepareExit();
    await peer.entered!.future;
    await f.client.login('fixture', 'fixture');
    peer.release!.complete();
    expect(await closing, isFalse);
    f.bind();
    await f.broker.openServer(beta);
    expect(await f.broker.prepareExit(), isTrue);
  });

  test(
    'a normal credential refresh preserves the current quit transaction',
    () async {
      final f = await ExitFixture.create();
      await f.broker.openServer(alpha);
      final peer = f.peers.single..hold();
      final closing = f.broker.prepareExit();
      await peer.entered!.future;
      f.api.routes['POST /auth/refresh'] = (_) => {
        'accessToken': 'rotated-fixture',
        'refreshToken': 'rotated-refresh-fixture',
      };
      await f.client.refresh();
      peer.release!.complete();
      expect(await closing, isTrue);
      expect(peer.sealed, isTrue);
      expect(peer.cancellations, 0);
    },
  );

  for (final action in ['unbind', 'dispose']) {
    test(
      '$action during a held save cannot approve an obsolete exit',
      () async {
        final f = await ExitFixture.create();
        await f.broker.openServer(alpha);
        final peer = f.peers.single..hold();
        final closing = f.broker.prepareExit();
        await peer.entered!.future;
        if (action == 'dispose') {
          await f.broker.dispose();
        } else {
          f.broker.bind(null, null);
        }
        peer.release!.complete();
        expect(await closing, isFalse);
        expect(peer.sealed, isFalse);
        expect(await rejected(f.broker.openServer(beta)), isTrue);
        if (action == 'unbind') {
          f.bind();
          await f.broker.openServer(beta);
          expect(await f.broker.prepareExit(), isTrue);
        }
      },
    );
  }

  test(
    'a failed save rolls back prepared children and permits another close',
    () async {
      final f = await ExitFixture.create();
      await f.broker.openServer(alpha);
      final peer = f.peers.single..fails = true;
      await expectLater(f.broker.prepareExit(), throwsStateError);
      expect(peer.sealed, isFalse);
      peer.fails = false;
      await f.broker.openServer(beta);
      expect(await f.broker.prepareExit(), isTrue);
    },
  );

  test(
    'the primary save veto unseals its children and permits another close',
    () async {
      final f = await ExitFixture.create();
      await f.broker.openServer(alpha);
      f.primaryAccepts = false;
      expect(await f.broker.prepareExit(), isFalse);
      expect(f.peers.single.sealed, isFalse);
      f.primaryAccepts = true;
      await f.broker.openServer(beta);
      expect(await f.broker.prepareExit(), isTrue);
    },
  );
}
