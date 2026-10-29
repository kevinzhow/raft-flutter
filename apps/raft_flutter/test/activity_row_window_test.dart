import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_row_window.dart';
import 'package:raft_flutter/data/resource_row_reconcile.dart';
import 'package:raft_flutter/features/resource_list_updates.dart';

Map<String, dynamic> row(int i, {String kind = 'channel'}) => {
  'kind': kind,
  if (kind == 'thread') 'threadChannelId': 'c$i' else 'channelId': 'c$i',
  'lastMessageId': 'old$i',
  'latestActivityMessageId': 'old$i',
  'latestActivitySeq': '1',
  'unreadCount': i % 3,
};

Map<String, dynamic> message(int i, int sequence) => {
  'id': 'm$sequence',
  'channelId': 'c$i',
  'seq': sequence,
  'content': 'Message $sequence',
};

bool unmuted(Map<String, dynamic> _) => false;

void main() {
  test(
    'changing the identity mode invalidates a retained window key cache',
    () {
      final rows = ActivityRowWindow.from([
        {...row(1), 'savedMessageId': 'saved1'},
      ]);
      final updates = ResourceListUpdates();
      String? savedKey(Map item) => 'saved:${item['savedMessageId']}';
      updates.observeRows(
        view: 'same-view',
        rows: rows,
        keyOf: savedKey,
        indexedActivity: true,
      );
      expect(updates.indexOf(const ResourceRowListKey('channel:c1')), 0);
      updates.observeRows(
        view: 'same-view',
        rows: rows,
        keyOf: savedKey,
        indexedActivity: false,
      );
      expect(updates.indexOf(const ResourceRowListKey('saved:saved1')), 0);
      expect(updates.indexOf(const ResourceRowListKey('channel:c1')), isNull);
    },
  );

  test(
    'moving rows preserves old snapshots, random access and unique indexes',
    () {
      var reference = [for (var i = 0; i < 301; i++) row(i)];
      var window = ActivityRowWindow.from(reference);
      final initial = window;
      final random = Random(199);
      final updates = ResourceListUpdates();
      final snapshots = <(ActivityRowWindow, List<String?>)>[];
      for (var sequence = 2; sequence < 1502; sequence++) {
        final selected = random.nextInt(reference.length);
        final input = message(selected, sequence);
        final index = reference.indexWhere(
          (r) => r['channelId'] == 'c$selected',
        );
        final next = advanceActivityRow(reference[index], input)!;
        reference = [
          next,
          ...reference.take(index),
          ...reference.skip(index + 1),
        ];
        window = window
            .advance(input, muted: unmuted, newestFirst: true)!
            .window;
        updates.observe(view: 'activity', keys: window.rowKeys);
        if (sequence % 100 == 0) {
          snapshots.add((window, window.rowKeys.toList()));
          expect(window.toList(), reference);
          expect(window.rowKeys.toList(), reference.map(activityItemKey));
          for (var i = 0; i < reference.length; i++) {
            final key = activityItemKey(reference[i])!;
            expect(window[i], reference[i]);
            expect(updates.indexOf(ResourceRowListKey(key)), i);
          }
        }
      }
      expect(initial.first['lastMessageId'], 'old0');
      expect(initial.last['channelId'], 'c300');
      for (final (snapshot, keys) in snapshots) {
        expect(snapshot.rowKeys.toList(), keys);
      }
      expect(() => window[-1], throwsRangeError);
      expect(() => window[window.length], throwsRangeError);
      expect(() => window.clear(), throwsUnsupportedError);
    },
  );

  test('ascending updates reuse the exact identity sequence', () {
    final original = ActivityRowWindow.from([row(1), row(2), row(3)]);
    final next = original.advance(
      message(2, 2),
      muted: unmuted,
      newestFirst: false,
    )!;
    expect(next.window.rowKeys, same(original.rowKeys));
    expect(next.window[0], same(original[0]));
    expect(next.window[2], same(original[2]));
    expect(next.window[1]['lastMessageId'], 'm2');
    expect(original[1]['lastMessageId'], 'old2');
  });

  test(
    'repeated, stale, unknown and muted messages leave the window untouched',
    () {
      final original = ActivityRowWindow.from([row(1), row(2)]);
      for (final input in [
        message(1, 1),
        {...message(1, 2), 'id': 'old1'},
        {...message(1, 2), 'seq': 'invalid'},
        message(99, 2),
        {'id': 'missing-scope'},
      ]) {
        expect(
          original.advance(input, muted: unmuted, newestFirst: true),
          isNull,
        );
      }
      expect(
        original.advance(message(1, 2), muted: (_) => true, newestFirst: true),
        isNull,
      );
      final next = original
          .advance(message(1, 2), muted: unmuted, newestFirst: true)!
          .window;
      expect(
        next.advance(message(1, 2), muted: unmuted, newestFirst: true),
        isNull,
      );
    },
  );

  test('channels, DMs and threads keep the same scope and preview rules', () {
    for (final kind in ['channel', 'dm', 'thread']) {
      final original = ActivityRowWindow.from([row(1, kind: kind), row(2)]);
      final next = original.advance(
        message(1, 2),
        muted: unmuted,
        newestFirst: true,
      )!;
      expect(next.key, '$kind:c1');
      expect(next.row['unreadCount'], 1);
      expect(next.row['kind'], kind);
      expect(
        next.row[kind == 'thread'
            ? 'latestActivityMessageId'
            : 'lastMessageId'],
        'm2',
      );
    }
    final action = {'kind': 'mention_action', 'id': 'a1', 'channelId': 'c1'};
    expect(
      ActivityRowWindow.from([action])
          .advance(message(1, 2), muted: unmuted, newestFirst: true),
      isNull,
    );
  });

  test(
    'duplicate identities stay unkeyed and preserve first eligible update',
    () {
      final first = {...row(1), 'latestActivitySeq': '20'};
      final second = row(1);
      final original = ActivityRowWindow.from([first, row(2), second]);
      expect(original.rowKeys.uniqueIndexOf('channel:c1'), isNull);
      final next = original.advance(
        message(1, 2),
        muted: unmuted,
        newestFirst: true,
      )!;
      expect(next.window.first['lastMessageId'], 'm2');
      expect(next.window[1], same(first));
      expect(next.window.rowKeys.uniqueIndexOf('channel:c1'), isNull);
      final accepted = original.replaceKey(next.key, next.row);
      expect(accepted[0], same(next.row));
      expect(accepted[1], same(original[1]));
      expect(accepted[2], same(next.row));
      expect(original[2], same(second));
    },
  );

  test('retained pointer order resolves fresh content without reordering', () {
    final original = ActivityRowWindow.from([row(1), row(2), row(3)]);
    final next = original
        .advance(message(3, 2), muted: unmuted, newestFirst: true)!
        .window;
    final retained = next.retaining(original);
    expect(retained.rowKeys, same(original.rowKeys));
    expect(retained.map((r) => r['channelId']), ['c1', 'c2', 'c3']);
    expect(retained.last['lastMessageId'], 'm2');
    expect(original.last['lastMessageId'], 'old3');
    final removed = ActivityRowWindow.from([next.first, next[1]])
        .retaining(original);
    expect(removed[1], same(original[1]));
  });

  test(
    'new accepted membership rebuilds indexes without reviving removed rows',
    () {
      final original = ActivityRowWindow.from([row(1), row(2)]);
      final narrowed = ActivityRowWindow.from([original[1]]);
      expect(narrowed.rowKeys.uniqueIndexOf('channel:c1'), isNull);
      expect(narrowed.rowKeys.uniqueIndexOf('channel:c2'), 0);
      expect(
        narrowed.advance(message(1, 2), muted: unmuted, newestFirst: true),
        isNull,
      );
      expect(ActivityRowWindow.from(narrowed), same(narrowed));
      expect(ActivityRowWindow.from([]).rowKeys, isEmpty);
    },
  );
}
