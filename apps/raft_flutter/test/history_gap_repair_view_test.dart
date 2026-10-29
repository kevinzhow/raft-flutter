import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_gap_repair_test.dart' show RepairGapClient, seedImportedGap;
import 'history_memory_test.dart' show receiver, row;
import 'history_memory_viewport_test.dart' show drainIo;

void main() {
  for (final empty in [false, true]) {
    testWidgets(
      'automatic gap status clears after ${empty ? 'empty' : 'duplicate-only'} response and stays clear offline after reopening',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(900, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (directory, file, initialDb, initialClient, initialW) = (await t
            .runAsync(() async {
              final directory = await Directory.systemTemp.createTemp(
                'raft-gap-view-',
              );
              final file = File('${directory.path}/history.sqlite');
              final db = DriftWorkspaceCache(NativeDatabase(file));
              final client = RepairGapClient(empty: empty),
                  w = receiver(client, db);
              await seedImportedGap(db, w);
              return (directory, file, db, client, w);
            }))!;
        var db = initialDb, client = initialClient, w = initialW;
        var opened = true;
        Future<void> mount() async {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              home: Scaffold(body: RaftChatView(controller: w)),
            ),
          );
          await drainIo(t, w.flushCache());
          await t.pumpAndSettle();
        }

        Future<void> close() async {
          if (!opened) return;
          opened = false;
          await t.pumpWidget(const SizedBox());
          await drainIo(t, w.flushCache());
          w.dispose();
          await drainIo(t, client.arrivals.close());
          await drainIo(t, db.close());
        }

        try {
          await mount();
          expect(find.text('Load this gap'), findsNothing);
          final loaded = Completer<void>();
          void finished() {
            if (!w.messageDomain.state.loadingOlder &&
                client.beforeReads.isNotEmpty &&
                !loaded.isCompleted) {
              loaded.complete();
            }
          }

          w.addListener(finished);
          try {
            await drainIo(t, client.beforeArrived.future);
            expect(find.text('Loading missing messages…'), findsNothing);
            if (empty) {
              client.arrivals.add(
                RaftEvent('message:updated', {
                  ...row('chat', 500),
                  'content': 'Current socket version',
                }),
              );
              await drainIo(t, db.messageHistory.receiver.settled);
            }
            client.release.complete();
            await drainIo(t, loaded.future);
            await drainIo(t, w.flushCache());
            await t.pumpAndSettle();
            expect(client.beforeReads, [BigInt.from(900)]);
            expect(w.error, isNull);
            expect(
              w.messageDomain.messages.map((m) => m.id),
              containsAll(['chat-500', 'chat-900']),
            );
            if (empty) {
              expect(w.messageDomain.messages.map((m) => m.id), [
                'chat-500',
                'chat-900',
              ]);
            }
            expect(
              find.byKey(const ValueKey('message-history-gap')),
              findsNothing,
            );
          } finally {
            w.removeListener(finished);
            if (!client.release.isCompleted) client.release.complete();
          }
          await close();
          final reopened = (await t.runAsync(() async {
            final db = DriftWorkspaceCache(NativeDatabase(file));
            final client = RepairGapClient(empty: empty)..offline = true;
            final w = receiver(client, db);
            await w.selectChannel(w.channels.single, autoRead: false);
            return (db, client, w);
          }))!;
          (db, client, w) = reopened;
          opened = true;
          await mount();
          expect(
            w.messageDomain.messages.map((m) => m.id),
            containsAll(['chat-500', 'chat-900']),
          );
          expect(
            find.byKey(const ValueKey('message-history-gap')),
            findsNothing,
          );
          expect(client.beforeReads, isEmpty);
          expect(t.takeException(), isNull);
        } finally {
          if (!client.release.isCompleted) client.release.complete();
          await close();
          await t.runAsync(() => directory.delete(recursive: true));
        }
      },
    );
  }
}
