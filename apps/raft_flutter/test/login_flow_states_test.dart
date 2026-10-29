// Login / onboarding acceptance guard (docs/login-acceptance.md): every screen
// between cold start and the first workspace frame is pumped through the real
// RaftApp on a phone (390x844) in the three themes. None may paint text in
// Flutter's missing-Material fallback style (yellow double underline).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_ui/test_themes.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'fallback_text_style.dart';

/// The `layer-standalone` role `RaftServerResolutionBody` reads through
/// `RaftTokens.standaloneSurface` (page_tokens.dart:13, which is not exported
/// from raft_ui.dart): the pack colour, else the canvas.
Color _standaloneSurface(RaftTokens tokens) =>
    tokens.colors['layer-standalone'] ?? tokens.canvas;

typedef _Prepare = void Function(RootFixture f);
typedef _Act = Future<void> Function(WidgetTester t, RootFixture f);

class _State {
  const _State(this.name, {this.prepare, this.act, this.uri, this.expectText});
  final String name;
  final _Prepare? prepare;
  final _Act? act;
  final Uri? uri;
  final String? expectText;
}

final _held = <String, Completer<dynamic>>{};

Map<String, dynamic> _me({bool verified = true, bool profile = true}) => {
  'id': 'alice',
  'name': profile ? 'alice' : 'pending_alice',
  'displayName': profile ? 'Alice' : null,
  'email': 'alice@example.invalid',
  'emailVerified': verified,
  if (!profile) 'profileSetupCompletedAt': null,
  if (!profile) 'profileSetupSuggestedHandle': 'alice',
};

void _hold(RootFixture f, String route) =>
    f.holds[route] = _held[route] = Completer<dynamic>();

Future<void> _enter(WidgetTester t) async {
  await t.enterText(find.byKey(const Key('login-email')), 'a@example.invalid');
  await t.enterText(find.byKey(const Key('login-password')), 'password-1234');
}

final _states = <_State>[
  _State(
    'restoring',
    prepare: (f) => _hold(f, 'GET /auth/me'),
    expectText: 'Restoring session…',
  ),
  _State(
    'login',
    prepare: (f) => f.adapter.statuses['GET /auth/me'] = 401,
    expectText: 'Sign In',
  ),
  _State(
    'login-wrong-password',
    prepare: (f) {
      f.adapter.statuses['GET /auth/me'] = 401;
      f.overrides['POST /auth/login'] = (_) => {
        'error': 'Invalid credentials',
        'code': 'AUTH_INVALID_CREDENTIALS',
      };
      f.adapter.statuses['POST /auth/login'] = 401;
    },
    act: (t, f) async {
      await _enter(t);
      await t.tap(find.byKey(const Key('login-submit')));
      await f.flush(t);
    },
    expectText: 'Incorrect email or password.',
  ),
  _State(
    'login-busy',
    prepare: (f) {
      f.adapter.statuses['GET /auth/me'] = 401;
      _hold(f, 'POST /auth/login');
    },
    act: (t, f) async {
      await _enter(t);
      await t.tap(find.byKey(const Key('login-submit')));
      await f.flush(t);
    },
  ),
  _State(
    'login-network-down',
    prepare: (f) {
      f.adapter.statuses['GET /auth/me'] = 401;
      f.adapter.statuses['POST /auth/login'] = 503;
      f.overrides['POST /auth/login'] = (_) => {'error': 'Service unavailable'};
    },
    act: (t, f) async {
      await _enter(t);
      await t.tap(find.byKey(const Key('login-submit')));
      await f.flush(t);
    },
  ),
  _State(
    'register',
    prepare: (f) => f.adapter.statuses['GET /auth/me'] = 401,
    act: (t, f) async {
      await t.tap(find.text('Create one'));
      await f.flush(t);
    },
  ),
  _State(
    'forgot',
    prepare: (f) => f.adapter.statuses['GET /auth/me'] = 401,
    act: (t, f) async {
      await t.tap(find.text('Forgot password?'));
      await f.flush(t);
    },
  ),
  _State(
    'invite-signed-out',
    uri: Uri.parse('/join/abc123'),
    prepare: (f) {
      f.adapter.statuses['GET /auth/me'] = 401;
      f.overrides['GET /auth/invite-info'] = (_) => {
        'kind': 'email',
        'serverName': 'Raft Design',
        'inviterName': 'Wenyi',
        'memberCount': 12,
        'agentCount': 5,
        'insideCountsHidden': false,
        'humanSeatLimitReached': false,
        'agreement': null,
      };
    },
  ),
  _State(
    'invite-expired',
    uri: Uri.parse('/join/abc123'),
    prepare: (f) {
      f.adapter.statuses['GET /auth/me'] = 401;
      f.adapter.statuses['GET /auth/invite-info'] = 410;
      f.overrides['GET /auth/invite-info'] = (_) => {'error': 'expired'};
    },
  ),
  _State(
    'invite-loading',
    uri: Uri.parse('/join/abc123'),
    prepare: (f) {
      f.adapter.statuses['GET /auth/me'] = 401;
      _hold(f, 'GET /auth/invite-info');
    },
  ),
  _State(
    'server-create-error',
    prepare: (f) {
      f.overrides['POST /servers'] = (_) => {'error': 'That URL is taken.'};
      f.adapter.statuses['POST /servers'] = 409;
    },
    act: (t, f) async {
      await t.tap(find.text('+ Create New Server'));
      await t.pump();
      await t.enterText(
        find.byKey(const ValueKey('global-server-name')),
        'Taken',
      );
      await t.tap(find.byKey(const ValueKey('global-server-create-submit')));
      await f.flush(t);
    },
  ),
  _State(
    'server-create-busy',
    prepare: (f) => _hold(f, 'POST /servers'),
    act: (t, f) async {
      await t.tap(find.text('+ Create New Server'));
      await t.pump();
      await t.enterText(
        find.byKey(const ValueKey('global-server-name')),
        'Busy',
      );
      await t.tap(find.byKey(const ValueKey('global-server-create-submit')));
      await f.flush(t);
    },
  ),
  _State(
    'servers-loading',
    prepare: (f) => _hold(f, 'GET /servers'),
    expectText: 'Loading servers…',
  ),
  _State('servers-many', expectText: 'Choose server'),
  _State(
    'servers-none',
    prepare: (f) => f.servers.clear(),
    expectText: 'Create your first server',
  ),
  _State(
    'servers-failed',
    prepare: (f) => f.serverDirectory = () => throw StateError('boom'),
  ),
  _State(
    'server-create',
    act: (t, f) async {
      await t.tap(find.text('+ Create New Server'));
      await t.pump();
    },
    expectText: 'Create Server',
  ),
  _State(
    'onboarding-profile',
    prepare: (f) => f.overrides['GET /auth/me'] = (_) => _me(profile: false),
  ),
  _State(
    'onboarding-verify',
    prepare: (f) => f.overrides['GET /auth/me'] = (_) => _me(verified: false),
  ),
  _State('invite-signed-in', uri: Uri.parse('/join/abc123')),
  _State('access-denied', uri: Uri.parse('/s/unknown')),
  _State(
    'joining-community',
    uri: Uri.parse('/s/community'),
    prepare: (f) => _hold(f, 'POST /servers/join-community'),
    expectText: 'Joining community…',
  ),
  _State(
    'workspace',
    act: (t, f) async {
      await t.tap(find.byKey(const ValueKey('global-server-a')));
      await f.flush(t);
    },
  ),
];

