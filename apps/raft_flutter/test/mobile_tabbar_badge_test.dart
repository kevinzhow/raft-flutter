import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  for (final theme in ['light']) {
    Future<RootFixture> mount(
      WidgetTester t, {
      required int unread,
    }) async {
      final f = RootFixture();
      f.overrides['GET /channels/inbox'] = (_) => {
        'items': [],
        'hasMore': false,
        'totalUnreadCount': unread,
      };
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      // The shared store's boot fetch fires two seconds after it binds.
      await t.pump(const Duration(seconds: 3));
      await f.flush(t);
      return f;
    }

    const dot = Key('mobile-tab-activity-unread-dot');

    testWidgets('$theme the Activity tab shows a dot for the shared unread', (
      t,
    ) async {
      final f = await mount(t, unread: 3);
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
      final f = await mount(t, unread: 120);
      expect(find.byKey(dot), findsOneWidget);
      expect(find.text('99+'), findsNothing);
      await f.close(t);
    });

    testWidgets('$theme no unread, no dot', (t) async {
      final f = await mount(t, unread: 0);
      expect(find.byKey(dot), findsNothing);
      await f.close(t);
    });
  }
}
