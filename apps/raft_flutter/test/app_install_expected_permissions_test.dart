// Server v1.24.0 routes/integrations.ts:1242-1246: POST
// /integrations/marketplace/:id/install answers 400 EXPECTED_PERMISSIONS_REQUIRED
// unless the body carries `expected_scopes` and `expected_groups`
// (services/appPermissionExpectation.ts:78-88), and 409 APP_PERMISSIONS_CHANGED
// unless they equal the app's current set (:105-120). With app_prompt_text_consent
// on it also needs `expected_text_revision_id`.
//
// Web v1.24.0 sends exactly what it showed:
// - Login with Raft, HumanLoginSetupPage.tsx:388-405 `installMarketplaceApp`;
// - Settings, IntegrationsSection.tsx:756-771 `handleInstallMarketplaceApp`.
// Both build `expectedAppPermissionsBody(effectiveAllowedOAuthScopes(allowedScopes),
// appNotificationGroups)` (lib/appPermissionExpectation.ts:10-12) plus the
// text revision while the flag is on (lib/appPromptText.ts:94-96). On a 409
// both take the current set from the answer, so the next press sends it.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart' show frames;

const _revision = '0b6d1c2e-3f40-4a51-8b62-7c83d94ea5f6';
const _newRevision = '1c7e2d3f-4051-4b62-9c73-8d94ea5fb607';
const _installPath = '/integrations/marketplace/app-record-1/install';

