import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';

import 'app_global_server_selector_test.dart' show RootCache;

import 'message_presentation_test.dart' show MessageAdapter;

final alpha = RaftRecord({'id': 'a', 'slug': 'alpha'});
final beta = RaftRecord({'id': 'b', 'slug': 'beta'});

class Peer implements DesktopWindowPeer, SharedSessionAuthority {
  Peer(this.broker, this.id);
  final DesktopSessionBroker broker;
  @override
  final String id;
  int focuses = 0, closes = 0;
  @override
  Future<bool> prepareClose() async => true;
  @override
  Future<void> cancelClose() async {}
  Completer<void>? readGate;
  bool dead = false;
  final stream = StreamController<SharedSessionSnapshot?>.broadcast();
  @override
  Future<void> focus() async {
    if (dead) throw StateError('closed');
    focuses++;
  }

  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<void> publish(SharedSessionSnapshot? snapshot) async {
    stream.add(snapshot);
  }

  @override
  Stream<SharedSessionSnapshot?> get changes => stream.stream;
  @override
  Future<SharedSessionSnapshot?> read() async {
    await readGate?.future;
    return broker.snapshot(id);
  }

  @override
  Future<SharedSessionSnapshot> refresh(int revision) =>
      broker.refresh(id, revision);
  @override
  Future<void> end(SessionEndReason reason) => broker.end(id, reason);
  @override
  Future<SharedSessionSnapshot> synchronizeUser() => broker.synchronizeUser(id);
}

class NoWrites extends MemorySessionStore {
  int writes = 0;
  @override
  Future<void> write(String origin, Session? session) async {
    writes++;
  }
}

Future<(RaftClient, MessageAdapter)> owner() async {
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'first',
    'refreshToken': 'refresh-first',
    'user': {'id': 'human'},
  };
  api.routes['GET /auth/me'] = (_) => {'id': 'human'};
  api.routes['GET /servers'] = (_) => [alpha.json, beta.json];
  api.routes['POST /auth/logout'] = (_) => {'ok': true};
  final client = RaftClient(
    origin: 'https://coordinator.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = api,
    recoveryBackoff: const [],
  );
  await client.login('fixture', 'fixture');
  return (client, api);
}

