import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
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
  // These cases talk to a real loopback server; undo the test binding's mock client.
  HttpOverrides.global = null;
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

  Future<RaftClient> loopbackClient(_OAuthAdapter transport) {
    final client = RaftClient(
      origin: 'https://example.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = transport,
    );
    addTearDown(client.dispose);
    return Future.value(client);
  }

  test(
    'loopback serves the styled return page in the app locale, with a strict CSP',
    () async {
      final transport = _OAuthAdapter();
      final client = await loopbackClient(transport);
      for (final (locale, error, expected) in const [
        (Locale('en'), null, 'Returning to Raft'),
        (Locale('zh', 'CN'), null, '正在返回 Raft'),
        (
          Locale('en'),
          'access_denied',
          'Sign-in was cancelled, or access was denied.',
        ),
        (Locale('zh', 'CN'), 'expired', '这个登录请求已过期。'),
        (
          Locale('en'),
          '<script>alert(1)</script>',
          'Sign-in could not be completed.',
        ),
      ]) {
        final broker = NativeOAuthBroker(
          android: false,
          locale: locale,
          presentWindow: () async {},
          launch: (url) async {
            final returned = Uri.parse(transport.start!['returnUri']);
            final browser = HttpClient();
            try {
              final query = error == null
                  ? ''
                  : '?provider=github&mode=login&error=${Uri.encodeQueryComponent(error)}';
              final response = await (await browser.getUrl(
                returned.replace(
                  fragment: '',
                  query: query.isEmpty ? null : query.substring(1),
                ),
              )).close();
              expect(response.statusCode, 200);
              expect(response.headers.contentType?.mimeType, 'text/html');
              expect(response.headers.value('cache-control'), 'no-store');
              expect(
                response.headers.value('x-content-type-options'),
                'nosniff',
              );
              final csp = response.headers.value('content-security-policy')!;
              expect(csp, contains("default-src 'none'"));
              expect(csp, contains("frame-ancestors 'none'"));
              expect(csp, isNot(contains('unsafe')));
              final html = await utf8.decoder.bind(response).join();
              expect(html, contains(expected));
              expect(
                html,
                contains(
                  'lang="${locale.languageCode == 'zh' ? 'zh-CN' : 'en'}"',
                ),
              );
              expect(html, isNot(contains('<script>alert')));
              // Finish the attempt through the real callback.
              final state = Uri.splitQueryString(returned.fragment)['state'];
              final post = await browser.postUrl(
                returned.replace(path: '/auth/callback', fragment: ''),
              );
              post.headers.contentType = ContentType.json;
              post.write(
                jsonEncode({
                  'state': state,
                  'provider': 'github',
                  'mode': 'login',
                  'code': 'ephemeral-test-code',
                }),
              );
              await (await post.close()).drain<void>();
            } finally {
              browser.close(force: true);
            }
          },
        );
        addTearDown(broker.cancel);
        await broker.begin(client, 'github');
      }
    },
  );

  test(
    'only an accepted callback brings the app window to the front',
    () async {
      final transport = _OAuthAdapter();
      final client = await loopbackClient(transport);
      var presented = 0;
      late int afterRejected;
      final broker = NativeOAuthBroker(
        android: false,
        presentWindow: () async => presented++,
        launch: (url) async {
          final returned = Uri.parse(transport.start!['returnUri']);
          final state = Uri.splitQueryString(returned.fragment)['state'];
          final browser = HttpClient();
          try {
            Future<int> post(String proof) async {
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

            expect(await post('wrong-state'), 403);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            afterRejected = presented;
            expect(await post(state!), 200);
          } finally {
            browser.close(force: true);
          }
        },
      );
      addTearDown(broker.cancel);
      await broker.begin(client, 'github');
      expect(afterRejected, 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(presented, 1);
    },
  );
}
