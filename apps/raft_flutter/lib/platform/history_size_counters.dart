import 'package:drift/drift.dart';

/// Incremental retention accounting. Backfill releases the shared queue after
/// each rowid chunk; trigger predicates cover only the already-counted prefix.
class HistorySizeCounters {
  HistorySizeCounters(this.db);
  final GeneratedDatabase db;
  static const _historyKinds =
      "'window','thread-window','message-history','message-history-denied','history-anchor','history-kept','history-budget'";
  static String rowWeight(String p) =>
      '$p.byte_size+96+3*(length(cast($p.origin as blob))+'
      'length(cast($p.principal as blob))+length(cast($p.server as blob))+'
      'length(cast($p.channel as blob)))+2*length(cast($p.message_id as blob))+'
      '2*length($p.seq_key)';
  static String _cacheWeight(String p) =>
      'length(cast($p.payload as blob))+96+2*(length(cast($p.origin as blob))+'
      'length(cast($p.principal as blob))+length(cast($p.server as blob))+'
      'length(cast($p.kind as blob))+length(cast($p.id as blob)))';
  static String _historyWeight(String p) =>
      'CASE WHEN $p.kind IN ($_historyKinds) THEN ${_cacheWeight(p)} ELSE 0 END';
  Future<List<QueryRow>> _query(String sql, [List<Variable> args = const []]) =>
      db.customSelect(sql, variables: args).get();

