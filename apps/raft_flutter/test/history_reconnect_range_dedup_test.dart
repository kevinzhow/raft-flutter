import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_gap_recovery.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_gaps_test.dart' show GapClient, seedGap;
import 'history_memory_test.dart' show receiver, row;

class _ReconnectClient extends GapClient {
  bool disconnected = false;

  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async => dm
      ? []
      : [
          RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
        ];

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (disconnected && before != null) {
      beforeReads.add(before);
      if (!beforeArrived.isCompleted) beforeArrived.complete();
      throw StateError('Synthetic offline gap');
    }
    if (before == null) {
      return {
        'messages': [for (var n = 201; n <= 250; n++) row(id, n)],
        'historyLimited': false,
      };
    }
    return super.messagePage(id, limit: limit, before: before, after: after);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reconnect verification and visible gap request each range once', () async {
    // Initial: saved islands 1–100 and 201–250, with automatic repair offline.
    // Event: rooms are joined again, with no user retry.
    // Expected: both missing pages and older verification pages are fetched once.
    final db = DriftWorkspaceCache(NativeDatabase.memory());
    final client = _ReconnectClient(), w = receiver(client, db);
    final view = Object(), recovery = HistoryGapRecovery.of(w, false);
    var attached = false;
    Future<void> settle() async {
      await db.messageHistory.reads.settled;
      await w.flushCache();
      await db.messageHistory.reads.settled;
    }

    try {
      final scope = MessageHistoryPages.scope(w, 'chat')!;
      await seedGap(db, scope);
      await w.selectChannel(w.channels.single, autoRead: false);
      await w.messageDomain.older();
      await settle();
      client.beforeReads.clear();
      client.disconnected = true;
      expect(w.messageDomain.messageWindow!.visible, isTrue);
      recovery.start(view);
      attached = true;
      await client.beforeArrived.future;
      await settle();
      expect(client.beforeReads, [BigInt.from(201)]);

      client.beforeReads.clear();
      client.disconnected = false;
      client.arrivals.add(const RaftEvent('rooms:joined', null));
      await settle();

      expect(
        await db.messageHistory.gaps.read(scope, [
          ('chat-100', BigInt.from(100)),
          ('chat-201', BigInt.from(201)),
        ]),
        isEmpty,
      );
      expect(w.messageDomain.messages.map((m) => m.id), contains('chat-151'));
      expect(
        client.beforeReads,
        [
          for (final n in [201, 151, 101, 51]) BigInt.from(n),
        ],
        reason:
            'Each reconnect page must be applied once across both workflows.',
      );
      expect(w.error, isNull);
    } finally {
      if (attached) recovery.stop(view);
      await settle();
      w.dispose();
      await client.arrivals.close();
      await client.dispose();
      await db.close();
    }
  });
}
