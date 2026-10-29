import 'package:drift/drift.dart';

import '../data/message_history.dart';

/// Updates existing rollback copies inside the canonical message transaction.
/// JSON stays on the database worker; no full window crosses the UI isolate.
class HistoryShadows {
  HistoryShadows(this.db);
  final GeneratedDatabase db;

  Future<void> refresh(MessageHistoryScope scope) async {
    final marker = await db
        .customSelect(
          r'''SELECT CASE WHEN json_valid(payload) THEN
          CASE WHEN json_type(payload,'$.parentMessageId')='text'
            THEN json_extract(payload,'$.parentMessageId') END END AS parent,
        CASE WHEN json_valid(payload) THEN
          CASE WHEN json_type(payload,'$.evictionSequence')='text'
            THEN json_extract(payload,'$.evictionSequence') END END AS eviction
        FROM workspace_cache WHERE origin=? AND principal=? AND server=?
          AND kind='message-history' AND id=?''',
          variables: [for (final value in scope.key) Variable(value)],
        )
        .get();
    final parent =
        scope.parentMessage ??
        marker.firstOrNull?.readNullable<String>('parent');
    final eviction = marker.firstOrNull?.readNullable<String>('eviction');
    // Absent rollback copies cost only indexed lookups. Never create a second
    // copy as a side effect of a new-message or partial-edit write.
    final copies = await db
        .customSelect(
          "SELECT 1 FROM workspace_cache WHERE origin=? AND principal=? AND server=? "
          "AND ((kind='window' AND id=?) OR (kind='thread-window' AND id=?)) LIMIT 1",
          variables: [
            for (final value in [
              ...scope.key.take(3),
              scope.channel,
              parent ?? '',
            ])
              Variable(value),
          ],
        )
        .get();
    if (copies.isEmpty) return;
    final guards = await db
        .customSelect(
          'SELECT 1 FROM raft_history_compat_write WHERE origin=? AND principal=? AND server=?',
          variables: [for (final value in scope.key.take(3)) Variable(value)],
        )
        .get();
    if (guards.isEmpty) {
      await db.customStatement(
        'INSERT INTO raft_history_compat_write VALUES(?,?,?)',
        scope.key.take(3).toList(),
      );
    }
    try {
      await db.customStatement(_refreshSql, [
        ...scope.key.take(3),
        scope.channel,
        parent ?? '',
        scope.authority,
        scope.parentChannel,
        scope.channel,
        ...scope.key,
        eviction,
        eviction,
      ]);
    } finally {
      if (guards.isEmpty) {
        await db.customStatement(
          'DELETE FROM raft_history_compat_write WHERE origin=? AND principal=? AND server=?',
          scope.key.take(3).toList(),
        );
      }
    }
  }

  static const _refreshSql = r'''
    WITH candidates AS MATERIALIZED (
      SELECT rowid,kind,payload FROM workspace_cache
      WHERE origin=? AND principal=? AND server=?
        AND ((kind='window' AND id=?) OR (kind='thread-window' AND id=?))
    ), eligible AS MATERIALIZED (
      SELECT rowid,payload FROM candidates WHERE CASE WHEN json_valid(payload) THEN
        json_extract(payload,'$.version')=1
        AND json_extract(payload,'$.windowKind')='tail'
        AND json_extract(payload,'$.authority')=?
        AND json_extract(payload,'$.parentChannelId')=?
        AND (kind='window' OR json_extract(payload,'$.threadChannelId')=?)
        AND json_type(payload,'$.messages')='array'
        AND json_array_length(payload,'$.messages')<=500
        AND NOT EXISTS (
          SELECT 1 FROM json_each(payload,'$.messages') m
          WHERE CASE WHEN m.type='object'
            THEN json_type(m.value,'$.id')='text' ELSE 0 END IS NOT 1
        ) ELSE 0 END
    ), replacements AS MATERIALIZED (
      SELECT e.rowid,json_set(e.payload,'$.messages',json((
        SELECT json_group_array(json(body)) FROM (
          SELECT CASE WHEN r.tombstone=0 THEN r.payload ELSE m.value END AS body
          FROM json_each(e.payload,'$.messages') m
          LEFT JOIN raft_history_rows r ON r.origin=? AND r.principal=?
            AND r.server=? AND r.channel=? AND r.message_id=json_extract(m.value,'$.id')
          WHERE r.tombstone=0 OR (r.message_id IS NULL AND (? IS NULL OR (
            json_type(m.value,'$.seq') IN ('text','integer')
            AND length(CAST(json_extract(m.value,'$.seq') AS TEXT)) BETWEEN 1 AND 20
            AND CAST(json_extract(m.value,'$.seq') AS TEXT) NOT GLOB '*[^0-9]*'
            AND (length(CAST(json_extract(m.value,'$.seq') AS TEXT))=1
              OR substr(CAST(json_extract(m.value,'$.seq') AS TEXT),1,1)<>'0')
            AND (json_type(m.value,'$.seq')<>'integer'
              OR json_extract(m.value,'$.seq')<=9007199254740991)
            AND substr('00000000000000000000'||json_extract(m.value,'$.seq'),-20)<='18446744073709551615'
            AND substr('00000000000000000000'||json_extract(m.value,'$.seq'),-20)>?
          ))) ORDER BY CAST(m.key AS INTEGER)
        )
      ))) AS payload FROM eligible e
    )
    UPDATE workspace_cache SET payload=(
      SELECT payload FROM replacements WHERE replacements.rowid=workspace_cache.rowid
    ) WHERE rowid IN (
      SELECT r.rowid FROM replacements r JOIN eligible e ON e.rowid=r.rowid
      WHERE r.payload<>e.payload
    )
  ''';
}
