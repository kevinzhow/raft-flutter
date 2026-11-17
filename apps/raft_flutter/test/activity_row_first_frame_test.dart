import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/activity_card_row.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_object_row_test.dart' show objectRow;
import 'support/activity_row_harness.dart';

// AGENTS.md "first frame is final": a row that is on screen does not change
// from frame to frame when a live update reaches another row of the list. The
// author, face, title, badges and layout of the shown row are the same in every
// frame, and its state is kept (the same RaftInboxItem state, no rebuild of the
// tile).
class _Snapshot {
  _Snapshot(WidgetTester tester, Key key) {
    final row = find.byKey(key);
    state = tester.state(row);
    rect = tester.getRect(row);
    final item = tester.widget<RaftInboxItem>(row);
    label = item.semanticLabel;
    unread = item.unread;
    texts = [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: row, matching: find.byType(Text)),
      ))
        t.data ?? t.textSpan!.toPlainText(),
    ];
    leading = item.leading.runtimeType;
  }
  late final State state;
  late final Rect rect;
  late final String label;
  late final bool unread;
  late final List<String> texts;
  late final Type leading;

  void expectSame(_Snapshot other, String frame) {
    expect(identical(state, other.state), isTrue, reason: 'state at $frame');
    expect(rect, other.rect, reason: 'rect at $frame');
    expect(label, other.label, reason: 'name at $frame');
    expect(unread, other.unread, reason: 'unread at $frame');
    expect(texts, other.texts, reason: 'texts at $frame');
    expect(leading, other.leading, reason: 'leading at $frame');
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final (name, size, platform) in [
      rowEnvs[0],
      rowEnvs[2],
      rowEnvs[3],
      rowEnvs[4],
    ]) {
      testWidgets('${dark ? 'dark' : 'light'} $name: a live update to another row leaves a shown row unchanged', (
        tester,
      ) async {
        useFixedClock();
        final f = RowFixture(
          channels: [
            channelRecord('c1', 'launch-week'),
            channelRecord('c2', 'design'),
          ],
        );
        addTearDown(f.dispose);
        var rows = <Map<String, dynamic>>[
          threadRow(id: 't1', unread: 1, extra: {'hasMention': true}),
          channelRow(id: 'c2', name: 'design'),
          objectRow(unread: 2, preview: {'text': 'hi'}),
        ];
        late StateSetter set;
        await pumpRowApp(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return Column(
                children: [
                  for (final row in rows)
                    ActivityCardRow(
                      key: ValueKey(
                        row['kind'] == 'object'
                            ? 'o-${row['objectId']}'
                            : 'r-${row['threadChannelId'] ?? row['channelId']}',
                      ),
                      row: row,
                      host: f.host(),
                    ),
                ],
              );
            },
          ),
          size: size,
          platform: platform,
          dark: dark,
        );
        // The wrapper keys sit on the ActivityCardRow; read the row under it.
        Finder item(String key) => find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(RaftInboxItem),
        );
        Key inner(String key) => tester.widget<RaftInboxItem>(item(key)).key!;
        final keys = {
          for (final k in ['r-t1', 'r-c2', 'o-art1']) k: inner(k),
        };
        final before = {
          for (final e in keys.entries) e.key: _Snapshot(tester, e.value),
        };
        // A live update: the middle row (another conversation) gets a new
        // message and an unread count.
        set(() {
          rows = [
            rows[0],
            channelRow(
              id: 'c2',
              name: 'design',
              preview: 'A new message',
              unread: 4,
              sender: 'Carol',
              senderId: 'carol',
            ),
            rows[2],
          ];
        });
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (final k in ['r-t1', 'o-art1']) {
            before[k]!.expectSame(_Snapshot(tester, keys[k]!), 'frame $frame $k');
          }
        }
        // The updated row did change, and only it.
        expect(
          tester.widget<RaftInboxItem>(find.byKey(keys['r-c2']!)).semanticLabel,
          contains('A new message'),
        );
      });
    }
  }
}
