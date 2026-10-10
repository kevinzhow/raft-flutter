import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows;
import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// A channel or thread whose older pages wait for [older] completions.
Future<(WorkspaceController, List<Completer<void>>)> historyFixture(
  WidgetTester tester, {
  required bool thread,
  int total = 1000,
  int first = 50,
  bool short = false,
}) async {
  final (w, api) = (await tester.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  w.ledger.switchServer('s1');
  final scopeId = thread ? 'th' : 'c1';
  final rows = [
    for (final r in contextRows('h', count: total))
      {...r, 'channelId': scopeId, if (short) 'content': 'Row ${r['id']}'},
  ];
  final older = <Completer<void>>[];
  route(api, scopeId, rows, first, older);
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
  return (w, older);
}

void route(
  MessageAdapter api,
  String scopeId,
  List<Map<String, dynamic>> rows,
  int first,
  List<Completer<void>> older,
) {
  api.routes['GET /messages/channel/$scopeId'] = (request) {
    final before = int.tryParse('${request.queryParameters['before']}');
    if (before == null) return {'messages': rows.sublist(rows.length - first)};
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
}

/// Lets the oldest pending page land and the timeline settle.
Future<void> land(
  WidgetTester tester,
  WorkspaceController w,
  List<Completer<void>> older, {
  required bool thread,
}) async {
  int count() => thread ? w.replies.length : w.messages.length;
  final before = count();
  older.firstWhere((c) => !c.isCompleted).complete();
  for (var i = 0; i < 200 && (count() == before || w.loadingOlder); i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(count(), before + 50);
  expect(w.loadingOlder, isFalse);
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> idle(WidgetTester tester, [int frames = 60]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
}

/// Older history loads one page per reach of the top region (Web: one top
/// sentinel intersection per page): a landed page, layout or metrics change
/// never requests the next page; only the user moving toward older again.
void main() {
  for (final thread in [false, true]) {
    final name = thread ? 'thread' : 'channel';
    testWidgets('$name: one older page per user reach of the top', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      // A tall window: each 50-row page is shorter than the prefetch region,
      // so the reader is still inside it when a page lands.
      tester.view.physicalSize = const Size(1280, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, older) = await historyFixture(
        tester,
        thread: thread,
        short: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftChatView(controller: w, thread: thread),
          ),
        ),
      );
      await idle(tester, 30);
      final dynamic state = tester.state(find.byType(RaftChatView));
      final ScrollController scroll = state.viewport;
      // Opening never requests history by itself.
      expect(older, isEmpty);

      Future<void> reach() async {
        final start = older.length;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(RaftChatView)),
        );
        for (var k = 0; k < 40 && older.length == start; k++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Keep moving within the region while the page is in flight.
        for (var k = 0; k < 5; k++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.moveBy(Offset.zero);
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        expect(older.length, start + 1, reason: 'one page per reach');
      }

      for (var page = 1; page <= 3; page++) {
        await reach();
        await idle(tester);
        expect(older.length, page);
        await land(tester, w, older, thread: thread);
        final position = scroll.position;
        // Still inside the prefetch region: the landed page alone must not
        // request the next one.
        expect(position.extentBefore, lessThan(position.viewportDimension * 2));
        await idle(tester);
        expect(older.length, page, reason: 'a landed page requested more');
        // Programmatic moves (jumps, alignment) are not the user reaching.
        scroll.jumpTo(position.minScrollExtent);
        await idle(tester, 20);
        expect(older.length, page, reason: 'a jump requested more');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('$name: holding at the top while a page lands requests '
        'nothing more', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, older) = await historyFixture(tester, thread: thread);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftChatView(controller: w, thread: thread),
          ),
        ),
      );
      await idle(tester, 30);
      final dynamic state = tester.state(find.byType(RaftChatView));
      final ScrollController scroll = state.viewport;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RaftChatView)),
      );
      // Drag to the temporary top and keep pulling there.
      for (var k = 0; k < 400; k++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 16));
        if (scroll.position.pixels <= scroll.position.minScrollExtent) break;
      }
      expect(older, hasLength(1));
      await land(tester, w, older, thread: thread);
      // The finger is still down; the page went above the reader.
      for (var k = 0; k < 20; k++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(older, hasLength(1));
      // Moving toward older again within the region requests the next one
      // only when the reader reaches the region again.
      for (var k = 0; k < 400 && older.length == 1; k++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(older, hasLength(2));
      await gesture.up();
      await idle(tester, 30);
      expect(older, hasLength(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
