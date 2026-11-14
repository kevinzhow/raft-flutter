import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/rw_freshness.dart';

/// Web v1.24 task #164 (store/rwFreshness.ts, rwStaleCounts.ts,
/// api/overloadRetry.ts `getRwRead`): a RisingWave read answered with
/// `X-Raft-Stale` or a failure keeps what is shown, says so once, and reads
/// again on a backoff until a clean answer.
class _Adapter implements HttpClientAdapter {
  final calls = <String>[];
  final answers =
      <
        String,
        List<({int status, Object body, Map<String, String> headers})>
      >{};

  void queue(
    String path,
    int status,
    Object body, [
    Map<String, String> headers = const {},
  ]) => (answers[path] ??= []).add((
    status: status,
    body: body,
    headers: headers,
  ));

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o.path);
    if (o.path == '/auth/login') {
      return _body(200, {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      }, const {});
    }
    final list = answers[o.path];
    final next = list == null || list.isEmpty
        ? (
            status: 200,
            body: <String, dynamic>{'channels': {}},
            headers: const <String, String>{},
          )
        : list.length == 1
        ? list.first
        : list.removeAt(0);
    if (next.status == 0) {
      throw DioException.connectionError(requestOptions: o, reason: 'offline');
    }
    return _body(next.status, next.body, next.headers);
  }

  ResponseBody _body(int status, Object body, Map<String, String> headers) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          for (final e in headers.entries) e.key: [e.value],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Adapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

const _overloaded = {
  'error': 'Busy',
  'code': 'rw_overloaded',
  'retryable': true,
};

