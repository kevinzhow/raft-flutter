import 'package:drift/drift.dart';

import '../data/history_capacity.dart';
import '../data/message_history.dart';
import '../data/workspace_cache_codec.dart';
import 'message_history.dart' show HistoryOperationOrder;

/// Retains exact recent eviction identities and a conservative fence for the
/// older identities. The fence never expires while its conversation exists.
class HistoryEvictions {
  HistoryEvictions(this.db);
  final GeneratedDatabase db;
  static const retainedIds = 256;
  static const _where = 'origin=? AND principal=? AND server=? AND channel=?';
  Future<List<QueryRow>> _query(String sql, Iterable<Object> values) => db
      .customSelect(
        sql,
        variables: [
          for (final v in values) v is int ? Variable(v) : Variable('$v'),
        ],
      )
      .get();

  /// Call inside the caller's transaction. At most 200 identities are removed.
  Future<bool> trimNow(MessageHistoryScope scope) async {
    final rows = await _query(
      'SELECT message_id,seq_key,revision FROM raft_history_rows WHERE $_where AND tombstone=2 ORDER BY revision DESC,message_id DESC LIMIT 200 OFFSET $retainedIds',
      scope.key,
    );
    if (rows.isEmpty) return false;
    final records = await _query(
      "SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind='message-history' AND id=?",
      scope.key,
    );
    if (records.isEmpty) return false;
    final marker = Map<String, dynamic>.from(
      await decodeWorkspaceCache(records.single.read<String>('payload')) as Map,
    );
    var revision = marker['evictionRevision'] as int? ?? 0;
    var sequence =
        marker['evictionSequence'] as String? ??
        historySequenceKey(BigInt.zero);
    for (final row in rows) {
      if (row.read<int>('revision') > revision) {
        revision = row.read<int>('revision');
      }
      if (row.read<String>('seq_key').compareTo(sequence) > 0) {
        sequence = row.read<String>('seq_key');
      }
    }
    await db.customStatement(
      "UPDATE workspace_cache SET payload=? WHERE origin=? AND principal=? AND server=? AND kind='message-history' AND id=?",
      [
        await encodeWorkspaceCache({
          ...marker,
          'evictionRevision': revision,
          'evictionSequence': sequence,
        }),
        ...scope.key,
      ],
    );
    await db.customStatement(
      'DELETE FROM raft_history_rows WHERE $_where AND tombstone=2 AND message_id IN (${List.filled(rows.length, '?').join(',')})',
      [...scope.key, for (final row in rows) row.read<String>('message_id')],
    );
    return rows.length == 200;
  }

  static const _progressKind = 'history-receipt-cleanup';

  Future<void> _saveProgress(
    HistoryAccount account,
    ({int cursor, int ceiling, int skipped}) progress,
  ) async {
    await db.customStatement(
      "INSERT INTO workspace_cache VALUES(?,?,'','$_progressKind','',?) "
      'ON CONFLICT(origin,principal,server,kind,id) DO UPDATE SET payload=excluded.payload',
      [
        account.origin,
        account.principal,
        await encodeWorkspaceCache({
          'version': 1,
          'cursor': progress.cursor,
          'ceiling': progress.ceiling,
          'skippedMarkers': progress.skipped,
          'complete': progress.cursor >= progress.ceiling,
        }),
      ],
    );
  }

  Future<Map?> _readMap(String payload) async {
    try {
      final value = await decodeWorkspaceCache(payload);
      return value is Map ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// Handles receipts left by an older installation, even below its quota.
  /// Progress commits with each bounded batch. New eviction writes already
  /// trim their own receipts, so a completed upgrade sweep need not rescan.
  Future<void> cleanAccount(
    HistoryAccount a,
    HistoryOperationOrder order,
    bool Function() current,
  ) async {
    var progress = await order(
      () => db.transaction(() async {
        final saved = await _query(
          "SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server='' AND kind='$_progressKind' AND id=''",
          [a.origin, a.principal],
        );
        final raw = saved.isEmpty
            ? null
            : await _readMap(saved.single.read<String>('payload'));
        if (raw != null &&
            raw['version'] == 1 &&
            raw['cursor'] is int &&
            raw['ceiling'] is int &&
            raw['skippedMarkers'] is int &&
            (raw['cursor'] as int) >= 0 &&
            (raw['ceiling'] as int) >= 0) {
          return (
            cursor: raw['cursor'] as int,
            ceiling: raw['ceiling'] as int,
            skipped: raw['skippedMarkers'] as int,
          );
        }
        final ceiling = (await _query(
          "SELECT coalesce(max(rowid),0) AS last FROM workspace_cache WHERE origin=? AND principal=? AND kind='message-history'",
          [a.origin, a.principal],
        )).single.read<int>('last');
        final initial = (cursor: 0, ceiling: ceiling, skipped: 0);
        if (current()) await _saveProgress(a, initial);
        return initial;
      }),
    );
    while (current() && progress.cursor < progress.ceiling) {
      progress = await order(
        () => db.transaction(() async {
          if (!current()) return progress;
          final records = await _query(
            "SELECT rowid,server,id,payload FROM workspace_cache WHERE rowid>? AND rowid<=? AND origin=? AND principal=? AND kind='message-history' ORDER BY rowid LIMIT 1",
            [progress.cursor, progress.ceiling, a.origin, a.principal],
          );
          var cursor = progress.ceiling, skipped = progress.skipped;
          if (records.isNotEmpty) {
            final record = records.single;
            cursor = record.read<int>('rowid');
            final marker = await _readMap(record.read<String>('payload'));
            if (marker == null ||
                marker['parentChannelId'] is! String ||
                marker['authority'] is! String ||
                marker['evictionRevision'] != null &&
                    marker['evictionRevision'] is! int ||
                marker['evictionSequence'] != null &&
                    marker['evictionSequence'] is! String) {
              skipped++;
            } else {
              final scope = MessageHistoryScope(
                origin: a.origin,
                principal: a.principal,
                server: record.read<String>('server'),
                channel: record.read<String>('id'),
                parentChannel: marker['parentChannelId'] as String,
                authority: marker['authority'] as String,
              );
              if (await trimNow(scope)) cursor = progress.cursor;
            }
          }
          final next = (
            cursor: cursor,
            ceiling: progress.ceiling,
            skipped: skipped,
          );
          await _saveProgress(a, next);
          return next;
        }),
      );
      if (progress.cursor < progress.ceiling) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  }
}
