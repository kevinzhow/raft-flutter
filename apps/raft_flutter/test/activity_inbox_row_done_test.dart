import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/activity_inbox_row.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_row_harness.dart';

Finder get _mouseDone => find.byKey(const ValueKey('inbox-row-done'));
Finder get _actions => find.byKey(const ValueKey('inbox-item-actions'));

double _actionsOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: _actions, matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

Future<TestGesture> _hover(WidgetTester tester, Finder at) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(at));
  await tester.pump(const Duration(milliseconds: 300));
  return gesture;
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets(
      '$mode 1440 mouse: ghost 28px Done appears on hover, with the tooltip',
      (tester) async {
        useFixedClock();
        final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
        addTearDown(f.dispose);
        await pumpRowApp(
          tester,
          ActivityInboxRow(row: channelRow(), host: f.host()),
          dark: dark,
        );
        expect(_actionsOpacity(tester), 0);
        await _hover(tester, find.byKey(const ValueKey('inbox-item-open')));
        expect(_actionsOpacity(tester), 1);
        expect(tester.getSize(_mouseDone), const Size(28, 28));
        final button = tester.widget<RaftInboxRowDone>(
          find.byType(RaftInboxRowDone),
        );
        expect(button.tooltip, 'Mark as Done');
        expect(button.semanticLabel, 'Mark #launch-week as Done');
        await tester.tap(_mouseDone);
        expect(f.calls.actions, ['done']);
      },
    );

    for (final (name, size, platform) in rowEnvs) {
      final touch = platform == TargetPlatform.android;
      testWidgets(
        '$mode $name: Done is ${touch ? 'a row semantics action' : 'a hover button'}',
        (tester) async {
          useFixedClock();
          final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
          addTearDown(f.dispose);
          final row = ActivityInboxRow(row: channelRow(), host: f.host());
          final excerpt = find.byKey(const ValueKey('conversation-card-body'));
          double? compactExcerptWidth;
          if (touch && size.width > 390) {
            await pumpRowApp(
              tester,
              row,
              size: const Size(390, 844),
              platform: platform,
              dark: dark,
            );
            compactExcerptWidth = tester.getSize(excerpt).width;
          }
          await pumpRowApp(
            tester,
            row,
            size: size,
            platform: platform,
            dark: dark,
          );
          if (touch) {
            expect(find.byType(RaftInboxRowDone), findsNothing);
            expect(_actions, findsNothing);
            if (compactExcerptWidth != null) {
              expect(tester.getSize(excerpt).width, compactExcerptWidth);
            }
            final semantics = tester.ensureSemantics();
            try {
              await tester.pump();
              final node = tester.getSemantics(
                find.bySemanticsLabel(RegExp('^launch-week')),
              );
              final data = node.getSemanticsData();
              final actionId = data.customSemanticsActionIds!.single;
              expect(
                CustomSemanticsAction.getAction(actionId)!.label,
                'Mark #launch-week as Done',
              );
              tester.binding.performSemanticsAction(
                SemanticsActionEvent(
                  type: SemanticsAction.customAction,
                  viewId: tester.view.viewId,
                  nodeId: node.id,
                  arguments: actionId,
                ),
              );
              expect(f.calls.actions, ['done']);
            } finally {
              semantics.dispose();
            }
          } else {
            expect(_actionsOpacity(tester), 0);
            await _hover(tester, find.byKey(const ValueKey('inbox-item-open')));
            expect(_actionsOpacity(tester), 1);
            expect(_mouseDone, findsOneWidget);
            // 28px bar button from 768 wide with a mouse, 32 below.
            expect(
              tester.getSize(_mouseDone),
              size.width >= 768 ? const Size(28, 28) : const Size(32, 32),
            );
            await tester.tap(_mouseDone);
            expect(f.calls.actions, ['done']);
          }
        },
      );
    }
  }

  testWidgets('narrow Linux: keyboard focus reveals and activates Done', (
    tester,
  ) async {
    useFixedClock();
    final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
    addTearDown(f.dispose);
    await pumpRowApp(
      tester,
      ActivityInboxRow(row: channelRow(), host: f.host()),
      size: const Size(390, 844),
    );
    expect(_actionsOpacity(tester), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_actionsOpacity(tester), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(f.calls.actions, ['done']);
  });

  testWidgets('wide touch hides the button even with phone swipes disabled', (
    tester,
  ) async {
    useFixedClock();
    final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
    addTearDown(f.dispose);
    await pumpRowApp(
      tester,
      ActivityInboxRow(row: channelRow(), host: f.host(phoneTouch: false)),
      size: const Size(856, 944),
      platform: TargetPlatform.android,
    );
    expect(find.byType(RaftInboxRowDone), findsNothing);
  });

  testWidgets('the host may say it is a phone with touch', (tester) async {
    useFixedClock();
    final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
    addTearDown(f.dispose);
    await pumpRowApp(
      tester,
      ActivityInboxRow(row: channelRow(), host: f.host(phoneTouch: true)),
    );
    expect(find.byType(RaftInboxRowDone), findsNothing);
  });

  testWidgets(
    'thread rows: "Mark the thread in #channel as Done"; task rows name the task',
    (tester) async {
      useFixedClock();
      final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
      addTearDown(f.dispose);
      await pumpRowApp(
        tester,
        ActivityInboxRow(row: threadRow(), host: f.host()),
      );
      expect(
        tester
            .widget<RaftInboxRowDone>(find.byType(RaftInboxRowDone))
            .semanticLabel,
        'Mark the thread in #launch-week as Done',
      );
      await pumpRowApp(
        tester,
        ActivityInboxRow(
          row: threadRow(
            parentPreview: '',
            extra: {
              'conversationKind': 'task',
              'taskNumber': 7,
              'taskStatus': 'todo',
              'taskTitle': 'Fix the login bug',
            },
          ),
          host: f.host(taskV2: true),
        ),
      );
      expect(
        tester
            .widget<RaftInboxRowDone>(find.byType(RaftInboxRowDone))
            .semanticLabel,
        'Mark Fix the login bug as Done',
      );
      await pumpRowApp(
        tester,
        ActivityInboxRow(
          row: threadRow(
            parentPreview: '',
            extra: {
              'conversationKind': 'task',
              'taskNumber': 7,
              'taskStatus': 'todo',
              'taskTitle': 'Fix the login bug',
            },
          ),
          host: f.host(taskV2: false),
        ),
      );
      expect(
        tester
            .widget<RaftInboxRowDone>(find.byType(RaftInboxRowDone))
            .semanticLabel,
        'Mark #launch-week:#7 as Done',
      );
    },
  );

  testWidgets('a mention_action row has no Done', (tester) async {
    useFixedClock();
    final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
    addTearDown(f.dispose);
    await pumpRowApp(
      tester,
      ActivityInboxRow(
        row: {
          'kind': 'mention_action',
          'id': 'm1',
          'channelId': 'c1',
          'channelName': 'launch-week',
          'channelType': 'channel',
          'messageId': 'msg',
          'messagePreview': 'Pending mention',
          'createdAt': fixedNow.toString().replaceFirst(' ', 'T'),
          'unreadCount': 0,
        },
        host: f.host(),
      ),
    );
    expect(find.byType(RaftInboxRowDone), findsNothing);
    expect(find.text('launch-week'), findsOneWidget);
  });

  testWidgets('"Restore conversation" and "Mark conversation done" are gone', (
    tester,
  ) async {
    useFixedClock();
    final f = RowFixture(channels: [channelRecord('c1', 'launch-week')]);
    addTearDown(f.dispose);
    await pumpRowApp(
      tester,
      ActivityInboxRow(
        row: channelRow(),
        host: f.host(filter: 'done'),
      ),
    );
    expect(find.byTooltip('Restore conversation'), findsNothing);
    expect(find.byTooltip('Mark conversation done'), findsNothing);
    expect(find.byIcon(Icons.undo), findsNothing);
  });
}
