import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({this.observationFields = true, this.observationStatus = 200});
  final bool observationFields;
  final int observationStatus;
  final calls = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final Map<String, dynamic> body;
    var status = 200;
    if (options.path == '/auth/me/timezone-observation') {
      status = observationStatus;
      body = {
        'firstObservedTimezone': options.data['timezone'],
        'firstObservedTimezoneAt': '2026-10-21T00:00:00.000Z',
        'lastObservedTimezone': options.data['timezone'],
        'lastObservedTimezoneAt': '2026-10-21T00:00:00.000Z',
      };
    } else if (options.path == '/auth/me') {
      body = {
        'id': 'user-1',
        'name': 'person',
        if (observationFields) 'firstObservedTimezone': null,
      };
    } else {
      body = {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'user': {
          'id': 'user-1',
          'name': 'person',
          if (observationFields) 'firstObservedTimezone': null,
        },
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

RaftClient _client(
  _Adapter adapter, {
  Future<String?> Function()? probe,
  MemorySessionStore? store,
}) {
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: store ?? MemorySessionStore(),
    transport: Dio()..httpClientAdapter = adapter,
    timezoneProbe: probe,
  );
  addTearDown(client.dispose);
  return client;
}

/// Lets the background report run: waits for [done] (up to 2 s) or, when
/// nothing is expected to happen, a short moment.
Future<void> _flush([bool Function()? done]) async {
  final until = DateTime.now().add(const Duration(seconds: 2));
  while (done != null && !done() && DateTime.now().isBefore(until)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

List<RequestOptions> _posts(_Adapter a) =>
    a.calls.where((c) => c.path == '/auth/me/timezone-observation').toList();

void main() {
  test('signing in reports the device timezone once', () async {
    final adapter = _Adapter();
    final client = _client(adapter, probe: () async => 'Asia/Shanghai');
    await client.login('person@example.invalid', 'secret');
    await _flush(() => _posts(adapter).isNotEmpty);
    expect(_posts(adapter).single.data, {'timezone': 'Asia/Shanghai'});
    expect(client.user?.json['lastObservedTimezone'], 'Asia/Shanghai');
    expect(client.user?.json['firstObservedTimezoneAt'], isNotNull);
    expect(client.user?.json['name'], 'person', reason: 'the rest is kept');
  });

  test('restoring a stored session reports it too, once', () async {
    final adapter = _Adapter();
    final store = MemorySessionStore();
    final first = _client(adapter, store: store);
    await first.login('person@example.invalid', 'secret');
    adapter.calls.clear();
    final again = _client(
      adapter,
      probe: () async => 'Europe/Paris',
      store: store,
    );
    expect(await again.restore(), true);
    await _flush(() => _posts(adapter).isNotEmpty);
    expect(_posts(adapter).single.data, {'timezone': 'Europe/Paris'});
  });

  test('a server without the observation fields is not asked', () async {
    final adapter = _Adapter(observationFields: false);
    final client = _client(adapter, probe: () async => 'Asia/Shanghai');
    await client.login('person@example.invalid', 'secret');
    await _flush();
    expect(_posts(adapter), isEmpty);
  });

  test('no timezone from the device means no request', () async {
    for (final zone in <String?>[null, '  ']) {
      final adapter = _Adapter();
      final client = _client(adapter, probe: () async => zone);
      await client.login('person@example.invalid', 'secret');
      await _flush();
      expect(_posts(adapter), isEmpty);
    }
  });

  test('a failed report never fails the sign-in', () async {
    final adapter = _Adapter(observationStatus: 500);
    final client = _client(adapter, probe: () async => 'Asia/Shanghai');
    await client.login('person@example.invalid', 'secret');
    await _flush(() => _posts(adapter).isNotEmpty);
    expect(client.signedIn, true);
    expect(_posts(adapter), hasLength(1));
  });

  test('without a probe nothing is reported', () async {
    final adapter = _Adapter();
    final client = _client(adapter);
    await client.login('person@example.invalid', 'secret');
    await _flush();
    expect(_posts(adapter), isEmpty);
  });
}
