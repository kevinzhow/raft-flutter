import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_account_usage.dart';
import 'package:raft_flutter/data/runtime_auth.dart';

/// The runtime-auth client (Web utils/runtimeAuthClient.ts) and the usage
/// client's v1.24 additions (runtimeAccountUsageClient.ts), against fakes.
void main() {
  late DateTime now;
  late StreamController<RaftEvent> events;
  late List<String> gets;
  late List<(String, Map<String, dynamic>)> posts;
  Object? answer;
  late RuntimeAuthClient client;

  Map<String, dynamic> view(String kind) => {
    'status': {
      'runtimes': {
        'claude': {'kind': kind},
      },
    },
    'availability': 'ok',
    'canAct': true,
  };

  setUp(() {
    now = DateTime(2026, 11, 16, 10);
    events = StreamController<RaftEvent>.broadcast(sync: true);
    gets = [];
    posts = [];
    answer = view('logged_in');
    client = RuntimeAuthClient(
      get: (path) async {
        gets.add(path);
        return answer;
      },
      post: (path, body) async {
        posts.add((path, body));
        return answer;
      },
      events: events.stream,
      now: () => now,
    );
  });
  tearDown(() async {
    client.dispose();
    await events.close();
  });

  group('the sign-in view', () {
    test('is read once and cached for 30 seconds', () async {
      final first = await client.read('s', 'c');
      expect(first.statusOf('claude')?.loggedIn, isTrue);
      await client.read('s', 'c');
      expect(gets, ['/servers/s/machines/c/runtime-auth']);
      expect(client.cached('s', 'c'), isNotNull);
      now = now.add(const Duration(seconds: 29));
      await client.read('s', 'c');
      expect(gets, hasLength(1));
      now = now.add(const Duration(seconds: 2));
      expect(client.cached('s', 'c'), isNull);
      await client.read('s', 'c');
      expect(gets, hasLength(2));
    });

    test('reads that overlap share one request', () async {
      final a = client.read('s', 'c');
      final b = client.read('s', 'c');
      await Future.wait([a, b]);
      expect(gets, hasLength(1));
      // Another Computer, another read.
      await client.read('s', 'd');
      expect(gets, hasLength(2));
    });

    test('invalidate drops the cache and tells the watchers of that '
        'Computer only', () async {
      await client.read('s', 'c');
      var c = 0, d = 0;
      final stopC = client.watch('c', () => c++);
      final stopD = client.watch('d', () => d++);
      client.invalidate('s', 'c');
      expect((c, d), (1, 0));
      expect(client.cached('s', 'c'), isNull);
      await client.read('s', 'c');
      expect(gets, hasLength(2));
      stopC();
      client.invalidate('s', 'c');
      expect(c, 1);
      stopD();
    });

    test('machine:runtime_auth:updated drops that Computer on every '
        'server and wakes its watchers', () async {
      await client.read('s1', 'c');
      await client.read('s2', 'c');
      await client.read('s1', 'other');
      var woke = 0;
      final stop = client.watch('c', () => woke++);
      events.add(
        const RaftEvent('machine:runtime_auth:updated', {'machineId': 'c'}),
      );
      expect(woke, 1);
      expect(client.cached('s1', 'c'), isNull);
      expect(client.cached('s2', 'c'), isNull);
      expect(client.cached('s1', 'other'), isNotNull);
      // A payload without a Computer changes nothing.
      events.add(const RaftEvent('machine:runtime_auth:updated', {}));
      events.add(const RaftEvent('machine:runtime_auth:updated', 'c'));
      expect(woke, 1);
      stop();
    });

    test('an answer that is not a view reads as a Computer offline, not a '
        'crash; unknown runtimes and statuses are dropped', () {
      final empty = RuntimeAuthView.fromJson(null);
      expect(empty.availability, 'computer_offline');
      expect(empty.canAct, isFalse);
      final v = RuntimeAuthView.fromJson({
        'status': {
          'runtimes': {
            'claude': {'kind': 'logged_in'},
            'made-up': {'kind': 'logged_in'},
            'codex': {'kind': 'surprise'},
            'qoder': {'kind': 'unavailable', 'reason': 'not_installed'},
          },
        },
        'availability': 'ok',
        'canAct': true,
        'runtimes': ['claude', 'made-up', 'pi'],
      });
      expect(v.statuses.keys, unorderedEquals(['claude', 'qoder']));
      expect(v.runtimes, ['claude', 'pi']);
      expect(v.statusOf('qoder')?.reason, 'not_installed');
    });

    test('what a Computer can sign in and out follows its lists', () {
      // A server that predates `runtimes`: Claude and Codex only.
      final old = RuntimeAuthView.fromJson(view('logged_in'));
      expect(old.supports('claude'), isTrue);
      expect(old.supports('kimi'), isFalse);
      expect(old.signsOut('claude'), isTrue);
      // Qoder has no sign-out; Antigravity's needs the Computer's capability.
      final listed = RuntimeAuthView.fromJson({
        ...view('logged_in'),
        'runtimes': ['claude', 'qoder', 'antigravity'],
      });
      expect(listed.signsOut('qoder'), isFalse);
      expect(listed.signsOut('antigravity'), isFalse);
      final capable = RuntimeAuthView.fromJson({
        ...view('logged_in'),
        'runtimes': ['claude', 'antigravity'],
        'logoutRuntimes': ['claude', 'antigravity'],
      });
      expect(capable.signsOut('antigravity'), isTrue);
    });

    test('the account line is the masked email, then the plan; the Kimi CLI '
        'has no sign-in', () {
      expect(
        runtimeAuthAccountText(
          const RuntimeAuthAccount(
            maskedLabel: 'a***@example.com',
            planLabel: 'Max',
          ),
        ),
        'a***@example.com · Max',
      );
      expect(
        runtimeAuthAccountText(const RuntimeAuthAccount(planLabel: 'Max')),
        'Max',
      );
      expect(runtimeAuthAccountText(const RuntimeAuthAccount()), isNull);
      expect(runtimeAuthRuntimeFor('kimi-sdk'), 'kimi');
      expect(runtimeAuthRuntimeFor('kimi'), isNull);
      expect(runtimeAuthRuntimeFor('builtin'), isNull);
      expect(runtimeAuthRuntimeFor('pi'), 'pi');
    });
  });

  group('login pushes', () {
    Map<String, dynamic> push(
      Map<String, dynamic> over, {
      String name = RuntimeAuthClient.loginEvent,
    }) => {
      'name': name,
      'payload': {
        'serverId': 's',
        'machineId': 'c',
        'runtime': 'claude',
        'loginId': 'login-1',
        'event': {'kind': 'auth_url', 'url': 'https://example.com/login'},
        ...over,
      },
    };

    Future<List<RuntimeAuthLoginPush>> send(
      List<Map<String, dynamic>> pushes,
    ) async {
      final seen = <RuntimeAuthLoginPush>[];
      final sub = client.loginPushes.listen(seen.add);
      for (final p in pushes) {
        events.add(RaftEvent(p['name'] as String, p['payload']));
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return seen;
    }

    test('a well-formed event and result reach the caller', () async {
      final seen = await send([
        push({}),
        push({
          'result': {'kind': 'logged_in'},
        }, name: RuntimeAuthClient.loginResultEvent),
      ]);
      expect(seen.map((p) => p.isResult), [false, true]);
      expect(seen.first.kind, 'auth_url');
      expect(seen.last.kind, 'logged_in');
      expect(seen.first.loginId, 'login-1');
    });

    test('a bad login id, an unknown runtime, an unknown kind, a link '
        'that is not https and a missing payload are dropped', () async {
      final seen = await send([
        push({'loginId': 'has space'}),
        push({'loginId': ''}),
        push({'loginId': 'x' * 129}),
        push({'runtime': 'made-up'}),
        push({
          'event': {'kind': 'surprise'},
        }),
        push({
          'event': {'kind': 'auth_url', 'url': 'http://example.com'},
        }),
        push({
          'event': {'kind': 'auth_url', 'url': 'javascript:alert(1)'},
        }),
        push({
          'event': {
            'kind': 'device_code',
            'verificationUri': 'ftp://example.com',
            'userCode': 'AB',
          },
        }),
        push({'event': 'text'}),
        push({'serverId': null}),
        // A result's kind is checked against the result kinds.
        push({
          'result': {'kind': 'auth_url'},
        }, name: RuntimeAuthClient.loginResultEvent),
        // Good ones still pass after the bad.
        push({
          'event': {
            'kind': 'device_code',
            'verificationUri': 'https://example.com/device',
            'userCode': 'AB',
          },
        }),
        push({
          'event': {'kind': 'code_prompt'},
        }),
      ]);
      expect(seen.map((p) => p.kind), ['device_code', 'code_prompt']);
    });

    test('startLogin answers the login id and throws on one it cannot '
        'trust', () async {
      answer = {'loginId': 'abc_DEF-123'};
      expect(
        await client.startLogin('s', 'c', 'kimi', region: 'global'),
        'abc_DEF-123',
      );
      expect(posts.single.$1, '/servers/s/machines/c/runtime-auth/kimi/login');
      expect(posts.single.$2, {'region': 'global'});
      for (final bad in [
        null,
        'x',
        <String, dynamic>{},
        {'loginId': 'bad id'},
        {'loginId': 7},
        {'loginId': ''},
      ]) {
        answer = bad;
        await expectLater(
          client.startLogin('s', 'c', 'claude'),
          throwsA(isA<RuntimeAuthMalformedResponse>()),
          reason: '$bad',
        );
      }
    });
  });

  group('envelopes', () {
    test('a logout is the result itself or inside {result}; another kind is '
        'malformed', () async {
      answer = {'kind': 'logged_out'};
      expect((await client.logout('s', 'c', 'claude'))['kind'], 'logged_out');
      answer = {
        'result': {'kind': 'failed', 'reason': 'timed_out'},
      };
      expect(
        (await client.logout('s', 'c', 'pi', providerId: 'x'))['reason'],
        'timed_out',
      );
      expect(posts.last.$2, {'providerId': 'x'});
      answer = {
        'result': {'kind': 'surprise'},
      };
      await expectLater(
        client.logout('s', 'c', 'claude'),
        throwsA(isA<RuntimeAuthMalformedResponse>()),
      );
    });

    test('a provider list needs its providers; a connect answers one of '
        'its four kinds', () async {
      answer = {'kind': 'listed'};
      await expectLater(
        client.listProviders('s', 'c', 'qwen'),
        throwsA(isA<RuntimeAuthMalformedResponse>()),
      );
      answer = {'kind': 'listed', 'providers': <Object>[]};
      expect(
        (await client.listProviders('s', 'c', 'qwen'))['providers'],
        isEmpty,
      );
      expect(gets.last, '/servers/s/machines/c/runtime-auth/qwen/providers');
      for (final kind in ['connected', 'failed', 'unsupported', 'busy']) {
        answer = {'kind': kind};
        expect(
          (await client.connectProvider('s', 'c', 'qwen', {
            'apiKey': 'k',
          }))['kind'],
          kind,
        );
      }
      answer = {'kind': 'listed'};
      await expectLater(
        client.connectProvider('s', 'c', 'qwen', const {}),
        throwsA(isA<RuntimeAuthMalformedResponse>()),
      );
    });

    test('a limit reset sends its idempotency key and answers the outcome '
        'with the snapshot only when it is one', () async {
      answer = {
        'result': {'kind': 'reset'},
        'snapshot': {'accounts': <Object>[]},
      };
      final ok = await client.redeemLimitReset('s', 'c', 'codex', 'key-1');
      expect(ok.result['kind'], 'reset');
      expect(ok.snapshot, isNotNull);
      expect(
        posts.last.$1,
        endsWith('/runtime-account-usage/codex/limit-reset'),
      );
      expect(posts.last.$2, {'idempotencyKey': 'key-1'});
      answer = {
        'result': {'kind': 'unknown'},
        'snapshot': {'accounts': 'no'},
      };
      final unknown = await client.redeemLimitReset('s', 'c', 'codex', 'key-1');
      expect(unknown.snapshot, isNull);
      answer = {'result': 'nope'};
      await expectLater(
        client.redeemLimitReset('s', 'c', 'codex', 'key-1'),
        throwsA(isA<RuntimeAuthMalformedResponse>()),
      );
    });

    test('Claude resets: a read needs its list; consent is sent only when '
        'given', () async {
      answer = {
        'result': {'kind': 'read'},
      };
      await expectLater(
        client.readLimitResets('s', 'c', consent: false),
        throwsA(isA<RuntimeAuthMalformedResponse>()),
      );
      answer = {
        'result': {'kind': 'read', 'resets': <Object>[]},
      };
      await client.readLimitResets('s', 'c', consent: true);
      expect(posts.last.$2, {'consent': true});
      await client.readLimitResets('s', 'c', consent: false);
      expect(posts.last.$2, isEmpty);
    });

    test('runtimeAuthRequestError reads the status and code of a refusal', () {
      final error = RaftApiException.response(
        'no',
        status: 409,
        body: {'error': 'no', 'code': 'computer_offline'},
      );
      expect(runtimeAuthRequestError(error), (
        status: 409,
        code: 'computer_offline',
      ));
      expect(runtimeAuthRequestError(StateError('x')), (
        status: null,
        code: null,
      ));
    });
  });

  group('the usage client', () {
    late List<String> usageGets;
    late Object? usageAnswer;
    late RuntimeAccountUsageClient usage;
    setUp(() {
      usageGets = [];
      usageAnswer = {'state': 'unsupported'};
      usage = RuntimeAccountUsageClient(
        get: (path) async {
          usageGets.add(path);
          return usageAnswer;
        },
        post: (path, body) async => {'accepted': true, 'state': 'requested'},
        now: () => now,
      );
    });

    Map<String, dynamic> snapshot() => {
      'provider': 'codex',
      'collectedAt': '2026-11-16T10:00:00.000Z',
      'accounts': <Object>[],
    };

    test('`unsupported` is a read with no snapshot and no attention', () async {
      final read = await usage.read('s', 'c', 'codex');
      expect(read.state, 'unsupported');
      expect(read.unsupported, isTrue);
      expect(read.missing, isTrue);
      expect(read.attention, isFalse);
    });

    test('only a well-formed snapshot is kept', () async {
      usageAnswer = {
        'state': 'fresh',
        'snapshot': {'accounts': 'no'},
      };
      expect((await usage.read('s', 'c', 'codex')).state, 'missing');
      usage.invalidate('s', 'c', 'codex');
      usageAnswer = {'state': 'fresh', 'snapshot': snapshot()};
      final fresh = await usage.read('s', 'c', 'codex');
      expect(fresh.state, 'fresh');
      expect(fresh.snapshot, isNotNull);
      // A fresh state without a snapshot is missing.
      expect(RuntimeUsageRead.fromJson({'state': 'stale'}).state, 'missing');
    });

    test(
      'a listener hears every read that lands, and a stored snapshot',
      () async {
        var heard = 0;
        final stop = usage.subscribe(() => heard++);
        usageAnswer = {'state': 'fresh', 'snapshot': snapshot()};
        await usage.read('s', 'c', 'codex');
        expect(heard, 1);
        usage.storeSnapshot('s', 'c', 'codex', snapshot());
        expect(heard, 2);
        expect(usage.cached('s', 'c', 'codex')?.state, 'fresh');
        stop();
        usage.storeSnapshot('s', 'c', 'codex', snapshot());
        expect(heard, 2);
      },
    );

    test(
      'a stored snapshot is what the next read gets, without a request',
      () async {
        usage.storeSnapshot('s', 'c', 'codex', snapshot());
        final read = await usage.read('s', 'c', 'codex');
        expect(read.state, 'fresh');
        expect(usageGets, isEmpty);
        now = now.add(const Duration(seconds: 61));
        expect(usage.cached('s', 'c', 'codex'), isNull);
      },
    );

    test('Antigravity reads through its own provider', () {
      expect(runtimeUsageProvider('antigravity'), 'antigravity');
      expect(runtimeUsageProviderName('antigravity'), 'Antigravity');
      expect(runtimeUsageProvider('kimi-sdk'), 'kimi');
      expect(runtimeUsageProvider('builtin'), isNull);
    });
  });
}
