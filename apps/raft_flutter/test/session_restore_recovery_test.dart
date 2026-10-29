// Startup restore: only "no stored credentials" and a definitive rejection show
// the login form. Everything else keeps the stored credentials and shows a
// recovery state with retry (docs/architecture.md, "登出策略").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/session_recovery_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _origin = 'https://fixture.invalid';

class _FlakyStore extends MemorySessionStore {
  Object? readError;
  int clears = 0;
  @override
  Future<Session?> read(String origin) async {
    final error = readError;
    if (error != null) throw error;
    return super.read(origin);
  }

  @override
  Future<void> write(String origin, Session? session) {
    if (session == null) clears++;
    return super.write(origin, session);
  }
}

Finder get _recovery => find.byType(SessionRecoveryView);

void main() {
  // /auth/me answer for a stored session that has no cached account record.
  final noCache = <(String, int)>[
    ('503 outage', 503),
    ('500', 500),
    ('429 rate limited', 429),
    ('403 from a proxy', 403),
    ('404', 404),
    ('408', 408),
  ];
  for (final (name, status) in noCache) {
    testWidgets(
      'stored session and /auth/me $name: recovery state, never the login form',
      (t) async {
        final f = RootFixture();
        f.overrides['GET /auth/me'] = (_) => {'error': 'x'};
        f.adapter.statuses['GET /auth/me'] = status;
        await f.mount(t, 'light', 390);
        expect(_recovery, findsOneWidget);
        expect(find.byType(AuthView), findsNothing);
        final stored = await f.sessions.read(_origin);
        expect(stored?.refreshToken, 'fixture-only', reason: 'credentials kept');
        await f.close(t);
      },
    );
  }

  testWidgets(
    'a definitive rejection (/auth/me 401 then refresh 401) shows the login form with the reason and clears credentials',
    (t) async {
      final f = RootFixture();
      f.adapter.statuses['GET /auth/me'] = 401;
      await f.mount(t, 'light', 390);
      expect(find.byType(AuthView), findsOneWidget);
      expect(_recovery, findsNothing);
      expect(find.text('Your session has expired. Sign in again.'), findsOneWidget);
      expect(await f.sessions.read(_origin), isNull);
      expect(
        f.adapter.calls.where((c) => c.path == '/auth/logout'),
        isEmpty,
        reason: 'an involuntary end never revokes',
      );
      await f.close(t);
    },
  );

  for (final (name, error) in <(String, Object)>[
    ('a Keystore/Keychain exception', StateError('KeyStoreException')),
    ('an unreadable record', const FormatException('Data has been reset')),
  ]) {
    testWidgets(
      'secure storage failure ($name): recovery state, nothing deleted, retry restores the session',
      (t) async {
        final store = _FlakyStore();
        final f = RootFixture(sessionStore: store);
        // The fixture seeds the session in mount(); make reads fail from the
        // moment the app starts reading.
        f.overrides['GET /auth/me'] = (_) => {
          'id': 'alice',
          'name': 'alice',
          'email': 'alice@example.invalid',
          'emailVerified': true,
        };
        store.readError = error;
        await f.mount(t, 'light', 390);
        expect(_recovery, findsOneWidget);
        expect(find.byType(AuthView), findsNothing);
        expect(store.clears, 0);
        expect(find.text('Your saved sign-in is not available yet'), findsOneWidget);

        // The device unlocks / the Keystore answers again.
        store.readError = null;
        await t.tap(find.byKey(const Key('session-recovery-retry')));
        await f.flush(t);
        expect(_recovery, findsNothing);
        expect(
          find.byType(GlobalServerSelector).evaluate().isNotEmpty ||
              find.byType(WorkspaceView).evaluate().isNotEmpty,
          isTrue,
        );
        expect((await store.read(_origin))?.refreshToken, anyOf('fixture-only'));
        await f.close(t);
      },
    );
  }

  testWidgets('retry after the server returns restores the session', (t) async {
    final f = RootFixture();
    f.adapter.statuses['GET /auth/me'] = 503;
    await f.mount(t, 'light', 390);
    expect(_recovery, findsOneWidget);
    f.adapter.statuses.remove('GET /auth/me');
    await t.tap(find.byKey(const Key('session-recovery-retry')));
    await f.flush(t);
    expect(_recovery, findsNothing);
    expect(find.byType(GlobalServerSelector), findsOneWidget);
    await f.close(t);
  });

  testWidgets('"Sign in again" is an explicit choice that keeps stored credentials until a new sign-in', (
    t,
  ) async {
    final f = RootFixture();
    f.adapter.statuses['GET /auth/me'] = 503;
    await f.mount(t, 'light', 390);
    await t.tap(find.byKey(const Key('session-recovery-sign-in')));
    await f.flush(t);
    expect(find.byType(AuthView), findsOneWidget);
    expect((await f.sessions.read(_origin))?.refreshToken, 'fixture-only');
    await f.close(t);
  });

  for (final status in [400, 403, 404, 408, 429, 500, 503]) {
    testWidgets(
      'cached account and /auth/me $status: stays signed in on the cached workspace',
      (t) async {
        final f = RootFixture();
        f.adapter.statuses['GET /auth/me'] = status;
        await f.mount(t, 'light', 390, cachedSession: true);
        expect(find.byType(AuthView), findsNothing);
        expect(_recovery, findsNothing);
        expect(
          find.byType(GlobalServerSelector).evaluate().isNotEmpty ||
              find.byType(WorkspaceView).evaluate().isNotEmpty,
          isTrue,
        );
        expect(f.client.signedIn, isTrue);
        expect(f.client.restoredOffline, isTrue);
        expect((await f.sessions.read(_origin))?.refreshToken, 'fixture-only');
        await f.close(t);
      },
    );
  }
}
