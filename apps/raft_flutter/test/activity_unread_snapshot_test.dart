import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_unread_snapshot.dart';

Map<String, dynamic> row(String id, {int unread = 1, String last = 'm1'}) => {
  'kind': 'channel',
  'channelId': id,
  'unreadCount': unread,
  'hasMention': false,
  'firstUnreadMessageId': unread > 0 ? 'f$id' : null,
  'lastMessageId': last,
  'latestActivitySeq': '1',
};

List<String> ids(List<Map<String, dynamic>> rows) => [
  for (final r in rows) '${r['channelId']}:${r['unreadCount']}',
];

void main() {
  const visit = 1;
  late ActivityUnreadSnapshotStore store;
  setUp(() => store = ActivityUnreadSnapshotStore());

  test('a read row the store stops listing stays, shown read, in place', () {
    final a = row('a'), b = row('b'), c = row('c');
    expect(ids(store.shown([a, b, c], list: 'L', visit: visit)), [
      'a:1',
      'b:1',
      'c:1',
    ]);
    store.noteRead(['channel:b']);
    expect(ids(store.shown([a, c], list: 'L', visit: visit)), [
      'a:1',
      'b:0',
      'c:1',
    ]);
    // Shown again: the same copy, nothing changes.
    expect(ids(store.shown([a, c], list: 'L', visit: visit)), [
      'a:1',
      'b:0',
      'c:1',
    ]);
  });

  test('a row that left for another reason is not kept', () {
    final a = row('a'), b = row('b');
    store.shown([a, b], list: 'L', visit: visit);
    expect(ids(store.shown([a], list: 'L', visit: visit)), ['a:1']);
  });

  test('another list, another visit or no list ends the snapshot', () {
    final a = row('a'), b = row('b');
    store.shown([a, b], list: 'L', visit: visit);
    store.noteRead(['channel:b']);
    expect(ids(store.shown([a], list: 'M', visit: visit)), ['a:1']);
    store.shown([a, b], list: 'L', visit: 1);
    store.noteRead(['channel:b']);
    expect(ids(store.shown([a], list: 'L', visit: 2)), ['a:1']);
    store.shown([a, b], list: 'L', visit: 3);
    store.noteRead(['channel:b']);
    expect(ids(store.shown([a], list: null, visit: 3)), ['a:1']);
    expect(store.current, isNull);
  });

  test('a row that got a new message moves and is not kept', () {
    final a = row('a'), b = row('b'), c = row('c');
    store.shown([a, b, c], list: 'L', visit: visit);
    store.noteRead(['channel:a']);
    // a is read and gone from the store; c got a new message and moved to the top.
    final c2 = row('c', last: 'm2');
    final shown = store.shown([c2, b], list: 'L', visit: visit);
    expect(ids(shown), ['c:1', 'a:0', 'b:1']);
  });

  test('a kept row with no unmoved row above goes before the one below', () {
    final a = row('a'), b = row('b');
    store.shown([a, b], list: 'L', visit: visit);
    store.noteRead(['channel:a']);
    final n = row('n');
    expect(ids(store.shown([n, b], list: 'L', visit: visit)), [
      'n:1',
      'a:0',
      'b:1',
    ]);
  });

  test('a row read, then unread again, is no longer read', () {
    final a = row('a'), b = row('b');
    store.shown([a, b], list: 'L', visit: visit);
    store.noteRead(['channel:a']);
    store.forgetUnreadAgain([row('a', last: 'm9')]);
    expect(ids(store.shown([b], list: 'L', visit: visit)), ['b:1']);
  });

  test('at most 500 are kept, the earliest leave', () {
    final rows = [for (var i = 0; i < 600; i++) row('r$i')];
    store.shown(rows, list: 'L', visit: visit);
    store.noteRead([for (var i = 0; i < 600; i++) 'channel:r$i']);
    final shown = store.shown([], list: 'L', visit: visit);
    expect(shown, hasLength(500));
    expect(shown.first['channelId'], 'r100');
  });

  test('Done on a kept row takes it out and an undo puts it back', () {
    final a = row('a'), b = row('b'), c = row('c');
    store.shown([a, b, c], list: 'L', visit: visit);
    store.noteRead(['channel:b']);
    store.shown([a, c], list: 'L', visit: visit);
    expect(store.keptRow('channel:b'), isNotNull);
    final undo = store.take('channel:b')!;
    expect(ids(store.shown([a, c], list: 'L', visit: visit)), ['a:1', 'c:1']);
    undo();
    expect(ids(store.shown([a, c], list: 'L', visit: visit)), [
      'a:1',
      'b:0',
      'c:1',
    ]);
  });

  test('object rows keep by their object key and read by their own rule', () {
    Map<String, dynamic> object(int unread, String seq) => {
      'kind': 'object',
      'objectKind': 'artifact',
      'objectId': 'o1',
      'unreadCount': unread,
      'hasMention': false,
      'doneFrontierSeq': seq,
    };
    expect(ActivityUnreadSnapshot.isRead(object(0, '3')), isTrue);
    expect(ActivityUnreadSnapshot.isRead(object(2, '3')), isFalse);
    final a = row('a');
    store.shown([object(2, '3'), a], list: 'L', visit: visit);
    store.noteRead(['object:artifact:o1']);
    final shown = store.shown([a], list: 'L', visit: visit);
    expect(shown.first['kind'], 'object');
    expect(shown.first['unreadCount'], 0);
  });

  test('the visit ends when the last surface leaves', () {
    final visits = ActivityVisit();
    final leaveList = visits.enter();
    final first = visits.current;
    final leavePane = visits.enter();
    expect(visits.current, first);
    leaveList();
    expect(visits.current, first);
    leavePane();
    expect(visits.active, isFalse);
    visits.enter();
    expect(visits.current, first + 1);
  });

  test('index of a kept row among the store rows', () {
    final a = row('a'), b = row('b'), c = row('c');
    store.shown([a, b, c], list: 'L', visit: visit);
    expect(store.indexOf('channel:b', [a, c]), 1);
    expect(store.indexOf('channel:zz', [a, c]), 2);
  });
}
