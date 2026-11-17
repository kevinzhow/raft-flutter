import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/activity_context_menu.dart';
import 'package:raft_flutter/features/activity_inbox_row.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_object_row_test.dart' show objectRow;
import 'support/activity_row_harness.dart';

// Web `InboxContextMenu`: the entries per row kind (R39 Mute / Unmute Activity,
// R40 "Mark as Done"), and how the row asks for the menu: right click with a
// mouse, press-and-hold with a finger.
Future<List<String>> _entries(
  WidgetTester tester,
  Map<String, dynamic> row, {
  bool dark = false,
  bool? unread,
  RaftChannel? mute,
  List<ActivityContextAction>? log,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Builder(
          builder: (context) => buildActivityContextMenu(
            context,
            row,
            unread: unread,
            muteChannel: mute,
            onDismiss: () {},
            onAction: (a) => log?.add(a),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return [for (final item in _items(tester)) item.label];
}

List<RaftSidebarMenuItem> _items(WidgetTester tester) => tester
    .widget<RaftSidebarContextMenu>(find.byType(RaftSidebarContextMenu))
    .entries
    .whereType<RaftSidebarMenuItem>()
    .toList();

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    group('$mode entries per kind', () {
      testWidgets('channel: read toggle, Mark as Done, Mute Activity', (tester) async {
        final channel = channelRecord('c1', 'launch-week');
        expect(
          await _entries(tester, channelRow(unread: 2), dark: dark, unread: true, mute: channel),
          ['Mark as read', 'Mark as Done', 'Mute Activity'],
        );
        expect(
          await _entries(tester, channelRow(), dark: dark, unread: false, mute: channel),
          ['Mark as unread', 'Mark as Done', 'Mute Activity'],
        );
      });

      testWidgets('a muted channel offers Unmute Activity', (tester) async {
        final muted = channelRecord('c1', 'x', extra: {'activityMuted': true});
        expect(
          await _entries(tester, channelRow(), dark: dark, mute: muted),
          ['Mark as unread', 'Mark as Done', 'Unmute Activity'],
        );
      });

      testWidgets('no Mute where the channel cannot be muted', (tester) async {
        final names = ['Mark as unread', 'Mark as Done'];
        // Not joined, or a type outside channel / private / joint.
        expect(
          await _entries(tester, channelRow(), dark: dark, mute: RaftChannel({'id': 'c', 'name': 'x', 'type': 'channel', 'joined': false})),
          names,
        );
        expect(
          await _entries(tester, channelRow(), dark: dark, mute: channelRecord('c', 'x', type: 'thread')),
          names,
        );
        expect(await _entries(tester, channelRow(), dark: dark), names);
        // A joint and a private channel can.
        expect(
          (await _entries(tester, channelRow(), dark: dark, mute: channelRecord('c', 'x', type: 'joint'))).last,
          'Mute Activity',
        );
        expect(
          (await _entries(tester, channelRow(), dark: dark, mute: channelRecord('c', 'x', type: 'private'))).last,
          'Mute Activity',
        );
      });

      testWidgets('DM: Mute only when the server says activityMuteSupported', (tester) async {
        final dm = {...channelRow(id: 'd1'), 'kind': 'dm', 'channelType': 'dm'};
        expect(
          await _entries(
            tester,
            dm,
            dark: dark,
            mute: channelRecord('d1', 'dm', type: 'dm', extra: {'activityMuteSupported': true}),
          ),
          ['Mark as unread', 'Mark as Done', 'Mute Activity'],
        );
        expect(
          await _entries(tester, dm, dark: dark, mute: channelRecord('d1', 'dm', type: 'dm')),
          ['Mark as unread', 'Mark as Done'],
        );
        // A stored mute keeps its Unmute even when the DM no longer qualifies.
        expect(
          await _entries(tester, dm, dark: dark, mute: channelRecord('d1', 'dm', type: 'dm', extra: {'activityMuted': true})),
          ['Mark as unread', 'Mark as Done', 'Unmute Activity'],
        );
      });

      testWidgets('thread: read toggle, Done, Unfollow; never Mute', (tester) async {
        expect(
          await _entries(tester, threadRow(unread: 1), dark: dark, unread: true, mute: channelRecord('c1', 'x')),
          ['Mark as read', 'Mark as Done', 'Unfollow'],
        );
      });

      testWidgets('an unfollowed thread: Done and Follow, no read toggle', (tester) async {
        expect(
          await _entries(tester, threadRow(extra: {'isFollowing': false}), dark: dark),
          ['Mark as Done', 'Follow'],
        );
      });

      testWidgets('mention_action: read toggle and Done only', (tester) async {
        expect(
          await _entries(
            tester,
            {'kind': 'mention_action', 'channelId': 'c1', 'unreadCount': 0},
            dark: dark,
            mute: channelRecord('c1', 'x'),
          ),
          ['Mark as unread', 'Mark as Done'],
        );
      });

      testWidgets('object: Mark as read only while unread, never Mark as unread', (tester) async {
        expect(await _entries(tester, objectRow(unread: 2), dark: dark, unread: true), [
          'Mark as read',
          'Mark as Done',
        ]);
        expect(await _entries(tester, objectRow(), dark: dark, unread: false), [
          'Mark as Done',
        ]);
      });

      testWidgets('icons: Unfollow / Follow use the thread marks, Mute the bell', (tester) async {
        await _entries(tester, threadRow(), dark: dark);
        final glyphs = _items(tester).map((i) => i.glyph).toList();
        expect(glyphs, [
          RaftGlyph.messageSquareDot,
          RaftGlyph.check,
          RaftGlyph.unfollowThread,
        ]);
        await _entries(tester, threadRow(extra: {'isFollowing': false}), dark: dark);
        expect(
          _items(tester).last.glyph,
          RaftGlyph.followThread,
        );
        await _entries(tester, channelRow(), dark: dark, mute: channelRecord('c', 'x'));
        expect(
          _items(tester).last.glyph,
          RaftGlyph.bellOff,
        );
        await _entries(tester, channelRow(), dark: dark, mute: channelRecord('c', 'x', extra: {'activityMuted': true}));
        expect(
          _items(tester).last.glyph,
          RaftGlyph.bell,
        );
      });
    });
  }

  testWidgets('each entry reports its action; the toggle keeps its key', (tester) async {
    final log = <ActivityContextAction>[];
    await _entries(tester, threadRow(), log: log);
    expect(find.byKey(const ValueKey('activity-menu-toggle-read')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-menu-toggle-read')));
    await tester.tap(find.text('Mark as Done'));
    await tester.tap(find.text('Unfollow'));
    await _entries(tester, threadRow(extra: {'isFollowing': false}), log: log);
    await tester.tap(find.text('Follow'));
    await _entries(tester, channelRow(), log: log, mute: channelRecord('c', 'x'));
    await tester.tap(find.text('Mute Activity'));
    await _entries(
      tester,
      channelRow(),
      log: log,
      mute: channelRecord('c', 'x', extra: {'activityMuted': true}),
    );
    await tester.tap(find.text('Unmute Activity'));
    expect(log, [
      ActivityContextAction.toggleRead,
      ActivityContextAction.done,
      ActivityContextAction.unfollow,
      ActivityContextAction.follow,
      ActivityContextAction.mute,
      ActivityContextAction.unmute,
    ]);
  });

  group('how the row asks for its menu', () {
    for (final (name, size, platform) in rowEnvs) {
      final touch = platform == TargetPlatform.android;
      testWidgets('$name: ${touch ? 'press and hold' : 'right click'} opens the menu at the pointer', (
        tester,
      ) async {
        useFixedClock();
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await pumpRowApp(
          tester,
          ActivityInboxRow(row: channelRow(), host: f.host()),
          size: size,
          platform: platform,
        );
        final at = tester.getCenter(find.byKey(const ValueKey('inbox-item-open')));
        if (touch) {
          await tester.longPressAt(at);
        } else {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await mouse.addPointer(location: at);
          addTearDown(mouse.removePointer);
          await mouse.down(at);
          await mouse.up();
        }
        await tester.pump();
        expect(f.calls.menus, hasLength(1));
        expect((f.calls.menus.single - at).distance, lessThan(2));
        expect(f.calls.opened, 0, reason: 'the menu\'s gesture does not open the row');
      });
    }
  });
}
