import 'package:drift/drift.dart';

import '../data/history_gaps.dart';
import '../data/message_history.dart';
import 'message_history.dart' show HistoryOperationOrder;

/// Checks open intervals between saved rows with bounded indexed seeks.
class SqliteHistoryGaps extends HistoryGapQueries {
  SqliteHistoryGaps(
    this.db,
    this.order, {
    required this.ready,
    required this.allowed,
  });
  final GeneratedDatabase db;
  final HistoryOperationOrder order;
  final Future<void> Function() ready;
  final Future<bool> Function(MessageHistoryScope) allowed;
  final _versions = <(String, String, String, String), int>{};
  int _epoch = 0;
  @override
  int get retirement => _epoch;
  bool _closed = false;
  (String, String, String, String) key(MessageHistoryScope scope) =>
      (scope.origin, scope.principal, scope.server, scope.channel);
  @override
  Object revision(MessageHistoryScope scope) =>
      (_epoch, _versions[key(scope)] ?? 0);
  void changed(MessageHistoryScope? scope) {
    if (_closed) return;
    if (scope == null) {
      _epoch++;
    } else {
      _versions.update(key(scope), (value) => value + 1, ifAbsent: () => 1);
    }
    notifyListeners();
  }

  void forgetAccount(String origin, String principal) {
    _versions.removeWhere((key, _) => key.$1 == origin && key.$2 == principal);
    changed(null);
  }

  @override
  Future<List<HistoryGap>> read(
    MessageHistoryScope scope,
    List<(String, BigInt)> visible,
  ) async {
    if (_closed || visible.length < 2) return const [];
    final result = <HistoryGap>[];
    // Five values per pair plus scope keys stay below SQLite's 999-bind limit.
    for (var offset = 0; offset < visible.length - 1; offset += 160) {
      final end = (offset + 160).clamp(0, visible.length - 1);
      final pairs = [
        for (var n = offset; n < end; n++)
          if (visible[n + 1].$2 > visible[n].$2 + BigInt.one)
            (
              visible[n].$2,
              visible[n + 1].$2,
              visible[n + 1].$1,
              visible[n].$2 + BigInt.one,
              visible[n + 1].$2 - BigInt.one,
            ),
      ];
      if (pairs.isEmpty) continue;
      final gaps = await order(() async {
        await ready();
        if (_closed || !await allowed(scope)) return <HistoryGap>[];
        final rows = await db
            .customSelect(
              // Endpoints already exist. A before=N response proves through
              // N-1 even when N came from a legacy window without its own proof.
              // Completely unverified legacy pairs are unknown, not separate
              // fetched fragments. They still cannot answer cached pagination.
              '''WITH pairs(older_key,newer_key,newer_id,first_key,last_key) AS (VALUES
          ${List.filled(pairs.length, '(?,?,?,?,?)').join(',')})
          SELECT newer_id,newer_key,older_key FROM pairs WHERE coalesce((
            SELECT upper_key FROM raft_history_ranges WHERE origin=? AND principal=?
              AND server=? AND channel=? AND lower_key<=pairs.first_key
              ORDER BY lower_key DESC LIMIT 1),'')<last_key
          AND (coalesce((
            SELECT upper_key FROM raft_history_ranges WHERE origin=? AND principal=?
              AND server=? AND channel=? AND lower_key<=pairs.older_key
              ORDER BY lower_key DESC LIMIT 1),'')>=older_key
            OR coalesce((
            SELECT upper_key FROM raft_history_ranges WHERE origin=? AND principal=?
              AND server=? AND channel=? AND lower_key<=pairs.newer_key
              ORDER BY lower_key DESC LIMIT 1),'')>=newer_key)
          ORDER BY newer_key''',
              variables: [
                for (final pair in pairs) ...[
                  Variable(historySequenceKey(pair.$1)),
                  Variable(historySequenceKey(pair.$2)),
                  Variable(pair.$3),
                  Variable(historySequenceKey(pair.$4)),
                  Variable(historySequenceKey(pair.$5)),
                ],
                for (var n = 0; n < 3; n++)
                  for (final value in scope.key) Variable(value),
              ],
            )
            .get();
        return [
          for (final row in rows)
            HistoryGap(
              row.read<String>('newer_id'),
              BigInt.parse(row.read<String>('newer_key')),
              older: BigInt.parse(row.read<String>('older_key')),
            ),
        ];
      });
      result.addAll(gaps);
      if (end < visible.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
    return result;
  }

  @override
  Future<List<HistoryGap>> readSaved(MessageHistoryScope scope) async {
    final points = await order(() async {
      await ready();
      if (_closed || !await allowed(scope)) return <(String, BigInt)>[];
      // Proof edges and their nearest saved neighbors delimit possible gaps.
      // This indexed metadata query does not read bodies or depend on the
      // in-memory timeline retaining both endpoints.
      final rows = await db
          .customSelect(
            r'''WITH candidates(seq_key) AS (
          SELECT (SELECT min(seq_key) FROM raft_history_rows r
            WHERE r.origin=p.origin AND r.principal=p.principal AND r.server=p.server
              AND r.channel=p.channel AND r.tombstone=0 AND r.seq_key>p.upper_key)
          FROM raft_history_ranges p WHERE p.origin=? AND p.principal=? AND p.server=? AND p.channel=?
          UNION
          SELECT (SELECT min(seq_key) FROM raft_history_rows r
            WHERE r.origin=p.origin AND r.principal=p.principal AND r.server=p.server
              AND r.channel=p.channel AND r.tombstone=0 AND r.seq_key>=p.lower_key)
          FROM raft_history_ranges p WHERE p.origin=? AND p.principal=? AND p.server=? AND p.channel=?
        ), neighbors(seq_key) AS (
          SELECT seq_key FROM candidates WHERE seq_key IS NOT NULL
          UNION
          SELECT (SELECT max(r.seq_key) FROM raft_history_rows r
            WHERE r.origin=? AND r.principal=? AND r.server=? AND r.channel=?
              AND r.tombstone=0 AND r.seq_key<c.seq_key) FROM candidates c
        )
        SELECT message_id,seq_key FROM raft_history_rows
          WHERE origin=? AND principal=? AND server=? AND channel=? AND tombstone=0
            AND seq_key IN (SELECT seq_key FROM neighbors) ORDER BY seq_key''',
            variables: [
              for (var i = 0; i < 4; i++)
                for (final key in scope.key) Variable(key),
            ],
          )
          .get();
      return [
        for (final row in rows)
          (
            row.read<String>('message_id'),
            BigInt.parse(row.read<String>('seq_key')),
          ),
      ];
    });
    return read(scope, points);
  }

  @override
  void dispose() {
    _closed = true;
    _versions.clear();
    super.dispose();
  }
}