void main() {
  test('deduplicates a live matching window, keeps primary selection and revalidates membership', () async {
    final (client, api) = await owner();
    client.selectServer('a');
    final peers = <Peer>[];
    late DesktopSessionBroker broker;
    broker = DesktopSessionBroker(
      createWindow: (binding, server, _) async {
        final peer = Peer(broker, binding);
        peers.add(peer);
        return peer;
      },
      focusPrimary: () async {},
    );
    broker.bind(client, 'a', cache: RootCache());
    await Future.wait([broker.openServer(beta), broker.openServer(beta)]);
    expect(peers, hasLength(1));
    await broker.openServer(beta);
    expect(peers.single.focuses, 2);
    expect(client.serverId, 'a');
    api.routes['GET /servers'] = (_) => [alpha.json];
    await expectLater(
      broker.openServer(beta),
      throwsA(isA<RaftApiException>()),
    );
    expect(peers.single.focuses, 2);
    await broker.dispose();
    await client.dispose();
  });

  test(
    'binding follows child server changes, closed peers are recreated',
    () async {
      final (client, _) = await owner();
      final peers = <Peer>[];
      late DesktopSessionBroker broker;
      broker = DesktopSessionBroker(
        createWindow: (id, server, _) async {
          final peer = Peer(broker, id);
          peers.add(peer);
          return peer;
        },
        focusPrimary: () async {},
      );
      broker.bind(client, null, cache: RootCache());
      await broker.openServer(beta);
      await broker.bindServer(peers.single.id, 'a');
      await broker.openServer(alpha);
      expect(peers, hasLength(1));
      peers.single.dead = true;
      await broker.openServer(alpha);
      expect(peers, hasLength(2));
      await broker.dispose();
      await client.dispose();
    },
  );

  test(
    'logout retires pending creates and rejects late membership responses',
    () async {
      final (client, api) = await owner();
      final held = Completer<Peer>();
      final entered = Completer<void>();
      late DesktopSessionBroker broker;
      broker = DesktopSessionBroker(
        createWindow: (id, server, _) {
          entered.complete();
          return held.future;
        },
        focusPrimary: () async {},
      );
      broker.bind(client, null, cache: RootCache());
      final opening = broker.openServer(beta);
      final rejected = expectLater(opening, throwsA(isA<RaftApiException>()));
      await entered.future;
      broker.bind(null, null);
      final peer = Peer(broker, 'late');
      held.complete(peer);
      await rejected;
      expect(peer.closes, 1);
      expect(peer.focuses, 0);
      broker.bind(client, null, cache: RootCache());
      final membership = Completer<dynamic>();
      api.routes['GET /servers'] = (_) => membership.future;
      final other = expectLater(
        broker.openServer(beta),
        throwsA(isA<RaftApiException>()),
      );
      broker.bind(null, null);
      membership.complete([beta.json]);
      await other;
      await broker.dispose();
      await client.dispose();
    },
  );

  test(
    'two normal clients share one rotation owner and no child persistence',
    () async {
      final (primary, api) = await owner();
      int rotations = 0, logouts = 0;
      final gate = Completer<void>();
      api.routes['POST /auth/refresh'] = (_) async {
        rotations++;
        await gate.future;
        return {'accessToken': 'second', 'refreshToken': 'refresh-second'};
      };
      api.routes['POST /auth/logout'] = (_) {
        logouts++;
        return {'ok': true};
      };
      final peers = <Peer>[];
      late DesktopSessionBroker broker;
      broker = DesktopSessionBroker(
        createWindow: (id, server, _) async {
          final peer = Peer(broker, id);
          peers.add(peer);
          return peer;
        },
        focusPrimary: () async {},
      );
      broker.bind(primary, null, cache: RootCache());
      await broker.openServer(alpha);
      await broker.openServer(beta);
      final stores = [NoWrites(), NoWrites()];
      final children = [
        for (var i = 0; i < 2; i++)
          RaftClient(
            origin: primary.origin,
            sessionStore: stores[i],
            sharedSessionAuthority: peers[i],
            transport: Dio()..httpClientAdapter = api,
            recoveryBackoff: const [],
          ),
      ];
      for (var i = 0; i < 2; i++) {
        expect(await children[i].restore(cachedFirst: true), isTrue);
        await children[i].sessionValidated;
        children[i].selectServer(i == 0 ? 'a' : 'b');
      }
      final refreshing = Future.wait(children.map((c) => c.refresh()));
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await refreshing;
      expect(rotations, 1);
      expect(stores.map((s) => s.writes), [0, 0]);
      expect(children.map((c) => c.sessionForSharing!.accessToken), [
        'second',
        'second',
      ]);
      expect(children.map((c) => c.serverId), ['a', 'b']);
      await children.first.logout();
      await Future<void>.delayed(Duration.zero);
      expect(logouts, 1);
      expect(primary.signedIn, isFalse);
      expect(children.every((c) => !c.signedIn), isTrue);
      await broker.dispose();
      for (final child in children) {
        await child.dispose();
      }
      for (final peer in peers) {
        await peer.stream.close();
      }
      await primary.dispose();
    },
  );

  test(
    'a child cannot accept a late credential snapshot after revocation',
    () async {
      final (primary, api) = await owner();
      late Peer peer;
      final broker = DesktopSessionBroker(
        createWindow: (id, server, broker) async {
          peer = Peer(broker, id);
          return peer;
        },
        focusPrimary: () async {},
      );
      broker.bind(primary, null, cache: RootCache());
      await broker.openServer(beta);
      final child = RaftClient(
        origin: primary.origin,
        sessionStore: NoWrites(),
        sharedSessionAuthority: peer,
        transport: Dio()..httpClientAdapter = api,
        recoveryBackoff: const [],
      );
      await child.restore(cachedFirst: true);
      await child.sessionValidated;
      final snapshot = broker.snapshot(peer.id);
      await peer.publish(null);
      await Future<void>.delayed(Duration.zero);
      await peer.publish(snapshot);
      await Future<void>.delayed(Duration.zero);
      expect(child.signedIn, isFalse);
      await child.dispose();
      await broker.dispose();
      await primary.dispose();
      await peer.stream.close();
    },
  );

  test('authenticated requests retain their window scope while checking broker ownership', () async {
    final (primary, api) = await owner();
    late Peer peer;
    final broker = DesktopSessionBroker(
      createWindow: (id, server, broker) async {
        peer = Peer(broker, id);
        return peer;
      },
      focusPrimary: () async {},
    );
    broker.bind(primary, null, cache: RootCache());
    await broker.openServer(beta);
    final child = RaftClient(
      origin: primary.origin,
      sessionStore: NoWrites(),
      sharedSessionAuthority: peer,
      transport: Dio()..httpClientAdapter = api,
      recoveryBackoff: const [],
    );
    await child.restore(cachedFirst: true);
    await child.sessionValidated;
    child.selectServer('b');
    peer.readGate = Completer<void>();
    final before = api.calls.length;
    final pending = expectLater(
      child.get('/channels'),
      throwsA(isA<RaftApiException>()),
    );
    child.selectServer('a');
    peer.readGate!.complete();
    await pending;
    expect(api.calls.length, before);
    peer.readGate = null;
    await primary.logout();
    await expectLater(child.get('/channels'), throwsA(isA<RaftApiException>()));
    expect(api.calls.where((r) => r.path == '/channels'), isEmpty);
    await child.dispose();
    await broker.dispose();
    await primary.dispose();
    await peer.stream.close();
  });

  test(
    'the same primary object cannot open under a newer authentication epoch',
    () async {
      final (primary, _) = await owner();
      var creates = 0;
      final broker = DesktopSessionBroker(
        createWindow: (id, server, broker) async {
          creates++;
          return Peer(broker, id);
        },
        focusPrimary: () async {},
      );
      broker.bind(primary, null, cache: RootCache());
      await primary.login('fixture', 'fixture');
      await expectLater(
        broker.openServer(beta),
        throwsA(isA<RaftApiException>()),
      );
      expect(creates, 0);
      await broker.dispose();
      await primary.dispose();
    },
  );

  test(
    'definitive rejection from a child retires all windows without logout POST',
    () async {
      final (primary, api) = await owner();
      late Peer peer;
      final broker = DesktopSessionBroker(
        createWindow: (id, server, broker) async {
          peer = Peer(broker, id);
          return peer;
        },
        focusPrimary: () async {},
      );
      broker.bind(primary, null, cache: RootCache());
      await broker.openServer(beta);
      await broker.end(peer.id, SessionEndReason.accountRejected);
      expect(primary.signedIn, isFalse);
      expect(api.calls.where((r) => r.path == '/auth/logout'), isEmpty);
      await broker.dispose();
      await primary.dispose();
      await peer.stream.close();
    },
  );

  test(
    'closing the requesting window fences its pending native open',
    () async {
      final (client, _) = await owner();
      final created = <Peer>[];
      final entered = Completer<void>(), held = Completer<Peer>();
      late DesktopSessionBroker broker;
      broker = DesktopSessionBroker(
        createWindow: (id, server, _) async {
          final peer = Peer(broker, id);
          created.add(peer);
          if (created.length == 1) return peer;
          entered.complete();
          return held.future;
        },
        focusPrimary: () async {},
      );
      broker.bind(client, null, cache: RootCache());
      await broker.openServer(alpha);
      final pending = expectLater(
        broker.openFromWindow(created.first.id, beta),
        throwsA(isA<RaftApiException>()),
      );
      await entered.future;
      broker.remove(created.first.id);
      held.complete(created.last);
      await pending;
      expect(created.last.focuses, 0);
      expect(created.last.closes, 1);
      await broker.dispose();
      await client.dispose();
      for (final peer in created) {
        await peer.stream.close();
      }
    },
  );
}
