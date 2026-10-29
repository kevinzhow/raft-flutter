import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart' show frames;
import 'support/human_login_fake.dart';

/// Phase 2 of Login with Raft: a Marketplace app the server has not
/// installed ("Install and continue"), and the picker of several servers.
/// The HTTP layer is the fake; the sheet and the flow are the app's own.
void main() {
  // Tall, so a long sheet shows whole (its pinned title would cover a row that
  // ensureVisible scrolls to the top).
  const phone = Size(390, 1800);
  const callback = 'https://artifacts.example.com/auth/callback';
  const acme = HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme');
  const beta = HumanLoginServer(id: 'srv-2', slug: 'beta', name: 'Beta');

  final sheet = find.byKey(const ValueKey('human-login-sheet'));
  final primary = find.byKey(const ValueKey('human-login-continue'));
  final cancel = find.byKey(const ValueKey('human-login-cancel'));
  final error = find.byKey(const ValueKey('human-login-error'));
  final commitZone = find.byKey(const ValueKey('human-login-commit-zone'));

  Uri? result;
  var done = false;

  Future<void> open(
    WidgetTester t,
    FakeHumanLoginApi api, {
    String server = 'srv-1',
    Size size = phone,
    Locale locale = const Locale('en'),
  }) async {
    result = null;
    done = false;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('go'),
            onPressed: () async {
              result = await showHumanLoginSheet(
                context,
                api: api,
                request: HumanLoginRequest.fromSetupUri(
                  Uri.parse(
                    'https://app.example.com/login-with-raft/setup'
                    '?client_id=artifact-share'
                    '&return_to=${Uri.encodeComponent(callback)}&state=st-1'
                    '&scope=openid+profile${server.isEmpty ? '' : '&server=$server'}',
                  ),
                ),
              );
              done = true;
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('go')));
    await frames(t, 25);
  }

  Future<void> tapKey(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await frames(t);
    await t.tap(f);
    await frames(t, 25);
  }

  /// A Marketplace app waiting for an install on [acme].
  FakeHumanLoginApi waiting({
    bool canInstall = true,
    String? setupUrl,
    String? setupDescription,
    Object? installError,
    Object? authorizeError,
    Completer<void>? gate,
  }) => FakeHumanLoginApi(
    client: FakeHumanLoginApi.app(
      installRequired: true,
      canInstall: canInstall,
      setupUrl: setupUrl,
      setupDescription: setupDescription,
    ),
    installError: installError,
    authorizeError: authorizeError,
    installGate: gate,
  );

  RaftApiException refusal(String message, {String? description}) =>
      RaftApiException.response(
        message,
        status: 403,
        body: {'error': message, 'error_description': ?description},
      );

  RaftButton button(WidgetTester t, Finder f) => t.widget<RaftButton>(f);

  group('Install and continue', () {
    testWidgets(
      'offers it, in Web\'s words, and acts on nothing until pressed',
      (t) async {
        final api = waiting();
        await open(t, api);
        expect(
          find.descendant(
            of: commitZone,
            matching: find.textContaining('has not installed Artifact Share'),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'You are an admin of this Server. Continuing will install the App as you.',
          ),
          findsOneWidget,
        );
        expect(find.text('Access granted: openid · profile'), findsOneWidget);
        expect(find.text('Install and continue'), findsOneWidget);
        expect(
          find.text('Login with Raft'),
          findsOneWidget,
          reason: 'the title',
        );
        expect(button(t, primary).onPressed, isNotNull);
        // Looking at it installed and authorized nothing.
        expect(api.installs, isEmpty);
        expect(api.authorizations, isEmpty);
        expect(done, isFalse);
      },
    );

    testWidgets('installs the app on that server, then continues the login', (
      t,
    ) async {
      final api = waiting();
      await open(t, api);
      await tapKey(t, primary);
      expect(api.calls, ['lookup:srv-1', 'install:srv-1', 'authorize:srv-1']);
      expect(api.installs.single.appId, 'app-record-1');
      expect(api.authorizations.single, {
        'clientId': 'artifact-share',
        'serverId': 'srv-1',
        'returnUrl': callback,
        'scopes': ['openid', 'profile'],
      });
      expect(done, isTrue);
      expect(result.toString(), '$callback?code=issued-code-1&state=st-1');
    });

    testWidgets('while it installs: the button says so and nothing can leave', (
      t,
    ) async {
      final gate = Completer<void>();
      final api = waiting(gate: gate);
      await open(t, api);
      await t.tap(primary);
      await frames(t);
      expect(find.text('Installing and continuing...'), findsOneWidget);
      expect(button(t, primary).onPressed, isNull);
      expect(button(t, cancel).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('human-login-install-row-spinner')),
        findsOneWidget,
        reason: 'the row of the server being installed on',
      );
      // A second press, Escape and the back gesture install nothing twice.
      await t.tap(primary, warnIfMissed: false);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(t);
      expect(sheet, findsOneWidget);
      expect(api.installs, hasLength(1));
      gate.complete();
      await frames(t, 25);
      expect(api.calls, ['lookup:srv-1', 'install:srv-1', 'authorize:srv-1']);
      expect(done, isTrue);
    });

    testWidgets(
      'a failed install shows the server\'s words and can be retried',
      (t) async {
        final api = waiting(installError: refusal('Marketplace app not found'));
        await open(t, api);
        await tapKey(t, primary);
        expect(
          find.descendant(
            of: error,
            matching: find.text('Marketplace app not found'),
          ),
          findsOneWidget,
        );
        // Nothing was authorized; the sheet stays, still offering the install.
        expect(api.authorizations, isEmpty);
        expect(done, isFalse);
        expect(find.text('Install and continue'), findsOneWidget);
        expect(button(t, primary).onPressed, isNotNull);
        expect(button(t, cancel).onPressed, isNotNull);
        // The person tries again and it works.
        api.installError = null;
        await tapKey(t, primary);
        expect(api.installs, hasLength(2));
        expect(done, isTrue);
        expect(result, isNotNull);
      },
    );

    testWidgets('an install failure without words shows Web\'s text', (
      t,
    ) async {
      final api = waiting(installError: StateError('boom code=secret-1'));
      await open(t, api);
      await tapKey(t, primary);
      expect(
        find.text('Failed to install this Marketplace app.'),
        findsOneWidget,
      );
      expect(find.textContaining('secret-1'), findsNothing);
    });

    testWidgets(
      'installed but the login refused: the app is ready, the person continues',
      (t) async {
        final api = waiting(
          authorizeError: refusal(
            'invalid_scope',
            description: 'This OAuth client is not allowed to request: x.',
          ),
        );
        await open(t, api);
        await tapKey(t, primary);
        expect(
          find.descendant(
            of: error,
            matching: find.text(
              'This OAuth client is not allowed to request: x.',
            ),
          ),
          findsOneWidget,
        );
        expect(done, isFalse);
        // It is installed now: the next press only continues the login.
        expect(find.text('Install and continue'), findsNothing);
        expect(find.text('Continue login'), findsOneWidget);
        expect(find.textContaining('Selected'), findsOneWidget);
        api.authorizeError = null;
        await tapKey(t, primary);
        expect(api.installs, hasLength(1), reason: 'never installed twice');
        expect(api.authorizations, hasLength(2));
        expect(done, isTrue);
        expect(result, isNotNull);
      },
    );

    testWidgets('shows the setup page the app asks for after the install', (
      t,
    ) async {
      final api = waiting(
        setupUrl: 'https://setup.example.com/configure',
        setupDescription: 'Paste your workspace key.',
      );
      await open(t, api);
      expect(
        find.byKey(const ValueKey('app-setup-requirement')),
        findsOneWidget,
      );
      expect(find.text('Setup required'), findsOneWidget);
      expect(
        find.text(
          'After installation, continue configuration at setup.example.com.',
        ),
        findsOneWidget,
      );
      expect(find.text('Paste your workspace key.'), findsOneWidget);
      expect(api.installs, isEmpty);
    });

    testWidgets('scopes the person cannot grant block the install too', (
      t,
    ) async {
      final api = FakeHumanLoginApi(
        client: FakeHumanLoginApi.app(
          installRequired: true,
          canInstall: true,
          disallowed: ['agent:read'],
          reason: 'not_allowed',
        ),
      );
      await open(t, api);
      expect(
        find.byKey(const ValueKey('human-login-scope-error')),
        findsOneWidget,
      );
      expect(button(t, primary).onPressed, isNull);
      await t.tap(primary, warnIfMissed: false);
      await frames(t);
      expect(api.installs, isEmpty);
    });

    testWidgets('Cancel before installing installs and authorizes nothing', (
      t,
    ) async {
      final api = waiting();
      await open(t, api);
      await tapKey(t, cancel);
      expect(sheet, findsNothing);
      expect(done, isTrue);
      expect(result, isNull);
      expect(api.installs, isEmpty);
      expect(api.authorizations, isEmpty);
    });

    testWidgets('Cancel after a failed install leaves it uninstalled', (
      t,
    ) async {
      final api = waiting(installError: refusal('Marketplace app not found'));
      await open(t, api);
      await tapKey(t, primary);
      await tapKey(t, cancel);
      expect(sheet, findsNothing);
      expect(result, isNull);
      expect(api.installs, hasLength(1));
      expect(api.authorizations, isEmpty);
    });

    testWidgets('Cancel after install + refused login returns no callback', (
      t,
    ) async {
      final api = waiting(authorizeError: refusal('Nope'));
      await open(t, api);
      await tapKey(t, primary);
      await tapKey(t, cancel);
      expect(sheet, findsNothing);
      expect(result, isNull);
      expect(api.authorizations, hasLength(1));
    });

    testWidgets('Cancel while the servers load asks for nothing more', (
      t,
    ) async {
      final gate = Completer<void>();
      final api = waiting()..lookupGate = gate;
      await open(t, api);
      expect(find.text('Loading available Raft Servers...'), findsOneWidget);
      expect(
        button(t, primary).onPressed,
        isNull,
        reason: 'nothing to confirm yet',
      );
      await tapKey(t, cancel);
      expect(sheet, findsNothing);
      expect(result, isNull);
      // The answer arriving late changes nothing.
      gate.complete();
      await frames(t, 25);
      expect(api.installs, isEmpty);
      expect(api.authorizations, isEmpty);
    });
  });

  group('a person who cannot install', () {
    testWidgets('gets Web\'s explanation and no button', (t) async {
      final api = waiting(canInstall: false);
      await open(t, api);
      expect(
        find.descendant(
          of: commitZone,
          matching: find.textContaining(
            'Only an owner or admin of this Server can install it.',
          ),
        ),
        findsOneWidget,
      );
      expect(primary, findsNothing);
      expect(find.text('Install and continue'), findsNothing);
      expect(find.text('Continue login'), findsNothing);
      expect(cancel, findsOneWidget);
      expect(api.installs, isEmpty);
      expect(api.authorizations, isEmpty);
    });

    testWidgets('Cancel closes without a callback', (t) async {
      final api = waiting(canInstall: false);
      await open(t, api);
      await tapKey(t, cancel);
      expect(result, isNull);
      expect(done, isTrue);
    });
  });

  group('server picker', () {
    FakeHumanLoginApi several({
      int count = 3,
      Map<String, Map<String, Object?>>? overrides,
    }) {
      final servers = [
        acme,
        beta,
        for (var i = 3; i <= count; i++)
          HumanLoginServer(
            id: 'srv-$i',
            slug: 'team-$i',
            name: 'Team ${String.fromCharCode(64 + i)}',
          ),
      ];
      return FakeHumanLoginApi(
        servers: servers,
        clients: {
          // Acme: installed. Beta: can install. Others: admin needed.
          'srv-1': FakeHumanLoginApi.app(marketplace: true),
          'srv-2': FakeHumanLoginApi.app(
            installRequired: true,
            canInstall: true,
          ),
          for (var i = 3; i <= count; i++)
            'srv-$i': FakeHumanLoginApi.app(installRequired: true),
          ...?overrides,
        },
      );
    }

    testWidgets('lists every server with its state, ready first', (t) async {
      final api = several();
      await open(t, api, server: '');
      for (final id in ['srv-1', 'srv-2', 'srv-3']) {
        expect(find.byKey(ValueKey('human-login-server-$id')), findsOneWidget);
      }
      String state(String id) => t
          .widget<RaftSettingsRecipeBadge>(
            find.byKey(ValueKey('human-login-server-state-$id')),
          )
          .label;
      expect(state('srv-1'), 'Installed');
      expect(state('srv-2'), 'Not installed');
      expect(state('srv-3'), 'Admin needed');
      // The best server is the one selected: Acme, installed.
      expect(find.text('Selected Acme.'), findsOneWidget);
      expect(find.text('Continue login'), findsOneWidget);
      // No search for a few servers.
      expect(
        find.byKey(const ValueKey('human-login-server-search')),
        findsNothing,
      );
    });

    testWidgets('choosing a server does not install or authorize', (t) async {
      final api = several();
      await open(t, api, server: '');
      await tapKey(t, find.byKey(const ValueKey('human-login-server-srv-2')));
      expect(api.installs, isEmpty);
      expect(api.authorizations, isEmpty);
      // Beta can be installed on: its commit zone and button.
      expect(find.text('Install and continue'), findsOneWidget);
      expect(
        find.textContaining('Beta has not installed Artifact Share'),
        findsOneWidget,
      );
      // Admin-needed Team C: explanation, no button.
      await tapKey(t, find.byKey(const ValueKey('human-login-server-srv-3')));
      expect(primary, findsNothing);
      expect(
        find.textContaining('Only an owner or admin of this Server'),
        findsOneWidget,
      );
      expect(api.installs, isEmpty);
    });

    testWidgets('installs on the picked server, not the first one', (t) async {
      final api = several();
      await open(t, api, server: '');
      await tapKey(t, find.byKey(const ValueKey('human-login-server-srv-2')));
      await tapKey(t, primary);
      expect(api.calls.skip(3), ['install:srv-2', 'authorize:srv-2']);
      expect(api.authorizations.single['serverId'], 'srv-2');
      expect(done, isTrue);
    });

    testWidgets('a server that did not answer is Unavailable, not usable', (
      t,
    ) async {
      final api = several(count: 2);
      api.clients.remove('srv-2');
      await open(t, api, server: '');
      expect(
        t
            .widget<RaftSettingsRecipeBadge>(
              find.byKey(const ValueKey('human-login-server-state-srv-2')),
            )
            .label,
        'Unavailable',
      );
      await tapKey(t, find.byKey(const ValueKey('human-login-server-srv-2')));
      expect(
        find.text(
          'Installation status could not be loaded. Reload this page to try again.',
        ),
        findsOneWidget,
      );
      expect(button(t, primary).onPressed, isNull);
      expect(api.installs, isEmpty);
      expect(api.authorizations, isEmpty);
    });

    testWidgets('more than five servers: a search by name or slug', (t) async {
      final api = several(count: 7);
      await open(t, api, server: '');
      final search = find.byKey(const ValueKey('human-login-server-search'));
      expect(search, findsOneWidget);
      Future<void> type(String text) async {
        await t.enterText(
          find.descendant(of: search, matching: find.byType(EditableText)),
          text,
        );
        await frames(t);
      }

      await type('team-5');
      expect(
        find.byKey(const ValueKey('human-login-server-srv-5')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('human-login-server-srv-1')),
        findsNothing,
      );
      await type('ACME');
      expect(
        find.byKey(const ValueKey('human-login-server-srv-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('human-login-server-srv-5')),
        findsNothing,
      );
      await type('nothing like it');
      expect(
        find.byKey(const ValueKey('human-login-no-server-match')),
        findsOneWidget,
      );
      expect(find.text('No Servers match your search.'), findsOneWidget);
      // A search does not change the server chosen.
      expect(api.installs, isEmpty);
      expect(api.authorizations, isEmpty);
    });

    testWidgets('rows and search are locked while it installs', (t) async {
      final gate = Completer<void>();
      final api = several(count: 7)..installGate = gate;
      await open(t, api, server: '');
      await tapKey(t, find.byKey(const ValueKey('human-login-server-srv-2')));
      await t.tap(primary);
      await frames(t);
      expect(
        find.byKey(const ValueKey('human-login-install-row-spinner')),
        findsOneWidget,
      );
      await t.tap(
        find.byKey(const ValueKey('human-login-server-srv-3')),
        warnIfMissed: false,
      );
      await frames(t);
      expect(find.text('Installing and continuing...'), findsOneWidget);
      expect(
        find.textContaining('Beta has not installed'),
        findsOneWidget,
        reason: 'the server being installed on stays selected',
      );
      gate.complete();
      await frames(t, 25);
      expect(api.authorizations.single['serverId'], 'srv-2');
    });

    testWidgets('the server the link names is the only one offered', (t) async {
      final api = several();
      await open(t, api, server: 'beta');
      expect(api.lookups.map((l) => l.serverId), ['srv-2']);
      expect(
        find.byKey(const ValueKey('human-login-server-srv-1')),
        findsNothing,
      );
      expect(find.text('Install and continue'), findsOneWidget);
    });

    testWidgets('a server the account is not a member of: Web\'s message', (
      t,
    ) async {
      final api = several();
      await open(t, api, server: 'srv-elsewhere');
      expect(api.lookups, isEmpty);
      expect(
        find.descendant(
          of: error,
          matching: find.text('You do not have access to any Raft Servers.'),
        ),
        findsOneWidget,
      );
      expect(primary, findsNothing);
      expect(find.text('Back'), findsOneWidget);
      await tapKey(t, cancel);
      expect(result, isNull);
      expect(api.installs, isEmpty);
    });

    testWidgets('a server that answers "not a member" is kept as Unavailable', (
      t,
    ) async {
      // The lookup answers 404 for a server the account cannot see the app on.
      final api = several(count: 2)..clients.remove('srv-1');
      await open(t, api, server: '');
      expect(
        t
            .widget<RaftSettingsRecipeBadge>(
              find.byKey(const ValueKey('human-login-server-state-srv-1')),
            )
            .label,
        'Unavailable',
      );
      // The usable server is the one chosen first.
      expect(find.text('Install and continue'), findsOneWidget);
    });

    testWidgets('an app no server has: Web\'s "not accessible" explanation', (
      t,
    ) async {
      final api = FakeHumanLoginApi(clients: {});
      await open(t, api, server: '');
      expect(
        find.byKey(const ValueKey('human-login-not-accessible')),
        findsOneWidget,
      );
      expect(find.text('This App is not accessible yet'), findsOneWidget);
      expect(find.text('How can I get access?'), findsOneWidget);
      expect(primary, findsNothing);
      await tapKey(t, cancel);
      expect(result, isNull);
    });
  });

  group('page content', () {
    testWidgets('the FAQ opens in place with Web\'s three answers', (t) async {
      final api = waiting();
      await open(t, api);
      expect(find.byKey(const ValueKey('human-login-faq-body')), findsNothing);
      await tapKey(t, find.byKey(const ValueKey('human-login-faq')));
      expect(
        find.byKey(const ValueKey('human-login-faq-body')),
        findsOneWidget,
      );
      expect(find.text('What is Login with Raft?'), findsOneWidget);
      expect(find.text('How to register an App?'), findsOneWidget);
      expect(find.text('How can my agent use this app?'), findsOneWidget);
      await tapKey(t, find.byKey(const ValueKey('human-login-faq')));
      expect(find.byKey(const ValueKey('human-login-faq-body')), findsNothing);
      expect(api.installs, isEmpty);
    });

    testWidgets('reads in Chinese with Web\'s catalog wording', (t) async {
      final api = waiting(setupUrl: 'https://setup.example.com/configure');
      await open(t, api, locale: const Locale('zh', 'CN'));
      expect(find.text('安装并继续'), findsOneWidget);
      expect(find.text('将授予：openid · profile'), findsOneWidget);
      expect(
        find.textContaining('尚未安装 Artifact Share。你是该 Server 的管理员，继续将以你的身份安装。'),
        findsOneWidget,
      );
      expect(find.text('需要配置'), findsOneWidget);
      await t.tap(primary);
      await frames(t);
      expect(api.installs, hasLength(1));
    });

    testWidgets(
      'an installed Marketplace app continues with "Continue login"',
      (t) async {
        final api = FakeHumanLoginApi(
          client: FakeHumanLoginApi.app(marketplace: true),
        );
        await open(t, api);
        expect(find.text('Marketplace'), findsOneWidget);
        expect(find.text('Selected Acme.'), findsOneWidget);
        await tapKey(t, primary);
        expect(api.installs, isEmpty);
        expect(api.calls, ['lookup:srv-1', 'authorize:srv-1']);
        expect(done, isTrue);
      },
    );

    testWidgets(
      'an app that is not on the Marketplace keeps "Login with Raft"',
      (t) async {
        final api = FakeHumanLoginApi();
        await open(t, api);
        expect(
          find.byKey(const ValueKey('human-login-commit-zone')),
          findsNothing,
        );
        expect(t.widget<RaftButton>(primary).label, 'Login with Raft');
      },
    );
  });
}
