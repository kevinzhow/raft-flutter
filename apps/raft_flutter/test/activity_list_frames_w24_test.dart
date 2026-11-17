import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/features/resource_view.dart';

import 'support/activity_list_harness.dart';

/// What a shown row is, frame to frame: where it is and what it reads.
class _Shot {
  _Shot(WidgetTester t, String key)
    : rect = t.getRect(find.byKey(ValueKey(key))),
      texts = [
        for (final e in find
            .descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text))
            .evaluate())
          (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
      ];
  final Rect rect;
  final List<String> texts;
  @override
  bool operator ==(Object other) =>
      other is _Shot && other.rect == rect && _same(other.texts, texts);
  @override
  int get hashCode => rect.hashCode;
  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((e) => e);
}

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;

  setUp(() {
    final (c, base) = activityFixture();
    client = c;
    w = base
      ..inbox = [
        for (var i = 0; i < 8; i++) dayRow(i, day: 12 - i ~/ 4, unread: i == 1 ? 2 : 0),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  for (final env in [desktop, phoneTouch, foldA, foldB]) {
    for (final dark in [false, true]) {
      final label = '${env.name} ${dark ? 'dark' : 'light'}';
      testWidgets('[$label] switching the filter and back leaves the rows as they were', (t) async {
        final dynamic state = await mountActivity(t, w, env, dark: dark);
        final keys = ['activity-channel-ch0', 'activity-channel-ch1', 'activity-channel-ch5'];
        final before = {for (final k in keys) k: _Shot(t, k)};
        state.chooseActivityFilter(ActivityFilterChoice.unread);
        await t.pumpAndSettle();
        state.chooseActivityFilter(ActivityFilterChoice.all);
        for (var frame = 0; frame < 4; frame++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        await t.pumpAndSettle();
        for (final k in keys) {
          expect(_Shot(t, k), before[k], reason: k);
        }
      });

      testWidgets('[$label] a live event on another row leaves every shown row unchanged each frame', (t) async {
        await mountActivity(t, w, env, dark: dark);
        final keys = ['activity-channel-ch1', 'activity-channel-ch2', 'activity-channel-ch3'];
        final before = {for (final k in keys) k: _Shot(t, k)};
        final elements = {
          for (final k in keys) k: t.element(find.byKey(ValueKey(k))),
        };
        w.inbox[0] = {
          ...w.inbox[0],
          'lastMessagePreview': 'A newer line',
          'latestActivitySeq': '4000',
        };
        client.emit('message:new', {
          'id': 'live1',
          'channelId': 'ch0',
          'seq': 4000,
          'content': 'A newer line',
          'senderId': 'carol',
          'senderType': 'user',
          'senderName': 'Carol',
          'createdAt': '2026-10-12T14:00:00Z',
        });
        for (var frame = 0; frame < 8; frame++) {
          await t.pump(const Duration(milliseconds: 16));
          for (final k in keys) {
            final now = t.element(find.byKey(ValueKey(k)));
            expect(identical(now, elements[k]), isTrue, reason: '$k element');
            expect(_Shot(t, k), before[k], reason: '$k frame $frame');
          }
        }
        await t.pumpAndSettle();
        for (final k in keys) {
          expect(_Shot(t, k), before[k], reason: '$k settled');
        }
      });
    }
  }
}
