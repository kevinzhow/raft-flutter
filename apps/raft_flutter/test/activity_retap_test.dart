import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/activity_retap.dart';

ActivityRetapRow row(String key, double top, {bool unread = false}) =>
    ActivityRetapRow(key: key, top: top, unread: unread);

void main() {
  final rows = [
    row('a', 0),
    row('b', 100, unread: true),
    row('c', 200),
    row('d', 300, unread: true),
    row('e', 400, unread: true),
  ];
  ActivityRetapTarget next({
    double scrollTop = 0,
    double max = 1000,
    ActivityRetapAnchor? anchor,
    int now = 10000,
    List<ActivityRetapRow>? list,
  }) => nextActivityRetapTarget(
    rows: list ?? rows,
    scrollTop: scrollTop,
    maxScrollTop: max,
    anchor: anchor,
    now: now,
  );

  test('at the top the first unread row counts', () {
    expect(next(), const ActivityRetapRowTarget('b', 100));
  });

  test('below the position: the first unread row whose top is further down', () {
    expect(next(scrollTop: 100), const ActivityRetapRowTarget('d', 300));
    expect(next(scrollTop: 50), const ActivityRetapRowTarget('b', 100));
  });

  test('the target is clamped to what can scroll', () {
    expect(next(scrollTop: 100, max: 250), const ActivityRetapRowTarget('d', 250));
  });

  test('after the last unread it goes to the top', () {
    expect(next(scrollTop: 400), const ActivityRetapTopTarget());
    expect(next(list: [row('a', 0), row('b', 10)]), const ActivityRetapTopTarget());
  });

  test('a recent anchor stands in for the position', () {
    final anchor = ActivityRetapAnchor(key: 'b', to: 100, at: 9800);
    // The list is still near 0 (smooth scroll on its way) but within 700 ms.
    expect(next(scrollTop: 20, anchor: anchor), const ActivityRetapRowTarget('d', 300));
  });

  test('a stale anchor away from where it sent the list is dropped', () {
    final anchor = ActivityRetapAnchor(key: 'b', to: 100, at: 1000);
    expect(next(scrollTop: 150, anchor: anchor), const ActivityRetapRowTarget('d', 300));
  });

  test('an anchor at the top (null key) means the first unread row', () {
    final anchor = ActivityRetapAnchor(key: null, to: 0, at: 9900);
    expect(next(scrollTop: 150, anchor: anchor), const ActivityRetapRowTarget('b', 100));
  });

  test('an anchored row that moved is looked up as it is now', () {
    final moved = [
      row('a', 0, unread: true),
      row('x', 100),
      row('b', 200),
      row('d', 300, unread: true),
    ];
    final anchor = ActivityRetapAnchor(key: 'b', to: 100, at: 9900);
    expect(next(list: moved, scrollTop: 100, anchor: anchor),
        const ActivityRetapRowTarget('d', 300));
  });

  test('unloaded unread needs more, a server with more, and a larger total', () {
    expect(hasUnloadedUnread(loadedUnreadCount: 3, totalUnreadCount: 9, hasMore: true), isTrue);
    expect(hasUnloadedUnread(loadedUnreadCount: 3, totalUnreadCount: 3, hasMore: true), isFalse);
    expect(hasUnloadedUnread(loadedUnreadCount: 3, totalUnreadCount: 9, hasMore: false), isFalse);
  });
}
