import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

/// A server that answers each path from a script of status codes, with real
/// express-rate-limit (draft-6) 429 headers.
class _Server implements HttpClientAdapter {
  final scripts = <String, List<int>>{};
  final seen = <String>[];
  Duration delay = Duration.zero;
  String? retryAfter = '7';
  Map<String, String> extra = const {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    seen.add('${o.method} ${o.path}');
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final script = scripts[o.path];
    final status = script == null || script.isEmpty ? 200 : script.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(
        status == 429
            ? {'error': 'Too many requests, please try again later'}
            : {'ok': true, 'path': o.path, 'rows': [1, 2, 3]},
      ),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (status == 429) ...{
          if (retryAfter != null) 'retry-after': [retryAfter!],
          'ratelimit-limit': ['120'],
          'ratelimit-remaining': ['0'],
          'ratelimit-reset': ['7'],
        },
        for (final e in extra.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Clock {
  var t = DateTime.utc(2026, 10, 13, 12);
  DateTime now() => t;
}

Future<(RaftClient, _Server, List<Duration>, _Clock)> _client() async {
  final server = _Server()..scripts['/auth/login'] = [200];
  final clock = _Clock();
  final slept = <Duration>[];
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = server,
    governor: RateLimitGovernor(
      now: clock.now,
      random: math.Random(1),
      sleep: (d) async {
        slept.add(d);
        clock.t = clock.t.add(d);
      },
    ),
    sleep: (d) async {
      slept.add(d);
      clock.t = clock.t.add(d);
    },
  );
  server.scripts['/auth/login'] = [200];
  return (client, server, slept, clock);
}

Future<void> _signIn(RaftClient client, _Server server) async {
  final adapter = server;
  adapter.scripts['/auth/login'] = [200];
  // login() needs a session in the body.
  final original = client.http.httpClientAdapter;
  client.http.httpClientAdapter = _LoginAdapter(original);
  await client.login('a', 'b');
  client.http.httpClientAdapter = original;
  client.selectServer('s1');
}

class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter(this.next);
  final HttpClientAdapter next;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    if (o.path == '/auth/login') {
      return ResponseBody.fromString(
        jsonEncode({
          'accessToken': 'fixture-only',
          'refreshToken': 'fixture-only',
          'user': {'id': 'alice'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return next.fetch(o, s, c);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Retry-After parsing', () {
    final now = DateTime.utc(2026, 10, 13, 12);
    Headers h(Map<String, String> m) =>
        Headers.fromMap({for (final e in m.entries) e.key: [e.value]});
    test('delta seconds, HTTP date and RateLimit-Reset', () {
      expect(retryAfterOf(h({'retry-after': '12'}), now), const Duration(seconds: 12));
      expect(
        retryAfterOf(h({'retry-after': 'Tue, 13 Oct 2026 12:00:30 GMT'}), now),
        const Duration(seconds: 30),
      );
      expect(
        retryAfterOf(h({'retry-after': 'Tue, 13 Oct 2026 11:00:00 GMT'}), now),
        Duration.zero,
      );
      expect(retryAfterOf(h({'ratelimit-reset': '9'}), now), const Duration(seconds: 9));
      expect(retryAfterOf(h({'retry-after': 'soon'}), now), isNull);
      expect(retryAfterOf(h({}), now), isNull);
    });
  });

  group('backoff', () {
    test('never earlier than the server hint, jitter spreads a crowd', () {
      final rng = math.Random(7);
      final delays = [
        for (var i = 0; i < 50; i++)
          backoffDelay(0, hint: const Duration(seconds: 10), random: rng),
      ];
      expect(delays.every((d) => d >= const Duration(seconds: 10)), isTrue);
      expect(delays.every((d) => d <= const Duration(seconds: 13)), isTrue);
      expect(delays.toSet().length, greaterThan(10));
    });
    test('without a hint it grows exponentially, is jittered and capped', () {
      final rng = math.Random(3);
      int max(int attempt) => [
        for (var i = 0; i < 200; i++)
          backoffDelay(attempt, random: rng).inMilliseconds,
      ].reduce(math.max);
      expect(max(0), lessThanOrEqualTo(1250));
      expect(max(3), lessThanOrEqualTo(8250));
      expect(max(3), greaterThan(max(0)));
      expect(max(12), lessThanOrEqualTo(60250));
    });
  });

  group('client 429 handling', () {
    test('a 429 on a read waits Retry-After, retries once and succeeds', () async {
      final (client, server, slept, _) = await _client();
      await _signIn(client, server);
      server.scripts['/channels/c1'] = [429, 200];
      final body = await client.get('/channels/c1');
      expect(body['ok'], true);
      expect(server.seen.where((s) => s == 'GET /channels/c1'), hasLength(2));
      expect(slept, hasLength(1));
      expect(slept.single, greaterThanOrEqualTo(const Duration(seconds: 7)));
      expect(slept.single, lessThan(const Duration(seconds: 12)));
      expect(client.signedIn, isTrue);
      await client.dispose();
    });

    test('keeps the session on repeated 429 and stops after two retries', () async {
      final (client, server, slept, _) = await _client();
      await _signIn(client, server);
      server.scripts['/channels/c1'] = [429, 429, 429, 429];
      Object? error;
      try {
        await client.get('/channels/c1');
      } catch (e) {
        error = e;
      }
      expect(error, isA<RaftApiException>());
      final e = error as RaftApiException;
      expect(e.rateLimited, isTrue);
      expect(e.retryAfter, const Duration(seconds: 7));
      // The original try plus RaftClient.rateLimitRetries retries, no storm.
      expect(
        server.seen.where((s) => s == 'GET /channels/c1'),
        hasLength(1 + RaftClient.rateLimitRetries),
      );
      expect(slept, hasLength(RaftClient.rateLimitRetries));
      expect(client.signedIn, isTrue);
      expect(client.lastEndReason, isNull);
      await client.dispose();
    });

    test('while a bucket is closed, other callers wait instead of sending', () async {
      final (client, server, slept, _) = await _client();
      await _signIn(client, server);
      server.scripts['/attachments/a/url'] = [429, 200];
      await client.get('/attachments/a/url');
      final before = server.seen.length;
      // The attachments bucket was closed by the 429 and is open again after
      // the wait: the next calls go straight through.
      await client.get('/attachments/b/url');
      expect(server.seen.length, before + 1);
      // A 429 with a long Retry-After closes it; a new read must not hit the
      // network at all, and must fail with the remaining wait.
      server.retryAfter = '120';
      server.scripts['/attachments/c/url'] = [429];
      Object? error;
      try {
        await client.get('/attachments/c/url');
      } catch (e) {
        error = e;
      }
      expect((error as RaftApiException).retryAfter, const Duration(seconds: 120));
      final sent = server.seen.length;
      Object? second;
      try {
        await client.get('/attachments/d/url');
      } catch (e) {
        second = e;
      }
      expect(server.seen.length, sent, reason: 'closed bucket: nothing sent');
      expect((second as RaftApiException).rateLimited, isTrue);
      expect(slept.where((d) => d > const Duration(seconds: 100)), isEmpty);
      await client.dispose();
    });

    test('background requests never wait: refused while the bucket is closed', () async {
      final (client, server, slept, _) = await _client();
      await _signIn(client, server);
      server.scripts['/attachments/urls'] = [429];
      Object? first;
      try {
        await RaftClient.runBackground(
          () => client.post('/attachments/urls', data: {'attachmentIds': ['a']}),
        );
      } catch (e) {
        first = e;
      }
      expect((first as RaftApiException).rateLimited, isTrue);
      expect(slept, isEmpty, reason: 'a background call is not retried');
      final sent = server.seen.length;
      Object? second;
      try {
        await RaftClient.runBackground(
          () => client.post('/attachments/urls', data: {'attachmentIds': ['b']}),
        );
      } catch (e) {
        second = e;
      }
      expect(second, isA<RaftApiException>());
      expect(server.seen.length, sent);
      await client.dispose();
    });

    test('credential endpoints are not retried behind the person typing', () async {
      final (client, server, slept, _) = await _client();
      server.scripts['/auth/login'] = [429];
      Object? error;
      try {
        await client.login('a', 'b');
      } catch (e) {
        error = e;
      }
      expect((error as RaftApiException).rateLimited, isTrue);
      expect(server.seen.where((s) => s == 'POST /auth/login'), hasLength(1));
      expect(slept, isEmpty);
      await client.dispose();
    });
  });

  group('single-flight', () {
    test('identical reads in flight share one request; bodies are copies', () async {
      final (client, server, _, _) = await _client();
      await _signIn(client, server);
      server.delay = const Duration(milliseconds: 20);
      final results = await Future.wait([
        for (var i = 0; i < 5; i++)
          RaftClient.runShared(() => client.get('/agents')),
      ]);
      expect(server.seen.where((s) => s == 'GET /agents'), hasLength(1));
      expect(client.singleFlightJoins, 4);
      (results[0]['rows'] as List).add(99);
      expect((results[1]['rows'] as List), [1, 2, 3]);
      // Different query: a different question.
      await Future.wait([
        RaftClient.runShared(() => client.get('/agents', query: {'a': 1})),
        RaftClient.runShared(() => client.get('/agents', query: {'a': 2})),
      ]);
      expect(server.seen.where((s) => s == 'GET /agents'), hasLength(3));
      // Once finished, a later read asks again (no stale reuse).
      await RaftClient.runShared(() => client.get('/agents'));
      expect(server.seen.where((s) => s == 'GET /agents'), hasLength(4));
      await client.dispose();
    });

    test('reads are not shared unless the caller opts in', () async {
      final (client, server, _, _) = await _client();
      await _signIn(client, server);
      server.delay = const Duration(milliseconds: 20);
      await Future.wait([client.get('/agents'), client.get('/agents')]);
      expect(server.seen.where((s) => s == 'GET /agents'), hasLength(2));
      await client.dispose();
    });

    test('a write between two reads ends the sharing (read-after-write)', () async {
      final (client, server, _, _) = await _client();
      await _signIn(client, server);
      server.delay = const Duration(milliseconds: 20);
      final first = RaftClient.runShared(() => client.get('/agents'));
      final write = client.post('/agents');
      final second = RaftClient.runShared(() => client.get('/agents'));
      await Future.wait([first, write, second]);
      expect(server.seen.where((s) => s == 'GET /agents'), hasLength(2));
      await client.dispose();
    });

    test('a stalled read is not joined by a fresh attempt', () async {
      final (client, server, _, _) = await _client();
      await _signIn(client, server);
      client.singleFlightWindow = Duration.zero;
      server.delay = const Duration(milliseconds: 20);
      await Future.wait([
        RaftClient.runShared(() => client.get('/agents')),
        RaftClient.runShared(() => client.get('/agents')),
      ]);
      expect(server.seen.where((s) => s == 'GET /agents'), hasLength(2));
      await client.dispose();
    });

    test('writes are never merged', () async {
      final (client, server, _, _) = await _client();
      await _signIn(client, server);
      server.delay = const Duration(milliseconds: 20);
      await Future.wait([
        client.post('/channels/c1/read'),
        client.post('/channels/c1/read'),
      ]);
      expect(server.seen.where((s) => s == 'POST /channels/c1/read'), hasLength(2));
      await client.dispose();
    });
  });

  group('pacing', () {
    test('reset opens a closed bucket and zeroes the counters', () async {
      final clock = _Clock();
      final governor = RateLimitGovernor(now: clock.now);
      const limits = [ServerRateLimits.attachments];
      governor.limitedBy(limits, const Duration(minutes: 5));
      await expectLater(
        governor.acquire(limits, RequestPriority.foreground),
        throwsA(isA<RateLimitedException>()),
      );
      expect(governor.limited, 1);
      // A zero-length block cannot undo a longer one; reset can.
      governor.limitedBy(limits, Duration.zero);
      expect(governor.blockedFor('attachments'), isNotNull);
      governor.reset();
      expect(governor.blockedFor('attachments'), isNull);
      expect(governor.limited, 0);
      await governor.acquire(limits, RequestPriority.foreground);
    });

    test('background attachment traffic stays under its share of the limit', () async {
      final clock = _Clock();
      final slept = <Duration>[];
      final governor = RateLimitGovernor(
        now: clock.now,
        random: math.Random(1),
        sleep: (d) async {
          slept.add(d);
          clock.t = clock.t.add(d);
        },
      );
      const limits = [ServerRateLimits.attachments];
      var sent = 0, refused = 0;
      for (var i = 0; i < 400; i++) {
        try {
          await governor.acquire(limits, RequestPriority.background);
          sent++;
        } on RateLimitedException {
          refused++;
        }
        clock.t = clock.t.add(const Duration(milliseconds: 100));
      }
      // 40 seconds of one background request every 100 ms.
      expect(sent, lessThanOrEqualTo(48));
      expect(refused, greaterThan(300));
      expect(slept, isEmpty);
    });

    test('foreground waits (bounded) instead of exceeding its share', () async {
      final clock = _Clock();
      final slept = <Duration>[];
      final governor = RateLimitGovernor(
        now: clock.now,
        random: math.Random(1),
        maxWait: const Duration(minutes: 5),
        sleep: (d) async {
          slept.add(d);
          clock.t = clock.t.add(d);
        },
      );
      final stamps = <DateTime>[];
      for (var i = 0; i < 300; i++) {
        await governor.acquire(
          const [ServerRateLimits.attachments],
          RequestPriority.foreground,
        );
        stamps.add(clock.t);
      }
      // No sliding minute ever holds more than 75% of the 120 limit.
      var peak = 0;
      for (var i = 0, j = 0; i < stamps.length; i++) {
        while (stamps[i].difference(stamps[j]) >= const Duration(minutes: 1)) {
          j++;
        }
        peak = math.max(peak, i - j + 1);
      }
      expect(peak, lessThanOrEqualTo(90));
      expect(slept, isNotEmpty);
    });

    test('RateLimit-Remaining headers make background work yield', () async {
      final clock = _Clock();
      final governor = RateLimitGovernor(now: clock.now);
      governor.observe(
        const [ServerRateLimits.attachments],
        Headers.fromMap({
          'ratelimit-limit': ['120'],
          'ratelimit-remaining': ['10'],
          'ratelimit-reset': ['20'],
        }),
      );
      await expectLater(
        governor.acquire(
          const [ServerRateLimits.attachments],
          RequestPriority.background,
        ),
        throwsA(isA<RateLimitedException>()),
      );
      await governor.acquire(
        const [ServerRateLimits.attachments],
        RequestPriority.foreground,
      );
      clock.t = clock.t.add(const Duration(seconds: 21));
      await governor.acquire(
        const [ServerRateLimits.attachments],
        RequestPriority.background,
      );
    });

    test('a cancelled caller stops waiting and spends no budget', () async {
      final clock = _Clock();
      final sleeping = Completer<void>();
      final governor = RateLimitGovernor(
        now: clock.now,
        // Time never passes on its own: only a cancel can end the wait.
        sleep: (_) => sleeping.future,
      );
      // Fill the foreground share (90 of 120) so the next request must wait.
      for (var i = 0; i < 90; i++) {
        await governor.acquire(
          const [ServerRateLimits.attachments],
          RequestPriority.foreground,
        );
      }
      // 45 s into the window the next slot frees in 15 s: a wait, not a refusal.
      clock.t = clock.t.add(const Duration(seconds: 45));
      final token = CancelToken();
      final waiting = governor.acquire(
        const [ServerRateLimits.attachments],
        RequestPriority.foreground,
        cancelled: token.whenCancel,
      );
      var done = false;
      unawaited(waiting.then<void>((_) {}, onError: (Object _) {}).whenComplete(() => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse, reason: 'still paced');
      token.cancel();
      await expectLater(waiting, throwsA(isA<RateLimitWaitCancelled>()));
      // The cancelled request was not recorded: once the window passes, all
      // 90 slots are free again, not 89.
      sleeping.complete();
      clock.t = clock.t.add(const Duration(minutes: 1, seconds: 1));
      for (var i = 0; i < 90; i++) {
        await governor.acquire(
          const [ServerRateLimits.attachments],
          RequestPriority.foreground,
        );
      }
    });
  });
}
