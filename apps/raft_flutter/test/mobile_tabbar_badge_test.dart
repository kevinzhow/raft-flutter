import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const withActivity = '["chat","tasks","activity"]';

void main() {
  for (final theme in ['light']) {
    Future<RootFixture> mount(
      WidgetTester t, {
      required int unread,
      String? bar,
    }) async {
      final f = RootFixture();
      f.overrides['GET /channels/inbox'] = (_) => {
        'items': [],
        'hasMore': false,
        'totalUnreadCount': unread,
      };
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {MobileTabbarStore.preferenceKey: ?bar},
      );
      // The shared store's boot fetch fires two seconds after it binds.
      await t.pump(const Duration(seconds: 3));
      await f.flush(t);
      return f;
    }

    testWidgets('$theme the Activity tab shows the shared unread count', (
      t,
    ) async {
      final f = await mount(t, unread: 3, bar: withActivity);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mobile-nav-badge-activity')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('mobile-nav-badge-chat')), findsNothing);
      expect(
        t
            .widget<Semantics>(
              find.byKey(const ValueKey('mobile-nav-badge-activity')),
            )
            .properties
            .label,
        '3 unread',
      );
      await f.close(t);
    });

    testWidgets('$theme the count caps at 99+', (t) async {
      final f = await mount(t, unread: 120, bar: withActivity);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mobile-nav-badge-activity')),
          matching: find.text('99+'),
        ),
        findsOneWidget,
      );
      await f.close(t);
    });

    testWidgets('$theme no unread, no badge', (t) async {
      final f = await mount(t, unread: 0, bar: withActivity);
      expect(
        find.byKey(const ValueKey('mobile-nav-badge-activity')),
        findsNothing,
      );
      await f.close(t);
    });

    testWidgets('$theme Home drops its Activity entry only while it is a tab', (
      t,
    ) async {
      var f = await mount(t, unread: 3, bar: withActivity);
      expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
      expect(find.byKey(const Key('nav-activity')), findsNothing);
      expect(find.byKey(const Key('nav-search')), findsOneWidget);
      await f.close(t);
      f = await mount(t, unread: 3);
      expect(find.byKey(const Key('nav-activity')), findsOneWidget);
      await f.close(t);
    });
  }
}