void main() {
  late _Adapter adapter;
  late _Client client;
  late RwFreshnessStore store;
  var refetched = 0;

  Future<void> read(String path) async {
    try {
      await client.get(path);
    } catch (_) {}
  }

  setUp(() async {
    adapter = _Adapter();
    client = _Client(adapter);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    refetched = 0;
    store = RwFreshnessStore(
      client,
      refetch: {
        RwSurface.unread: () async {
          refetched++;
          await read('/channels/unread');
        },
      },
      random: Random(1),
    )..watch();
    addTearDown(store.dispose);
  });

  test('[BP-READ-077] an X-Raft-Stale answer marks its surface stale; a clean 200 marks it fresh', () async {
    adapter.queue(
      '/channels/unread',
      200,
      {'channels': {}},
      {'x-raft-stale': 'rw_overloaded', 'retry-after': '3'},
    );
    await read('/channels/unread');
    expect(store[RwSurface.unread].freshness, RwFreshness.stale);
    expect(store[RwSurface.unread].retryAfter, const Duration(seconds: 3));
    expect(
      store.outOfDate(const [
        RwSurface.unread,
        RwSurface.followed,
        RwSurface.summary,
      ]),
      isTrue,
    );
    expect(store.outOfDate(const [RwSurface.inbox]), isFalse);
    adapter.answers.clear();
    await read('/channels/unread');
    expect(store[RwSurface.unread].freshness, RwFreshness.fresh);
    expect(store.outOfDate(RwSurface.values), isFalse);
  });

  test('[BP-READ-077] a 503 the client retries once is judged by the retry, a second one is unavailable', () {
    fakeAsync((async) {
      adapter.queue('/channels/inbox', 503, _overloaded, {'retry-after': '1'});
      adapter.queue('/channels/inbox', 200, {'items': []});
      unawaited(read('/channels/inbox'));
      async.flushMicrotasks();
      // The first 503 alone does not show the notice: the retry decides.
      expect(store[RwSurface.inbox].outOfDate, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(adapter.calls.where((p) => p == '/channels/inbox'), hasLength(2));
      expect(store[RwSurface.inbox].freshness, RwFreshness.fresh);
      adapter.answers.clear();
      adapter.queue('/channels/inbox', 503, _overloaded, {'retry-after': '1'});
      unawaited(read('/channels/inbox'));
      async.elapse(const Duration(seconds: 2));
      expect(store[RwSurface.inbox].freshness, RwFreshness.unavailable);
      expect(store[RwSurface.inbox].code, 'rw_overloaded');
    });
  });

  test(
    '503 rw_unconfigured says temporarily unavailable; a 4xx changes nothing',
    () async {
      adapter.queue('/channels/threads/followed', 404, {'error': 'nope'});
      await read('/channels/threads/followed');
      expect(store[RwSurface.followed], RwSurfaceState.fresh);
      adapter.answers.clear();
      adapter.queue('/channels/threads/followed', 503, {
        'error': 'no rw',
        'code': 'rw_unconfigured',
      });
      await read('/channels/threads/followed');
      expect(store.unconfigured(const [RwSurface.followed]), isTrue);
      expect(store.unconfigured(const [RwSurface.inbox]), isFalse);
    },
  );

  test('a read with no answer (offline) is unavailable', () async {
    adapter.queue('/servers/unread-summary', 0, const {});
    await read('/servers/unread-summary');
    expect(store[RwSurface.summary].freshness, RwFreshness.unavailable);
  });

  test('recovery reads again after Retry-After, then 5, 10 s ... until a clean answer, and stops', () {
    expect(
      RwFreshnessStore.recoveryDelay(0, const Duration(seconds: 2)),
      const Duration(seconds: 2),
    );
    expect(RwFreshnessStore.recoveryDelay(0, null), const Duration(seconds: 5));
    expect(
      RwFreshnessStore.recoveryDelay(0, const Duration(minutes: 5)),
      const Duration(seconds: 60),
    );
    expect(RwFreshnessStore.recoveryDelay(1, null), const Duration(seconds: 5));
    expect(
      RwFreshnessStore.recoveryDelay(3, null),
      const Duration(seconds: 20),
    );
    expect(
      RwFreshnessStore.recoveryDelay(9, null),
      const Duration(seconds: 60),
    );
    fakeAsync((async) {
      adapter.queue(
        '/channels/unread',
        200,
        {'channels': {}},
        {'x-raft-stale': 'rw_slow'},
      );
      adapter.queue(
        '/channels/unread',
        200,
        {'channels': {}},
        {'x-raft-stale': 'rw_slow'},
      );
      adapter.queue('/channels/unread', 200, {'channels': {}});
      unawaited(read('/channels/unread'));
      async.elapse(const Duration(milliseconds: 10));
      expect(store[RwSurface.unread].freshness, RwFreshness.stale);
      // First re-read: 5 s ± 20 % (no Retry-After).
      async.elapse(const Duration(milliseconds: 3900));
      expect(refetched, 0);
      async.elapse(const Duration(milliseconds: 2200));
      expect(refetched, 1);
      expect(store[RwSurface.unread].freshness, RwFreshness.stale);
      async.elapse(const Duration(seconds: 7));
      expect(refetched, 2);
      expect(store[RwSurface.unread].freshness, RwFreshness.fresh);
      async.elapse(const Duration(minutes: 5));
      expect(refetched, 2, reason: 'a fresh surface stops its timer');
    });
  });

  test('in the background the timer waits; a nudge reads at once', () {
    var visible = false;
    store.dispose();
    store = RwFreshnessStore(
      client,
      refetch: {
        RwSurface.unread: () async {
          refetched++;
          await read('/channels/unread');
        },
      },
      visible: () => visible,
      random: Random(1),
    )..watch();
    fakeAsync((async) {
      adapter.queue('/channels/unread', 503, {'error': 'x'});
      unawaited(read('/channels/unread'));
      async.elapse(const Duration(minutes: 2));
      expect(refetched, 0);
      visible = true;
      store.nudge();
      async.elapse(const Duration(milliseconds: 10));
      expect(refetched, 1);
    });
  });

  test('no timer runs while nothing that shows the counts is mounted', () {
    fakeAsync((async) {
      store.unwatch();
      adapter.queue('/channels/unread', 503, {'error': 'x'});
      unawaited(read('/channels/unread'));
      async.elapse(const Duration(minutes: 2));
      expect(store[RwSurface.unread].outOfDate, isTrue);
      expect(refetched, 0);
      expect(async.pendingTimers, isEmpty);
      store.watch();
      async.elapse(const Duration(seconds: 7));
      expect(refetched, 1);
    });
  });

  test('a server switch starts the server-scoped reads over', () async {
    adapter.queue('/channels/unread', 503, {'error': 'x'});
    await read('/channels/unread');
    expect(store[RwSurface.unread].outOfDate, isTrue);
    client.selectServer('s2');
    adapter.answers.clear();
    adapter.queue('/servers/unread-summary', 200, const []);
    await read('/servers/unread-summary');
    expect(store[RwSurface.unread], RwSurfaceState.fresh);
  });
}