  Future<void> openNow() async {
    await db.customStatement('''CREATE TABLE IF NOT EXISTS raft_history_sizes (
      origin TEXT NOT NULL, principal TEXT NOT NULL, payload INTEGER NOT NULL,
      weight INTEGER NOT NULL, rows INTEGER NOT NULL,
      PRIMARY KEY(origin,principal))''');
    await db.customStatement(
      '''CREATE TABLE IF NOT EXISTS raft_history_size_state (
      id INTEGER PRIMARY KEY, initialized INTEGER NOT NULL)''',
    );
    await db.customStatement(
      'INSERT OR IGNORE INTO raft_history_size_state VALUES(1,0)',
    );
    await db.customStatement(
      '''CREATE TABLE IF NOT EXISTS raft_history_cache_sizes (
      origin TEXT NOT NULL, principal TEXT NOT NULL,
      weight INTEGER NOT NULL,
      PRIMARY KEY(origin,principal))''',
    );
    await db.customStatement(
      '''CREATE TABLE IF NOT EXISTS raft_history_counter_progress (
      kind TEXT PRIMARY KEY, cursor INTEGER NOT NULL, complete INTEGER NOT NULL)''',
    );
    await db.customStatement(
      "INSERT OR IGNORE INTO raft_history_counter_progress SELECT 'rows',0,initialized FROM raft_history_size_state WHERE id=1",
    );
    await db.customStatement(
      "INSERT OR IGNORE INTO raft_history_counter_progress VALUES('cache',0,0)",
    );
    for (final op in ['insert', 'update', 'delete']) {
      final add = op != 'delete', subtract = op != 'insert';
      final ref = subtract ? 'OLD' : 'NEW';
      // Read hits only touch LRU time. They must not subtract and re-add the
      // same charge for every displayed row.
      final updatedColumns = op == 'update'
          ? ' OF origin,principal,server,channel,message_id,seq_key,byte_size,tombstone'
          : '';
      final changedCharge = op == 'update'
          ? '''AND (NEW.origin IS NOT OLD.origin OR NEW.principal IS NOT OLD.principal
            OR NEW.server IS NOT OLD.server OR NEW.channel IS NOT OLD.channel
            OR NEW.message_id IS NOT OLD.message_id OR NEW.seq_key IS NOT OLD.seq_key
            OR NEW.byte_size IS NOT OLD.byte_size OR (NEW.tombstone=0) IS NOT (OLD.tombstone=0))'''
          : '';
      await db.customStatement('DROP TRIGGER IF EXISTS raft_history_size_$op');
      await db.customStatement('''CREATE TRIGGER raft_history_size_$op
        AFTER ${op.toUpperCase()}$updatedColumns ON raft_history_rows
        WHEN (SELECT complete OR $ref.rowid<=cursor FROM raft_history_counter_progress WHERE kind='rows')
        $changedCharge
        BEGIN
        ${subtract ? '''UPDATE raft_history_sizes SET payload=payload-OLD.byte_size,
          weight=weight-(${rowWeight('OLD')}),rows=rows-(OLD.tombstone=0)
          WHERE origin=OLD.origin AND principal=OLD.principal;''' : ''}
        ${add ? '''INSERT INTO raft_history_sizes VALUES
          (NEW.origin,NEW.principal,NEW.byte_size,${rowWeight('NEW')},(NEW.tombstone=0))
          ON CONFLICT(origin,principal) DO UPDATE SET
          payload=payload+excluded.payload,weight=weight+excluded.weight,rows=rows+excluded.rows;''' : ''}
        ${subtract ? '''DELETE FROM raft_history_sizes WHERE origin=OLD.origin
          AND principal=OLD.principal AND weight<=0;''' : ''}
        END''');
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS raft_history_cache_size_$op
        AFTER ${op.toUpperCase()} ON workspace_cache
        WHEN (SELECT complete OR $ref.rowid<=cursor FROM raft_history_counter_progress WHERE kind='cache') AND $ref.kind IN ($_historyKinds)
        BEGIN
        ${subtract ? '''UPDATE raft_history_cache_sizes
          SET weight=weight-(${_historyWeight('OLD')})
          WHERE origin=OLD.origin AND principal=OLD.principal;''' : ''}
        ${add ? '''INSERT INTO raft_history_cache_sizes VALUES
          (NEW.origin,NEW.principal,${_historyWeight('NEW')})
          ON CONFLICT(origin,principal) DO UPDATE SET
          weight=weight+excluded.weight;''' : ''}
        ${subtract ? '''DELETE FROM raft_history_cache_sizes WHERE origin=OLD.origin
          AND principal=OLD.principal AND weight<=0;''' : ''}
        END''',
      );
    }
    // The previous client uses REPLACE, whose implicit deletion does not fire
    // DELETE triggers on its default connection. Its unguarded window writes
    // therefore invalidate the shadow counters for a bounded rebuild.
    await db.customStatement(
      """CREATE TRIGGER IF NOT EXISTS raft_history_cache_old_writer
      AFTER INSERT ON workspace_cache WHEN NEW.kind IN ('window','thread-window')
      AND NOT EXISTS (SELECT 1 FROM raft_history_compat_write WHERE origin=NEW.origin
        AND principal=NEW.principal AND server=NEW.server)
      BEGIN
        DELETE FROM raft_history_cache_sizes;
        UPDATE raft_history_counter_progress SET cursor=0,complete=0 WHERE kind='cache';
      END""",
    );
  }

  /// Exactly one bounded transaction. Updates/deletes of counted rows remain
  /// covered while inserts above the prefix are picked up by later chunks.
  Future<bool> backfillNow() async {
    final progress = await _query(
      'SELECT kind,cursor FROM raft_history_counter_progress WHERE complete=0 ORDER BY kind DESC LIMIT 1',
    );
    if (progress.isEmpty) return true;
    final kind = progress.single.read<String>('kind'),
        cursor = progress.single.read<int>('cursor');
    final rows = kind == 'rows',
        table = rows ? 'raft_history_rows' : 'workspace_cache';
    final ids = await _query(
      'SELECT rowid FROM $table WHERE rowid>? ORDER BY rowid LIMIT ${rows ? 1000 : 8}',
      [Variable(cursor)],
    );
    await db.transaction(() async {
      if (ids.isEmpty) {
        await db.customStatement(
          'UPDATE raft_history_counter_progress SET complete=1 WHERE kind=?',
          [kind],
        );
        if (rows) {
          await db.customStatement(
            'UPDATE raft_history_size_state SET initialized=1 WHERE id=1',
          );
        }
        return;
      }
      final last = ids.last.read<int>('rowid');
      if (rows) {
        await db.customStatement(
          '''INSERT INTO raft_history_sizes
          SELECT r.origin,r.principal,sum(r.byte_size),sum(${rowWeight('r')}),sum(r.tombstone=0)
          FROM raft_history_rows r WHERE rowid>? AND rowid<=? GROUP BY r.origin,r.principal
          ON CONFLICT(origin,principal) DO UPDATE SET payload=payload+excluded.payload,
          weight=weight+excluded.weight,rows=rows+excluded.rows''',
          [cursor, last],
        );
      } else {
        await db.customStatement(
          '''INSERT INTO raft_history_cache_sizes
          SELECT c.origin,c.principal,sum(${_historyWeight('c')})
          FROM workspace_cache c WHERE rowid>? AND rowid<=? AND c.kind IN ($_historyKinds) GROUP BY c.origin,c.principal
          ON CONFLICT(origin,principal) DO UPDATE SET weight=weight+excluded.weight''',
          [cursor, last],
        );
      }
      await db.customStatement(
        'UPDATE raft_history_counter_progress SET cursor=? WHERE kind=?',
        [last, kind],
      );
    });
    return false;
  }
}
