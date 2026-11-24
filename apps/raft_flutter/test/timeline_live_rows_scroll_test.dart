// #373: rows that arrived after the channel opened live in the forward
// (center) sliver. Scrolling up through them mounts them above the reader;
// content the reader is looking at must follow the finger exactly, and a new
// message must not make it jump.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_flutter/features/timeline_row_hydration.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

const _long =
    'This is a longer message that wraps across several lines on a phone. '
    'It talks about the release, the scroll position and how the timeline '
    'should keep rows steady while new messages arrive from other people. ';

final _report = [
  '## Status report',
  for (var i = 0; i < 30; i++)
    '- item $i: the agent checked the build and found nothing unusual here',
  '',
  'See https://example.com/build/123 for details.',
].join('\n');

/// Rows of very different heights, so an estimated height is visibly wrong.
String _content(int i) => switch (i % 8) {
  0 => 'short $i',
  1 => '$_long$i',
  2 => List.filled(3, 'line $i').join('\n'),
  3 => '$_long$_long$i',
  4 => '**bold $i** and `code` and a list:\n\n- one\n- two\n- three',
  5 => '```\ncode block $i\nsecond line\nthird line\n```',
  6 => '$_report\n$i',
  _ => 'link [docs $i](https://example.com/docs/$i) and https://example.com/$i',
};

Map<String, dynamic> _row(int i, {String? sender}) {
  final from = sender ?? (i % 3 == 0 ? 'bob' : 'alice');
  return {
    'id': 'm-$i',
    'channelId': 'c1',
    'seq': '${i + 1}',
    'senderId': from,
    'senderName': from == 'bob' ? 'Bob' : 'Alice',
    'createdAt': DateTime.utc(
      2026,
      11,
      23,
      8,
    ).add(Duration(minutes: i * 7)).toIso8601String(),
    'content': _content(i),
  };
}

const _touch = Size(390, 844);
const _desktop = Size(1280, 800);

