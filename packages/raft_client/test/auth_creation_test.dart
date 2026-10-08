import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:raft_client/raft_client.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  Completer<dynamic>? delayed;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final data = delayed == null
        ? {
            'accessToken': 'test-access',
            'refreshToken': 'test-refresh',
            'user': {
              'id': 'new-user',
              'name': 'pending_fixture',
              'emailVerified': false,
            },
          }
        : await delayed!.future;
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('registration requires explicit consent before any request', () async {
    final adapter = _Adapter(), store = MemorySessionStore();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: store,
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.dispose);
    await expectLater(
      client.register('a@example.invalid', 'password', acceptTerms: false),
      throwsA(isA<RaftApiException>()),
    );
    expect(adapter.calls, isEmpty);
    expect(client.signedIn, false);
    expect(await store.read(client.origin), isNull);
  });
  test('registration pins legal versions and persists the unverified profile without making workspace calls', () async {
    final adapter = _Adapter(), store = MemorySessionStore();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: store,
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.dispose);
    await client.register('a@example.invalid', ' password ', acceptTerms: true);
    expect(adapter.calls.single.path, '/auth/register');
    expect(adapter.calls.single.data, {
      'email': 'a@example.invalid',
      'password': ' password ',
      'acceptTerms': true,
      'termsVersion': '2026-05-12',
      'privacyVersion': '2026-05-12',
      'legalAcceptanceSource': 'signup',
    });
    expect(client.user?.json['emailVerified'], false);
    expect(client.signedIn, true);
    expect(await store.read(client.origin), isNotNull);
  });
  test(
    'late registration response cannot restore a logged-out account',
    () async {
      final adapter = _Adapter()..delayed = Completer<dynamic>();
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.dispose);
      final registering = client.register(
        'a@example.invalid',
        'password',
        acceptTerms: true,
      );
      await Future<void>.delayed(Duration.zero);
      await client.logout();
      adapter.delayed!.complete({
        'accessToken': 'test',
        'refreshToken': 'test',
        'user': {'id': 'new-user'},
      });
      await expectLater(registering, throwsA(isA<RaftApiException>()));
      expect(client.user, isNull);
      expect(client.signedIn, false);
    },
  );
  test('OAuth completion sends consent only after user agreement', () async {
    final adapter = _Adapter();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.dispose);
    await client.completeMobileOAuth('handoff-only', 'verifier-only');
    expect(adapter.calls.single.data, {
      'code': 'handoff-only',
      'codeVerifier': 'verifier-only',
    });
    expect(client.signedIn, true);
  });
  test('late login cannot restore a logged-out session', () async {
    final adapter = _Adapter()..delayed = Completer<dynamic>();
    final store = MemorySessionStore();
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: store,
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.dispose);
    final pending = client.login('first', 'fixture');
    await Future<void>.delayed(Duration.zero);
    await client.logout();
    adapter.delayed!.complete({
      'accessToken': 'test',
      'refreshToken': 'test',
      'user': {'id': 'first'},
    });
    await expectLater(pending, throwsA(isA<RaftApiException>()));
    expect(client.user, isNull);
    expect(await store.read(client.origin), isNull);
  });
  test('newer login wins over an earlier OAuth completion', () async {
    final adapter = _Adapter()..delayed = Completer<dynamic>();
    final oldResult = adapter.delayed!;
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.dispose);
    final pending = client.completeMobileOAuth('old-code', 'fixture-verifier');
    final rejected = expectLater(pending, throwsA(isA<RaftApiException>()));
    while (adapter.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    adapter.delayed = null;
    await client.login('new', 'fixture');
    oldResult.complete({
      'accessToken': 'test',
      'refreshToken': 'test',
      'user': {'id': 'old'},
    });
    await rejected;
    expect(client.user!.id, 'new-user');
  });
}
