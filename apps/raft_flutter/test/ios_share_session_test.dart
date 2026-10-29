import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/ios_share_session.dart';

class _Credentials implements SessionStore {
  Session? value = Session(
    accessToken: 'fixture-access',
    refreshToken: 'fixture-refresh-private',
    cachedUser: {'id': 'alice', 'name': 'Alice'},
  );
  Completer<Session?>? held;
  int reads = 0;
  @override
  Future<Session?> read(String origin) async {
    reads++;
    return held == null ? value : await held!.future;
  }

  @override
  Future<void> write(String origin, Session? session) async {
    value = session;
  }
}

class _Client extends RaftClient {
  _Client(_Credentials storage)
    : super(origin: 'https://fixture.invalid', sessionStore: storage) {
    user = RaftRecord({'id': 'alice', 'name': 'Alice'});
    selectServer('s1');
  }
  @override
  bool get signedIn => user != null;
}

class _Responses implements HttpClientAdapter {
  bool rotate = false;
  final List<String> paths = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    paths.add(options.path);
    Object payload = {};
    var status = 200;
    if (options.path == '/auth/me') {
      payload = {'id': 'alice', 'name': 'Alice'};
    }
    if (options.path == '/auth/refresh') {
      payload = {
        'accessToken': 'rotated-access',
        'refreshToken': 'private-rotated',
      };
    }
    if (options.path == '/fixture' &&
        rotate &&
        options.headers['Authorization'] != 'Bearer rotated-access') {
      status = 401;
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fixture-ios-share-session');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('projects selected access only; preserves account while changing selected server', () async {
    final storage = _Credentials();
    final c = _Client(storage);
    final owner = IOSShareSession(channel: channel, supported: true);
    addTearDown(owner.dispose);
    addTearDown(c.dispose);
    owner.bind(c);
    await owner.publish();
    await owner.settled;
    final records = calls.where((call) => call.arguments != null).toList();
    expect(records.last.method, 'updateShareSession');
    final record = records.last.arguments as Map;
    expect(record['principal'], 'alice');
    expect(record['accessToken'], 'fixture-access');
    expect(record.keys, isNot(contains('refreshToken')));
    expect(record['preferredServerId'], 's1');
    expect(
      record['expiresAt'],
      greaterThan(DateTime.now().millisecondsSinceEpoch),
    );
    c.selectServer('s2');
    await owner.publish();
    await owner.settled;
    expect((calls.last.arguments as Map)['preferredServerId'], 's2');
    owner.bind(null);
    await owner.settled;
    expect(calls.last.arguments, isNull);
  });
  test(
    'late credential read cannot restore a signed-out extension session',
    () async {
      final storage = _Credentials()..held = Completer<Session?>();
      final c = _Client(storage),
          owner = IOSShareSession(channel: channel, supported: true);
      addTearDown(c.dispose);
      addTearDown(owner.dispose);
      owner.bind(c);
      final pending = owner.publish();
      await Future<void>.delayed(Duration.zero);
      owner.bind(null);
      storage.held!.complete(storage.value);
      await pending;
      await owner.settled;
      expect(calls.every((call) => call.arguments == null), isTrue);
    },
  );
  test(
    'wrong cached principal and offline restoration never export a credential',
    () async {
      final storage = _Credentials()
        ..value = Session(
          accessToken: 'other-account',
          refreshToken: 'other-refresh',
          cachedUser: {'id': 'bob'},
        );
      final c = _Client(storage),
          owner = IOSShareSession(channel: channel, supported: true);
      addTearDown(c.dispose);
      addTearDown(owner.dispose);
      owner.bind(c);
      await owner.publish();
      await owner.settled;
      expect(calls.every((call) => call.arguments == null), isTrue);
      storage.value = Session(
        accessToken: 'fixture-access',
        refreshToken: 'private',
        cachedUser: {'id': 'alice'},
      );
      c.restoredOffline = true;
      await owner.publish();
      await owner.settled;
      expect(calls.every((call) => call.arguments == null), isTrue);
    },
  );
  test(
    'native write failure retries without breaking account persistence',
    () async {
      var fail = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (fail) throw PlatformException(code: 'fixture-unavailable');
            calls.add(call);
            return null;
          });
      final storage = _Credentials();
      final client = _Client(storage),
          owner = IOSShareSession(channel: channel, supported: true);
      addTearDown(client.dispose);
      addTearDown(owner.dispose);
      owner.bind(client);
      await owner.publish();
      await owner.settled;
      fail = false;
      await owner.publish();
      await owner.settled;
      expect(calls.last.arguments, isNotNull);
      expect(storage.value!.refreshToken, 'fixture-refresh-private');
      await owner.dispose();
      expect(calls.last.arguments, isNull);
    },
  );
  test(
    'non-iOS service neither reads credentials nor invokes native sharing',
    () async {
      final storage = _Credentials();
      final c = _Client(storage);
      final owner = IOSShareSession(channel: channel, supported: false);
      addTearDown(c.dispose);
      owner.bind(c);
      await owner.publish();
      await owner.dispose();
      expect(calls, isEmpty);
      expect(storage.reads, 0);
    },
  );
  test(
    'changed principal clears before publishing the replacement account',
    () async {
      final storage = _Credentials();
      final client = _Client(storage),
          owner = IOSShareSession(channel: channel, supported: true);
      addTearDown(client.dispose);
      addTearDown(owner.dispose);
      owner.bind(client);
      await owner.publish();
      await owner.settled;
      expect((calls.last.arguments as Map)['principal'], 'alice');
      calls.clear();
      client.user = RaftRecord({'id': 'bob'});
      storage.value = Session(
        accessToken: 'bob-access',
        refreshToken: 'never-export',
        cachedUser: {'id': 'bob'},
      );
      await owner.publish();
      await owner.settled;
      expect(calls.first.arguments, isNull);
      expect((calls.last.arguments as Map)['principal'], 'bob');
    },
  );
  test(
    'expired access token retires an already published extension session',
    () async {
      final storage = _Credentials();
      final c = _Client(storage),
          owner = IOSShareSession(channel: channel, supported: true);
      addTearDown(c.dispose);
      addTearDown(owner.dispose);
      owner.bind(c);
      await owner.publish();
      await owner.settled;
      final claims = base64Url.encode(utf8.encode(jsonEncode({'exp': 1})));
      storage.value = Session(
        accessToken: 'fixture.$claims.signature',
        refreshToken: 'private',
        cachedUser: {'id': 'alice'},
      );
      await owner.publish();
      await owner.settled;
      expect(calls.last.arguments, isNull);
    },
  );
  test(
    'logout retires a native write already in flight in serial order',
    () async {
      final held = Completer<void>(), started = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.arguments != null && !started.isCompleted) {
              started.complete();
              await held.future;
            }
            calls.add(call);
            return null;
          });
      final c = _Client(_Credentials()),
          owner = IOSShareSession(channel: channel, supported: true);
      addTearDown(c.dispose);
      addTearDown(owner.dispose);
      owner.bind(c);
      await started.future;
      owner.bind(null);
      held.complete();
      await owner.settled;
      expect(calls[calls.length - 2].arguments, isNotNull);
      expect(calls.last.arguments, isNull);
    },
  );
  test(
    '100 ordinary API responses never re-read or republish shared credentials',
    () async {
      final storage = _Credentials();
      final c = _Client(storage),
          owner = IOSShareSession(channel: channel, supported: true);
      addTearDown(c.dispose);
      addTearDown(owner.dispose);
      c.http.httpClientAdapter = _Responses();
      owner.bind(c);
      await owner.publish();
      await owner.settled;
      final reads = storage.reads, writes = calls.length;
      for (var i = 0; i < 100; i++) {
        await c.get('/fixture');
      }
      await Future<void>.delayed(Duration.zero);
      await owner.settled;
      expect(storage.reads, reads);
      expect(calls.length, writes);
    },
  );
  test('successful token rotation emits no credentials and publishes new access once', () async {
    final storage = _Credentials();
    final client = _Client(storage), response = _Responses();
    final owner = IOSShareSession(channel: channel, supported: true),
        events = <RaftEvent>[];
    addTearDown(client.dispose);
    addTearDown(owner.dispose);
    client.http.httpClientAdapter = response;
    await client.restore();
    final subscription = client.events.listen(events.add);
    addTearDown(subscription.cancel);
    owner.bind(client);
    await owner.publish();
    await owner.settled;
    final reads = storage.reads;
    response.rotate = true;
    await client.get('/fixture');
    await Future<void>.delayed(Duration.zero);
    await owner.settled;
    expect(storage.reads, reads + 1);
    expect((calls.last.arguments as Map)['accessToken'], 'rotated-access');
    final updated = events
        .where((e) => e.name == 'session:credentials-updated')
        .toList();
    expect(updated.length, 1);
    expect(updated.single.payload, isNull);
  });
}
