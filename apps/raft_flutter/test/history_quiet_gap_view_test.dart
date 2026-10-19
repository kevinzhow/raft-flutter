import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/features/message_history_gaps.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_gap_repair_test.dart' show RepairGapClient, seedImportedGap;
import 'history_memory_test.dart' show receiver, row;
import 'history_memory_viewport_test.dart' show drainIo;
import 'support/history_gap_view_cleanup.dart';

class _Client extends RepairGapClient {
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async => dm
      ? []
      : [
          RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
        ];
  bool seeded = false;
  int failures = 0;
  bool denied = false;
  Completer<void>? pending;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (before == null && seeded && !offline) {
      return {
        'messages': [
          for (var n = 2; n <= 50; n++) row(id, n * 10),
          row(id, 900),
        ],
        'historyLimited': false,
      };
    }
    if (before == null) {
      return super.messagePage(id, limit: limit, after: after);
    }
    beforeReads.add(before);
    if (!beforeArrived.isCompleted) beforeArrived.complete();
    await pending?.future;
    if (offline) throw StateError('Synthetic offline');
    if (denied) throw const RaftApiException('Unauthorized', status: 401);
    if (failures > 0) {
      failures--;
      throw const RaftApiException('Unavailable', status: 503);
    }
    return {
      'messages': [
        for (var n = before.toInt() > 900 ? 2 : 1; n <= 50; n++)
          row(id, n * 10),
        if (before.toInt() > 900) row(id, 900),
      ],
      'historyLimited': false,
    };
  }
}

void main() {
  for (final mode in ['pending', 'offline', 'retry exhausted', 'sign in']) {
    testWidgets('gap stays quiet until actionable failure: $mode', (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(900, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final directory = (await t.runAsync(
        () => Directory.systemTemp.createTemp('raft-quiet-gap-'),
      ))!;
      final file = File.fromUri(directory.uri.resolve('history.sqlite'));
      var (db, client, w) = (await t.runAsync(() async {
        final db = DriftWorkspaceCache(NativeDatabase(file));
        final client = _Client();
        final w = receiver(client, db);
        await seedImportedGap(db, w);
        client.seeded = true;
        client.offline = mode == 'offline';
        client.denied = mode == 'sign in';
        client.failures = mode == 'retry exhausted' ? 3 : 0;
        if (mode == 'pending') client.pending = Completer<void>();
        w.connected = !client.offline;
        return (db, client, w);
      }))!;
      final notice = find.byType(HistoryGapNotice);
      final retry = find.descendant(of: notice, matching: find.text('Retry'));
      void quiet() {
        expect(
          find.descendant(of: notice, matching: find.byType(Text)),
          findsNothing,
        );
        expect(retry, findsNothing);
      }

      Future<void> settleIo() async {
        await drainIo(t, db.messageHistory.reads.settled);
        await t.pumpAndSettle();
      }

      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await drainIo(t, client.beforeArrived.future);
        if (mode != 'pending') await settleIo();
        final dynamic state = t.state(find.byType(RaftChatView));
        state.recenter(
          first: 'chat-900',
          alignment: RaftTimelineAlignment.start,
        );
        await t.pumpAndSettle();
        state.viewport.jumpTo(200.0);
        await t.pumpAndSettle();
        expect(notice, findsOneWidget);
        if (mode != 'sign in') quiet();
        if (mode == 'retry exhausted') {
          await t.pump(const Duration(seconds: 2));
          await settleIo();
          expect(client.beforeReads, hasLength(2));
          quiet();
          await t.pump(const Duration(seconds: 4));
          await settleIo();
        }
        if (mode == 'retry exhausted' || mode == 'sign in') {
          expect(retry, findsOneWidget);
          expect(
            find.descendant(of: notice, matching: find.byType(Text)),
            findsNWidgets(2),
          );
          final attempts = client.beforeReads.length;
          await t.pump(const Duration(minutes: 2));
          await settleIo();
          expect(client.beforeReads, hasLength(attempts));
          if (mode == 'retry exhausted') {
            client.offline = true;
            client.arrivals.add(const RaftEvent('disconnected', null));
            await settleIo();
            quiet();
            w.connected = true;
            w.notifyListeners();
            await settleIo();
            expect(retry, findsOneWidget);
            client.offline = false;
          }
          client.denied = false;
          await t.tap(retry);
        } else if (mode == 'offline') {
          expect(
            find.descendant(of: notice, matching: find.byType(RaftSpinner)),
            findsNothing,
          );
          client.offline = false;
          w.connected = true;
          client.arrivals.add(const RaftEvent('rooms:joined', null));
        } else {
          expect(
            find.descendant(of: notice, matching: find.byType(RaftSpinner)),
            findsOneWidget,
          );
          client.pending!.complete();
        }
        await settleIo();
        expect(notice, findsNothing);
        expect(w.error, isNull);
        await closeGapView(t, w, client, db);
        final reopened = (await t.runAsync(() async {
          final db = DriftWorkspaceCache(NativeDatabase(file));
          final client = _Client()
            ..offline = true
            ..seeded = true;
          final w = receiver(client, db);
          await w.selectChannel(w.channels.single, autoRead: false);
          return (db, client, w);
        }))!;
        (db, client, w) = reopened;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await settleIo();
        expect(notice, findsNothing);
        expect(
          w.messageDomain.messages.map((row) => row.id),
          contains('chat-900'),
        );
        expect(
          await drainIo(
            t,
            db.messageHistory.readContext(
              MessageHistoryPages.scope(w, 'chat')!,
              'chat-500',
              radius: 0,
            ),
          ),
          isNotNull,
        );
        expect(client.beforeReads, isEmpty);
        expect(t.takeException(), isNull);
      } finally {
        if (client.pending case final pending? when !pending.isCompleted) {
          pending.complete();
        }
        await closeGapView(t, w, client, db);
        await t.runAsync(() => directory.delete(recursive: true));
      }
    });
  }
}
