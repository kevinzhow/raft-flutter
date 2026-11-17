import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_object_rows.dart';
import 'package:raft_flutter/features/activity_counts_line.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  const objects = ActivityObjectCounts(
    objectCount: 2,
    objectUnreadCount: 1,
    objectMentionUnreadCount: 1,
  );

  test('counts include objects and use the settled page', () {
    final line = ActivityCountsLine()
      ..settle(
        loaded: true,
        totalCount: 10,
        objects: objects,
        totalUnread: 4,
        filter: 'all',
        activeUnreadHint: 0,
      );
    expect(line.known, isTrue);
    expect(line.active, 12);
    expect(line.unread, 5);
  });

  test('the object unread follows the filter', () {
    int unread(String filter) =>
        (ActivityCountsLine()..settle(
              loaded: true,
              totalCount: 0,
              objects: objects,
              totalUnread: 0,
              filter: filter,
              activeUnreadHint: 0,
            ))
            .unread;
    expect(unread('all'), 1);
    expect(unread('mentions'), 1);
    expect(unread('unread_mentions'), 2);
  });

  test('a refilter keeps the last settled counts until the page lands', () {
    final line = ActivityCountsLine()
      ..settle(loaded: true, totalCount: 10, objects: ActivityObjectCounts.none, totalUnread: 4, filter: 'all', activeUnreadHint: 0);
    line.settle(loaded: false, totalCount: 0, objects: ActivityObjectCounts.none, totalUnread: 0, filter: 'unread', activeUnreadHint: 0);
    expect(line.known, isTrue);
    expect([line.active, line.unread], [10, 4]);
    line.settle(loaded: true, totalCount: 3, objects: ActivityObjectCounts.none, totalUnread: 3, filter: 'unread', activeUnreadHint: 0);
    expect([line.active, line.unread], [3, 3]);
  });

  test('before the first page the line is unknown and holds the unread hint', () {
    final line = ActivityCountsLine()
      ..settle(loaded: false, totalCount: 0, objects: ActivityObjectCounts.none, totalUnread: 0, filter: 'all', activeUnreadHint: 7);
    expect(line.known, isFalse);
    expect(line.unread, 7);
  });

  test('missing object fields read as zero', () {
    final counts = ActivityObjectCounts.fromWindow({'items': []});
    expect(counts, ActivityObjectCounts.none);
    expect(ActivityObjectCounts.fromWindow({'objectCount': 3}).objectCount, 3);
  });

  Future<void> pump(WidgetTester tester, ActivityCountsLine line) =>
      tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) =>
                Scaffold(body: activityCountsLine(context, line)),
          ),
        ),
      );

  testWidgets('the wording is "in progress" / "unread" with both numbers', (tester) async {
    final line = ActivityCountsLine()
      ..settle(loaded: true, totalCount: 0, objects: ActivityObjectCounts.none, totalUnread: 0, filter: 'all', activeUnreadHint: 0);
    await pump(tester, line);
    expect(find.textContaining('0 in progress · 0 unread', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-counts-loading')), findsNothing);
  });

  testWidgets('unknown counts keep their height, are invisible and out of semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final known = ActivityCountsLine()
      ..settle(loaded: true, totalCount: 1, objects: ActivityObjectCounts.none, totalUnread: 1, filter: 'all', activeUnreadHint: 0);
    await pump(tester, known);
    final height = tester.getSize(find.byKey(const ValueKey('activity-counts-line'))).height;
    final unknown = ActivityCountsLine()
      ..settle(loaded: false, totalCount: 0, objects: ActivityObjectCounts.none, totalUnread: 0, filter: 'all', activeUnreadHint: 0);
    await pump(tester, unknown);
    expect(tester.getSize(find.byKey(const ValueKey('activity-counts-line'))).height, height);
    expect(tester.widget<Opacity>(find.byKey(const ValueKey('activity-counts-loading'))).opacity, 0);
    expect(find.bySemanticsLabel(RegExp('in progress')), findsNothing);
    handle.dispose();
  });
}
