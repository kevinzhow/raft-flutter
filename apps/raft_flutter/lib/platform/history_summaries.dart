import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/message_history.dart';

/// Inline reply previews ("N replies" under a parent message), kept next to
/// the parent row they describe. A summary exists only while its parent row
/// is live: row deletion, eviction, retention, channel/server revocation and
/// sign-out remove it through the triggers below, with no separate policy.
class SqliteHistorySummaries {
  static const table = 'raft_history_summaries';

  static Future<void> create(GeneratedDatabase db) async {
    await db.customStatement('''CREATE TABLE IF NOT EXISTS $table (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      channel TEXT NOT NULL, message_id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY(origin,principal,server,channel,message_id))''');
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS raft_history_summaries_row_gone
      AFTER DELETE ON raft_history_rows
      BEGIN
        DELETE FROM $table WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND channel=OLD.channel AND message_id=OLD.message_id;
      END''',
    );
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS raft_history_summaries_row_retired
      AFTER UPDATE OF tombstone ON raft_history_rows WHEN NEW.tombstone<>0
      BEGIN
        DELETE FROM $table WHERE origin=NEW.origin AND principal=NEW.principal
          AND server=NEW.server AND channel=NEW.channel AND message_id=NEW.message_id;
      END''',
    );
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS raft_history_summaries_purge
      AFTER DELETE ON workspace_cache WHEN OLD.kind='message-history'
      BEGIN
        DELETE FROM $table WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND channel=OLD.id;
      END''',
    );
  }

  /// Summaries of [ids] in one conversation, decoded. Unreadable payloads are
  /// skipped: a preview is never worth failing a message read for.
  static Future<Map<String, dynamic>> read(
    GeneratedDatabase db,
    String origin,
    String principal,
    String server,
    String channel,
    Iterable<Object?> ids,
  ) async {
    final wanted = [
      for (final id in ids)
        if (id is String) id,
    ];
    final found = <String, dynamic>{};
    // SQLite's bound-variable limit is far above a 500-row window, but keep
    // each statement small.
    for (var i = 0; i < wanted.length; i += 200) {
      final chunk = wanted.skip(i).take(200).toList();
      final rows = await db
          .customSelect(
            'SELECT message_id,payload FROM $table WHERE origin=? AND principal=? AND server=? AND channel=? '
            'AND message_id IN (${List.filled(chunk.length, '?').join(',')})',
            variables: [
              for (final value in [
                origin,
                principal,
                server,
                channel,
                ...chunk,
              ])
                Variable<String>(value),
            ],
          )
          .get();
      for (final row in rows) {
        try {
          final value = jsonDecode(row.read<String>('payload'));
          if (value is Map) {
            found[row.read<String>('message_id')] = Map<String, dynamic>.from(
              value,
            );
          }
        } on FormatException {
          continue;
        }
      }
    }
    return found;
  }

  /// Upserts [summaries] for parents whose live row is on the device, and
  /// removes the stored summary of every id in [absent] (a network page that
  /// carried the parent without a summary).
  static Future<void> write(
    GeneratedDatabase db,
    MessageHistoryScope scope,
    Map<dynamic, dynamic> summaries, {
    Iterable<String> absent = const [],
  }) async {
    for (final id in absent) {
      if (summaries.containsKey(id)) continue;
      await db.customStatement(
        'DELETE FROM $table WHERE origin=? AND principal=? AND server=? AND channel=? AND message_id=?',
        [...scope.key, id],
      );
    }
    for (final entry in summaries.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final String payload;
      try {
        payload = jsonEncode(entry.value);
      } on JsonUnsupportedObjectError {
        continue;
      }
      await db.customStatement(
        '''INSERT INTO $table (origin,principal,server,channel,message_id,payload)
        SELECT ?,?,?,?,?,? WHERE EXISTS (
          SELECT 1 FROM raft_history_rows WHERE origin=? AND principal=? AND server=?
            AND channel=? AND message_id=? AND tombstone=0)
        ON CONFLICT(origin,principal,server,channel,message_id)
        DO UPDATE SET payload=excluded.payload''',
        [...scope.key, entry.key, payload, ...scope.key, entry.key],
      );
    }
  }
}
