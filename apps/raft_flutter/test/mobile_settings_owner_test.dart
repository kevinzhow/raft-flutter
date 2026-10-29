import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/mobile_settings_owner.dart';
import 'package:raft_flutter/features/workspace_settings.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

Future<void> settleRoute(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('phone settings reads the workspace on the first open', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/settings'));
    expect(find.byType(MobileSettingsDirectPage), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-settings-direct-switch')),
      findsNothing,
    );
    await t.tap(find.byKey(const ValueKey('workspace-settings-nav-account')));
    await f.flush(t);
    await settleRoute(t);
    final name = find.byKey(const Key('account-profile-display-name'));
    await t.ensureVisible(name);
    await t.enterText(name, 'Kept while open');
    await t.pump();
    expect(find.text('Kept while open'), findsOneWidget);
    expect(find.byType(MobileSettingsDirectPage), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-settings-direct-switch')),
      findsNothing,
    );
    await f.close(t);
  });

  testWidgets(
    'direct phone settings ignores new messages and rebuilds when the role changes',
    (t) async {
      MobileSettingsDirectPage.builds = 0;
      final f = RootFixture();
      await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/settings'));
      expect(find.byType(MobileSettingsDirectPage), findsOneWidget);
      final before = MobileSettingsDirectPage.builds;
      expect(before, greaterThan(0));
      for (var i = 0; i < 4; i++) {
        f.client.event('message:new', {
          'id': 'settings-quiet-$i',
          'channelId': 'ca',
          'serverId': 'a',
          'seq': '${i + 2}',
          'content': 'Quiet $i',
          'senderId': 'bob',
          'senderType': 'user',
          'createdAt': '2026-10-15T03:40:00Z',
        });
        await f.flush(t);
      }
      expect(MobileSettingsDirectPage.builds, before);
      f.workspace(t).applyMembershipRole({
        'userId': 'alice',
        'serverId': 'a',
        'role': 'member',
      });
      await f.flush(t);
      expect(MobileSettingsDirectPage.builds, greaterThan(before));
      await f.close(t);
    },
  );

  testWidgets('a wide window has no phone settings switch', (t) async {
    final f = RootFixture();
    await f.mount(t, 'light', 1280, uri: Uri.parse('/s/alpha/settings'));
    expect(
      find.byKey(const Key('mobile-settings-direct-switch')),
      findsNothing,
    );
    expect(find.byType(MobileSettingsDirectPage), findsNothing);
    expect(find.byType(WorkspaceSettings), findsOneWidget);
    await f.close(t);
  });
}
