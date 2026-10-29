import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/data/history_gap_recovery.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_gaps_test.dart' show GapClient, seedGap;
import 'history_memory_test.dart' show receiver;

class _Client extends GapClient {
  void Function(BigInt)? beforeRequest;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) {
    if (before != null) beforeRequest?.call(before);
    return super.messagePage(id, limit: limit, before: before, after: after);
  }
}

void main() {
  for (final hard in [false, true]) {
    test(
      '800-row automatic gap completes after its RAM frontier is released, hard=$hard',
      () async {
        // Initial: saved 1–100 and 901–950, a presented conversation without UI.
        // Event: release the first new frontier (851) from RAM before its next
        // page; optionally decline all new disk bodies at the hard limit.
        // Expected: all 16 pages finish once, using durable or transient proof.
        var free = 2 << 30;
        final db = DriftWorkspaceCache(
          NativeDatabase.memory(),
          historyAvailableSpace: (_) async => free,
        );
        final client = _Client()..gate = Completer<void>();
        final w = receiver(client, db);
        final recovery = HistoryGapRecovery.of(w, false), owner = Object();
        var started = false, released = false, observedAbsent = false;
        void releaseFrontier() {
          if (!released &&
              !w.messageDomain.state.loadingOlder &&
              w.messageDomain.ledger.message('chat', 'chat-851') != null) {
            released = true;
            w.messageDomain.ledger.remove('chat', 'chat-851');
            w.messageDomain.visibleIds['chat']?.remove('chat-851');
          }
        }

        try {
          final scope = MessageHistoryPages.scope(w, 'chat')!;
          await seedGap(db, scope);
          await w.selectChannel(w.channels.single, autoRead: false);
          await w.messageDomain.older();
          expect(w.messageDomain.messageWindow?.visible, isTrue);
          if (hard) free = 512 << 20;
          client.beforeRequest = (before) {
            if (before == BigInt.from(851)) {
              observedAbsent =
                  w.messageDomain.ledger.message('chat', 'chat-851') == null;
            }
          };
          w.addListener(releaseFrontier);
          recovery.start(owner);
          started = true;
          await client.beforeArrived.future;
          client.gate!.complete();
          await db.messageHistory.reads.settled;
          expect(released, isTrue);
          expect(observedAbsent, isTrue);
          expect(client.beforeReads, [
            for (var before = 901; before >= 151; before -= 50)
              BigInt.from(before),
          ]);
          expect(recovery.contains('chat-901'), isFalse);
          final saved = await db.messageHistory.readContext(
            scope,
            'chat-851',
            radius: 0,
          );
          if (hard) {
            expect(saved, isNull);
            expect(
              (await db.messageHistory.capacity.usage(
                HistoryAccount(w.client.origin, w.client.user!.id),
              )).hardFull,
              isTrue,
            );
          } else {
            expect(saved, isNotNull);
            expect(
              await db.messageHistory.gaps.read(scope, [
                ('chat-100', BigInt.from(100)),
                ('chat-901', BigInt.from(901)),
              ]),
              isEmpty,
            );
          }
          expect(w.error, isNull);
        } finally {
          if (!client.gate!.isCompleted) client.gate!.complete();
          w.removeListener(releaseFrontier);
          if (started) recovery.stop(owner);
          w.dispose();
          await db.messageHistory.reads.settled;
          await client.arrivals.close();
          await client.dispose();
          await db.close();
        }
      },
    );
  }
}
