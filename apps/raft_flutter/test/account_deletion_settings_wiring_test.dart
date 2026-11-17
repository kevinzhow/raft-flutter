// Settings > Account ends with the Danger zone (Web AccountSection.tsx:648);
// its Delete account row opens the level-2 page /settings/account/delete,
// whose body is the deletion checklist (Web SettingsPanel › DeleteAccountPage).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/account_deletion_page.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final width in [1280.0, 390.0]) {
    testWidgets('$width: the Danger zone row opens Delete account', (t) async {
      final f = RootFixture();
      await f.mount(
        t,
        'light',
        width,
        uri: Uri.parse('/s/alpha/settings/account'),
      );
      await settle(t);
      final open = find.byKey(const ValueKey('account-deletion-open'));
      await t.ensureVisible(open);
      await t.pump();
      expect(find.byType(AccountDeletionPage), findsNothing);
      await t.tap(open);
      await f.flush(t);
      await settle(t);
      expect(f.workspace(t).location.settingsPath, ['account', 'delete']);
      expect(find.byType(AccountDeletionPage), findsOneWidget);
      await f.close(t);
    });
  }
}
