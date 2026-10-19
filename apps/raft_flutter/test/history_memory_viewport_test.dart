import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history_memory.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_memory_test.dart' show HistoryClient, receiver;

Future<T> drainIo<T>(WidgetTester tester, Future<T> work) async {
  var done = false;
  T? result;
  Object? failure;
  StackTrace? stack;
  work.then(
    (value) {
      result = value;
      done = true;
    },
    onError: (Object error, StackTrace trace) {
      failure = error;
      stack = trace;
      done = true;
    },
  );
  final watch = Stopwatch()..start();
  while (!done && watch.elapsed < const Duration(seconds: 10)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 5));
  }
  if (!done) throw TimeoutException('History test I/O did not settle');
  if (failure != null) Error.throwWithStackTrace(failure!, stack!);
  return result as T;
}

void main() {
  testWidgets(
    'releasing a distant timeline center keeps the visible row at its measured top',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (db, client, w) = (await tester.runAsync(() async {
        final db = DriftWorkspaceCache(NativeDatabase.memory()),
            client = HistoryClient();
        final w = receiver(client, db);
        db.messageHistory.memory.unregister(w);
        return (db, client, w);
      }))!;
      try {
        await tester.runAsync(() async {
          await w.selectChannel(w.channels.single, autoRead: false);
          for (var n = 0; n < 19; n++) {
            await w.messageDomain.older();
          }
          await w.flushCache();
        });
        expect(w.messageDomain.messages, hasLength(1000));
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(RaftChatView));
        state.recenter(
          first: 'chat-500',
          alignment: RaftTimelineAlignment.start,
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('current-timeline')),
          const Offset(0, -40),
        );
        await tester.pumpAndSettle();
        state.timelineScrolled();
        state.saveReadingAnchor();
        final anchor = w.messageWindows.readingAnchor('chat')!;
        final row = find.byKey(
          ValueKey('message-wrapper-${anchor.messageKey}'),
        );
        expect(row, findsOneWidget);
        final before = tester.getRect(row);
        MessageHistoryMemory.cancelSample(w, state);
        MessageHistoryMemory.attach(w, db.messageHistory);
        await drainIo(tester, db.messageHistory.memory.maintain());
        await tester.pumpAndSettle();
        expect(w.messageDomain.messages.length, lessThanOrEqualTo(500));
        expect(tester.getRect(row).top, closeTo(before.top, 1));
        for (var n = 0; n < 6; n++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(row).top, closeTo(before.top, 1));
        }
        expect(state.adapter.messages.length, lessThanOrEqualTo(500));
        expect(state.retiredAdapters, isEmpty);
        expect(state.retiredViewports, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await drainIo(tester, w.flushCache());
        w.dispose();
        await drainIo(tester, client.arrivals.close());
        await drainIo(tester, db.close());
      }
    },
  );
}
