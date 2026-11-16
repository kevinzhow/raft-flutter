import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// "First frame is final": once a row is shown, a live event below it, a
/// rebuild with the same data and the pointer moving over other rows must not
/// move its avatar, author, badge, time or body, nor change its height.
/// A guard: it must pass before and after the row recipe changes.
const _author = ValueKey('message-author');

Widget _row(
  int i, {
  required bool continuation,
  RaftMessageFollowedBy? followedBy,
  Widget? metadata,
}) => RaftMessageRow(
  key: ValueKey('row-$i'),
  author: 'Alice $i',
  timestamp: '14:3$i',
  continuation: continuation,
  followedBy: followedBy,
  avatar: ColoredBox(key: ValueKey('avatar-$i'), color: Colors.blue),
  metadata: metadata,
  content: Text('Body $i', key: ValueKey('body-$i')),
  toolbar: RaftMessageToolbar(
    children: [
      RaftMessageToolbarAction(
        label: 'Reply',
        icon: const SizedBox(),
        onPressed: () {},
      ),
    ],
  ),
);

List<Widget> _rows(int count) => [
  _row(
    0,
    continuation: false,
    followedBy: RaftMessageFollowedBy.compact,
    metadata: const SizedBox(key: ValueKey('badge-0'), width: 36, height: 16),
  ),
  _row(
    1,
    continuation: true,
    followedBy: count > 3 ? RaftMessageFollowedBy.group : null,
  ),
  _row(
    2,
    continuation: false,
    followedBy: count > 3 ? RaftMessageFollowedBy.group : null,
    metadata: const Text('sent by Bob', key: ValueKey('badge-2')),
  ),
  if (count > 3) _row(3, continuation: false),
].sublist(0, count);

Map<String, Rect> _snapshot(WidgetTester t, Iterable<int> rows) {
  final out = <String, Rect>{};
  for (final i in rows) {
    final row = find.byKey(ValueKey('row-$i'));
    out['row-$i'] = t.getRect(row);
    for (final key in ['avatar-$i', 'body-$i', 'badge-$i']) {
      final f = find.byKey(ValueKey(key));
      if (f.evaluate().isNotEmpty) out[key] = t.getRect(f);
    }
    final author = find.descendant(of: row, matching: find.byKey(_author));
    if (author.evaluate().isNotEmpty)
      out['author-$i'] = t.getRect(author.first);
    final time = find.descendant(of: row, matching: find.text('14:3$i'));
    if (time.evaluate().isNotEmpty && !_isContinuation(i))
      out['time-$i'] = t.getRect(time.first);
  }
  return out;
}

bool _isContinuation(int i) => i == 1;

void _same(Map<String, Rect> before, Map<String, Rect> after, String step) {
  for (final entry in before.entries) {
    expect(after[entry.key], entry.value, reason: '$step: ${entry.key} moved');
  }
}

void main() {
  testWidgets(
    'shown rows do not move on frames, a live row below, rebuilds or hover',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late StateSetter update;
      var count = 3;
      var epoch = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: false),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SingleChildScrollView(
                  child: Column(
                    key: ValueKey('epoch-$epoch'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _rows(count),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final first = _snapshot(tester, [0, 1, 2]);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        _same(first, _snapshot(tester, [0, 1, 2]), 'frame $frame');
      }
      // Live event: a new row appended below; row 2 now has a follower.
      update(() => count = 4);
      await tester.pump();
      final shown = _snapshot(tester, [0, 1]);
      _same(
        {
          for (final e in first.entries)
            if (!e.key.endsWith('2')) e.key: e.value,
        },
        shown,
        'live row',
      );
      final row2Before = first['row-2']!;
      expect(
        tester.getRect(find.byKey(const ValueKey('row-2'))).top,
        row2Before.top,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('row-2'))).height,
        row2Before.height,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('body-2'))),
        first['body-2'],
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('avatar-2'))),
        first['avatar-2'],
      );
      final withLive = _snapshot(tester, [0, 1, 2]);
      // Rebuild with the same data (new widget instances, same keys).
      update(() => epoch++);
      await tester.pump();
      _same(withLive, _snapshot(tester, [0, 1, 2]), 'rebuild');
      update(() {});
      await tester.pump();
      _same(withLive, _snapshot(tester, [0, 1, 2]), 'rebuild again');
      // Hover another row, then each row itself.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      for (final over in [3, 2, 1, 0]) {
        final c = tester.getCenter(find.byKey(ValueKey('row-$over')));
        await mouse.moveTo(c + const Offset(10, 0));
        await mouse.moveTo(c);
        await tester.pump();
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          _same(withLive, _snapshot(tester, [0, 1, 2]), 'hover row $over');
        }
      }
    },
  );
}
