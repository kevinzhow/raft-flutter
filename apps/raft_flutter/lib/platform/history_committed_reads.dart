import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/message_history.dart';
import '../data/workspace_cache_codec.dart';
import 'history_summaries.dart';

class CommittedHistoryWindow {
  CommittedHistoryWindow(
    this.scope,
    this.value, {
    required this.hasPosition,
    required this.positionsUnchanged,
  });
  final MessageHistoryScope scope;
  final Map<String, dynamic> value;
  final bool hasPosition;
  final bool Function() positionsUnchanged;
}

/// Reads metadata, permission denial, coverage and rows in one SQLite snapshot.
/// It does not migrate, repair authority, update LRU, or acquire a write executor.
class SqliteCommittedHistoryReads {
  static Future<CommittedHistoryWindow?> read(
    GeneratedDatabase db,
    String origin,
    String principal,
    String server,
    String kind,
    String id, {
    required bool Function() positionsUnchanged,
  }) async {
    final rows = await db
        .customSelect(
          '''/* raft-history-snapshot */
      WITH seeds AS (
        SELECT payload FROM workspace_cache
        WHERE origin=? AND principal=? AND server=? AND kind='message-history'
          AND ${kind == 'window' ? 'id=?' : "json_extract(payload,'\$.parentMessageId')=?"}
        LIMIT 2
      ), metadata AS (
        SELECT payload,
          json_extract(payload,'\$.channelId') AS channel,
          json_extract(payload,'\$.parentChannelId') AS parent,
          coalesce(json_extract(payload,'\$.knownEmpty'),0) AS empty,
          coalesce(json_extract(payload,'\$.windowSize'),50) AS requested
        FROM seeds
        WHERE json_valid(payload) AND (SELECT count(*) FROM seeds)=1
      ), permitted AS (
        SELECT * FROM metadata m WHERE requested BETWEEN 1 AND 500
          AND (empty=1 OR coalesce(json_extract(payload,'\$.windowKind'),'tail')!='context')
          AND NOT EXISTS (
            SELECT 1 FROM workspace_cache d
            WHERE d.origin=? AND d.principal=? AND d.server=?
              AND d.kind='message-history-denied' AND d.id IN (m.channel,m.parent)
          )
      ), latest AS (
        SELECT m.*, (
          SELECT seq_key FROM raft_history_rows r
          WHERE r.origin=? AND r.principal=? AND r.server=? AND r.channel=m.channel
            AND r.tombstone=0 ORDER BY seq_key DESC LIMIT 1
        ) AS last_key FROM permitted m
      ), bounds AS MATERIALIZED (
        SELECT *, CASE
          WHEN typeof(json_extract(payload,'\$.tailSequence'))!='text'
            OR json_extract(payload,'\$.tailSequence')='0' THEN last_key
          ELSE substr('00000000000000000000'||json_extract(payload,'\$.tailSequence'),-20)
          END AS target,
          coalesce(json_extract(payload,'\$.tailFloor'),'00000000000000000000') AS floor
        FROM latest WHERE empty=1 OR last_key IS NOT NULL
      ), messages AS (
        SELECT r.payload,r.seq_key,r.message_id
        FROM raft_history_rows r
        WHERE r.origin=? AND r.principal=? AND r.server=?
          AND r.channel=(SELECT channel FROM bounds)
          AND (SELECT empty FROM bounds)=0 AND r.tombstone=0
          AND r.seq_key>=(SELECT floor FROM bounds)
          AND r.seq_key<=(SELECT target FROM bounds)
        ORDER BY r.seq_key DESC,r.message_id DESC
        LIMIT coalesce((SELECT requested+1 FROM bounds),0)
      )
      SELECT b.payload AS marker,b.requested,b.empty,m.payload AS message,
        EXISTS (
          SELECT 1 FROM workspace_cache a
          WHERE a.origin=? AND a.principal=? AND a.server=?
            AND a.kind='history-anchor' AND a.id=b.channel
        ) AS has_position,
        EXISTS (
          SELECT 1 FROM raft_history_ranges g
          WHERE g.origin=? AND g.principal=? AND g.server=? AND g.channel=b.channel
            AND g.lower_key<='00000000000000000000' AND g.upper_key>=b.target
        ) AS complete
      FROM bounds b LEFT JOIN messages m ON 1=1
      ORDER BY m.seq_key DESC,m.message_id DESC''',
          variables: [
            for (final value in [
              origin,
              principal,
              server,
              id,
              origin,
              principal,
              server,
              origin,
              principal,
              server,
              origin,
              principal,
              server,
              origin,
              principal,
              server,
              origin,
              principal,
              server,
            ])
              Variable(value),
          ],
        )
        .get();
    if (rows.isEmpty) return null;
    final marker = jsonDecode(rows.first.read<String>('marker'));
    if (marker is! Map ||
        marker['channelId'] is! String ||
        marker['parentChannelId'] is! String ||
        marker['authority'] is! String) {
      return null;
    }
    final tail = marker['tailSequence'];
    if (tail is String && tail != '0') {
      try {
        historySequenceKey(tail);
      } on FormatException {
        return null;
      }
    }
    final size = rows.first.read<int>('requested');
    final payloads = [
      for (final row in rows) ?row.readNullable<String>('message'),
    ];
    final messages = await decodeWorkspaceTranslations(
      payloads.take(size).toList().reversed.toList(),
    );
    final empty = rows.first.read<int>('empty') == 1;
    // Reply previews are read right after the rows, from the read executor;
    // a parent evicted in between simply has no preview.
    final summaries = await SqliteHistorySummaries.read(
      db,
      origin,
      principal,
      server,
      marker['channelId'] as String,
      messages.map((row) => row['id']),
    );
    return CommittedHistoryWindow(
      MessageHistoryScope(
        origin: origin,
        principal: principal,
        server: server,
        channel: marker['channelId'] as String,
        parentChannel: marker['parentChannelId'] as String,
        authority: marker['authority'] as String,
      ),
      {
        ...Map<String, dynamic>.from(marker),
        'messages': messages,
        // Markers written before previews had their own table still carry
        // them; the table wins where it has the parent.
        'threadSummaries': {
          if (marker['threadSummaries'] case final Map old)
            ...Map<String, dynamic>.from(old),
          ...summaries,
        },
        'hasMore':
            !empty &&
            marker['historyLimited'] != true &&
            (payloads.length > size || rows.first.read<int>('complete') == 0),
        'historyLimited': marker['historyLimited'] == true,
      },
      hasPosition: rows.first.read<int>('has_position') != 0,
      positionsUnchanged: positionsUnchanged,
    );
  }
}
