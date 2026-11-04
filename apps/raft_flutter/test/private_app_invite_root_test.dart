import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/private_app_invite.dart';
import 'package:raft_flutter/features/private_app_invite_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

Map<String, Object?> privateInvite({bool installed = false}) => {
  'client': {
    'id': 'private-app',
    'clientId': 'private-client',
    'name': 'Shared Calendar',
    'description': 'A calendar shared by its publisher.',
    'homepageUrl': 'https://calendar.example.invalid',
    'returnUrl': 'https://calendar.example.invalid/callback',
    'allowedScopes': ['openid', 'profile'],
    'publisherName': 'Publisher',
    'sourceServerName': 'Design',
  },
  'link': {'id': 'share', 'expiresAt': null},
  'manageableServers': [
    {
      'id': 'b',
      'name': 'Beta',
      'slug': 'beta',
      'role': 'owner',
      'installedAt': installed ? '2026-11-04T00:00:00Z' : null,
    },
  ],
};

void main() {
  testWidgets('permission summary opens by pointer and closes by keyboard', (
    t,
  ) async {
    final client = ScreenFixtureClient(
      (_, _, _) => privateInvite(),
      user: const {'id': 'alice'},
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: ScreenClientHost(
          create: () => client,
          builder: (_, api) => PrivateAppInviteView(
            client: api,
            link: const PrivateAppInviteLink('test-invite'),
            onClose: () {},
            onSettings: (_, _) async {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final disclosure = find.byKey(
      const ValueKey('human-login-identity-disclosure'),
    );
    expect(
      find.byKey(const ValueKey('human-login-scope-openid')),
      findsNothing,
    );
    await t.ensureVisible(disclosure);
    await t.tap(disclosure);
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('human-login-scope-openid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('human-login-scope-profile')),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('human-login-scope-openid')),
      findsNothing,
    );
    expect(client.requests.where((o) => o.startsWith('POST ')), isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });

  testWidgets(
    'choosing an installed target changes action without installing or switching',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      final invite = privateInvite();
      invite['manageableServers'] = <Map<String, Object?>>[
        {
          'id': 'a',
          'name': 'Alpha',
          'slug': 'alpha',
          'role': 'admin',
          'installedAt': '2026-11-04T00:00:00Z',
        },
        {
          'id': 'b',
          'name': 'Beta',
          'slug': 'beta',
          'role': 'owner',
          'installedAt': null,
        },
      ];
      f.overrides['GET /integration-invites/test-invite'] = (_) => invite;
      await f.mount(
        t,
        'light',
        856,
        uri: Uri.parse('/integration-invites/test-invite'),
      );
      expect(
        find.byKey(const ValueKey('private-app-invite-install')),
        findsOneWidget,
      );
      final select = find.byKey(const ValueKey('private-app-invite-server'));
      await t.ensureVisible(select);
      await t.tap(select);
      await f.flush(t);
      await t.tap(find.text('Alpha (installed)'));
      await f.flush(t);
      expect(
        find.byKey(const ValueKey('private-app-invite-install')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('private-app-invite-open-settings')),
        findsOneWidget,
      );
      expect(
        find.text('Shared Calendar is installed for Alpha.'),
        findsOneWidget,
      );
      expect(f.client.serverId, isNull);
      expect(
        f.adapter.calls.where((o) => o.path.endsWith('/install')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'private app route reviews before explicitly installing on selected server',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      f.overrides['GET /integration-invites/test-invite'] = (_) =>
          privateInvite();
      f.overrides['POST /integration-invites/test-invite/install'] = (o) {
        expect(o.data, {'serverId': 'b'});
        expect(o.headers['X-Server-Id'], 'b');
        return privateInvite(installed: true);
      };
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri.parse('/integration-invites/test-invite'),
      );
      expect(find.text('Install connected app'), findsOneWidget);
      expect(find.text('Shared Calendar'), findsOneWidget);
      expect(find.text('Requested access'), findsOneWidget);
      expect(
        f.adapter.calls.where(
          (o) => o.method == 'POST' && o.path.endsWith('/install'),
        ),
        isEmpty,
      );
      await t.tap(find.byKey(const ValueKey('private-app-invite-install')));
      await f.flush(t);
      expect(
        f.adapter.calls.where(
          (o) => o.path == '/integration-invites/test-invite/install',
        ),
        hasLength(1),
      );
      expect(
        find.byKey(const ValueKey('private-app-invite-open-settings')),
        findsOneWidget,
      );
    },
  );

  for (final theme in ['light', 'dark']) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        'installed invite opens selected server settings at $theme/$width',
        (t) async {
          final f = RootFixture();
          addTearDown(() => f.close(t));
          f.overrides['GET /integration-invites/test-invite'] = (_) =>
              privateInvite(installed: true);
          await f.mount(
            t,
            theme,
            width,
            uri: Uri.parse('/integration-invites/test-invite'),
          );
          final button = find.byKey(
            const ValueKey('private-app-invite-open-settings'),
          );
          await t.ensureVisible(button);
          await t.tap(button);
          await f.flush(t);
          expect(f.workspace(t).server?.id, 'b');
          expect(
            f.workspace(t).navigation.location.uri.path,
            '/s/beta/settings/integrations',
          );
          expect(
            f.adapter.calls.where(
              (o) => o.method == 'POST' && o.path.endsWith('/install'),
            ),
            isEmpty,
          );
        },
      );
    }
  }

  testWidgets('no manageable server has no install or settings action', (
    t,
  ) async {
    final f = RootFixture();
    addTearDown(() => f.close(t));
    f.overrides['GET /integration-invites/test-invite'] = (_) =>
        privateInvite()..['manageableServers'] = [];
    await f.mount(
      t,
      'light',
      390,
      uri: Uri.parse('/integration-invites/test-invite'),
    );
    expect(
      find.text(
        'You need to be an owner or admin of a server to install this app.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('private-app-invite-install')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('private-app-invite-open-settings')),
      findsNothing,
    );
  });

  testWidgets(
    'installed private app setup reads the chosen server without switching',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      final invite = privateInvite(installed: true);
      (invite['client'] as Map)['setupUrl'] =
          'https://calendar.example.invalid/setup';
      f.overrides['GET /integration-invites/test-invite'] = (_) => invite;
      f.overrides['GET /integrations/clients/private-app/setup'] = (o) {
        expect(o.headers['X-Server-Id'], 'b');
        return {
          'status': 'pending',
          'revision': 1,
          'canConfigure': true,
          'url': 'https://calendar.example.invalid/setup',
          'description': 'Connect your calendar.',
          'completedAt': null,
        };
      };
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri.parse('/integration-invites/test-invite'),
      );
      expect(find.text('Connect your calendar.'), findsOneWidget);
      expect(
        f.adapter.calls.where(
          (o) => o.path == '/integrations/clients/private-app/setup',
        ),
        hasLength(1),
      );
      expect(f.client.serverId, isNull);
    },
  );

  testWidgets(
    'expired invitation retry recovers the real route without installing',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      f.overrides['GET /integration-invites/test-invite'] = (_) => {
        'error': 'Private app invite not found',
      };
      f.adapter.statuses['GET /integration-invites/test-invite'] = 404;
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri.parse('/integration-invites/test-invite'),
      );
      expect(find.text('Private app invite not found'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('private-app-invite-install')),
        findsNothing,
      );
      f.adapter.statuses['GET /integration-invites/test-invite'] = 200;
      f.adapter.routes['GET /integration-invites/test-invite'] = (_) =>
          privateInvite();
      await t.tap(find.byKey(const ValueKey('private-app-invite-retry')));
      await f.flush(t);
      expect(find.text('Private app invite not found'), findsNothing);
      expect(
        find.byKey(const ValueKey('private-app-invite-install')),
        findsOneWidget,
      );
      expect(
        f.adapter.calls.where(
          (o) => o.method == 'POST' && o.path.endsWith('/install'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'signed out invite resumes after real sign in without installing',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      f.adapter.statuses['GET /auth/me'] = 401;
      f.overrides['GET /auth/me'] = (_) => {'error': 'Unauthorized'};
      f.overrides['POST /auth/login'] = (_) => {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {
          'id': 'alice',
          'name': 'alice',
          'email': 'alice@example.invalid',
          'emailVerified': true,
        },
      };
      f.overrides['GET /integration-invites/test-invite'] = (_) =>
          privateInvite();
      await f.mount(
        t,
        'light',
        390,
        uri: Uri.parse('/integration-invites/test-invite'),
      );
      expect(find.byType(AuthView), findsOneWidget);
      expect(
        f.adapter.calls.where(
          (o) => o.path.startsWith('/integration-invites/'),
        ),
        isEmpty,
      );
      await t.enterText(
        find.byKey(const Key('login-email')),
        'alice@example.invalid',
      );
      await t.enterText(
        find.byKey(const Key('login-password')),
        'secret-password',
      );
      await t.tap(find.byKey(const Key('login-submit')));
      await f.flush(t);
      await f.flush(t);
      expect(find.text('Install connected app'), findsOneWidget);
      expect(find.text('Requested access'), findsOneWidget);
      expect(
        f.adapter.calls.where(
          (o) => o.method == 'POST' && o.path.endsWith('/install'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'pending install accepts one click and never paints after sign out',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      final reply = Completer<Map<String, Object?>>();
      addTearDown(() {
        if (!reply.isCompleted) reply.complete(privateInvite(installed: true));
      });
      f.overrides['GET /integration-invites/test-invite'] = (_) =>
          privateInvite();
      f.overrides['POST /integration-invites/test-invite/install'] = (_) =>
          reply.future;
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri.parse('/integration-invites/test-invite'),
      );
      final install = find.byKey(const ValueKey('private-app-invite-install'));
      await t.ensureVisible(install);
      await t.tap(install);
      await t.tap(install);
      await f.flush(t);
      expect(
        f.adapter.calls.where((o) => o.path.endsWith('/install')),
        hasLength(1),
      );
      final signingOut = f.client.logout();
      expect(f.client.user, isNull);
      reply.complete(privateInvite(installed: true));
      await f.flush(t);
      await signingOut;
      expect(find.byType(AuthView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('private-app-invite-open-settings')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'install permission failure is recoverable and never claims success',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      f.overrides['GET /integration-invites/test-invite'] = (_) =>
          privateInvite();
      f.overrides['POST /integration-invites/test-invite/install'] = (_) => {
        'error': 'Owner or admin required',
      };
      f.adapter.statuses['POST /integration-invites/test-invite/install'] = 403;
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri.parse('/integration-invites/test-invite'),
      );
      final install = find.byKey(const ValueKey('private-app-invite-install'));
      await t.ensureVisible(install);
      await t.tap(install);
      await f.flush(t);
      expect(find.text('Owner or admin required'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('private-app-invite-open-settings')),
        findsNothing,
      );
      f.adapter.statuses['POST /integration-invites/test-invite/install'] = 200;
      f.adapter.routes['POST /integration-invites/test-invite/install'] = (_) =>
          privateInvite(installed: true);
      await t.ensureVisible(install);
      await t.tap(install);
      await f.flush(t);
      expect(find.text('Owner or admin required'), findsNothing);
      expect(
        find.byKey(const ValueKey('private-app-invite-open-settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets('membership change removes stale installation consent', (
    t,
  ) async {
    final f = RootFixture();
    addTearDown(() => f.close(t));
    f.overrides['GET /integration-invites/test-invite'] = (_) =>
        privateInvite();
    await f.mount(
      t,
      'light',
      1280,
      uri: Uri.parse('/integration-invites/test-invite'),
    );
    f.adapter.routes['GET /integration-invites/test-invite'] = (_) =>
        privateInvite()..['manageableServers'] = [];
    f.client.event('server:membership-removed', {'serverId': 'b'});
    await f.flush(t);
    expect(
      find.byKey(const ValueKey('private-app-invite-install')),
      findsNothing,
    );
    expect(
      find.text(
        'You need to be an owner or admin of a server to install this app.',
      ),
      findsOneWidget,
    );
    expect(f.adapter.calls.where((o) => o.path.endsWith('/install')), isEmpty);
  });

  testWidgets(
    'message invite uses root navigation and back preserves the active workspace',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      f.overrides['GET /integration-invites/test-invite'] = (_) =>
          privateInvite();
      await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/channel/ca'));
      final w = f.workspace(t);
      await openMessageLink(
        t.element(find.byType(WorkspaceView)),
        'https://fixture.invalid/integration-invites/test-invite',
      );
      await f.flush(t);
      expect(find.text('Install connected app'), findsOneWidget);
      expect(f.client.serverId, 'a');
      final close = find.byKey(const ValueKey('private-app-invite-close'));
      await t.ensureVisible(close);
      await t.tap(close);
      await f.flush(t);
      expect(f.workspace(t), same(w));
      expect(find.byType(GlobalServerSelector), findsNothing);
      expect(f.workspace(t).server?.id, 'a');
    },
  );
}
