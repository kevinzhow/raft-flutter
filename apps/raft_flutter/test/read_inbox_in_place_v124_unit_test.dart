// Web v1.24.0 #244: a live message patches its Activity row's unread in place
// (store/inboxInPlaceUnread.ts, inboxCountedIds.ts), a served window behind it
// keeps the local unread, and the realtime re-read is a leading+trailing
// throttle (store/inboxStore.ts requestInboxBackgroundRefresh).
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/inbox_counted_ids.dart';
import 'package:raft_flutter/data/inbox_in_place_unread.dart';

Map<String, dynamic> _channel(
  String id,
  int seq,
  int unread, {
  String kind = 'channel',
}) => {
  'kind': kind,
  'channelId': id,
  'lastMessageId': 'm$seq',
  'latestActivitySeq': '$seq',
  'unreadCount': unread,
  'hasMention': false,
  'firstUnreadMessageId': null,
  'firstMentionMessageId': null,
};

Map<String, dynamic> _thread(String id, int seq, int unread) => {
  'kind': 'thread',
  'threadChannelId': id,
  'latestActivityMessageId': 'r$seq',
  'latestActivitySeq': '$seq',
  'unreadCount': unread,
  'hasMention': false,
  'firstUnreadMessageId': null,
  'firstMentionMessageId': null,
  'replyCount': seq,
};

Map<String, dynamic> _message(String channel, int seq, {Map? extra}) => {
  'id': 'm$seq',
  'channelId': channel,
  'seq': seq,
  'senderId': 'bob',
  'senderType': 'user',
  'content': 'hello $seq',
  ...?extra,
};

const _counts = LiveUnread(counts: true, mention: false, viewer: 'alice');
const _mention = LiveUnread(counts: true, mention: true, viewer: 'alice');
const _silent = LiveUnread(counts: false, mention: false, viewer: 'alice');

