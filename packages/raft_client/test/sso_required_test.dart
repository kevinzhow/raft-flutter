// Server v1.24.0 SSO enforcement: 403 SSO_REQUIRED on every request of a
// session a Server's SSO does not accept. The client records it once and
// tells the app (`auth:sso-required`); it never ends the session itself.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'error':
          'Your organization requires you to sign in with its single sign-on.',
      'code': 'SSO_REQUIRED',
      'signInUrl': 'https://example.invalid/api/auth/sso/servers/x/start',
    }),
    403,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('403 SSO_REQUIRED is recorded once and announced', () async {
    final store = MemorySessionStore();
    await store.write(
      'https://example.invalid',
      Session(accessToken: 'a', refreshToken: 'r'),
    );
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: store,
      transport: Dio()..httpClientAdapter = _Adapter(),
    );
    addTearDown(client.dispose);
    final events = <RaftEvent>[];
    client.events.listen(events.add);
    for (var i = 0; i < 2; i++) {
      await expectLater(
        client.get('/servers'),
        throwsA(isA<RaftApiException>()),
      );
    }
    await Future<void>.delayed(Duration.zero);
    // Dynamic so this file also compiles (and fails) on the pre-v1.24 code.
    expect(
      (client as dynamic).ssoRequired,
      'Your organization requires you to sign in with its single sign-on.',
    );
    expect(events.where((e) => e.name == 'auth:sso-required'), hasLength(1));
    expect(await store.read('https://example.invalid'), isNotNull);
  });
}
