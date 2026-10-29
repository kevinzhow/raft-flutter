// Desktop OAuth sign-in when the system browser does not appear: after a few
// seconds (or at once when the launcher fails) the page offers "Browser didn't
// open? Copy sign-in link" and "Open Again". The loopback flow is unchanged.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/platform/oauth_broker.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

const _authorizationUrl =
    'https://provider.example.invalid/authorize?state=secret-state-1234';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final body = request.path.endsWith('/auth/providers')
        ? {
            'providers': [
              {'id': 'github', 'label': 'GitHub', 'enabled': true},
            ],
          }
        : {'authorizationUrl': _authorizationUrl};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

RaftClient _client(String origin) => RaftClient(
  origin: origin,
  sessionStore: MemorySessionStore(),
  transport: Dio()..httpClientAdapter = _Adapter(),
);

Future<void> _mount(
  WidgetTester t,
  Future<void> Function(Uri) launch, {
  required List<NativeOAuthBroker> brokers,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: AuthView(
        origin: 'https://example.invalid',
        onLogin: (b, e, p) async {},
        onRegister: (b, e, p, a) async {},
        onOAuth: (origin, code, verifier, accepted) async {},
        anonymousClientFactory: _client,
        oauthBrokerFactory: () {
          final broker = NativeOAuthBroker(android: false, launch: launch);
          brokers.add(broker);
          return broker;
        },
      ),
    ),
  );
  await _settle(t, 10);
}

/// The broker binds a real loopback socket: give real I/O time between pumps.
Future<void> _settle(WidgetTester t, int rounds) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pump(const Duration(milliseconds: 10));
  }
}

final _help = find.byKey(const ValueKey('auth-browser-help'));

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<Uri?>']);
  HttpOverrides.global = null;
  testWidgets('a browser that never opens: help appears after 3 s', (t) async {
    // 0.7.1 buttons are taller (32 / 44 px); the 800x600 default no longer shows the whole stack.
    t.view.physicalSize = const Size(800, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final opened = <Uri>[];
    final brokers = <NativeOAuthBroker>[];
    final copied = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _mount(t, (url) async => opened.add(url), brokers: brokers);
    await t.tap(find.byKey(const ValueKey('auth-social-github')));
    await _settle(t, 6);
    // launchUrl "succeeded" (the Linux AppImage case: nothing opened).
    expect(opened.map((u) => u.toString()), [_authorizationUrl]);
    expect(find.text('Cancel Browser Sign-in'), findsOneWidget);
    expect(_help, findsNothing);

    await t.pump(const Duration(milliseconds: 2500));
    expect(_help, findsNothing, reason: 'not before ~3 s');
    await t.pump(const Duration(milliseconds: 700));
    expect(_help, findsOneWidget);
    expect(find.text("Browser didn't open?"), findsOneWidget);
    expect(find.text('Copy Sign-in Link'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('auth-copy-sign-in-link')));
    await t.pump();
    expect(copied, [_authorizationUrl], reason: 'the exact OAuth URL');
    expect(find.text('Link Copied'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('auth-open-again')));
    await t.pump();
    expect(opened, hasLength(2));
    expect(opened.last.toString(), _authorizationUrl);

    // Cancelling the attempt takes the help away with it.
    await t.tap(find.text('Cancel Browser Sign-in'));
    await _settle(t, 4);
    expect(_help, findsNothing);
  });

  testWidgets('a launcher that fails shows the help at once', (t) async {
    // 0.7.1 buttons are taller (32 / 44 px); the 800x600 default no longer shows the whole stack.
    t.view.physicalSize = const Size(800, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final attempts = <Uri>[];
    final brokers = <NativeOAuthBroker>[];
    await _mount(t, (url) async {
      attempts.add(url);
      throw const RaftApiException(
        'Could not open the authentication browser.',
      );
    }, brokers: brokers);
    await t.tap(find.byKey(const ValueKey('auth-social-github')));
    await _settle(t, 6);
    expect(attempts, hasLength(1));
    expect(_help, findsOneWidget, reason: 'no 3 s wait when launchUrl failed');
    // The attempt is still waiting (the link can be opened by hand): no error
    // banner, the cancel link is still there.
    expect(find.text('Cancel Browser Sign-in'), findsOneWidget);
    expect(find.textContaining('Could not open'), findsNothing);
    await t.tap(find.byKey(const ValueKey('auth-open-again')));
    await t.pump();
    expect(attempts, hasLength(2));
    await t.tap(find.text('Cancel Browser Sign-in'));
    await _settle(t, 4);
  });

  test('the help URL is never part of a thrown message', () async {
    final broker = NativeOAuthBroker(
      android: false,
      launch: (url) async => throw RaftApiException('failed $url'),
    );
    addTearDown(broker.cancel);
    final client = _client('https://example.invalid');
    addTearDown(client.dispose);
    final attempt = broker.begin(client, 'github');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(broker.helpUrl.value.toString(), _authorizationUrl);
    await broker.cancel();
    await expectLater(
      attempt,
      throwsA(
        isA<RaftApiException>().having(
          (e) => e.message,
          'message',
          isNot(contains('secret-state')),
        ),
      ),
    );
    expect(broker.helpUrl.value, isNull);
  });
}
