import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture;

/// ThreadsInbox `activity-context-menu` and SavedPanel `ContextMenuContent`:
/// a popup at the pointer (not a centred modal with a scrim), with the Web's
/// items and behaviour.
void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() {
    (client, w) = activityFixture();
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<dynamic> mount(WidgetTester tester, String section) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Scaffold(
            body: ResourceView(
              controller: w,
              section: section,
              onMessage: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(ResourceView));
  }

  Future<Offset> rightClick(WidgetTester tester, Finder row) async {
    final at = tester.getTopLeft(row) + const Offset(24, 12);
    await tester.tapAt(
      at,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    return at;
  }

  testWidgets(
    '[BP-READ-036] Activity menu opens at the pointer with Mark as Read and Done',
    (tester) async {
      final dynamic state = await mount(tester, 'activity');
      // Row 3 is the unread one.
      final at = await rightClick(
        tester,
        find.byKey(const ValueKey('activity-channel-ch3')),
      );
      expect(find.byType(Dialog), findsNothing);
      final menu = find.byType(RaftSidebarContextMenu);
      expect(menu, findsOneWidget);
      expect(tester.getTopLeft(menu), at);
      // Web db5e InboxContextMenu sets width: 184 without a minWidth override.
      // raft-ui 0.7.0 ContextMenuPopup's min-w-60 therefore wins (240px).
      expect(tester.getSize(menu).width, 240);
      expect(find.text('Mark as Read'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      // A channel row has no follow control.
      expect(find.text('Unfollow'), findsNothing);
      await tester.tap(find.text('Mark as Read'));
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
      final row = (state.rows as List).firstWhere(
        (r) => r['channelId'] == 'ch3',
      );
      expect(row['unreadCount'], 0);
    },
  );

  testWidgets(
    '[BP-READ-036] a read Activity row offers Mark as Unread (POST /unread)',
    (tester) async {
      await mount(tester, 'activity');
      await rightClick(
        tester,
        find.byKey(const ValueKey('activity-channel-ch0')),
      );
      expect(find.text('Mark as Read'), findsNothing);
      await tester.tap(find.text('Mark as Unread'));
      await tester.pumpAndSettle();
      expect(client.posts, contains('POST /channels/ch0/unread'));
    },
  );

  testWidgets('Activity Done from the menu marks the conversation done', (
    tester,
  ) async {
    await mount(tester, 'activity');
    await rightClick(
      tester,
      find.byKey(const ValueKey('activity-channel-ch0')),
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(client.posts, contains('POST /channels/inbox/done'));
    expect(client.bodies.last.toString(), contains('ch0'));
  });

  testWidgets(
    'Saved menu is a popup at the pointer: Copy link, Copy Markdown, Remove',
    (tester) async {
      await mount(tester, 'saved');
      final at = await rightClick(
        tester,
        find.byKey(const ValueKey('saved-saved0')),
      );
      expect(find.byType(Dialog), findsNothing);
      final menu = find.byType(RaftContextMenuContent);
      expect(menu, findsOneWidget);
      expect(tester.getTopLeft(menu), at);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Copy Markdown'), findsOneWidget);
      expect(find.text('Remove from Saved'), findsOneWidget);
      await tester.tap(find.text('Remove from Saved'));
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
      expect(client.posts.any((p) => p.contains('saved0')), isTrue);
    },
  );
}
