// Web v1.21.23 SocialAuthCallbackPage: a social sign-in the server will only
// finish after an explicit acceptance of the current terms shows a checkbox
// page; nothing is accepted silently any more.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/auth_harness.dart';

Map<String, dynamic> _legal(String terms) => {
  'termsVersion': terms,
  'privacyVersion': terms,
  'termsUrl': 'https://raft.build/terms',
  'privacyUrl': 'https://raft.build/privacy',
};

const _session = {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'user': {'id': 'user-1', 'name': 'person'},
};

/// The box is at the leading edge; the row's middle is a link.
Future<void> _tick(WidgetTester t) => t.tapAt(
  t.getTopLeft(find.byKey(const Key('legal-checkbox'))) + const Offset(10, 10),
);

void main() {
  leakDebt(const ['ValueNotifier<Uri?>']);
  HttpOverrides.global = null;

  testWidgets('a new social account is asked, nothing is accepted silently', (
    t,
  ) async {
    final h = AuthHarness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [
      (
        422,
        {'error': 'LEGAL_ACCEPTANCE_REQUIRED', 'legal': _legal('2027-01-01')},
      ),
      (200, _session),
    ];
    await h.mount();
    await h.socialSignIn('github');

    final first = h.server.to('/auth/mobile/oauth/complete').single.data;
    expect(first.containsKey('acceptTerms'), false);
    expect(find.text('GitHub sign-in'), findsOneWidget);
    expect(find.byKey(const Key('legal-checkbox')), findsOneWidget);
    expect(find.textContaining('changed'), findsNothing);
    // Continue stays off until the box is ticked.
    await t.tap(find.byKey(const Key('legal-continue')), warnIfMissed: false);
    await h.settle();
    expect(h.server.to('/auth/mobile/oauth/complete'), hasLength(1));

    await _tick(t);
    await h.settle(2);
    await t.tap(find.byKey(const Key('legal-continue')));
    await h.settle();

    final again = h.server.to('/auth/mobile/oauth/complete').last.data;
    expect(again['code'], first['code'], reason: 'the same one-time code');
    expect(again['acceptTerms'], true);
    expect(
      again['termsVersion'],
      '2027-01-01',
      reason: 'what the server named',
    );
    expect(again['privacyVersion'], '2027-01-01');
    expect(again['legalAcceptanceSource'], 'oauth');
    expect(h.signedIn.single.signedIn, true);
  });

  testWidgets('changed terms say so', (t) async {
    final h = AuthHarness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [
      (409, {'error': 'TERMS_CHANGED', 'legal': _legal('2027-01-01')}),
    ];
    await h.mount();
    await h.socialSignIn('google');
    expect(
      find.text(
        'The Terms of Service or Privacy Policy changed. Review and continue.',
      ),
      findsOneWidget,
    );
    expect(find.text('Google sign-in'), findsOneWidget);
  });

  testWidgets('leaving the step returns to sign-in with nothing sent', (
    t,
  ) async {
    final h = AuthHarness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [
      (
        422,
        {'error': 'LEGAL_ACCEPTANCE_REQUIRED', 'legal': _legal('2027-01-01')},
      ),
    ];
    await h.mount();
    await h.socialSignIn('github');
    await t.tap(find.byKey(const Key('legal-back')));
    await h.settle();
    expect(find.byKey(const Key('legal-checkbox')), findsNothing);
    expect(find.byKey(const ValueKey('auth-social-github')), findsOneWidget);
    expect(h.server.to('/auth/mobile/oauth/complete'), hasLength(1));
    expect(h.signedIn, isEmpty);
  });

  testWidgets('a failure after accepting leaves the step with the reason', (
    t,
  ) async {
    final h = AuthHarness(t);
    h.server.answers['/auth/mobile/oauth/complete'] = [
      (
        422,
        {'error': 'LEGAL_ACCEPTANCE_REQUIRED', 'legal': _legal('2027-01-01')},
      ),
      (
        410,
        {
          'code': 'handoff_code_expired',
          'error': 'Mobile OAuth code has expired',
        },
      ),
    ];
    await h.mount();
    await h.socialSignIn('github');
    await _tick(t);
    await h.settle(2);
    await t.tap(find.byKey(const Key('legal-continue')));
    await h.settle();
    expect(find.byKey(const Key('legal-checkbox')), findsNothing);
    expect(find.text('Mobile OAuth code has expired'), findsOneWidget);
    expect(h.signedIn, isEmpty);
  });

  testWidgets('the step reads in Chinese', (t) async {
    final h = AuthHarness(t, zh: true);
    h.server.answers['/auth/mobile/oauth/complete'] = [
      (409, {'error': 'TERMS_CHANGED', 'legal': _legal('2027-01-01')}),
    ];
    await h.mount();
    await h.socialSignIn('github');
    expect(find.text('GitHub 登录'), findsOneWidget);
    expect(find.text('服务条款或隐私政策已更新，请查看后继续。'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
  });
}
