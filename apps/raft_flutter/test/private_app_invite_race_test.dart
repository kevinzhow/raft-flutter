import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/features/invite_accept_view.dart';
import 'package:raft_flutter/features/private_app_invite_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'private_app_invite_root_test.dart' show privateInvite;

const _path = '/integration-invites/test-invite';
const _alpha = '/s/alpha/channel/ca';
const _installKey = ValueKey('private-app-invite-install');
const _settingsKey = ValueKey('private-app-invite-open-settings');

Future<void> _tap(WidgetTester t, RootFixture f, Finder control) async {
  expect(control, findsOneWidget);
  await t.ensureVisible(control);
  await t.pump();
  expect(control.hitTestable(), findsOneWidget);
  await t.tap(control);
  await f.flush(t);
}

Future<void> _open(
  WidgetTester t,
  RootFixture f, [
  String token = 'test-invite',
]) async {
  await openMessageLink(
    t.element(find.byType(WorkspaceView)),
    'https://fixture.invalid/integration-invites/$token',
  );
  await f.flush(t);
  expect(find.byType(PrivateAppInviteView), findsOneWidget);
  expect(f.router(t).currentConfiguration.path, '/integration-invites/$token');
}

Map<String, Object?> _installedTargets() =>
    privateInvite(installed: true)
      ..['manageableServers'] = [
        for (final (id, name, slug) in [
          ('b', 'Beta', 'beta'),
          ('c', 'Gamma', 'gamma'),
        ])
          {
            'id': id,
            'name': name,
            'slug': slug,
            'role': 'owner',
            'installedAt': '2026-11-04T00:00:00Z',
          },
      ];

