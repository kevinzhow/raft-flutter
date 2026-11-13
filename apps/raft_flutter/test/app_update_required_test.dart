// Server v1.24 legacy_mobile_oauth_upgrade_required_v0 (decided: keep the
// native social sign-in, show a clear message): /auth/mobile/oauth/start
// answers 426 APP_UPDATE_REQUIRED. The sign-in page says the server's
// sentence in the app's language and stays usable.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/auth_harness.dart';

const _en =
    'This version of Raft is no longer supported. Download the latest version at app.raft.build/download, then sign in.';

void main() {
  // NativeOAuthBroker.helpUrl, as in social_legal_acceptance_test.dart.
  leakDebt(const ['ValueNotifier<Uri?>']);
  for (final zh in [false, true]) {
    testWidgets('426 APP_UPDATE_REQUIRED on social sign-in (zh: $zh)', (
      t,
    ) async {
      final h = AuthHarness(t, zh: zh);
      h.server.answers['/auth/mobile/oauth/start'] = [
        (426, {'error': _en, 'message': _en, 'code': 'APP_UPDATE_REQUIRED'}),
      ];
      await h.mount();
      await t.tap(find.byKey(const ValueKey('auth-social-github')));
      await h.settle();
      expect(
        find.text(
          zh ? '当前版本过旧，请访问 app.raft.build/download 下载最新版 Raft 后再登录。' : _en,
        ),
        findsOneWidget,
      );
      expect(h.launched, isEmpty);
      expect(h.signedIn, isEmpty);
      expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    });
  }
}
