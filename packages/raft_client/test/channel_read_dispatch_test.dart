import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

void main() {
  test('a channel read reaches the adapter before the caller yields', () async {
    final adapter = _Adapter();
    final client = _client(adapter);
    addTearDown(client.dispose);
    await client.login('ada@example.invalid', 'secret');
    client.selectServer('s1');
    final before = adapter.calls.length;

    final read = client.post('/channels/c1/read', data: {'seq': '901'});
    final readAll = client.post('/channels/c1/read-all');
    final sent = adapter.calls.sublist(before).map((c) => c.path).toList();

    expect(sent, ['/channels/c1/read']);
    final receipt = adapter.calls[before];
    expect(receipt.method, 'POST');
    expect(receipt.data, {'seq': '901'});
    expect(receipt.headers['X-Server-Id'], 's1');
    expect('${receipt.headers['Authorization']}', startsWith('Bearer '));
    for (var n = 0; n < 64; n++) {
      unawaited(Future<void>.delayed(Duration.zero));
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      adapter.calls.sublist(before).map((c) => c.path),
      contains('/channels/c1/read'),
    );
    expect(await read, {'maxReadSeq': '901', 'readStateVersion': 3});
    expect(adapter.bodies[before], '{"seq":"901"}');
    await readAll;
    expect(adapter.calls.map((c) => c.path), contains('/channels/c1/read-all'));
  });

  test('sync interceptors still see the read on that same turn', () async {
    final adapter = _Adapter();
    final client = _client(adapter);
    addTearDown(client.dispose);
    await client.login('ada@example.invalid', 'secret');
    final order = <String>[];
    client.http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          order.add('request');
          options.extra['stamped'] = true;
          handler.next(options);
        },
        onResponse: (response, handler) {
          order.add('response');
          handler.next(response);
        },
      ),
    );
    adapter.onFetch = () => order.add('adapter');

    final pending = client.post('/channels/c1/read', data: {'seq': '1'});
    expect(order, ['request', 'adapter']);
    expect(adapter.calls.last.extra['stamped'], isTrue);
    expect(await pending, {'maxReadSeq': '901', 'readStateVersion': 3});
    expect(order, ['request', 'adapter', 'response']);
  });

  test('a 401 on the read still refreshes once and retries', () async {
    final adapter = _Adapter();
    final client = _client(adapter);
    addTearDown(client.dispose);
    await client.login('ada@example.invalid', 'secret');
    var reads = 0;
    adapter.handler = (options) {
      if (options.path == '/channels/c1/read') {
        reads++;
        if (reads == 1) return _json({'error': 'expired'}, 401);
        return _json({'maxReadSeq': '1', 'readStateVersion': 2});
      }
      if (options.path == '/auth/refresh') {
        return _json({'accessToken': 'access-2', 'refreshToken': 'refresh-2'});
      }
      return _json({'error': 'missing'}, 404);
    };

    expect(await client.post('/channels/c1/read', data: {'seq': '1'}), {
      'maxReadSeq': '1',
      'readStateVersion': 2,
    });
    final receipts = adapter.calls.where((c) => c.path == '/channels/c1/read');
    expect(receipts, hasLength(2));
    expect(receipts.last.headers['Authorization'], 'Bearer access-2');
    expect(adapter.calls.where((c) => c.path == '/auth/refresh'), hasLength(1));
  });

  test('a channel read hands its cancel signal to the adapter before the caller yields', () async {
    final adapter = _Adapter();
    final client = _client(adapter);
    addTearDown(client.dispose);
    await client.login('ada@example.invalid', 'secret');
    final cancel = UploadCancellation();

    final pending = client.request(
      'POST',
      '/channels/c1/read',
      data: {'seq': '1'},
      cancellation: cancel,
    );

    final signal = adapter.cancelSignals.last;
    expect(signal, isNotNull);
    expect(adapter.calls.last.path, '/channels/c1/read');
    var heard = false;
    unawaited(signal!.whenComplete(() => heard = true));
    await Future<void>.delayed(Duration.zero);
    expect(heard, isFalse);
    cancel.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(heard, isTrue);
    expect(await pending, {'maxReadSeq': '901', 'readStateVersion': 3});
  });

  test(
    'a channel read cancelled before it starts never reaches the adapter',
    () async {
      final adapter = _Adapter();
      final client = _client(adapter);
      addTearDown(client.dispose);
      await client.login('ada@example.invalid', 'secret');
      final cancel = UploadCancellation()..cancel();
      final before = adapter.calls.length;

      await expectLater(
        client.request(
          'POST',
          '/channels/c1/read',
          data: {'seq': '1'},
          cancellation: cancel,
        ),
        throwsA(isA<RaftApiException>()),
      );
      expect(adapter.calls, hasLength(before));
    },
  );

  test(
    'a channel read cancelled while an interceptor waits is not sent',
    () async {
      final adapter = _Adapter();
      final client = _client(adapter);
      addTearDown(client.dispose);
      await client.login('ada@example.invalid', 'secret');
      final gate = Completer<void>();
      var waiting = false;
      client.http.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            waiting = true;
            await gate.future;
            handler.next(options);
          },
        ),
      );
      final cancel = UploadCancellation();
      final before = adapter.calls.length;
      final pending = client.request(
        'POST',
        '/channels/c1/read',
        data: {'seq': '1'},
        cancellation: cancel,
      );
      final rejected = expectLater(pending, throwsA(isA<RaftApiException>()));
      for (var i = 0; i < 50 && !waiting; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(waiting, isTrue);
      expect(adapter.calls, hasLength(before));
      cancel.cancel();
      gate.complete();
      await rejected;
      expect(adapter.calls, hasLength(before));
    },
  );

  test(
    'cancelling a channel read during refresh does not send the retry',
    () async {
      final adapter = _Adapter();
      final client = _client(adapter);
      addTearDown(client.dispose);
      await client.login('ada@example.invalid', 'secret');
      final refreshGate = Completer<void>();
      adapter.pauseRefresh = refreshGate.future;
      var reads = 0;
      adapter.handler = (options) {
        if (options.path == '/channels/c1/read') {
          reads++;
          return _json({'error': 'expired'}, 401);
        }
        if (options.path == '/auth/refresh') {
          return _json({
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
          });
        }
        return _json({'error': 'missing'}, 404);
      };
      final cancel = UploadCancellation();
      final pending = client.request(
        'POST',
        '/channels/c1/read',
        data: {'seq': '1'},
        cancellation: cancel,
      );
      final rejected = expectLater(pending, throwsA(isA<RaftApiException>()));
      for (var i = 0; i < 100 && !adapter.refreshSeen; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(adapter.refreshSeen, isTrue);
      expect(reads, 1);
      cancel.cancel();
      refreshGate.complete();
      await rejected;
      expect(reads, 1);
      expect(
        adapter.calls.where((c) => c.path == '/auth/refresh'),
        hasLength(1),
      );
    },
  );
}

RaftClient _client(_Adapter adapter) => RaftClient(
  origin: 'https://example.invalid',
  sessionStore: MemorySessionStore(),
  transport: Dio()..httpClientAdapter = adapter,
);

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final bodies = <String>[];
  final cancelSignals = <Future<void>?>[];
  void Function()? onFetch;
  Future<void>? pauseRefresh;
  bool refreshSeen = false;
  ResponseBody Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    cancelSignals.add(cancelFuture);
    onFetch?.call();
    if (requestStream == null) {
      bodies.add('');
    } else {
      final bytes = await requestStream.fold<List<int>>(<int>[], (all, chunk) {
        all.addAll(chunk);
        return all;
      });
      bodies.add(utf8.decode(bytes));
    }
    if (options.path == '/auth/refresh') {
      refreshSeen = true;
      final pause = pauseRefresh;
      if (pause != null) await pause;
    }
    final answer = handler?.call(options);
    if (answer != null) return answer;
    if (options.path == '/auth/login') {
      return _json({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'user': {'id': 'ada'},
      });
    }
    if (options.path == '/channels/c1/read') {
      return _json({'maxReadSeq': '901', 'readStateVersion': 3});
    }
    return _json({'ok': true});
  }

  @override
  void close({bool force = false}) {}
}
