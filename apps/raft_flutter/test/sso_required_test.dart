// Server v1.24.0 enterprise SSO enforcement (middleware/auth.ts
// respondSsoRequired): a Server that requires its single sign-on answers
// every request of this session with 403 SSO_REQUIRED. The app must say so
// and offer signing out (the one route still accepted), never fail silently.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _text =
    'Your organization requires you to sign in with its single sign-on.';

void main() {
  testWidgets('403 SSO_REQUIRED shows the requirement and signs out', (
    t,
  ) async {
    final f = RootFixture();
    f.overrides['GET /servers'] = (_) {
      f.adapter.statuses['GET /servers'] = 403;
      return {
        'error': _text,
        'code': 'SSO_REQUIRED',
        'signInUrl': 'https://fixture.invalid/api/auth/sso/servers/00000000-0000-4000-8000-000000000000/start',
      };
    };
    await f.mount(t, 'light', 1280);
    expect(find.text('Sign in with SSO'), findsOneWidget);
    expect(find.text(_text), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sso-required-sign-out')));
    await f.flush(t);
    expect(f.adapter.calls.where((c) => c.path == '/auth/logout'), isNotEmpty);
    expect(find.text('Sign in with SSO'), findsNothing);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await f.close(t);
  });
}
