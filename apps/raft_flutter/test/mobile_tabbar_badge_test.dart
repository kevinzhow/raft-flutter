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

    const dot = Key('mobile-tab-activity-unread-dot');

    testWidgets('$theme the Activity tab shows a dot for the shared unread', (
      t,
    ) async {
      final f = await mount(t, unread: 3, bar: withActivity);
      // Web v1.24: a dot, never a number.
      expect(find.byKey(dot), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-nav-badge-activity')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('mobile-nav-badge-chat')), findsNothing);
      await f.close(t);
    });

    testWidgets('$theme a large unread count is still only a dot', (t) async {
      final f = await mount(t, unread: 120, bar: withActivity);
      expect(find.byKey(dot), findsOneWidget);
      expect(find.text('99+'), findsNothing);
      await f.close(t);
    });

    testWidgets('$theme no unread, no dot', (t) async {
      final f = await mount(t, unread: 0, bar: withActivity);
      expect(find.byKey(dot), findsNothing);
      await f.close(t);
    });

    testWidgets(
      '$theme Home drops its Activity and Search entries only while they are tabs',
      (t) async {
        var f = await mount(t, unread: 3, bar: withActivity);
        expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
        expect(find.byKey(const Key('nav-activity')), findsNothing);
        expect(find.byKey(const Key('nav-search')), findsOneWidget);
        await f.close(t);
        f = await mount(t, unread: 3, bar: '["chat","tasks"]');
        expect(find.byKey(const Key('nav-activity')), findsOneWidget);
        expect(find.byKey(const Key('nav-search')), findsOneWidget);
        await f.close(t);
        // Web v1.24's bar has both: Home lists neither.
        f = await mount(t, unread: 3);
        expect(find.byKey(const Key('nav-activity')), findsNothing);
        expect(find.byKey(const Key('nav-search')), findsNothing);
        await f.close(t);
      },
    );
  }
}
