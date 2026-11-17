// The settings shell inside the workspace: `/settings/account/delete` with its
// breadcrumb and Back to the tab, Search settings on the phone root and the
// desktop list, a result's `#<id>` location, and "Search everywhere".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/settings_search.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('desktop: Account > Delete account, and the tab link goes back', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(
      t,
      'light',
      1280,
      uri: Uri.parse('/s/alpha/settings/account/delete'),
    );
    await settle(t);
    expect(find.byKey(const Key('settings-breadcrumb')), findsOneWidget);
    expect(f.workspace(t).location.settingsPath, ['account', 'delete']);
    await t.tap(find.byKey(const Key('settings-breadcrumb-tab')));
    await f.flush(t);
    await settle(t);
    expect(find.byKey(const Key('settings-breadcrumb')), findsNothing);
    expect(f.workspace(t).location.settingsPath, ['account']);
    expect(
      find.byKey(const Key('account-profile-display-name')),
      findsOneWidget,
      reason: 'the Account tab',
    );
    await f.close(t);
  });

  testWidgets(
    'phone: Back from the sub-page returns to Account, not the list',
    (t) async {
      final f = RootFixture();
      await f.mount(
        t,
        'light',
        390,
        uri: Uri.parse('/s/alpha/settings/account/delete'),
      );
      await settle(t);
      expect(find.byKey(const Key('settings-breadcrumb')), findsNothing);
      await t.tap(find.byKey(const Key('mobile-settings-back')));
      await f.flush(t);
      await settle(t);
      expect(f.workspace(t).location.settingsPath, ['account']);
      expect(
        find.byKey(const Key('account-profile-display-name')),
        findsOneWidget,
      );
      await f.close(t);
    },
  );

  testWidgets(
    'phone: results replace the list, a result opens its #id, Back keeps the query',
    (t) async {
      final f = RootFixture();
      await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha/settings'));
      await settle(t);
      expect(find.byKey(SettingsSearchField.fieldKey), findsOneWidget);
      await t.enterText(find.byKey(SettingsSearchField.fieldKey), 'font');
      await t.pump();
      expect(
        find.byKey(SettingsSearchResults.rowKey('message-font-size')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-account')),
        findsNothing,
      );
      await t.tap(
        find.byKey(SettingsSearchResults.rowKey('message-font-size')),
      );
      await f.flush(t);
      await settle(t);
      final location = f.workspace(t).location;
      expect(location.settingsPath, ['appearance']);
      expect(location.uri.fragment, 'message-font-size');
      await t.tap(find.byKey(const Key('mobile-settings-back')));
      await f.flush(t);
      await settle(t);
      final field = t.widget<TextField>(
        find.byKey(SettingsSearchField.fieldKey),
      );
      expect(
        field.controller!.text,
        'font',
        reason: 'Back returns to the results',
      );
      expect(
        find.byKey(SettingsSearchResults.rowKey('message-font-size')),
        findsOneWidget,
      );
      await f.close(t);
    },
  );

  testWidgets('desktop: no match offers Search everywhere with the query', (
    t,
  ) async {
    final f = RootFixture();
    await f.mount(
      t,
      'light',
      1280,
      uri: Uri.parse('/s/alpha/settings/account'),
    );
    await settle(t);
    await t.enterText(find.byKey(SettingsSearchField.fieldKey), 'zzzz');
    await t.pump();
    await t.tap(find.byKey(SettingsSearchResults.everywhereKey));
    await f.flush(t);
    await settle(t);
    final location = f.workspace(t).location;
    expect(location.route, RaftRoute.search);
    expect(location.query('q'), 'zzzz');
    await f.close(t);
  });

  testWidgets('a person only finds settings they can see', (t) async {
    final f = RootFixture();
    await f.mount(
      t,
      'light',
      1280,
      uri: Uri.parse('/s/alpha/settings/account'),
    );
    await settle(t);
    // The owner of this server does not see Leave server.
    await t.enterText(find.byKey(SettingsSearchField.fieldKey), 'leave');
    await t.pump();
    expect(
      find.byKey(SettingsSearchResults.rowKey('leave-server')),
      findsNothing,
    );
    await f.close(t);
  });
}
