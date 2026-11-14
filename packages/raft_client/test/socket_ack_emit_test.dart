// Server v1.24 socket events the client must answer or send itself
// (docs/contracts/notifications.md §1.3, §6): `notification:desktop` is
// emitted with an acknowledgement once a desktop reports `ackAlerts`, the
// client reports `presence:activity`, and `POST /notifications/test` names
// this connection by its socket id. The fake server below speaks the
// engine.io v4 / socket.io v5 websocket framing the real one uses.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _FakeSocketServer {
  late final HttpServer http;
  WebSocket? peer;
  final frames = StreamController<String>.broadcast();
  final received = <String>[];

  Future<void> start() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(request);
      peer = ws;
      ws.add(
        '0${jsonEncode({'sid': 'engine-1', 'upgrades': <String>[], 'pingInterval': 25000, 'pingTimeout': 20000, 'maxPayload': 1000000})}',
      );
      ws.listen((data) {
        final text = data as String;
        received.add(text);
        if (text.startsWith('40'))
          ws.add('40${jsonEncode({'sid': 'socket-42'})}');
        if (!frames.isClosed) frames.add(text);
      }, onError: (Object _) {});
    });
  }

  String get origin => 'http://127.0.0.1:${http.port}';

  Future<String> next(bool Function(String) test) =>
      frames.stream.firstWhere(test).timeout(const Duration(seconds: 5));

  Future<void> close() async {
    await peer?.close();
    await http.close(force: true);
    await frames.close();
  }
}

Future<RaftClient> _connected(_FakeSocketServer server) async {
  final store = MemorySessionStore();
  await store.write(
    server.origin,
    Session(
      accessToken: 'a',
      refreshToken: 'r',
      cachedUser: const {'id': 'u1', 'email': 'u1@example.invalid'},
    ),
  );
  final client = RaftClient(
    origin: server.origin,
    sessionStore: store,
    transport: Dio(),
    clientKind: 'desktop',
  );
  await client.restore(cachedFirst: true);
  client.selectServer('s1');
  final connected = client.events.firstWhere((e) => e.name == 'connected');
  client.connect();
  await connected.timeout(const Duration(seconds: 5));
  return client;
}

void main() {
  group('RaftEvent.fromSocket', () {
    test('an event without an ack is passed through unchanged', () {
      final plain = RaftEvent.fromSocket('message:new', {'id': 'm1'});
      expect(plain.payload, {'id': 'm1'});
      expect(plain.ack, isNull);
      final two = RaftEvent.fromSocket('x', ['a', 'b']);
      expect(two.payload, ['a', 'b']);
      expect(two.ack, isNull);
      expect(RaftEvent.fromSocket('y').payload, isNull);
    });

    test('an acked event unwraps its payload and answers once', () {
      final answers = <Object?>[];
      final event = RaftEvent.fromSocket('notification:desktop', [
        {'id': 'n1'},
        (Object? data) => answers.add(data),
      ]);
      expect(event.payload, {'id': 'n1'});
      event.ack!({'received': true});
      event.ack!({'received': false});
      expect(answers, [
        {'received': true},
      ]);
      final bare = RaftEvent.fromSocket(
        'ping',
        (Object? data) => answers.add(data),
      );
      expect(bare.payload, isNull);
      expect(bare.ack, isNotNull);
      final list = RaftEvent.fromSocket('rows', [
        ['a'],
        (Object? _) {},
      ]);
      expect(list.payload, ['a']);
    });
  });

  group('live socket', () {
    late _FakeSocketServer server;
    setUp(() async {
      server = _FakeSocketServer();
      await server.start();
    });
    tearDown(() => server.close());

    test(
      'the server ack callback reaches the event and sends the answer back',
      () async {
        final client = await _connected(server);
        addTearDown(client.dispose);
        expect(client.socketId, 'socket-42');
        final plain = client.events.firstWhere((e) => e.name == 'hello');
        final acked = client.events.firstWhere(
          (e) => e.name == 'notification:desktop',
        );
        server.peer!.add(
          '42${jsonEncode([
            'hello',
            {'a': 1},
          ])}',
        );
        server.peer!.add(
          '427${jsonEncode([
            'notification:desktop',
            {'id': 'n1', 'v': 1},
          ])}',
        );
        final hello = await plain.timeout(const Duration(seconds: 5));
        expect(hello.payload, {'a': 1});
        expect(hello.ack, isNull);
        final desktop = await acked.timeout(const Duration(seconds: 5));
        expect(desktop.payload, {'id': 'n1', 'v': 1});
        final answer = server.next((f) => f.startsWith('437'));
        desktop.ack!({'received': true, 'socketId': client.socketId});
        expect(jsonDecode((await answer).substring(3)), [
          {'received': true, 'socketId': 'socket-42'},
        ]);
      },
    );

    test(
      'emitSocketEvent sends on a live connection and never queues',
      () async {
        final client = await _connected(server);
        addTearDown(client.dispose);
        final sent = server.next((f) => f.startsWith('42'));
        expect(
          client.emitSocketEvent('presence:activity', {
            'active': true,
            'idleSeconds': 0,
          }),
          isTrue,
        );
        expect(jsonDecode((await sent).substring(2)), [
          'presence:activity',
          {'active': true, 'idleSeconds': 0},
        ]);
        client.suspendConnection();
        expect(client.socketId, isNull);
        expect(
          client.emitSocketEvent('presence:activity', {'active': false}),
          isFalse,
        );
      },
    );
  });

  group('emitSocketEventWithAck', () {
    late _FakeSocketServer server;
    setUp(() async {
      server = _FakeSocketServer();
      await server.start();
    });
    tearDown(() => server.close());

    test('waits for the server acknowledgement and returns its data', () async {
      final client = await _connected(server);
      addTearDown(client.dispose);
      final sent = server.next((f) => f.startsWith('42'));
      final answer = client.emitSocketEventWithAck('sync:horizon', {
        'scope': 'all',
      });
      final frame = await sent;
      // `42<id>[event, payload]`: the ack id sits between the type and the body.
      final match = RegExp(r'^42(\d+)(\[.*)$').firstMatch(frame)!;
      expect(jsonDecode(match[2]!), [
        'sync:horizon',
        {'scope': 'all'},
      ]);
      server.peer!.add(
        '43${match[1]}${jsonEncode([
          {'horizon': 7},
        ])}',
      );
      expect(await answer, {'horizon': 7});
    });

    test('times out when the server never answers', () async {
      final client = await _connected(server);
      addTearDown(client.dispose);
      await expectLater(
        client.emitSocketEventWithAck(
          'sync:horizon',
          null,
          const Duration(milliseconds: 200),
        ),
        throwsA(
          isA<RaftSocketAckException>().having(
            (e) => e.reason,
            'reason',
            'timeout',
          ),
        ),
      );
    });
  });

  test(
    'without a connection there is no socket id and nothing is sent',
    () async {
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio(),
      );
      addTearDown(client.dispose);
      expect(client.socketId, isNull);
      expect(
        client.emitSocketEvent('presence:activity', {'active': true}),
        isFalse,
      );
      await expectLater(
        client.emitSocketEventWithAck('sync:horizon'),
        throwsA(
          isA<RaftSocketAckException>().having(
            (e) => e.reason,
            'reason',
            'not_connected',
          ),
        ),
      );
    },
  );
}
