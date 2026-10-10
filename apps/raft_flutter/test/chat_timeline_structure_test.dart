import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/message_scroll_performance_test.dart'
    show longMessage;
import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

/// The two-sided timeline keeps every row it has shown at a fixed scroll
/// coordinate while older history lands: a row's screen position changes only
/// by the reader's own scrolling (screen top + scroll pixels is invariant).
class _Invariant {
  _Invariant(this.tester, this.scroll);
  final WidgetTester tester;
  final ScrollController scroll;
  final seen = <String, double>{};
  final log = <String>[];
  var bad = 0;

  void check(String label) {
    final pixels = scroll.position.pixels;
    for (final element in find.byType(RaftMessageTile).evaluate()) {
      final key = element.widget.key;
      if (key is! ValueKey<String>) continue;
      final id = key.value.substring('message-'.length);
      final rect = paintedMessage(tester, id);
      if (rect == null) continue;
      final value = rect.top + pixels;
      final before = seen[id];
      if (before != null && (value - before).abs() > .5) {
        bad++;
        log.add('$label $id moved ${(value - before).toStringAsFixed(1)}');
      }
      seen[id] = value;
    }
  }
}

Future<(WorkspaceController, List<Completer<void>>, ScrollController)> _open(
  WidgetTester tester, {
  required bool thread,
  int count = 400,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (w, api) = (await tester.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  w.ledger.switchServer('s1');
  final scopeId = thread ? 'th' : 'c1';
  final rows = [
    for (final r in contextRows('h', count: count))
      {
        ...r,
        'channelId': scopeId,
        'content': int.parse((r['id'] as String).substring(2)) % 3 == 0
            ? longMessage(int.parse((r['id'] as String).substring(2)))
            : r['content'],
      },
  ];
  final older = <Completer<void>>[];
  api.routes['GET /messages/channel/$scopeId'] = (request) {
    final before = int.tryParse('${request.queryParameters['before']}');
    if (before == null) return {'messages': rows.sublist(count - 50)};
    final end = before - 1, start = (end - 50).clamp(0, end);
    final page = Completer<void>();
    older.add(page);
    return page.future.then((_) => {'messages': rows.sublist(start, end)});
  };
  api.routes['GET /messages/context/parent'] = (_) => {
    'messages': [
      {
        'id': 'parent',
        'channelId': 'c1',
        'seq': '1',
        'senderId': 'bob',
        'content': 'parent',
      },
    ],
  };
  api.routes['POST /channels/$scopeId/read'] = (_) => {};
  await tester.runAsync(() async {
    if (thread) {
      await w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 'th',
        navigate: false,
      );
    } else {
      await w.selectChannel(w.channel!, navigate: false);
    }
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: RaftChatView(controller: w, thread: thread),
      ),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final dynamic state = tester.state(find.byType(RaftChatView));
  return (w, older, state.viewport as ScrollController);
}

Future<void> _land(WidgetTester tester, Completer<void> page) =>
    tester.runAsync(() async {
      page.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

void main() {
  for (final thread in [false, true]) {
    final scope = thread ? 'thread' : 'channel';

    testWidgets('$scope: several older pages landing during one long drag '
        'never move a shown row', (tester) async {
      final (w, older, scroll) = await _open(tester, thread: thread);
      final invariant = _Invariant(tester, scroll)..check('open');
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RaftChatView)),
      );
      var landed = 0, unfollowed = 0;
      // The content follows the finger exactly: 60px per move.
      Future<void> move(String label) async {
        final before = scroll.position.pixels;
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 16));
        final moved = before - scroll.position.pixels;
        if ((moved - 60).abs() > .5) {
          unfollowed++;
          invariant.log.add('$label moved $moved');
        }
        invariant.check(label);
      }

      // Past the touch slop first.
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      for (var step = 0; step < 900 && landed < 3; step++) {
        await move('drag $step');
        final pending = older.where((page) => !page.isCompleted).toList();
        if (pending.isNotEmpty) {
          // Lands within the drag, one frame after it was requested.
          await _land(tester, pending.first);
          landed++;
          await move('landed $landed');
        } else {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
        }
      }
      await gesture.up();
      expect(
        landed,
        3,
        reason: 'messages=${w.timeline(thread: thread).length}',
      );
      expect(w.timeline(thread: thread).length, 200);
      expect(invariant.bad, 0, reason: invariant.log.take(30).join('\n'));
      expect(unfollowed, 0, reason: invariant.log.take(30).join('\n'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      '$scope: an older page landing during a fling never moves a shown row',
      (tester) async {
        final (w, older, scroll) = await _open(tester, thread: thread);
        final invariant = _Invariant(tester, scroll)..check('open');
        var landedWhileFlinging = 0;
        for (var fling = 0; fling < 12 && landedWhileFlinging < 2; fling++) {
          await tester.fling(
            find.byType(RaftChatView),
            const Offset(0, 500),
            6000,
          );
          double? lastStep;
          for (var i = 0; i < 300; i++) {
            final before = scroll.position.pixels;
            await tester.pump(const Duration(milliseconds: 16));
            invariant.check('fling $fling/$i');
            // The fling decelerates smoothly through every landing.
            final step = scroll.position.pixels - before;
            if (i > 1 && lastStep != null && (step - lastStep).abs() > 40) {
              invariant
                ..bad += 1
                ..log.add('fling $fling/$i step $lastStep -> $step');
            }
            lastStep = step;
            final pending = older.where((page) => !page.isCompleted).toList();
            if (pending.isNotEmpty) {
              final coasting = scroll.position.isScrollingNotifier.value;
              await _land(tester, pending.first);
              if (coasting) landedWhileFlinging++;
            }
            if (!scroll.position.isScrollingNotifier.value) break;
          }
        }
        expect(landedWhileFlinging, greaterThan(0));
        expect(invariant.bad, 0, reason: invariant.log.take(30).join('\n'));
        expect(
          w.timeline(thread: thread).length,
          greaterThan(100),
          reason: 'history kept loading while flinging',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('$scope: the last older page landing while the reader rests '
        'at the temporary top goes above the reader', (tester) async {
      final (w, older, scroll) = await _open(tester, thread: thread, count: 80);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RaftChatView)),
      );
      for (var k = 0; k < 400; k++) {
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        if (older.isNotEmpty &&
            scroll.position.pixels <= scroll.position.minScrollExtent) {
          break;
        }
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(older, hasLength(1));
      expect(scroll.position.pixels, scroll.position.minScrollExtent);
      final invariant = _Invariant(tester, scroll)..check('parked');
      final top = scroll.position.pixels;
      await _land(tester, older.single);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        invariant.check('landed $i');
      }
      expect(w.timeline(thread: thread).length, 80);
      expect(scroll.position.pixels, top);
      expect(scroll.position.minScrollExtent, lessThan(top));
      expect(invariant.bad, 0, reason: invariant.log.take(30).join('\n'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('$scope: a live arrival at the latest end stays pinned there; '
        'within 100px of it the reader is brought to the end', (tester) async {
      final (w, _, scroll) = await _open(tester, thread: thread);
      final id = thread ? 'th' : 'c1';
      Future<void> arrive(String key, String content) =>
          tester.runAsync(() async {
            w.ledger.ingest([
              {
                'id': key,
                'channelId': id,
                'seq': '${900 + key.length}',
                'senderId': 'bob',
                'content': content,
              },
            ], expectedGeneration: w.ledger.generation);
            w.visibleIds[id]!.add(key);
            w.notifyListeners();
            await Future<void>.delayed(Duration.zero);
          });
      double distance() =>
          scroll.position.maxScrollExtent - scroll.position.pixels;
      expect(distance(), 0);
      await arrive('live-a', longMessage(1));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        // Pinned in the same layout: no frame shows the end below the edge.
        expect(distance(), 0);
      }
      expect(paintedMessage(tester, 'live-a'), isNotNull);
      scroll.jumpTo(scroll.position.maxScrollExtent - 60);
      await tester.pump();
      await arrive('live-bb', 'Second arrival');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(distance(), 0);
      expect(paintedMessage(tester, 'live-bb'), isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('channel: ensureVisible (focus traversal, accessibility) '
      'reveals a row at the requested edge', (tester) async {
    final (_, _, scroll) = await _open(tester, thread: false);
    // A row built in the cache area just above the viewport.
    final rows = find.byType(RaftMessageTile, skipOffstage: false);
    final above = rows.evaluate().firstWhere((element) {
      final box = element.renderObject as RenderBox;
      return box.localToGlobal(Offset.zero).dy < -10;
    });
    await tester.runAsync(() => Scrollable.ensureVisible(above, alignment: 0));
    await tester.pump();
    final view = tester.getRect(find.byType(RaftChatView));
    final box = above.renderObject as RenderBox;
    expect(box.localToGlobal(Offset.zero).dy, closeTo(view.top, .5));
    expect(scroll.position.outOfRange, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('sync of 500 unchanged rows reuses every projection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    api.routes['POST /channels/c1/read'] = (_) => {};
    w.ledger.switchServer('s1');
    final rows = contextRows('bench', count: 500);
    w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = rows.map((r) => r['id'] as String).toSet();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(RaftChatView));
    final window = state.adapter.messages as List;
    final revision = state.windowRevision as int;
    expect(window, hasLength(500));
    final clock = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      state.sync();
      await (state.updates as Future<void>);
    }
    clock.stop();
    // Unchanged rows: no new window, no new projection, no encoding.
    expect(identical(state.adapter.messages, window), isTrue);
    expect(state.windowRevision, revision);
    expect(
      clock.elapsedMicroseconds / 20,
      lessThan(25000),
      reason: 'debug-mode bound; profile builds are far below it',
    );
    // A changed row is the only new projection.
    final changed = Map<String, dynamic>.of(rows[250])..['content'] = 'edited';
    w.ledger.ingest([changed], expectedGeneration: w.ledger.generation);
    state.sync();
    await (state.updates as Future<void>);
    final next = state.adapter.messages as List;
    expect(state.windowRevision, revision + 1);
    for (var i = 0; i < 500; i++) {
      expect(identical(next[i], window[i]), i != 250, reason: 'row $i');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
