import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_list_harness.dart';

const _done = '/channels/inbox/done';

void main() {
  late ServerClient client;
  late ActivityWorkspace w;

  setUp(() {
    final (c, base) = serverFixture();
    client = c;
    w = base
      ..inbox = [
        dayRow(0, unread: 2),
        dayRow(1),
        dayRow(2),
        threadRow(3, unread: 1),
        dayRow(4),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Finder rowOf(String key) => find.byKey(ValueKey(key));
  List<String> writes() => [
    for (final p in client.posts)
      if (p.endsWith('/done') || p.endsWith('/unfollow')) p,
  ];

  Future<void> swipeLeft(WidgetTester t, String key) async {
    await t.drag(rowOf(key), const Offset(-220, 0));
    await t.pumpAndSettle();
  }

  Future<void> remount(WidgetTester t, ListEnv env) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await mountActivity(t, w, env);
  }

  group('phone with touch swipes', () {
    testWidgets('left uncovers Done; a channel row has Done and Mute', (t) async {
      await mountActivity(t, w, phoneTouch);
      await t.drag(rowOf('activity-channel-ch1'), const Offset(-150, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-done')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-row-swipe-mute')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-row-swipe-unfollow')), findsNothing);
    });

    testWidgets('a thread row has Done and Unfollow; right swipe reads', (t) async {
      await mountActivity(t, w, phoneTouch);
      await t.drag(rowOf('activity-thread-th3'), const Offset(-150, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-unfollow')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-row-swipe-mute')), findsNothing);
      await t.drag(rowOf('activity-thread-th3'), const Offset(200, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(), findsNothing);
      await t.drag(rowOf('activity-thread-th3'), const Offset(100, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-read')), findsOneWidget);
    });

    testWidgets('one row is open at a time; scrolling closes it', (t) async {
      await mountActivity(t, w, phoneTouch);
      await t.drag(rowOf('activity-channel-ch1'), const Offset(-150, 0));
      await t.pumpAndSettle();
      // The press on another row closes this one and is swallowed.
      await t.drag(rowOf('activity-channel-ch2'), const Offset(-150, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(), findsNothing);
      await t.drag(rowOf('activity-channel-ch2'), const Offset(-150, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(), findsOneWidget);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -60));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(), findsNothing);
    });

    testWidgets('a press elsewhere closes the row and is swallowed', (t) async {
      final opened = <String>[];
      await mountActivity(t, w, phoneTouch, opened: opened);
      await t.drag(rowOf('activity-channel-ch1'), const Offset(-150, 0));
      await t.pumpAndSettle();
      await t.tap(rowOf('activity-channel-ch2'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable(), findsNothing);
      expect(opened, isEmpty);
      await t.tap(rowOf('activity-channel-ch2'));
      await t.pumpAndSettle();
      expect(opened, ['ch2']);
    });

    testWidgets('Done hides the row at once, Undo brings it back with no write', (t) async {
      await mountActivity(t, w, phoneTouch);
      await swipeLeft(t, 'activity-channel-ch1');
      await t.tap(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable());
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(rowOf('activity-channel-ch1'), findsNothing);
      expect(find.text('Marked as done'), findsOneWidget);
      expect(writes(), isEmpty);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(rowOf('activity-channel-ch1'), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      expect(writes(), isEmpty);
      await remount(t, phoneTouch);
      expect(rowOf('activity-channel-ch1'), findsOneWidget);
    });

    testWidgets('without Undo the write comes when the toast closes; the row stays gone', (t) async {
      await mountActivity(t, w, phoneTouch);
      await swipeLeft(t, 'activity-channel-ch1');
      await t.tap(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable());
      await t.pump();
      await t.pump(const Duration(seconds: 5));
      expect(writes(), isEmpty);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(writes(), ['POST $_done']);
      expect(rowOf('activity-channel-ch1'), findsNothing);
      await remount(t, phoneTouch);
      expect(rowOf('activity-channel-ch1'), findsNothing);
    });

    testWidgets('leaving the page flushes the pending write', (t) async {
      await mountActivity(t, w, phoneTouch);
      await swipeLeft(t, 'activity-channel-ch1');
      await t.tap(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable());
      await t.pump();
      expect(writes(), isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(writes(), ['POST $_done']);
    });

    testWidgets('a newer action writes the older one and replaces its toast', (t) async {
      await mountActivity(t, w, phoneTouch);
      await swipeLeft(t, 'activity-channel-ch1');
      await t.tap(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable());
      await t.pump();
      await swipeLeft(t, 'activity-channel-ch2');
      await t.tap(find.byKey(const ValueKey('inbox-row-swipe-done')).hitTestable());
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      expect(writes(), ['POST $_done']);
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      expect(writes(), ['POST $_done', 'POST $_done']);
    });

    testWidgets('Unfollow hides, toasts, and writes /threads/unfollow on close', (t) async {
      await mountActivity(t, w, phoneTouch);
      await swipeLeft(t, 'activity-thread-th3');
      await t.tap(find.byKey(const ValueKey('inbox-row-swipe-unfollow')).hitTestable());
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(rowOf('activity-thread-th3'), findsNothing);
      expect(find.textContaining('Unfollowed thread in'), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      expect(writes(), ['POST /channels/threads/unfollow']);
      expect(rowOf('activity-thread-th3'), findsNothing);
    });

    testWidgets('Mute applies at once and Undo un-mutes', (t) async {
      await mountActivity(t, w, phoneTouch);
      client.responses['PATCH /channels/ch1/notification-settings'] = {
        'activityMuted': true,
      };
      await swipeLeft(t, 'activity-channel-ch1');
      await t.tap(find.byKey(const ValueKey('inbox-row-swipe-mute')).hitTestable());
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(client.bodies.last, {'activityMuted': true});
      expect(w.channelById('ch1')!.flag('activityMuted'), isTrue);
      expect(find.textContaining('Muted activity in'), findsOneWidget);
      client.responses['PATCH /channels/ch1/notification-settings'] = {
        'activityMuted': false,
      };
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(client.bodies.last, {'activityMuted': false});
      expect(w.channelById('ch1')!.flag('activityMuted'), isFalse);
    });
  });

  for (final env in [foldA, foldB, phoneMouse, desktop]) {
    testWidgets('${env.name}: no swipe; Done keeps its Undo from the button', (t) async {
      await mountActivity(t, w, env);
      await t.drag(rowOf('activity-channel-ch1'), const Offset(-220, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-row-swipe-done')), findsNothing);
      final button = env.touch
          ? find.descendant(of: rowOf('activity-channel-ch1'), matching: find.byKey(const ValueKey('inbox-row-done-touch')))
          : find.descendant(of: rowOf('activity-channel-ch1'), matching: find.byKey(const ValueKey('inbox-row-done')));
      if (!env.touch) {
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: t.getCenter(rowOf('activity-channel-ch1')));
        await t.pump();
      }
      await t.tap(button.first, warnIfMissed: false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(rowOf('activity-channel-ch1'), findsNothing);
      expect(find.text('Marked as done'), findsOneWidget);
      expect(writes(), isEmpty);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(rowOf('activity-channel-ch1'), findsOneWidget);
      expect(writes(), isEmpty);
    });
  }

  testWidgets('the row menu Done offers the same Undo and Mute is silent', (t) async {
    await mountActivity(t, w, desktop);
    await t.tap(
      rowOf('activity-channel-ch2'),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await t.pumpAndSettle();
    expect(find.text('Mute Activity'), findsOneWidget);
    await t.tap(find.text('Mark as Done'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(rowOf('activity-channel-ch2'), findsNothing);
    expect(find.text('Marked as done'), findsOneWidget);
    expect(writes(), isEmpty);
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(writes(), ['POST $_done']);
  });
}
