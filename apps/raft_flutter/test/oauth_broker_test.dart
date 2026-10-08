import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/oauth_broker.dart';

class _OAuthAdapter implements HttpClientAdapter {
  Map<String, dynamic>? start;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    start = Map<String, dynamic>.from(request.data);
    return ResponseBody.fromString(
      jsonEncode({
        'authorizationUrl': 'https://provider.example.invalid/authorize',
      }),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('PKCE uses the RFC7636 S256 vector', () {
    expect(
      oauthCodeChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });
  test(
    'desktop loopback callback requires the exact state, provider and mode',
    () async {
      final transport = _OAuthAdapter();
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = transport,
      );
      addTearDown(client.dispose);
      final broker = NativeOAuthBroker(
        android: false,
        launch: (url) async {
          expect(url.host, 'provider.example.invalid');
          final returned = Uri.parse(transport.start!['returnUri']);
          expect(returned.host, '127.0.0.1');
          expect(returned.path, '/auth/done');
          final state = Uri.splitQueryString(returned.fragment)['state'];
          final browser = HttpClient();
          try {
            final page = await (await browser.getUrl(
              returned.replace(fragment: ''),
            )).close();
            expect(page.statusCode, 200);
            final html = await utf8.decoder.bind(page).join();
            expect(html, contains('history.replaceState'));
            expect(html, contains("location.hash"));
            Future<int> callback(String proof) async {
              final request = await browser.postUrl(
                returned.replace(path: '/auth/callback', fragment: ''),
              );
              request.headers.contentType = ContentType.json;
              request.write(
                jsonEncode({
                  'state': proof,
                  'provider': 'github',
                  'mode': 'login',
                  'code': 'ephemeral-test-code',
                }),
              );
              final response = await request.close();
              await response.drain<void>();
              return response.statusCode;
            }

            expect(await callback('wrong-state'), 403);
            expect(await callback(state!), 200);
          } finally {
            browser.close(force: true);
          }
        },
      );
      addTearDown(broker.cancel);
      final result = await broker.begin(client, 'github');
      expect(result.code, 'ephemeral-test-code');
      expect(
        oauthCodeChallenge(result.verifier),
        transport.start!['codeChallenge'],
      );
      expect(transport.start!['mode'], 'login');
      expect(client.signedIn, false);
      expect(broker.returnUri, isNull);
    },
  );
}
