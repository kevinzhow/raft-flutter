import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_login.dart';

import 'support/human_login_fake.dart';

/// The logic of Web `HumanLoginSetupPage` (pinned v1.21.23) and the two
/// `@botiverse/raft-shared` helpers it calls.
void main() {
  group('appendOAuthAuthorizationParams / isSafeOAuthReturnUrl', () {
    test('rejects executable, relative and non-TLS remote callbacks', () {
      // The vectors of packages/shared/src/oauthRedirect.test.ts.
      for (final url in [
        'javascript:window.auditExecuted=true//',
        'JaVaScRiPt:alert(1)',
        'java\tscript:alert(1)',
        'data:text/html,test',
        '//attacker.test/cb',
        '/cb',
        'http://attacker.test/cb',
        'https://user:password@client.test/cb',
        'https://client.test/cb#fragment',
        'http://localhost.attacker.test/cb',
      ]) {
        expect(isSafeOAuthReturnUrl(url), isFalse, reason: url);
        expect(
          () => appendOAuthAuthorizationParams(url, 'secret-code'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('returnUrl'),
            ),
          ),
          reason: url,
        );
      }
    });

    test('preserves the registered query and encodes code and state', () {
      for (final callback in [
        'https://client.test/cb?source=raft',
        'http://localhost:3000/cb',
        'http://127.0.0.1:3000/cb',
        'http://[::1]:3000/cb',
      ]) {
        expect(isSafeOAuthReturnUrl(callback), isTrue, reason: callback);
        final result = Uri.parse(
          appendOAuthAuthorizationParams(callback, 'code&value', 'state#value'),
        );
        expect(result.queryParameters['code'], 'code&value');
        expect(result.queryParameters['state'], 'state#value');
        expect(result.origin, Uri.parse(callback).origin);
      }
      expect(
        appendOAuthAuthorizationParams(
          'https://client.test/cb?source=raft',
          'c',
          's',
        ),
        'https://client.test/cb?source=raft&code=c&state=s',
      );
    });

    test('serializes like new URL(...).searchParams.set(...).toString()', () {
      // `set` replaces the first value of a name, drops the repeats and keeps
      // the other pairs in order; the query is form-encoded afresh; an empty
      // path becomes `/`; the default port goes.
      expect(
        appendOAuthAuthorizationParams(
          'https://Client.TEST:443?a=1&code=old&b=x%20y&code=again',
          'a b',
          '',
        ),
        'https://client.test/?a=1&code=a+b&b=x+y',
      );
      expect(
        appendOAuthAuthorizationParams('https://client.test:8443/cb', 'c'),
        'https://client.test:8443/cb?code=c',
      );
      // Non-ASCII and reserved characters: UTF-8 percent-encoding.
      expect(
        appendOAuthAuthorizationParams('https://client.test/cb', 'é*~'),
        'https://client.test/cb?code=%C3%A9*%7E',
      );
    });
  });

  group('the setup URL', () {
    final web = Uri.parse('https://app.example.com');

    test('the current path and both legacy aliases are Login with Raft', () {
      for (final path in [
        '/login-with-raft/setup',
        '/login-with-slock/setup',
        '/login-with-slock-human/setup',
        '/login-with-raft/setup/',
      ]) {
        expect(
          isHumanLoginSetupUri(
            Uri.parse('https://app.example.com$path?client_id=a'),
            web,
          ),
          isTrue,
          reason: path,
        );
      }
    });

    test('another page, host, scheme or port is not', () {
      for (final url in [
        'https://app.example.com/login',
        'https://app.example.com/login-with-raft',
        'https://app.example.com/s/acme/login-with-raft/setup',
        'https://evil.example.com/login-with-raft/setup',
        'http://app.example.com/login-with-raft/setup',
        'https://app.example.com:8443/login-with-raft/setup',
      ]) {
        expect(isHumanLoginSetupUri(Uri.parse(url), web), isFalse, reason: url);
      }
      // A local stack names its port; the default port is implicit.
      expect(
        isHumanLoginSetupUri(
          Uri.parse('http://localhost:15193/login-with-raft/setup'),
          Uri.parse('http://localhost:15193/'),
        ),
        isTrue,
      );
      expect(
        isHumanLoginSetupUri(
          Uri.parse('https://app.example.com:443/login-with-raft/setup'),
          web,
        ),
        isTrue,
      );
    });

    test('reads the parameters Web reads', () {
      final request = HumanLoginRequest.fromSetupUri(
        Uri.parse(
          'https://app.example.com/login-with-raft/setup?client_id=artifact-share'
          '&return_to=https%3A%2F%2Fartifacts.example.com%2Fcb%3Fx%3D1'
          '&state=abc&scope=openid+profile+identity&server=srv-1',
        ),
      );
      expect(request.clientId, 'artifact-share');
      expect(request.returnUrl, 'https://artifacts.example.com/cb?x=1');
      expect(request.state, 'abc');
      expect(request.scopes, ['openid', 'profile', 'identity']);
      expect(request.serverHint, 'srv-1');
      expect(request.oidc, isFalse);
    });

    test('defaults the scope, accepts redirect_uri, takes the first value', () {
      final request = HumanLoginRequest.fromSetupUri(
        Uri.parse(
          'https://app.example.com/login-with-raft/setup?client_id=a'
          '&redirect_uri=https%3A%2F%2Fa.example.com%2Fcb&client_id=b&scope=',
        ),
      );
      expect(request.clientId, 'a');
      expect(request.returnUrl, 'https://a.example.com/cb');
      expect(request.scopes, ['openid', 'profile']);
    });

    test('authorize body: plain, and with the OIDC fields', () {
      final plain = HumanLoginRequest.fromSetupUri(
        Uri.parse(
          'https://app.example.com/login-with-raft/setup?client_id=c'
          '&return_to=https%3A%2F%2Fa.example.com%2Fcb&scope=openid&server=acme',
        ),
      );
      expect(plain.authorizeBody(clientId: 'c', serverId: 'srv-1'), {
        'clientId': 'c',
        'serverId': 'srv-1',
        'returnUrl': 'https://a.example.com/cb',
        'scopes': ['openid'],
      });
      final oidc = HumanLoginRequest.fromSetupUri(
        Uri.parse(
          'https://app.example.com/login-with-raft/setup?client_id=c'
          '&return_to=https%3A%2F%2Fa.example.com%2Fcb&scope=openid&server=acme'
          '&flow=oidc&nonce=n1&code_challenge=ch&code_challenge_method=S256',
        ),
      );
      expect(oidc.authorizeBody(clientId: 'c', serverId: 'srv-1'), {
        'clientId': 'c',
        'serverId': 'srv-1',
        'returnUrl': 'https://a.example.com/cb',
        'scopes': ['openid'],
        'oidc': true,
        'nonce': 'n1',
        'codeChallenge': 'ch',
        'codeChallengeMethod': 'S256',
        'server': 'acme',
      });
    });
  });

  group('lookup', () {
    HumanLoginRequest request({String server = '', String client = 'c'}) =>
        HumanLoginRequest(
          clientId: client,
          returnUrl: 'https://a.example.com/cb',
          state: 's',
          scopes: const ['openid', 'profile'],
          serverHint: server,
        );
    const acme = HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme');
    const beta = HumanLoginServer(id: 'srv-2', slug: 'beta', name: 'Beta');

    test('sends the parameters Web sends, per candidate server', () async {
      final api = FakeHumanLoginApi(servers: const [acme, beta]);
      await lookupHumanLoginClient(api, request());
      expect(api.lookups.map((l) => l.serverId), ['srv-1', 'srv-2']);
      expect(api.lookups.first.query, {
        'client_id': 'c',
        'server_id': 'srv-1',
        'scope': 'openid profile',
      });
    });

    test('the server parameter names the server, by id or by slug', () async {
      for (final hint in ['srv-2', 'beta']) {
        final api = FakeHumanLoginApi(servers: const [acme, beta]);
        final found = await lookupHumanLoginClient(api, request(server: hint));
        expect(api.lookups.map((l) => l.serverId), ['srv-2']);
        expect(found.single.server.slug, 'beta');
      }
    });

    test('a server the account is not in: Web\'s "no access" text', () async {
      final api = FakeHumanLoginApi(servers: const [acme]);
      await expectLater(
        lookupHumanLoginClient(api, request(server: 'srv-9')),
        throwsA(
          isA<HumanLoginException>().having(
            (e) => e.text,
            'text',
            'You do not have access to any Raft Servers.',
          ),
        ),
      );
      expect(api.lookups, isEmpty);
    });

    test('an app registered nowhere, and a missing client id', () async {
      final api = FakeHumanLoginApi(servers: const [acme], clients: {});
      await expectLater(
        lookupHumanLoginClient(api, request()),
        throwsA(
          isA<HumanLoginException>().having(
            (e) => e.text,
            'text',
            'This app is not registered for any Raft Server you can access.',
          ),
        ),
      );
      await expectLater(
        lookupHumanLoginClient(api, request(client: ' ')),
        throwsA(
          isA<HumanLoginException>().having(
            (e) => e.text,
            'text',
            'This service is missing a registered client id.',
          ),
        ),
      );
    });

    test(
      'ready servers come first, then by name; a failure is skipped',
      () async {
        const gamma = HumanLoginServer(
          id: 'srv-3',
          slug: 'gamma',
          name: 'Gamma',
        );
        final api = FakeHumanLoginApi(
          servers: const [gamma, beta, acme],
          clients: {
            'srv-1': FakeHumanLoginApi.app(
              installRequired: true,
              canInstall: true,
            ),
            'srv-2': FakeHumanLoginApi.app(),
            // srv-3 answers 404.
          },
        );
        final found = await lookupHumanLoginClient(api, request());
        expect(found.map((c) => c.server.slug), ['beta', 'acme']);
        expect(found.last.client.installRequired, isTrue);
        expect(found.last.client.canInstall, isTrue);
      },
    );

    test('Web canContinue: install, scope and return-URL rules', () async {
      HumanLoginChoice choice(Map<String, Object?> client) =>
          HumanLoginChoice(acme, HumanLoginClient.fromJson(client));
      final ok = request();
      expect(
        humanLoginCanContinue(ok, choice(FakeHumanLoginApi.app())),
        isTrue,
      );
      expect(
        humanLoginCanContinue(
          ok,
          choice(FakeHumanLoginApi.app(installRequired: true)),
        ),
        isFalse,
      );
      expect(
        humanLoginCanContinue(
          ok,
          choice(
            FakeHumanLoginApi.app(
              disallowed: ['agent:read'],
              reason: 'not_allowed',
            ),
          ),
        ),
        isFalse,
      );
      expect(
        humanLoginCanContinue(
          HumanLoginRequest(
            clientId: 'c',
            returnUrl: 'https://a.example.com/cb',
            state: '',
            scopes: const ['openid', 'agent:event:write'],
            serverHint: '',
          ),
          choice(FakeHumanLoginApi.app()),
        ),
        isFalse,
        reason: 'agent messaging needs Agent Login, not this page',
      );
      expect(
        humanLoginCanContinue(
          HumanLoginRequest(
            clientId: 'c',
            returnUrl: ' ',
            state: '',
            scopes: const ['openid'],
            serverHint: '',
          ),
          choice(FakeHumanLoginApi.app()),
        ),
        isFalse,
      );
    });
  });

  group('authorize', () {
    final request = HumanLoginRequest(
      clientId: 'artifact-share',
      returnUrl: 'https://artifacts.example.com/auth/callback?x=1',
      state: 'st-1',
      scopes: const ['openid', 'profile'],
      serverHint: '',
    );
    final choice = HumanLoginChoice(
      const HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme'),
      HumanLoginClient.fromJson(FakeHumanLoginApi.app()),
    );

    test(
      'posts the body and builds the callback with code and state',
      () async {
        final api = FakeHumanLoginApi();
        final location = await authorizeHumanLogin(api, request, choice);
        expect(api.authorizations, [
          {
            'clientId': 'artifact-share',
            'serverId': 'srv-1',
            'returnUrl': 'https://artifacts.example.com/auth/callback?x=1',
            'scopes': ['openid', 'profile'],
          },
        ]);
        expect(
          location.toString(),
          'https://artifacts.example.com/auth/callback?x=1&code=issued-code-1&state=st-1',
        );
      },
    );

    test('shows the server\'s error_description, else its error', () async {
      var api = FakeHumanLoginApi(
        authorizeError: RaftApiException.response(
          'invalid_scope',
          status: 400,
          body: {
            'error': 'invalid_scope',
            'error_description':
                'This OAuth client is not allowed to request: agent:read.',
          },
        ),
      );
      await expectLater(
        authorizeHumanLogin(api, request, choice),
        throwsA(
          isA<HumanLoginException>().having(
            (e) => e.text,
            'text',
            'This OAuth client is not allowed to request: agent:read.',
          ),
        ),
      );
      api = FakeHumanLoginApi(
        authorizeError: RaftApiException.response(
          'OAuth client not found for server',
          status: 404,
          body: {'error': 'OAuth client not found for server'},
        ),
      );
      await expectLater(
        authorizeHumanLogin(api, request, choice),
        throwsA(
          isA<HumanLoginException>().having(
            (e) => e.text,
            'text',
            'OAuth client not found for server',
          ),
        ),
      );
    });

    test(
      'anything else is Web\'s generic text; no code leaves in it',
      () async {
        for (final api in [
          FakeHumanLoginApi(authorizeError: StateError('boom code=secret-1')),
          // A return URL the callback rule refuses.
          FakeHumanLoginApi(
            authorizeResult: {
              'code': 'secret-2',
              'returnUrl': 'http://attacker.test/cb',
            },
          ),
          FakeHumanLoginApi(
            authorizeResult: {'returnUrl': 'https://a.example.com/cb'},
          ),
        ]) {
          await expectLater(
            authorizeHumanLogin(api, request, choice),
            throwsA(
              isA<HumanLoginException>().having(
                (e) => e.text,
                'text',
                'Failed to continue with Raft.',
              ),
            ),
          );
        }
      },
    );
  });
}