void main() {
  final now = DateTime.utc(2026, 11, 14, 12);

  group('InboxCountedIds', () {
    test('[BP-READ-042] caps one row at 64 ids and all rows at 1024', () {
      final ids = InboxCountedIds();
      for (var i = 1; i <= 64; i++) {
        expect(ids.noteCounted('a', 'm$i', BigInt.from(i)), isTrue);
      }
      expect(
        ids.noteCounted('a', 'm65', BigInt.from(65)),
        isFalse,
        reason: 'the 65th id of a row is not kept: ask for a re-read',
      );
      expect(ids.sizeOf('a'), 64);
      expect(
        ids.noteCounted('a', 'm3', BigInt.from(3)),
        isTrue,
        reason: 'seen',
      );
      // The row stopped counting late messages until an answer covers it.
      ids.noteServed([_channel('a', 10, 0)], reset: true);
      expect(ids.isLateUncounted('a', 'x', BigInt.from(70)), isFalse);
      ids.noteServed([_channel('a', 70, 0)], reset: true);
      expect(ids.isLateUncounted('a', 'x', BigInt.from(80)), isTrue);

      final all = InboxCountedIds();
      for (var row = 0; row < 16; row++) {
        for (var i = 1; i <= 64; i++) {
          expect(all.noteCounted('r$row', 'm$i', BigInt.from(i)), isTrue);
        }
      }
      expect(all.noteCounted('r16', 'm1', BigInt.one), isFalse);
    });

    test('[BP-READ-042] an answer drops only the ids it covers and never '
        'moves back', () {
      final ids = InboxCountedIds()
        ..noteServed([_channel('a', 5, 0)], reset: true)
        ..noteCounted('a', 'm6', BigInt.from(6))
        ..noteCounted('a', 'm7', BigInt.from(7));
      ids.noteServed([_channel('a', 6, 0)], reset: false);
      expect(ids.isCounted('a', 'm6'), isFalse);
      expect(ids.isCounted('a', 'm7'), isTrue, reason: 'answer is behind m7');
      ids.noteServed([_channel('a', 4, 0)], reset: false);
      expect(ids.isLateUncounted('a', 'm5', BigInt.from(5)), isFalse);
      ids.noteServed(const [], reset: true);
      expect(ids.sizeOf('a'), 0, reason: 'a reset forgets unlisted rows');
    });
  });

  group('liveUnreadFields', () {
    test('[BP-READ-042] counts one, sets the first unread and mention ids', () {
      final row = _channel('c1', 5, 0);
      final fields = liveUnreadFields(row, _message('c1', 6), _mention);
      expect(fields, {
        'unreadCount': 1,
        'firstUnreadMessageId': 'm6',
        'hasMention': true,
        'firstMentionMessageId': 'm6',
      });
      final more = liveUnreadFields(
        {...row, ...fields},
        _message('c1', 7),
        _counts,
      );
      expect(more, {'unreadCount': 2}, reason: 'first ids stay');
      expect(liveUnreadFields(row, _message('c1', 6), _silent), isEmpty);
      expect(liveUnreadFields(row, _message('c1', 6), null), isEmpty);
    });

    test('[BP-READ-042] a thread row counts only followed, seq-carrying '
        'replies', () {
      final row = _thread('t1', 5, 0);
      expect(
        liveUnreadFields(row, _message('t1', 6), _counts)['unreadCount'],
        1,
      );
      expect(
        liveUnreadFields(
          {...row, 'isFollowing': false},
          _message('t1', 6),
          _counts,
        ),
        isEmpty,
      );
      expect(
        liveUnreadFields(row, {..._message('t1', 6), 'seq': null}, _counts),
        isEmpty,
      );
    });

    test('[BP-READ-042] system lines count as the server counts them', () {
      final row = _thread('t1', 5, 0);
      Map<String, dynamic> system(Map extra) =>
          _message('t1', 6, extra: {'messageType': 'system', ...extra});
      // No provenance: cannot be judged, left to the re-read.
      expect(liveUnreadFields(row, system({}), _counts), isEmpty);
      expect(liveUnreadFields(row, system({'systemSubtype': null}), _counts), {
        'unreadCount': 1,
        'firstUnreadMessageId': 'm6',
      });
      expect(
        liveUnreadFields(
          row,
          system({'systemSubtype': 'channel.self_unfollow_thread'}),
          _counts,
        ),
        isEmpty,
      );
      expect(
        liveUnreadFields(
          row,
          system({
            'systemSubtype': 'x',
            'causalActorType': 'user',
            'causalActorId': 'alice',
          }),
          _counts,
        ),
        isEmpty,
        reason: 'the person caused it',
      );
      expect(
        liveUnreadFields(
          {...row, 'conversationKind': 'task'},
          system({'systemSubtype': null}),
          _counts,
        ),
        isEmpty,
        reason: 'a task conversation counts chat replies only',
      );
      // A mention on an uncounted system line still lights the @.
      expect(
        liveUnreadFields(
          row,
          system({'systemSubtype': 'channel.self_unfollow_thread'}),
          _mention,
        )['hasMention'],
        isTrue,
      );
    });
  });

  group('InboxInPlaceUnread', () {
    test('[BP-READ-042] a newer message advances and moves the row to the '
        'top, counted once', () {
      final state = InboxInPlaceUnread();
      final rows = [_channel('c0', 9, 0), _channel('c1', 5, 2)];
      final applied = state.apply(rows, _message('c1', 6), _counts, now: now)!;
      expect(applied.delta, 1);
      expect(applied.rows.first['channelId'], 'c1');
      expect(applied.rows.first['unreadCount'], 3);
      expect(applied.rows.first['latestActivitySeq'], '6');
      expect(state.noteApplied(_message('c1', 6)), isTrue);
      // The same message again (socket replay, sync): nothing.
      expect(
        state.apply(applied.rows, _message('c1', 6), _counts, now: now),
        isNull,
      );
    });

    test('[BP-READ-042] a late message counts once and leaves the row\'s '
        'seq and preview', () {
      final state = InboxInPlaceUnread()
        ..counted.noteServed([_channel('c1', 5, 0)], reset: true);
      var rows = [_channel('c1', 5, 0)];
      rows = state.apply(rows, _message('c1', 8), _counts, now: now)!.rows;
      state.noteApplied(_message('c1', 8));
      // m7 came after m8: below the row's seq, newer than the served seq.
      final late = state.apply(rows, _message('c1', 7), _counts, now: now)!;
      expect(late.rows.single['unreadCount'], 2);
      expect(late.rows.single['latestActivitySeq'], '8');
      expect(late.rows.single['lastMessageId'], 'm8');
      state.noteApplied(_message('c1', 7));
      expect(
        state.apply(late.rows, _message('c1', 7), _counts, now: now),
        isNull,
      );
      // Read already: another device's cursor covers it.
      expect(
        state.apply(
          rows,
          _message('c1', 6),
          _counts,
          now: now,
          readSeq: BigInt.from(6),
        ),
        isNull,
      );
    });

    test(
      '[BP-READ-042] a row the list does not show is left to the re-read',
      () {
        final state = InboxInPlaceUnread();
        expect(
          state.apply(
            [_channel('c1', 5, 0)],
            _message('other', 6),
            _counts,
            now: now,
          ),
          isNull,
        );
        expect(
          state.apply(
            [_channel('c1', 5, 0)],
            {..._message('c1', 6), 'seq': null},
            _counts,
            now: now,
          ),
          isNull,
        );
      },
    );

    test(
      '[BP-READ-042] a mention sets hasMention and the first mention id',
      () {
        final applied = InboxInPlaceUnread().apply(
          [_thread('t1', 5, 0)],
          _message('t1', 6),
          _mention,
          now: now,
        )!;
        expect(applied.rows.single['hasMention'], isTrue);
        expect(applied.rows.single['firstMentionMessageId'], 'm6');
        expect(applied.rows.single['replyCount'], 6);
      },
    );

    test('[BP-READ-043] a served row behind a patched one keeps the local '
        'unread, then the answer that reaches it wins', () {
      final state = InboxInPlaceUnread();
      final shown = state
          .apply([_channel('c1', 5, 2)], _message('c1', 6), _counts, now: now)!
          .rows;
      expect(shown.single['unreadCount'], 3);
      final behind = state.keepAhead([_channel('c1', 5, 2)], shown, now: now);
      expect(behind.rows.single['unreadCount'], 3, reason: 'no flicker back');
      expect(
        behind.rows.single['latestActivitySeq'],
        '6',
        reason: 'as the live message left it',
      );
      expect(behind.delta, 1);
      final reached = state.keepAhead([_channel('c1', 6, 3)], shown, now: now);
      expect(reached.rows.single['unreadCount'], 3);
      expect(reached.delta, 0);
      // Done with it: a later behind answer is not held any more.
      final again = state.keepAhead([_channel('c1', 5, 2)], shown, now: now);
      expect(again.rows.single['unreadCount'], 2);
    });

    test('[BP-READ-043] the hold ends at the stale-list bound', () {
      final state = InboxInPlaceUnread();
      final shown = state
          .apply([_channel('c1', 5, 2)], _message('c1', 6), _counts, now: now)!
          .rows;
      final late = state.keepAhead(
        [_channel('c1', 5, 2)],
        shown,
        now: now.add(InboxInPlaceUnread.hold + const Duration(seconds: 1)),
      );
      expect(late.rows.single['unreadCount'], 2);
    });

    test('[BP-READ-043] a kept row stays on top of the served order', () {
      final state = InboxInPlaceUnread();
      final shown = state
          .apply(
            [_channel('c0', 9, 0), _channel('c1', 5, 2)],
            _message('c1', 6),
            _counts,
            now: now,
          )!
          .rows;
      final kept = state.keepAhead(
        [_channel('c0', 9, 0), _channel('c1', 5, 2)],
        shown,
        now: now,
      );
      expect([for (final r in kept.rows) r['channelId']], ['c1', 'c0']);
    });
  });

  group('readPersistedSkipsReread', () {
    final rows = [_channel('c1', 5, 0), _channel('c2', 5, 3)];
    test('[BP-READ-041] skips only a listed, read row of a settled list with '
        'the flag on', () {
      bool skip(String id, {bool settled = true, bool flag = true}) =>
          readPersistedSkipsReread(
            rows,
            id,
            listSettled: settled,
            flagOn: flag,
          );
      expect(skip('c1'), isTrue);
      expect(skip('c1', flag: false), isFalse, reason: 'flag off re-reads');
      expect(skip('c1', settled: false), isFalse);
      expect(skip('c2'), isFalse, reason: 'row shows unread again');
      expect(skip('absent'), isFalse, reason: 'not listed');
    });
  });

  group('clearedByReadThrough', () {
    Map<String, dynamic> row(int frontier, int display, int unread) => {
      ..._channel('c1', display, unread),
      'readState': {
        'kind': 'present',
        'latestActivity': {'seq': '$frontier'},
      },
    };
    test('[BP-READ-043] a read covering frontier and display seq zeroes the '
        'row', () {
      final cleared = clearedByReadThrough(
        row(5, 5, 3)..['hasMention'] = true,
        maxReadSeq: BigInt.from(5),
        markedUnread: false,
      )!;
      expect(cleared['unreadCount'], 0);
      expect(cleared['hasMention'], isFalse);
      expect(cleared['firstUnreadMessageId'], isNull);
    });

    test('[BP-READ-043] a newer live message, a leftover count or a mark keep '
        'the row', () {
      BigInt read(int n) => BigInt.from(n);
      expect(
        clearedByReadThrough(
          row(5, 6, 3),
          maxReadSeq: read(5),
          markedUnread: false,
        ),
        isNull,
        reason: 'display seq advanced by a live reply is past the read',
      );
      expect(
        clearedByReadThrough(
          row(5, 5, 3),
          maxReadSeq: read(5),
          markedUnread: false,
          unreadCount: 2,
        ),
        isNull,
      );
      expect(
        clearedByReadThrough(
          row(5, 5, 3),
          maxReadSeq: read(5),
          markedUnread: true,
        ),
        isNull,
      );
      expect(
        clearedByReadThrough(
          {..._channel('c1', 5, 3)},
          maxReadSeq: read(5),
          markedUnread: false,
        ),
        isNull,
        reason: 'no read-state frontier to judge by',
      );
    });
  });
}
