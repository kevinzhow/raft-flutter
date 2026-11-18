import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/features/activity_inbox_row.dart';

import 'support/activity_list_harness.dart';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> servedRows(Object? window, String field) =>
    ((window as Map)[field] as List).cast<Map<String, dynamic>>();

void main() {
  final fixture = readJson(
    'test/fixtures/field_parity/activity-producer-v1_24.json',
  );
  final all = servedRows(fixture['all'], 'items');
  final unread = servedRows(fixture['unread'], 'items');
  final followed = servedRows(fixture['followed'], 'threads');

  test('capture the raw task rows from the current upstream reference', () {
    final upstream = readJson('../../docs/upstream-sync.json');
    final adopted = (upstream['history'] as List).cast<Map>().reversed.where(
      (entry) =>
          entry['decision'] == 'follow' || entry['decision'] == 'partial',
    );
    expect(
      fixture['sourceCommit'],
      (upstream['pending'] as Map?)?['commit'] ??
          adopted.firstOrNull?['commit'] ??
          upstream['commit'],
      reason:
          'Refresh the Activity capture when the upstream reference changes. '
          'See docs/field-parity.md.',
    );
    for (final rows in [all, unread, followed]) {
      final task = rows.singleWhere((row) => row['kind'] == 'task');
      expect(task['parentMessageId'], isNull);
      expect(task['threadChannelId'], isNotEmpty);
      expect(task['taskTitle'], isNotEmpty);
      expect(task['lastActivityAt'], isNotEmpty);
      expect(task['unreadCount'], greaterThan(0));
      expect(task, isNot(contains('conversationKind')));
    }
  });

  testWidgets('raw task response keeps title, order and unread in Activity', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(() async {
      workspace.dispose();
      await client.dispose();
    });
    final task = all.singleWhere((row) => row['kind'] == 'task');
    workspace.inbox = [
      ...all,
      {...dayRow(1), 'lastMessageAt': '2025-10-01T08:00:00Z'},
    ];
    final dynamic page = await mountActivity(tester, workspace, desktop);
    final taskRow = find.byWidgetPredicate(
      (widget) =>
          widget is ActivityInboxRow && widget.row['taskId'] == task['taskId'],
    );
    final taskTitle = find.descendant(
      of: taskRow,
      matching: find.byKey(const ValueKey('conversation-card-primary')),
    );
    expect(taskRow, findsOneWidget);
    final titleInAll = tester.widget<Text>(taskTitle).data;
    final newestFirst =
        tester.getTopLeft(taskRow).dy <
        tester.getTopLeft(row('activity-channel-ch1')).dy;

    workspace.inbox = unread;
    page.chooseActivityFilter(ActivityFilterChoice.unread);
    await tester.pumpAndSettle();
    expect(workspace.inboxQueries.last['filter'], 'unread');
    expect(taskRow, findsOneWidget);
    final titleInUnread = tester.widget<Text>(taskTitle).data;
    final visibleUnread = tester
        .widget<ActivityInboxRow>(taskRow)
        .row['unreadCount'];

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      (titleInAll, newestFirst, titleInUnread, visibleUnread),
      (task['taskTitle'], true, task['taskTitle'], task['unreadCount']),
    );
  });
}
