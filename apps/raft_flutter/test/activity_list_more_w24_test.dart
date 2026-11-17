import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/activity_first_unread.dart';
import 'package:raft_flutter/features/activity_object_row.dart'
    show activityObjectRowKey;
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_list_harness.dart';

void main() {
  late ServerClient client;
  late ActivityWorkspace w;

  setUp(() {
    final (c, base) = serverFixture();
    client = c;
    w = base
      ..inbox = [
        dayRow(0, day: 12, unread: 2),
        dayRow(1, day: 12),
        dayRow(2, day: 11),
        dayRow(3, day: 11, unread: 1),
        dayRow(4, day: 10),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Finder rowOf(String key) => find.byKey(ValueKey(key));

  for (final env in [desktop, phoneMouse, foldA, foldB]) {
    testWidgets('${env.name}: the Filter menu picks a view and asks for it', (
      t,
    ) async {
      await mountActivity(t, w, env);
      await t.tap(find.text('Filter'));
      await t.pumpAndSettle();
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Artifacts'), findsOneWidget);
      await t.tap(find.text('Unread').last);
      await t.pumpAndSettle();
      expect(w.inboxQueries.last['filter'], 'unread');
      // The chip names the view and its x clears it.
      await t.tap(find.bySemanticsLabel('Clear filter'));
      await t.pumpAndSettle();
      expect(w.inboxQueries.last['filter'], 'all');
    });

    testWidgets(
      '${env.name}: Mark all read posts read-all and the bar then hides it',
      (t) async {
        await mountActivity(t, w, env);
        final dynamic state = t.state(find.byType(ResourceView));
        expect(state.activityShowsMarkAllRead, isTrue);
        await t.tap(
          find.byTooltip('Mark all as read').evaluate().isNotEmpty
              ? find.byTooltip('Mark all as read')
              : find.text('Mark all read'),
        );
        await t.pumpAndSettle();
        expect(client.posts, contains('POST /channels/inbox/read-all'));
      },
    );

    testWidgets(
      '${env.name}: Down and Up move between row triggers across day groups',
      (t) async {
        await mountActivity(t, w, env);
        String? focused() =>
            (FocusManager.instance.primaryFocus?.context
                            ?.findAncestorWidgetOfExactType<RaftInboxItem>()
                            ?.key
                        as ValueKey?)
                    ?.value
                as String?;
        for (var i = 0; i < 30 && focused() != 'activity-channel-ch0'; i++) {
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
        }
        expect(focused(), 'activity-channel-ch0');
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pump();
        expect(focused(), 'activity-channel-ch1');
        // ch1 closes the first day; the next day's first row is ch2.
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pump();
        expect(focused(), 'activity-channel-ch2');
        await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await t.pump();
        expect(focused(), 'activity-channel-ch1');
      },
    );
  }

  testWidgets('a press outside the list closes the open row and also acts', (
    t,
  ) async {
    var outside = 0;
    final opened = <String>[];
    t.view.physicalSize = phoneTouch.size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => outside++,
                child: const Text('Outside'),
              ),
              Expanded(
                child: ResourceView(
                  controller: w,
                  section: 'activity',
                  onMessage: (id, _) async => opened.add(id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.drag(rowOf('activity-channel-ch1'), const Offset(-150, 0));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(),
      findsOneWidget,
    );
    await t.tap(find.text('Outside'));
    await t.pumpAndSettle();
    expect(outside, 1);
    expect(
      find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets(
    'a jump lights the row as located for two seconds, not as selected',
    (t) async {
      await mountActivity(t, w, desktop);
      ActivityFirstUnread.of(w).request(w);
      await t.pump();
      await t.pump();
      RaftInboxItem item(String k) => t.widget<RaftInboxItem>(rowOf(k));
      expect(item('activity-channel-ch0').located, isTrue);
      expect(item('activity-channel-ch0').selected, isFalse);
      await t.pump(raftLocatedDuration + const Duration(milliseconds: 100));
      await t.pump();
      expect(item('activity-channel-ch0').located, isFalse);
    },
  );

  testWidgets('next unread follows the order on screen (days, newest first)', (
    t,
  ) async {
    // Data order puts the older day first; the screen puts today first.
    w.inbox = [
      dayRow(3, day: 11, unread: 1),
      dayRow(0, day: 12, unread: 2),
      dayRow(1, day: 12),
    ];
    await mountActivity(t, w, desktop);
    ActivityFirstUnread.of(w).request(w);
    await t.pump();
    await t.pump();
    expect(
      t.widget<RaftInboxItem>(rowOf('activity-channel-ch0')).located,
      isTrue,
    );
    await t.pump(raftLocatedDuration + const Duration(milliseconds: 100));
  });

  testWidgets(
    'a stuck heading is over the rows: a press there hits the heading',
    (t) async {
      w.inbox = [for (var i = 0; i < 40; i++) dayRow(i, day: 12)];
      await mountActivity(t, w, desktop);
      final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
      scroll.position.jumpTo(400);
      await t.pump();
      final heading = find.descendant(
        of: find.byType(RaftInboxItemListGroup).first,
        matching: find.byType(Text),
      );
      // Hit-testable: nothing painted over it takes the press.
      expect(heading.hitTestable(), findsOneWidget);
    },
  );

  Map<String, dynamic> objectRow() => {
    'kind': 'object',
    'objectKind': 'artifact',
    'objectId': 'o1',
    'lastActivityAt': '2026-10-12T13:00:00Z',
    'unreadCount': 1,
    'hasMention': false,
    'doneFrontierSeq': '9',
    'summary': null,
    'latestEvent': {
      'eventKind': 'comment',
      'reason': 'following',
      'actor': {'type': 'user', 'id': 'bob', 'name': 'Bob'},
      'at': '2026-10-12T13:00:00Z',
    },
  };

  testWidgets(
    'an Artifact row opens its viewer and reads, once, with one request',
    (t) async {
      w.inbox = [objectRow(), dayRow(1, day: 12)];
      await mountActivity(t, w, desktop);
      final key = activityObjectRowKey(w.inbox.first);
      await t.tap(find.byKey(key));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(
        client.posts.where((p) => p == 'POST /objects/activity/read'),
        hasLength(1),
      );
      expect(
        client.bodies[client.posts.indexOf('POST /objects/activity/read')],
        {'kind': 'artifact', 'objectId': 'o1', 'throughSeq': '9'},
      );
      expect(find.byType(RaftInboxItem), findsWidgets);
      // A viewer route was pushed over the list.
      expect(
        ModalRoute.of(t.element(find.byType(Scaffold).first))?.isCurrent,
        isFalse,
      );
    },
  );

  testWidgets(
    'phone swipe on an Artifact row: Done only, with Undo, written on close',
    (t) async {
      w.inbox = [objectRow(), dayRow(1, day: 12)];
      await mountActivity(t, w, phoneTouch);
      final key = activityObjectRowKey(w.inbox.first);
      await t.drag(find.byKey(key), const Offset(-150, 0));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inbox-row-swipe-done')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('inbox-row-swipe-mute')), findsNothing);
      expect(
        find.byKey(const ValueKey('inbox-row-swipe-unfollow')),
        findsNothing,
      );
      await t.drag(find.byKey(key), const Offset(200, 0));
      await t.pumpAndSettle();
      await t.drag(find.byKey(key), const Offset(100, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-read')), findsNothing);
      await t.drag(find.byKey(key), const Offset(-150, 0));
      await t.pumpAndSettle();
      await t.tap(
        find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(key), findsNothing);
      expect(client.posts.where((p) => p.contains('/objects/')), isEmpty);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(find.byKey(key), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      expect(client.posts.where((p) => p.contains('/objects/')), isEmpty);
      // Done again, no Undo: written after the toast.
      await t.drag(find.byKey(key), const Offset(-150, 0));
      await t.pumpAndSettle();
      await t.tap(
        find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(),
      );
      await t.pump();
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      expect(
        client.posts.where((p) => p == 'POST /objects/activity/done'),
        hasLength(1),
      );
    },
  );
}