void main() {
  setUp(InviteInfoMemory.clear);

  testWidgets(
    'changing the native login server never sends coordinator A private token to coordinator B',
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
      f.overrides['GET $_path'] = (_) => privateInvite();
      await f.mount(t, 'light', 390, uri: Uri.parse(_path));
      expect(find.byType(AuthView), findsOneWidget);
      expect(f.adapter.calls.where((o) => o.path == _path), isEmpty);
      await _tap(t, f, find.byKey(const Key('login-server')));
      await t.enterText(
        find.byKey(const Key('field-origin')),
        'https://other.invalid',
      );
      await _tap(
        t,
        f,
        find.descendant(
          of: find.byType(RaftFormDialog),
          matching: find.text('Save'),
        ),
      );
      expect(find.byType(RaftFormDialog), findsNothing);
      await t.enterText(
        find.byKey(const Key('login-email')),
        'alice@example.invalid',
      );
      await t.enterText(
        find.byKey(const Key('login-password')),
        'fixture-password',
      );
      await _tap(t, f, find.byKey(const Key('login-submit')));
      await f.flush(t);
      expect(
        f.adapter.calls.where(
          (o) =>
              o.method == 'POST' &&
              o.path == '/auth/login' &&
              o.uri.origin == 'https://other.invalid',
        ),
        hasLength(1),
        reason:
            'The actual server editor and login action must have selected B.',
      );
      expect(f.client.origin, 'https://other.invalid');
      expect(
        f.adapter.calls.where(
          (o) => o.path == _path && o.uri.origin == 'https://other.invalid',
        ),
        isEmpty,
        reason:
            'The pending A token cannot be reinterpreted under B after login.',
      );
    },
  );

  testWidgets(
    'a pending ordinary server selection cannot republish over a newer private invitation',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      f.overrides['GET $_path'] = (_) => privateInvite();
      await f.mount(t, 'light', 1280, uri: Uri.parse(_alpha));
      final channels = Completer<dynamic>();
      addTearDown(() {
        if (!channels.isCompleted) {
          channels.complete([
            {
              'id': 'cb',
              'name': 'general-b',
              'type': 'channel',
              'serverId': 'b',
              'joined': true,
            },
          ]);
        }
      });
      final ordinary = f.adapter.routes['GET /channels']!;
      f.adapter.routes['GET /channels'] = (o) =>
          o.headers['X-Server-Id'] == 'b' ? channels.future : ordinary(o);
      await f.pushUri(t, '/s/beta/channel/cb');
      expect(
        f.adapter.calls.where(
          (o) => o.path == '/channels' && o.headers['X-Server-Id'] == 'b',
        ),
        hasLength(1),
      );
      await f.pushUri(t, _path);
      expect(find.byType(PrivateAppInviteView), findsOneWidget);
      channels.complete([
        {
          'id': 'cb',
          'name': 'general-b',
          'type': 'channel',
          'serverId': 'b',
          'joined': true,
        },
      ]);
      await f.flush(t);
      expect(
        f.router(t).currentConfiguration.path,
        _path,
        reason: 'Finishing the older selection must not replace the new invitation URI.',
      );
      expect(find.byType(PrivateAppInviteView), findsOneWidget);
      expect(
        f.content.bound,
        isNull,
        reason:
            'The hidden workspace must stay detached while the invite is open.',
      );
    },
  );

  testWidgets(
    'an existing ordinary server invite is retired when a private invite opens',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      f.overrides['GET $_path'] = (_) => privateInvite();
      f.overrides['GET /auth/invite-info'] = (_) => {
        'kind': 'email',
        'serverName': 'Ordinary workspace',
        'inviterName': 'Owner',
        'memberCount': 2,
        'agentCount': 0,
        'insideCountsHidden': false,
        'humanSeatLimitReached': false,
        'agreement': null,
      };
      await f.mount(t, 'light', 1280, uri: Uri.parse(_alpha));
      await f.pushUri(t, '/join/ordinary-invite');
      expect(find.byType(InviteAcceptView), findsOneWidget);
      await f.pushUri(t, _path);
      expect(f.router(t).currentConfiguration.path, _path);
      expect(
        find.byType(PrivateAppInviteView),
        findsOneWidget,
        reason: 'The old ordinary invite must not mask the newer private invitation.',
      );
      expect(find.byType(InviteAcceptView), findsNothing);
    },
  );

  for (final next in ['close', 'token', 'target']) {
    testWidgets(
      'pending Settings directory read is cancelled after invite $next changes',
      (t) async {
        final f = RootFixture();
        addTearDown(() => f.close(t));
        // Beta is a newly manageable target whose membership has not reached
        // the ordinary directory yet; opening Settings must re-read it.
        final alpha = Map<String, dynamic>.from(f.servers.first);
        f.servers.removeWhere((s) => s['id'] == 'b');
        final directory = Completer<dynamic>();
        final rows = [
          alpha,
          {'id': 'b', 'name': 'Beta', 'slug': 'beta', 'role': 'owner'},
          {'id': 'c', 'name': 'Gamma', 'slug': 'gamma', 'role': 'owner'},
        ];
        addTearDown(() {
          if (!directory.isCompleted) directory.complete(rows);
        });
        f.overrides['GET $_path'] = (_) => next == 'target'
            ? _installedTargets()
            : privateInvite(installed: true);
        f.overrides['GET /integration-invites/next-invite'] = (_) =>
            privateInvite(installed: true);
        await f.mount(t, 'light', 1280, uri: Uri.parse(_alpha));
        final w = f.workspace(t);
        expect(w.servers.map((s) => s.id), ['a']);
        await _open(t, f);
        final before = f.adapter.calls
            .where((o) => o.path == '/servers')
            .length;
        f.serverDirectory = () => directory.future;
        await _tap(t, f, find.byKey(_settingsKey));
        expect(
          f.adapter.calls.where((o) => o.path == '/servers').length,
          before + 1,
        );
        if (next == 'close') {
          await _tap(
            t,
            f,
            find.byKey(const ValueKey('private-app-invite-close')),
          );
          expect(find.byType(WorkspaceView), findsOneWidget);
        } else if (next == 'token') {
          await f.pushUri(t, '/integration-invites/next-invite');
          expect(find.byType(PrivateAppInviteView), findsOneWidget);
        } else {
          await _tap(
            t,
            f,
            find.byKey(const ValueKey('private-app-invite-server')),
          );
          await _tap(t, f, find.text('Gamma (installed)').last);
          expect(
            find.text('Shared Calendar is installed for Gamma.'),
            findsOneWidget,
          );
        }
        directory.complete(rows);
        await f.flush(t);
        final expected = next == 'close'
            ? _alpha
            : next == 'token'
            ? '/integration-invites/next-invite'
            : _path;
        expect(
          f.router(t).currentConfiguration.path,
          expected,
          reason: 'An old Settings request cannot navigate after its invitation/target is superseded.',
        );
        if (next == 'close') {
          expect(f.workspace(t), same(w));
          expect(w.server?.id, 'a');
        } else {
          expect(find.byType(PrivateAppInviteView), findsOneWidget);
          expect(f.client.serverId, 'a');
        }
      },
    );
  }

  for (final clickAgain in [false, true]) {
    testWidgets(
      'membership refresh while installing ${clickAgain ? 'does not admit a second POST' : 'restores the committed server confirmation'}',
      (t) async {
        final f = RootFixture();
        addTearDown(() => f.close(t));
        final commit = Completer<void>();
        addTearDown(() {
          if (!commit.isCompleted) commit.complete();
        });
        var installed = false;
        f.overrides['GET $_path'] = (_) => privateInvite(installed: installed);
        f.overrides['POST $_path/install'] = (_) async {
          await commit.future;
          installed = true;
          return privateInvite(installed: true);
        };
        await f.mount(t, 'light', 1280, uri: Uri.parse(_alpha));
        await _open(t, f);
        final generation = f.client.generation;
        await _tap(t, f, find.byKey(_installKey));
        expect(
          f.adapter.calls.where(
            (o) => o.method == 'POST' && o.path == '$_path/install',
          ),
          hasLength(1),
        );
        // Exact server:member-updated schema from servers.ts. The current Alpha
        // role changes owner -> admin; Beta stays an eligible install target.
        f.servers.first['role'] = 'admin';
        f.client.event('server:member-updated', {
          'serverId': 'a',
          'userId': 'alice',
          'previousRole': 'owner',
          'role': 'admin',
        });
        await f.flush(t);
        expect(
          f.client.generation,
          generation,
          reason:
              'This case must not be repaired accidentally by a view remount.',
        );
        expect(
          f.adapter.calls
              .where((o) => o.method == 'GET' && o.path == _path)
              .length,
          greaterThanOrEqualTo(2),
        );
        if (clickAgain && find.byKey(_installKey).evaluate().isNotEmpty) {
          final button = t.widget<RaftSettingsRecipeButton>(
            find.byKey(_installKey),
          );
          if (button.onPressed != null) {
            await _tap(t, f, find.byKey(_installKey));
          }
        }
        final posts = f.adapter.calls
            .where((o) => o.method == 'POST' && o.path == '$_path/install')
            .length;
        commit.complete();
        await f.flush(t);
        expect(
          posts,
          1,
          reason: 'A refresh cannot unlock a second installation while the first POST is pending.',
        );
        expect(
          find.byKey(_settingsKey),
          findsOneWidget,
          reason: 'The completed POST must recover the committed target after a refresh supersedes its earlier GET.',
        );
        expect(
          find.text('Shared Calendar is installed for Beta.'),
          findsOneWidget,
        );
        expect(f.client.serverId, 'a');
      },
    );
  }

  testWidgets(
    'server-only membership removal on active Alpha clears stale Beta consent without changing generation',
    (t) async {
      final f = RootFixture();
      addTearDown(() => f.close(t));
      var eligible = true;
      f.overrides['GET $_path'] = (_) => eligible
          ? privateInvite()
          : (privateInvite()..['manageableServers'] = []);
      await f.mount(t, 'light', 1280, uri: Uri.parse(_alpha));
      final w = f.workspace(t);
      expect(w.server?.id, 'a');
      await _open(t, f);
      expect(find.byKey(_installKey), findsOneWidget);
      final generation = f.client.generation;
      eligible = false;
      f.servers.removeWhere((s) => s['id'] == 'b');
      // This user-room event intentionally has NO userId (servers.ts and the
      // socket revocation emitter both send exactly {serverId}).
      f.client.event('server:membership-removed', {'serverId': 'b'});
      await f.flush(t);
      expect(
        f.client.generation,
        generation,
        reason: 'The active Alpha authority stays put; no generation remount may mask the stale-consent bug.',
      );
      expect(w.server?.id, 'a');
      expect(w.servers.where((s) => s.id == 'b'), isEmpty);
      expect(
        find.byKey(_installKey),
        findsNothing,
        reason: 'Actual membership removal must revoke the private invitation consent on the existing view.',
      );
      expect(
        find.text(
          'You need to be an owner or admin of a server to install this app.',
        ),
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
}