void main() {
  for (final theme in raftThemeMatrix(['light', 'dark'], full: true)) {
    for (final state in _states) {
      testWidgets('login flow state ${state.name} ($theme, 390x844)', (
        t,
      ) async {
        _held.clear();
        final f = RootFixture();
        state.prepare?.call(f);
        await f.mount(t, theme, 390, uri: state.uri, settle: false);
        await f.flush(t);
        await state.act?.call(t, f);
        if (state.expectText != null) {
          expect(find.text(state.expectText!), findsWidgets);
        }
        expectNoFallbackTextStyle(state.name);
        for (final h in _held.values) {
          if (!h.isCompleted) h.complete(null);
        }
        await f.close(t);
      });
    }
  }

  // Pages the app mounts without an auth shell around them.
  for (final theme in raftThemeMatrix(['light', 'dark'], full: true)) {
    final dark = theme == 'dark';
    Future<void> pump(WidgetTester t, Widget page) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      // The page as the app routes it: a bare MaterialPage child.
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: page,
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
    }

    for (final label in [
      'Restoring session…',
      'Loading server…',
      'Loading servers…',
      'Joining community…',
    ]) {
      testWidgets('splash "$label" has a page frame ($theme)', (t) async {
        await pump(t, RaftServerResolutionBody(label: label));
        expect(find.text(label), findsOneWidget);
        expectNoFallbackTextStyle(label);
        // The splash paints the pack's standalone-page surface (Web
        // `bg-layer-sidebar`; the pre-theme packs map it to their canvas),
        // never a hard-coded cream over a dark theme.
        final context = t.element(find.text(label));
        final tokens = RaftTokens.of(context);
        final material = t.widget<Material>(
          find
              .descendant(
                of: find.byType(RaftServerResolutionBody),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, _standaloneSurface(tokens));
      });
    }

    testWidgets('root error fallback has a page frame ($theme)', (t) async {
      await pump(
        t,
        RaftRootErrorFallback(
          message: 'Bad state',
          stack: '#0 main',
          componentStack: '\n  in Widget',
          onReload: () {},
        ),
      );
      expectNoFallbackTextStyle('root error fallback');
    });
  }

  testWidgets('the first frame (Restoring session…) uses the saved theme', (
    t,
  ) async {
    // main() preloads DevicePreferences before runApp: the splash is already
    // painted in the saved dark theme, not in the default brutal cream.
    SharedPreferences.setMockInitialValues({'raft.mode': 'dark'});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    addTearDown(DevicePreferences.reset);
    _held.clear();
    final f = RootFixture();
    _hold(f, 'GET /auth/me');
    await f.mount(t, 'dark', 390, settle: false);
    expect(find.text('Restoring session…'), findsOneWidget);
    final tokens = RaftTokens.of(t.element(find.text('Restoring session…')));
    expect(tokens.dark, isTrue);
    final material = t.widget<Material>(
      find
          .descendant(
            of: find.byType(RaftServerResolutionBody),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, _standaloneSurface(tokens));
    for (final h in _held.values) {
      if (!h.isCompleted) h.complete(null);
    }
    await f.close(t);
  });
}