Future<WorkspaceController> _open(
  WidgetTester tester, {
  bool touch = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = touch ? _touch : _desktop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  w.messageDomain.ledger.switchServer('s1');
  final rows = [for (var i = 0; i < 120; i++) _row(i)];
  w.messageDomain.ledger.ingest(
    rows,
    expectedGeneration: w.messageDomain.ledger.generation,
  );
  w.messageDomain.visibleIds['c1'] = {for (final row in rows) row['id']};
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(
        platform: touch ? TargetPlatform.android : TargetPlatform.linux,
      ),
      home: Scaffold(
        body: RaftDensityScope(
          density: touch ? RaftDensity.touch : RaftDensity.desktop,
          child: RaftChatView(controller: w),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  return w;
}

/// Another participant sends message [i] while the channel is open.
void _arrive(WorkspaceController w, int i) {
  final row = _row(i, sender: 'bob');
  w.messageDomain.ledger.ingest([
    row,
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1']!.add(row['id'] as String);
  w.notifyListeners();
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(RaftMessageTimeline),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Offset _center(WidgetTester tester) =>
    tester.getCenter(find.byType(RaftMessageTimeline));

typedef _Row = ({double top, double height, bool preview});

/// Rows painted in the viewport, by message id.
Map<String, _Row> _visible(WidgetTester tester) {
  final view = tester.renderObject<RenderBox>(
    find
        .descendant(
          of: find.byType(RaftMessageTimeline),
          matching: find.byWidgetPredicate((w) => w is Viewport),
        )
        .first,
  );
  final clip = view.localToGlobal(Offset.zero) & view.size;
  final rows = <String, _Row>{};
  for (final element
      in find
          .byWidgetPredicate(
            (w) =>
                w is KeyedSubtree &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('m-'),
            skipOffstage: false,
          )
          .evaluate()) {
    final box = element.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.overlaps(clip)) continue;
    final id =
        ((element.widget as KeyedSubtree).key! as ValueKey<String>).value;
    final preview = find
        .descendant(
          of: find.byElementPredicate((e) => identical(e, element)),
          matching: find.byKey(ValueKey('$timelinePreviewKeyPrefix$id')),
          skipOffstage: false,
        )
        .evaluate()
        .isNotEmpty;
    rows[id] = (
      top: rect.top - clip.top,
      height: rect.height,
      preview: preview,
    );
  }
  return rows;
}

/// How far each built row that is visible in both [before] and [after], at
/// the same height, moved.
Map<String, double> _moves(Map<String, _Row> before, Map<String, _Row> after) =>
    {
      for (final MapEntry(key: id, value: row) in after.entries)
        if (before[id] case final old?
            when !old.preview &&
                !row.preview &&
                (old.height - row.height).abs() <= .5)
          id: row.top - old.top,
    };

String _describe(Map<String, double> moves) =>
    moves.map((id, d) => MapEntry(id, d.toStringAsFixed(1))).toString();

/// Follows the latest end through [count] arrivals, then drags up until the
/// first of them is mounted above the reader, and lifts without a fling.
Future<int> _readLiveRows(
  WidgetTester tester,
  WorkspaceController w, {
  int count = 15,
}) async {
  var next = 120;
  for (var k = 0; k < count; k++) {
    _arrive(w, next++);
    await tester.pumpAndSettle();
  }
  final gesture = await tester.startGesture(_center(tester));
  await gesture.moveBy(const Offset(0, 20));
  await tester.pump(const Duration(milliseconds: 16));
  final first = find.byKey(const ValueKey('m-120'), skipOffstage: false);
  var extra = 0;
  for (var step = 0; step < 200 && extra < 2; step++) {
    await gesture.moveBy(const Offset(0, 45));
    await tester.pump(const Duration(milliseconds: 16));
    if (first.evaluate().isNotEmpty) extra++;
  }
  expect(first, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
  return next;
}

void main() {
  testWidgets('a small drag after an arrival moves live rows with the finger', (
    tester,
  ) async {
    final w = await _open(tester);
    final position = _position(tester);
    final next = await _readLiveRows(tester, w);
    final distance = position.maxScrollExtent - position.pixels;
    final problems = <String>[];
    var before = _visible(tester);
    _arrive(w, next);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final rows = _visible(tester);
      final moves = _moves(before, rows);
      if (moves.values.any((d) => d.abs() > .5)) {
        problems.add('arrival frame $frame: ${_describe(moves)}');
      }
      before = rows;
    }
    await tester.pumpAndSettle();
    expect(
      position.maxScrollExtent - position.pixels,
      greaterThanOrEqualTo(distance - .5),
      reason: 'the reader was sent back down',
    );
    final gesture = await tester.startGesture(_center(tester));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
    for (var step = 0; step < 6; step++) {
      before = _visible(tester);
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
      final moves = _moves(before, _visible(tester));
      expect(moves, isNotEmpty);
      if (moves.values.any((d) => (d - 10).abs() > .5)) {
        problems.add('10px drag step $step: ${_describe(moves)}');
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(problems, isEmpty);
  });

  testWidgets('dragging up through live rows during arrivals follows the '
      'finger', (tester) async {
    final w = await _open(tester);
    var next = 120;
    for (var k = 0; k < 15; k++) {
      _arrive(w, next++);
      await tester.pumpAndSettle();
    }
    final gesture = await tester.startGesture(_center(tester));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
    final problems = <String>[];
    for (var step = 0; step < 70; step++) {
      final before = _visible(tester);
      // Another participant keeps talking while the reader scrolls up.
      if (step % 6 == 3) _arrive(w, next++);
      await gesture.moveBy(const Offset(0, 45));
      await tester.pump(const Duration(milliseconds: 16));
      final moves = _moves(before, _visible(tester));
      if (moves.values.any((d) => (d - 45).abs() > .5)) {
        problems.add('step $step: ${_describe(moves)}');
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(problems, isEmpty);
  });

  for (final touch in [true, false]) {
    final mode = touch ? 'touch' : 'desktop';

    testWidgets('[$mode] visible rows move rigidly through arrivals, drags '
        'and flings', (tester) async {
      final w = await _open(tester, touch: touch);
      final problems = <String>[];
      var previous = _visible(tester);
      var phase = '';
      double? expected;
      Future<void> frame() async {
        await tester.pump(const Duration(milliseconds: 16));
        final rows = _visible(tester);
        final moves = _moves(previous, rows);
        previous = rows;
        if (moves.isEmpty) return;
        final values = moves.values.toList()..sort();
        final want = expected;
        if (values.last - values.first > .5 ||
            (want != null && (values.first - want).abs() > .5)) {
          problems.add('$phase want=$want ${_describe(moves)}');
        }
      }

      var next = 120;
      phase = 'arrivals at the latest edge';
      for (var k = 0; k < 15; k++) {
        _arrive(w, next++);
        for (var f = 0; f < 6; f++) {
          await frame();
        }
      }
      for (var round = 0; round < 3; round++) {
        phase = 'drag up $round';
        final gesture = await tester.startGesture(_center(tester));
        await gesture.moveBy(const Offset(0, 20));
        expected = null;
        await frame();
        for (var step = 0; step < 50; step++) {
          if (step % 12 == 6) _arrive(w, next++);
          await gesture.moveBy(const Offset(0, 45));
          expected = 45;
          await frame();
        }
        await gesture.up();
        expected = null;
        phase = 'after drag $round';
        for (var f = 0; f < 60; f++) {
          await frame();
        }
        for (final (name, offset) in [
          ('fling up', const Offset(0, 400)),
          ('fling down', const Offset(0, -400)),
        ]) {
          phase = '$name $round';
          await tester.fling(
            find.byType(RaftMessageTimeline),
            offset,
            3000,
            warnIfMissed: false,
          );
          for (var f = 0; f < 90; f++) {
            if (f % 30 == 10) _arrive(w, next++);
            await frame();
          }
        }
      }
      expect(problems, isEmpty);
    });

    testWidgets('[$mode] an arrival at the latest edge keeps rows still', (
      tester,
    ) async {
      final w = await _open(tester, touch: touch);
      final position = _position(tester);
      final problems = <String>[];
      for (var k = 0; k < 3; k++) {
        final before = _visible(tester);
        _arrive(w, 120 + k);
        double? first;
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final rows = _visible(tester);
          if (rows.values.any((row) => row.preview)) {
            problems.add('arrival $k frame $frame shows a preview');
          }
          // The rows that were on screen all move up by one shift, the new
          // row's height, on its first frame and never again.
          final moves = _moves(before, rows);
          for (final d in moves.values) {
            first ??= d;
            if ((d - first).abs() > .5) {
              problems.add('arrival $k frame $frame: ${_describe(moves)}');
              break;
            }
          }
        }
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(position.maxScrollExtent, .5));
      }
      expect(problems, isEmpty);
    });
  }
}
