import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_login.dart';

import 'support/human_login_fake.dart';

/// Login with Raft over the app's real session client, with the HTTP layer
/// (Dio's adapter) faked: which requests are sent, with what, and under whose
/// credentials.
class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  int authorizeStatus = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    var status = 200;
    dynamic data;
    switch ('${o.method} ${o.path}') {
      case 'POST /auth/login':
        data = {
          'accessToken': 'fixture-only',
          'refreshToken': 'fixture-only',
          'user': {'id': 'alice', 'email': 'alice@example.com'},
        };
      case 'GET /oauth/clients/lookup':
        data = FakeHumanLoginApi.app();
      case 'POST /oauth/authorize/human':
        status = authorizeStatus;
        data = authorizeStatus == 200
            ? {
                'code': 'issued-code-2',
                'returnUrl': (o.data as Map)['returnUrl'],
              }
            : {
                'error': 'invalid_scope',
                'errorCode': 'OAUTH_SCOPE_NOT_ALLOWED',
                'error_description':
                    'This OAuth client is not allowed to request: agent:read.',
                'disallowedScopes': ['agent:read'],
              };
      case 'POST /integrations/marketplace/app-record-1/install':
        data = {'id': 'install-1'};
      default:
        status = 404;
        data = {'error': 'Unexpected endpoint'};
    }
    return ResponseBody.fromString(
      jsonEncode(data),
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
  late _Adapter adapter;
  late ClientHumanLoginApi api;
  const servers = [
    HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme'),
    HumanLoginServer(id: 'srv-2', slug: 'beta', name: 'Beta'),
  ];
  final request = HumanLoginRequest(
    clientId: 'artifact-share',
    returnUrl: 'https://artifacts.example.com/auth/callback',
    state: 'st-1',
    scopes: const ['openid', 'profile'],
    serverHint: 'srv-2',
  );

  setUp(() async {
    adapter = _Adapter();
    final client = RaftClient(
      origin: 'https://api.example.com',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = adapter,
    );
    await client.login('fixture', 'fixture');
    // The app is on another server than the link names.
    client.selectServer('srv-1');
    api = ClientHumanLoginApi(
      client: client,
      webOrigin: Uri.parse('https://app.example.com'),
      directory: () => [
        for (final s in servers)
          RaftRecord({'id': s.id, 'slug': s.slug, 'name': s.name}),
      ],
    );
  });

  test('the session\'s client sends the lookup for the named server', () async {
    expect(api.servers.map((s) => s.slug), ['acme', 'beta']);
    expect(api.signedInAs, 'alice@example.com');
    final found = (await lookupHumanLoginClient(api, request)).choices;
    expect(found.single.server.id, 'srv-2');
    final call = adapter.calls.singleWhere(
      (c) => c.path == '/oauth/clients/lookup',
    );
    expect(call.method, 'GET');
    expect(call.baseUrl, 'https://api.example.com/api');
    expect(call.queryParameters, {
      'client_id': 'artifact-share',
      'server_id': 'srv-2',
      'scope': 'openid profile',
    });
    expect(call.headers['X-Server-Id'], 'srv-2');
    expect(call.headers['Authorization'], isNotNull);
  });

  test('the authorization is the app\'s authenticated POST', () async {
    final found = (await lookupHumanLoginClient(api, request)).choices;
    final location = await authorizeHumanLogin(api, request, found.single);
    final call = adapter.calls.singleWhere(
      (c) => c.path == '/oauth/authorize/human',
    );
    expect(call.method, 'POST');
    expect(call.data, {
      'clientId': 'artifact-share',
      'serverId': 'srv-2',
      'returnUrl': 'https://artifacts.example.com/auth/callback',
      'scopes': ['openid', 'profile'],
    });
    expect(call.headers['Authorization'], isNotNull);
    expect(
      location.toString(),
      'https://artifacts.example.com/auth/callback?code=issued-code-2&state=st-1',
    );
  });

  test(
    'a refusal reaches the person as the server\'s error_description',
    () async {
      final found = (await lookupHumanLoginClient(api, request)).choices;
      adapter.authorizeStatus = 400;
      await expectLater(
        authorizeHumanLogin(api, request, found.single),
        throwsA(
          isA<HumanLoginException>().having(
            (e) => e.text,
            'text',
            'This OAuth client is not allowed to request: agent:read.',
          ),
        ),
      );
    },
  );

  test(
    'the install is the authenticated POST, addressed to that server',
    () async {
      // The app is on srv-1; the person installs on srv-2.
      await api.installMarketplaceApp('srv-2', 'app-record-1');
      final call = adapter.calls.singleWhere(
        (c) => c.path == '/integrations/marketplace/app-record-1/install',
      );
      expect(call.method, 'POST');
      expect(call.headers['X-Server-Id'], 'srv-2');
      expect(call.headers['Authorization'], isNotNull);
      expect(call.data, isNull);
    },
  );
}
