import 'dart:async';

import 'package:drift/native.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_gap_recovery.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import '../history_gaps_test.dart' show seedGap;
import '../history_memory_test.dart' show HistoryClient, receiver, row;

class RangeClient extends HistoryClient {
  final beforeReads = <BigInt>[];
  final edits = <int, String>{};
  final gates = <BigInt?, Completer<void>>{};
  final pendingGates = <Completer<void>>{};
  final failures = <BigInt>{};
  void Function(BigInt?)? requested;
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
    if (before != null) beforeReads.add(before);
    final gate = gates.remove(before);
    if (gate != null) pendingGates.add(gate);
    // Snapshot before waiting: a retired response must not repaint old bodies.
    final end = (before?.toInt() ?? 251) - 1;
    final response = {
      'messages': [
        for (var n = (end - limit + 1).clamp(1, 250); n <= end; n++)
          {...row(id, n), if (edits[n] != null) 'content': edits[n]},
      ],
      'historyLimited': false,
    };
    requested?.call(before);
    await gate?.future;
    pendingGates.remove(gate);
    if (disconnected && before != null || failures.remove(before)) {
      throw const RaftApiException('Synthetic temporary failure', status: 503);
    }
    return response;
  }
}

class HistoryRangeCase {
  int free = 2 << 30;
  late final db = DriftWorkspaceCache(
    NativeDatabase.memory(),
    historyAvailableSpace: (_) async => free,
  );
  final client = RangeClient();
  late final WorkspaceController w = receiver(client, db);
  late final MessageHistoryScope scope = MessageHistoryPages.scope(w, 'chat')!;
  HistoryGapRecovery? recovery;
  final view = Object();

  Future<void> open() async {
    await seedGap(db, scope);
    await w.selectChannel(w.channels.single, autoRead: false);
    await w.messageDomain.older();
    await settle();
    client.beforeReads.clear();
  }

  void attach() {
    recovery = HistoryGapRecovery.of(w, false)..start(view);
  }

  void detach() {
    recovery?.stop(view);
    recovery = null;
  }

  Future<void> settle() async {
    await db.messageHistory.reads.settled;
    await w.flushCache();
    await db.messageHistory.reads.settled;
  }

  void reconnect() =>
      client.arrivals.add(const RaftEvent('rooms:joined', null));

  Future<void> windowContains(int sequence) async {
    bool ready() =>
        !w.messageDomain.state.loadingOlder &&
        w.messageDomain.ledger.message('chat', 'chat-$sequence') != null;
    final done = Completer<void>();
    void listener() {
      if (ready() && !done.isCompleted) done.complete();
    }

    w.addListener(listener);
    try {
      listener();
      await done.future.timeout(const Duration(seconds: 5));
    } finally {
      w.removeListener(listener);
    }
  }

  Future<void> close() async {
    for (final gate in {...client.gates.values, ...client.pendingGates}) {
      if (!gate.isCompleted) gate.complete();
    }
    detach();
    w.dispose();
    await db.messageHistory.reads.settled;
    await client.arrivals.close();
    await client.dispose();
    await db.close();
  }
}
