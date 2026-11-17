import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/activity_inbox_row.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_row_harness.dart';

// Web v1.24 `InboxRow` title and excerpt rules (C44 task conversations, C45
// retracted / delegated / saved-copy rows, C46 Lounge and App-bot DMs), the
// marks, and the row's accessible name.
Finder get _title => find.byKey(const ValueKey('conversation-card-primary'));
Finder get _body => find.byKey(const ValueKey('conversation-card-body'));

String _plain(WidgetTester tester, Finder f) =>
    tester.widget<Text>(f).textSpan!.toPlainText(includePlaceholders: false);

Future<void> _pump(
  WidgetTester tester,
  RowFixture f,
  Map<String, dynamic> row, {
  bool v2 = false,
  bool dark = false,
  String filter = 'all',
}) async {
  useFixedClock();
  await pumpRowApp(
    tester,
    ActivityInboxRow(row: row, host: f.host(taskV2: v2, filter: filter)),
    dark: dark,
  );
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    group('$mode channel and DM titles', () {
      testWidgets('a channel is its name without the # prefix', (tester) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(tester, f, channelRow(name: '#launch-week'), dark: dark);
        expect(tester.widget<Text>(_title).data, 'launch-week');
        expect(_plain(tester, _body), 'Bob: Draft is ready');
      });

      testWidgets('a DM is the peer\'s display name; the peer\'s own line has no sender', (
        tester,
      ) async {
        final f = RowFixture(
          dms: [
            channelRecord(
              'd1',
              'dm-1',
              type: 'dm',
              extra: {
                'peerId': 'bob',
                'peerType': 'user',
                'peerDisplayName': 'Bobby',
                'peerName': 'bob',
              },
            ),
          ],
        );
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          {
            ...channelRow(id: 'd1', name: '@bob'),
            'kind': 'dm',
            'channelType': 'dm',
          },
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, 'Bobby');
        expect(_plain(tester, _body), 'Draft is ready');
      });

      testWidgets('Lounge: "{Name}\'s Lounge" for the agent\'s lounge channel', (
        tester,
      ) async {
        final f = RowFixture(
          channels: [
            channelRecord(
              'l1',
              'cindy-lounge',
              extra: {'loungeAgentId': 'a1'},
            ),
          ],
        );
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          channelRow(id: 'l1', name: 'cindy-lounge'),
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, "cindy's Lounge");
      });

      testWidgets('an App-bot DM shows the App badge after the name', (tester) async {
        final f = RowFixture(
          dms: [
            channelRecord(
              'd1',
              'dm-1',
              type: 'dm',
              extra: {'peerId': 'bot1', 'peerType': 'agent', 'peerName': 'Deploybot'},
            ),
          ],
          agents: [
            {
              'id': 'bot1',
              'name': 'Deploybot',
              'managedByAppInstallId': 'inst1',
              'managedByApp': {'name': 'Deploy'},
            },
          ],
        );
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          {
            ...channelRow(id: 'd1', name: 'Deploybot', senderId: 'bot1'),
            'kind': 'dm',
            'channelType': 'dm',
          },
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, 'Deploybot');
        final badge = find.byKey(const ValueKey('app-bot-badge'));
        expect(badge, findsOneWidget);
        expect(find.descendant(of: badge, matching: find.text('App · Deploy')), findsOneWidget);
        // The title takes the room it needs: the badge sits right after it.
        expect(
          tester.getTopLeft(badge).dx - tester.getTopRight(_title).dx,
          lessThanOrEqualTo(8),
        );
      });

      testWidgets('a human DM peer has no App badge', (tester) async {
        final f = RowFixture(
          dms: [
            channelRecord(
              'd1',
              'dm-1',
              type: 'dm',
              extra: {'peerId': 'bob', 'peerType': 'user', 'peerName': 'bob'},
            ),
          ],
        );
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          {...channelRow(id: 'd1', name: 'bob'), 'kind': 'dm', 'channelType': 'dm'},
          dark: dark,
        );
        expect(find.byKey(const ValueKey('app-bot-badge')), findsNothing);
      });
    });

    group('$mode thread and task titles', () {
      testWidgets('a thread is titled by its parent message, the body names the channel', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(tester, f, threadRow(), dark: dark);
        expect(tester.widget<Text>(_title).data, 'Ship the build');
        expect(_plain(tester, _body), '#launch-week · Bob: Looks good');
      });

      testWidgets('a saved copy: no parent text is "Thread in #channel", sender alone', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          threadRow(parentPreview: '', preview: ''),
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, 'Thread in #launch-week');
        expect(_plain(tester, _body), '#launch-week · Bob');
      });

      testWidgets('a retracted parent is the muted retracted line', (tester) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          threadRow(extra: {'parentRetracted': true}),
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, 'This message was retracted.');
        final color = tester.widget<Text>(_title).style!.color;
        expect(color, RaftTokens.of(tester.element(_title)).colors['foreground-placeholder']);
      });

      testWidgets('the server\'s placeholder text decides when it sent no flag', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          threadRow(
            parentPreview: 'This message was retracted by its sender.',
          ),
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, 'This message was retracted.');
      });

      testWidgets('a retracted latest message: the muted line after the sender', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          channelRow(extra: {'latestRetracted': true}),
          dark: dark,
        );
        expect(_plain(tester, _body), 'Bob: This message was retracted.');
      });

      testWidgets('a delegated sender: "Alice (sent by Friday)"', (tester) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          channelRow(
            sender: 'Alice',
            extra: {
              'latestDelegatedBy': {'id': 'ag1', 'name': 'Friday'},
            },
          ),
          dark: dark,
        );
        expect(_plain(tester, _body), 'Alice (sent by Friday): Draft is ready');
      });

      testWidgets('a deleted assistant', (tester) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          channelRow(
            sender: 'Alice',
            extra: {
              'latestDelegatedBy': {'id': 'ag1', 'name': 'Friday', 'deleted': true},
            },
          ),
          dark: dark,
        );
        expect(
          _plain(tester, _body),
          'Alice (sent by a deleted assistant): Draft is ready',
        );
      });

      testWidgets('the system sender is "System"', (tester) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          channelRow(sender: 'system', senderId: 'system'),
          dark: dark,
        );
        expect(_plain(tester, _body), 'System: Draft is ready');
      });

      Map<String, dynamic> task({Map<String, dynamic> extra = const {}}) =>
          threadRow(
            id: 'task-ch',
            parentPreview: '',
            extra: {
              'conversationKind': 'task',
              'taskId': 'tk1',
              'taskNumber': 7,
              'taskStatus': 'in_progress',
              'taskTitle': 'Fix the login bug',
              ...extra,
            },
          );

      testWidgets('a task conversation: the task title, status in the marks, v2 on', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(tester, f, task(), v2: true, dark: dark);
        expect(tester.widget<Text>(_title).data, 'Fix the login bug');
        expect(_plain(tester, _body), '#launch-week · Bob: Looks good');
        final status = find.byKey(const ValueKey('conversation-card-task-badge'));
        expect(status, findsOneWidget);
        expect(find.descendant(of: status, matching: find.byType(RaftInboxItemStatus)), findsOneWidget);
        // No legacy number badge beside the title.
        expect(find.text('#7'), findsNothing);
      });

      testWidgets('v2 off: the ref `#channel:#7` stands in the body, not the title', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(tester, f, task(), v2: false, dark: dark);
        expect(tester.widget<Text>(_title).data, 'Fix the login bug');
        expect(_plain(tester, _body), '#launch-week:#7 · Bob: Looks good');
      });

      testWidgets('no task title: "{channel} task" with v2, the ref without', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          task(extra: {'taskTitle': ''}),
          v2: true,
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, '#launch-week task');
        // The words already say the channel.
        expect(_plain(tester, _body), 'Bob: Looks good');
        await _pump(
          tester,
          f,
          task(extra: {'taskTitle': ''}),
          v2: false,
          dark: dark,
        );
        expect(tester.widget<Text>(_title).data, '#launch-week:#7');
      });

      testWidgets('a legacy task thread keeps its number badge only with v2 off', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        final legacy = threadRow(extra: {'taskNumber': 7, 'taskStatus': 'todo'});
        await _pump(tester, f, legacy, v2: false, dark: dark);
        expect(find.text('#7'), findsOneWidget);
        expect(find.byType(RaftInboxItemStatus), findsNothing);
        await _pump(tester, f, legacy, v2: true, dark: dark);
        expect(find.text('#7'), findsNothing);
        expect(find.byType(RaftInboxItemStatus), findsOneWidget);
      });
    });

    group('$mode marks', () {
      testWidgets('draft, @, then the unread count; muted bell replaces the count', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        f.w.drafts['t1'] = 'half a reply';
        await _pump(
          tester,
          f,
          threadRow(unread: 3, extra: {'hasMention': true}),
          dark: dark,
        );
        final draft = find.byKey(const ValueKey('inbox-thread-draft-badge'));
        final at = find.byKey(const ValueKey('inbox-mention-badge'));
        final count = find.byKey(const ValueKey('conversation-card-new-badge'));
        expect([draft, at, count].every((x) => x.evaluate().length == 1), isTrue);
        expect(tester.getTopLeft(draft).dx, lessThan(tester.getTopLeft(at).dx));
        expect(tester.getTopLeft(at).dx, lessThan(tester.getTopLeft(count).dx));
        expect(find.descendant(of: count, matching: find.text('3')), findsOneWidget);
      });

      testWidgets('the @ marker is hidden under the Mentions filter and when read', (
        tester,
      ) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          threadRow(unread: 3, extra: {'hasMention': true}),
          filter: 'mentions',
          dark: dark,
        );
        expect(find.byKey(const ValueKey('inbox-mention-badge')), findsNothing);
        await _pump(
          tester,
          f,
          threadRow(unread: 0, extra: {'hasMention': true}),
          dark: dark,
        );
        expect(find.byKey(const ValueKey('inbox-mention-badge')), findsNothing);
      });

      testWidgets('a muted conversation shows the bell, not the count', (tester) async {
        final f = RowFixture(
          channels: [channelRecord('c1', 'launch-week', extra: {'activityMuted': true})],
        );
        addTearDown(f.dispose);
        await _pump(tester, f, channelRow(unread: 4), dark: dark);
        expect(find.byKey(const ValueKey('conversation-card-muted')), findsOneWidget);
        expect(find.byKey(const ValueKey('conversation-card-new-badge')), findsNothing);
        expect(tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).unread, isFalse);
      });

      testWidgets('an unread row is bold (unread), a read one is not', (tester) async {
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await _pump(tester, f, channelRow(unread: 2), dark: dark);
        expect(tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).unread, isTrue);
        await _pump(tester, f, channelRow(), dark: dark);
        expect(tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).unread, isFalse);
      });
    });
  }

  group('keys', () {
    testWidgets('thread and conversation rows keep their row keys', (tester) async {
      final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
      addTearDown(f.dispose);
      await _pump(tester, f, threadRow(id: 'thread-1'));
      expect(find.byKey(const ValueKey('activity-thread-thread-1')), findsOneWidget);
      await _pump(tester, f, channelRow());
      expect(find.byKey(const ValueKey('activity-channel-c1')), findsOneWidget);
    });
  });

  group('accessible name', () {
    testWidgets('title, App badge, body with channel, status, time in words', (
      tester,
    ) async {
      useFixedClock();
      final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
      addTearDown(f.dispose);
      final handle = tester.ensureSemantics();
      await pumpRowApp(
        tester,
        ActivityInboxRow(
          row: threadRow(
            id: 'task-ch',
            parentPreview: '',
            unread: 2,
            extra: {
              'conversationKind': 'task',
              'taskNumber': 7,
              'taskStatus': 'in_progress',
              'taskTitle': 'Fix the login bug',
              'hasMention': true,
            },
          ),
          host: f.host(taskV2: true),
        ),
      );
      expect(
        tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).semanticLabel,
        'Fix the login bug #launch-week · Bob: Looks good In progress 3 minutes ago',
      );
      handle.dispose();
    });

    testWidgets('the count, @ and dot are not in the name', (tester) async {
      useFixedClock();
      final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
      addTearDown(f.dispose);
      await pumpRowApp(
        tester,
        ActivityInboxRow(
          row: channelRow(unread: 9, extra: {'hasMention': true}),
          host: f.host(),
        ),
      );
      expect(
        tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).semanticLabel,
        'launch-week Bob: Draft is ready 3 minutes ago',
      );
    });

    testWidgets('an App-bot DM names its badge', (tester) async {
      useFixedClock();
      final f = RowFixture(
        dms: [
          channelRecord(
            'd1',
            'dm-1',
            type: 'dm',
            extra: {'peerId': 'bot1', 'peerType': 'agent', 'peerName': 'Deploybot'},
          ),
        ],
        agents: [
          {'id': 'bot1', 'name': 'Deploybot', 'managedByAppInstallId': 'i'},
        ],
      );
      addTearDown(f.dispose);
      await pumpRowApp(
        tester,
        ActivityInboxRow(
          row: {
            ...channelRow(id: 'd1', name: 'Deploybot', senderId: 'bot1'),
            'kind': 'dm',
            'channelType': 'dm',
          },
          host: f.host(),
        ),
      );
      expect(
        tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).semanticLabel,
        'Deploybot App Draft is ready 3 minutes ago',
      );
    });
  });
}