/// The HTTP side of the app's session client: routes by `METHOD path`, each
/// answer `(status, body)` consumed in order (the last one repeats).
class _Server implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final answers = <String, List<(int, Object?)>>{};
  bool consent = false;

  List<RequestOptions> to(String path) =>
      calls.where((c) => c.method == 'POST' && c.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final key = '${o.method} ${o.path}';
    (int, Object?) answer = switch (key) {
      'POST /auth/login' => (
        200,
        <String, Object?>{
          'accessToken': 'fixture-only',
          'refreshToken': 'fixture-only',
          'user': {'id': 'alice', 'email': 'alice@example.com'},
        },
      ),
      'POST /feature-flags/evaluate' => (
        200,
        <String, Object?>{
          'evaluations': [
            {'key': 'app_prompt_text_consent', 'enabled': consent},
          ],
        },
      ),
      _ => (404, <String, Object?>{'error': 'Unexpected endpoint'}),
    };
    final queue = answers[key];
    if (queue != null && queue.isNotEmpty) {
      answer = queue.length > 1 ? queue.removeAt(0) : queue.first;
    }
    return ResponseBody.fromString(
      jsonEncode(answer.$2),
      answer.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _changed({
  List<String> scopes = const ['openid', 'profile', 'email'],
  List<String> groups = const ['messages'],
  String revision = _revision,
}) => {
  'error':
      "The app's permissions changed after they were shown. Review the "
      'current permissions and confirm again.',
  'code': 'APP_PERMISSIONS_CHANGED',
  'current_scopes': scopes,
  'current_groups': groups,
  'current_text_revision_id': revision,
  'current_text': null,
};

void main() {
  group('Login with Raft "Install and continue"', () {
    late _Server server;
    late RaftClient client;
    late ClientHumanLoginApi api;
    const callback = 'https://artifacts.example.com/auth/callback';

    Map<String, Object?> lookup({Object? allowedScopes = const ['openid']}) => {
      'id': 'app-record-1',
      'clientId': 'artifact-share',
      'appType': 'third_party_global',
      'name': 'Artifact Share',
      'returnUrl': callback,
      'allowedScopes': allowedScopes,
      'appNotificationGroups': ['messages', 'channels'],
      'promptTextRevisionId': _revision,
      'marketplace': true,
      'availability': 'install_required',
      'installation': {'serverId': 'srv-2', 'canInstall': true},
    };

    setUp(() async {
      server = _Server();
      client = RaftClient(
        origin: 'https://api.example.com',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = server,
      );
      await client.login('fixture', 'fixture');
      client.selectServer('srv-1');
      api = ClientHumanLoginApi(
        client: client,
        webOrigin: Uri.parse('https://app.example.com'),
        directory: () => [
          RaftRecord({'id': 'srv-2', 'slug': 'beta', 'name': 'Beta'}),
        ],
      );
    });
    tearDown(() => client.dispose());

    final request = HumanLoginRequest(
      clientId: 'artifact-share',
      returnUrl: callback,
      state: 'st-1',
      scopes: const ['openid'],
      serverHint: 'srv-2',
    );

    Future<HumanLoginChoice> found(Map<String, Object?> app) async {
      server.answers['GET /oauth/clients/lookup'] = [(200, app)];
      return (await lookupHumanLoginClient(api, request)).choices.single;
    }

    test('sends the set the lookup returned, and the text revision while '
        'the installing server has app_prompt_text_consent on', () async {
      server
        ..consent = true
        ..answers['POST $_installPath'] = [
          (200, {'id': 'install-1'}),
        ];
      await installHumanLoginApp(
        api,
        await found(lookup(allowedScopes: ['openid', 'profile', 'agent:read'])),
      );
      final install = server.to(_installPath).single;
      expect(install.headers['X-Server-Id'], 'srv-2');
      expect(install.data, {
        'expected_scopes': ['openid', 'profile', 'agent:read'],
        'expected_groups': ['messages', 'channels'],
        'expected_text_revision_id': _revision,
      });
      // The flag is the installing server's (Web readServerFeatureFlag(entry.server.id)).
      final flags = server.to('/feature-flags/evaluate').single;
      expect((flags.data as Map)['serverId'], 'srv-2');
      expect((flags.data as Map)['keys'], ['app_prompt_text_consent']);
    });

    test('with the flag off no text revision is sent, and an app that '
        'declares no scopes confirms the default ones', () async {
      server.answers['POST $_installPath'] = [
        (200, {'id': 'install-1'}),
      ];
      await installHumanLoginApp(api, await found(lookup(allowedScopes: null)));
      expect(server.to(_installPath).single.data, {
        // shared/src/oauthScopes.ts: the defaultAllowed scopes.
        'expected_scopes': ['openid', 'profile', 'identity'],
        'expected_groups': ['messages', 'channels'],
      });
    });

    testWidgets('a 409 says the permissions changed and the next press sends '
        'the current set', (t) async {
      server
        ..consent = true
        ..answers['GET /oauth/clients/lookup'] = [(200, lookup())]
        ..answers['POST $_installPath'] = [
          (409, _changed()),
          (200, {'id': 'install-1'}),
        ]
        ..answers['POST /oauth/authorize/human'] = [
          (200, {'code': 'issued-code-1', 'returnUrl': callback}),
        ];
      t.view
        ..physicalSize = const Size(390, 1800)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) => TextButton(
              key: const Key('go'),
              onPressed: () =>
                  showHumanLoginSheet(context, api: api, request: request),
              child: const Text('go'),
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await frames(t, 3);
        }
      }

      await t.tap(find.byKey(const Key('go')));
      await settle();
      await t.tap(find.text('Install and continue'));
      await settle();
      expect(
        find.text(
          "The text this app adds to agent prompts just changed. Review the "
          'current text, then try again.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          "This app's permissions just changed. Review the current "
          'permissions below, then install again.',
        ),
        findsOneWidget,
      );
      expect(server.to('/oauth/authorize/human'), isEmpty);

      await t.tap(find.text('Install and continue'));
      await settle();
      expect(server.to(_installPath), hasLength(2));
      expect(server.to(_installPath).last.data, {
        'expected_scopes': ['openid', 'profile', 'email'],
        'expected_groups': ['messages'],
        'expected_text_revision_id': _revision,
      });
      expect(server.to('/oauth/authorize/human'), hasLength(1));
    });

    test('a changed prompt text and a page the server calls out of date say '
        'so in Web\'s words', () async {
      server
        ..consent = true
        ..answers['POST $_installPath'] = [
          (
            409,
            {
              ..._changed(revision: _newRevision),
              'current_text': {
                'name': 'Slack Journal',
                'description': null,
                'when_to_use': 'Read notes from a linked channel.',
              },
            },
          ),
          (
            400,
            {
              'error': 'Send expected_scopes ...',
              'code': 'EXPECTED_PERMISSIONS_REQUIRED',
            },
          ),
        ];
      final choice = await found(lookup());
      await expectLater(
        installHumanLoginApp(api, choice),
        throwsA(
          isA<HumanLoginPermissionsChanged>()
              .having(
                (e) => e.text,
                'text',
                'The text this app adds to agent prompts just changed. Review the '
                    'current text, then try again.',
              )
              .having((e) => e.choice.client.name, 'name', 'Slack Journal')
              .having((e) => e.choice.client.description, 'description', null)
              .having(
                (e) => e.choice.client.whenToUse,
                'when to use',
                'Read notes from a linked channel.',
              ),
        ),
      );
      await expectLater(
        installHumanLoginApp(api, choice),
        throwsA(
          isA<HumanLoginException>().having(
            (e) => e.text,
            'text',
            "This page is out of date. Reload it, review the app's "
                'permissions, then try again.',
          ),
        ),
      );
    });
  });

  test('every refusal text reads in Chinese with the Web zh-cn wording', () {
    const zh = {
      "This app's permissions just changed. Review the current permissions below, then install again.":
          '应用的权限刚刚变了，请查看下方新的权限后再安装。',
      "This app's permissions just changed. Review the current permissions, then confirm again.":
          '应用的权限刚刚变了，请看过新的权限再确认。',
      'The text this app adds to agent prompts just changed. Review the current text, then try again.':
          '此应用加进 Agent prompt 的文字刚刚变了，请查看当前文字后再试。',
      "This page is out of date. Reload it, review the app's permissions, then try again.":
          '此页面已过期。请刷新，查看应用的权限后再试。',
    };
    for (final MapEntry(key: en, value: text) in zh.entries) {
      expect(raftChinese[en], text, reason: en);
    }
  });

  group('Settings marketplace Install', () {
    Map<String, Object?> listing({
      List<String> scopes = const ['openid', 'profile'],
      List<String> groups = const ['messages'],
      String revision = _revision,
    }) => {
      'id': 'app-record-1',
      'clientId': 'client_slack',
      'name': 'Slack Bridge',
      'description': 'Slack Bridge description',
      'category': 'Developer Tools',
      'publisherName': 'Raft Labs',
      'homepageUrl': 'https://example.com/slack',
      'returnUrl': 'https://example.com/slack/callback',
      'allowedScopes': scopes,
      'appNotificationGroups': groups,
      'promptTextRevisionId': revision,
      'installedAt': null,
      'privateShared': false,
      'publishStatus': 'published',
      'marketplaceInstallBadge': {'kind': 'none'},
    };

    Future<_Server> mount(WidgetTester t, {required bool consent}) async {
      final server = _Server()..consent = consent;
      final (w, client) = (await t.runAsync(() async {
        final client = RaftClient(
          origin: 'https://example.invalid',
          sessionStore: MemorySessionStore(),
          transport: Dio()..httpClientAdapter = server,
        );
        await client.login('fixture', 'fixture');
        client.selectServer('s1');
        final w = WorkspaceController(client)
          ..server = RaftRecord({
            'id': 's1',
            'name': 'Test workspace',
            'slug': 'test',
            'plan': 'free',
            'role': 'owner',
          });
        w.servers = [w.server!];
        return (w, client);
      }))!;
      addTearDown(w.dispose);
      server.answers
        ..['GET /integrations/marketplace'] = [
          (200, [listing()]),
        ]
        ..['GET /integrations/clients'] = [(200, <Object?>[])]
        ..['GET /integrations/overview'] = [(200, <Object?>[])];
      t.view
        ..physicalSize = const Size(1280, 2000)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [IntegrationsView(controller: w)],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-marketplace')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-app-app-record-1')));
      await t.pumpAndSettle();
      expect(client.user, isNotNull);
      return server;
    }

    testWidgets('Install sends the set the detail shows and, with the flag '
        'on, the prompt-text revision', (t) async {
      final server = await mount(t, consent: true);
      expect(find.text('Text added to agent prompts'), findsOneWidget);
      expect(find.text('Login scopes'), findsOneWidget);
      server.answers['POST $_installPath'] = [
        (200, {'ok': true}),
      ];
      await t.tap(find.byKey(const ValueKey('connected-app-install')));
      await t.pumpAndSettle();
      expect(server.to(_installPath).single.data, {
        'expected_scopes': ['openid', 'profile'],
        'expected_groups': ['messages'],
        'expected_text_revision_id': _revision,
      });
      final flags = server.to('/feature-flags/evaluate').single;
      expect((flags.data as Map)['serverId'], 's1');
    });

    testWidgets('a 409 says the permissions changed, reloads, and the next '
        'Install sends the current set', (t) async {
      final server = await mount(t, consent: false);
      server.answers['POST $_installPath'] = [
        (409, _changed(scopes: ['openid'], groups: [])),
        (200, {'ok': true}),
      ];
      server.answers['GET /integrations/marketplace'] = [
        (
          200,
          [
            listing(scopes: ['openid'], groups: []),
          ],
        ),
      ];
      await t.tap(find.byKey(const ValueKey('connected-app-install')));
      await t.pumpAndSettle();
      expect(
        find.text(
          "This app's permissions just changed. Review the current "
          'permissions, then confirm again.',
        ),
        findsOneWidget,
      );
      expect(server.to(_installPath).single.data, {
        'expected_scopes': ['openid', 'profile'],
        'expected_groups': ['messages'],
      });
      await t.tap(find.byKey(const ValueKey('connected-app-install')));
      await t.pumpAndSettle();
      expect(server.to(_installPath).last.data, {
        'expected_scopes': ['openid'],
        'expected_groups': <String>[],
      });
    });
  });
}
