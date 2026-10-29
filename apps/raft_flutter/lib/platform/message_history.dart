import 'dart:convert';
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:raft_sync/raft_sync.dart';
import 'package:raft_ui/raft_ui.dart' show RaftIdleTimer;

import '../data/message_history.dart';
import '../data/history_read_policy.dart';
import '../data/history_range_digest.dart';
import '../data/history_capacity.dart';
import '../data/history_memory.dart';
import '../data/history_body_proofs.dart';
import '../data/reading_positions.dart';
import '../data/workspace_cache_codec.dart';
import 'history_capacity.dart';
import 'history_positions.dart';
import 'history_gaps.dart';
import 'history_shadows.dart';
import 'history_committed_reads.dart';
import 'history_summaries.dart';
import 'device_storage.dart';

typedef HistoryOperationOrder = Future<T> Function<T>(
  Future<T> Function() action,
);

/// Additive tables share the workspace connection and its ordered purge queue.
/// The legacy schema version stays readable by the previous client version.
class SqliteMessageHistory implements MessageHistoryStorage {
  SqliteMessageHistory(
    this.db,
    this.order, {
    required this.readLegacy,
    required this.writeLegacy,
    this.historyBudget = 2 << 30,
    this.automaticMaintenance = true,
    this.hardLimitEnabled = true,
    this.historyAvailableSpace,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final GeneratedDatabase db;
  final HistoryOperationOrder order;
  final Future<dynamic> Function(String, String, String, String, String)
  readLegacy;
  final Future<void> Function(String, String, String, String, String, dynamic)
  writeLegacy;
  final DateTime Function() now;
  final int historyBudget;
  final bool automaticMaintenance, hardLimitEnabled;
  final Future<int?> Function(String)? historyAvailableSpace;
  final _memoryZone = Zone.current;
  late final _positions = SqliteHistoryPositions(db, order, ready: _ready,
    readLegacy: readLegacy, writeLegacy: writeLegacy, allowed: (scope) async =>
      (await _marker(scope))?['authority'] == scope.authority && await _denial(scope) < 0);
  @override
  Future<void> get positionsSettled => _positions.settled;
  @override
  Future<SavedReadingPosition?> readPosition(MessageHistoryScope scope) => _positions.read(scope);
  @override
  Future<void> savePosition(MessageHistoryScope scope, SavedReadingPosition? position) => _positions.save(scope, position);
  @override
  late final SqliteHistoryGaps gaps = SqliteHistoryGaps(db, order, ready: _ready, allowed: _positions.allowed);
  @override
  late final HistoryReadPolicy reads = HistoryReadPolicy(now: now);
  @override
  late final HistoryMemoryPool memory = HistoryMemoryPool(_inspectMemory,
    backgroundZone: _memoryZone,
    hold: (windows) => capacity.protect(memory, () => [for (final window in windows)
      if (window.current()) HistoryProtectedRows(
        HistoryAccount(window.scope.origin, window.scope.principal),
        window.scope.server, window.scope.channel, window.versions.keys,
      )]),
    releaseHold: () => capacity.release(memory),
  );

  final _bodyProofs = HistoryBodyProofs();
  Future<List<HistoryBodyProof>> _inspectMemory(
    MessageHistoryScope scope,
    Map<String, List<Map<String, dynamic>>> versions,
  ) async {
    final saved = await order(() async {
      await _ready();
      final marker = await _marker(scope);
      if (marker == null || marker['authority'] != scope.authority ||
          await _denial(scope) >= 0) { return <String, String>{}; }
      final stored = await _existing(scope, versions.keys);
      return {for (final entry in stored.entries)
        if (entry.value.read<int>('tombstone') == 0)
          entry.key: entry.value.read<String>('payload')};
    });
    return _bodyProofs(versions, saved);
  }
  @override
  late final SqliteHistoryCapacity capacity = SqliteHistoryCapacity(
    db, order, ready: _ready, advance: (s) => _revision(s, advance: true),
    now: now, defaultBudget: historyBudget, automatic: automaticMaintenance,
    hardLimitEnabled: hardLimitEnabled,
    pending: () => receiver.protectedRows,
    availableSpace: historyAvailableSpace ?? availableDeviceStorage,
    coverageChanged: () => gaps.changed(null),
  );
  @override
  final receiver = HistoryReceiverQueue();
  Future<void>? _opening;
  // Database IO and batch codecs already run on workers. Delay migration
  // between small chunks without depending on an animation ever stopping.
  final _migrationTimer = RaftIdleTimer(yieldToAnimation: false);
  final _migrations = <(String, String), MessageHistoryScope>{};
  bool _closed = false;

  void stop() {
    _closed = true;
    receiver.close();
    reads.close();
    capacity.close();
    memory.close();
    _bodyProofs.clear();
    gaps.dispose();
    _migrationTimer.cancel();
    _migrations.clear();
  }

  void cancelAccount(String origin, String principal) {
    _bodyProofs.clear();
    receiver.clearAccount(origin, principal);
    reads.forgetAccount(origin, principal);
    capacity.cancel(HistoryAccount(origin, principal));
    _memoryZone.run(() => gaps.forgetAccount(origin, principal));
    _migrations.remove((origin, principal));
    if (_migrations.isEmpty) _migrationTimer.cancel();
  }

  void _scheduleMigration(MessageHistoryScope scope) {
    if (_closed) return;
    _migrations[(scope.origin, scope.principal)] = scope;
    if (!_migrationTimer.isActive) {
      _migrationTimer.start(const Duration(milliseconds: 200), _migrateNext);
    }
  }

  void _migrateNext() async {
    if (_closed || _migrations.isEmpty) return;
    final entry = _migrations.entries.first;
    try {
      final count = await migrateLegacy(entry.value);
      if (count < 4) _migrations.remove(entry.key);
    } catch (_) {
      // Keep the cursor and original snapshots. Another visit retries.
      _migrations.remove(entry.key);
    }
    if (!_closed && _migrations.isNotEmpty) {
      _migrationTimer.start(const Duration(milliseconds: 200), _migrateNext);
    }
  }

  Future<void> _ready() =>
      _opening ??= _create().catchError((Object e, StackTrace s) {
        _opening = null;
        Error.throwWithStackTrace(e, s);
      });
  static const markerKind = 'message-history';
  static const denialKind = 'message-history-denied';
  static const _where = 'origin=? AND principal=? AND server=? AND channel=?';
  static const _columns = 'origin,principal,server,channel';
  List<Variable> _variables(Iterable<Object> values) => [
    for (final value in values)
      if (value is int) Variable(value) else Variable('$value'),
  ];
  Future<List<QueryRow>> _query(String sql, Iterable<Object> values) =>
      db.customSelect(sql, variables: _variables(values)).get();

  Future<void> _create() async {
    await db.customStatement('''CREATE TABLE IF NOT EXISTS raft_history_rows (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      channel TEXT NOT NULL, message_id TEXT NOT NULL, seq_key TEXT NOT NULL,
      payload TEXT NOT NULL, revision INTEGER NOT NULL, tombstone INTEGER NOT NULL,
      byte_size INTEGER NOT NULL, touched INTEGER NOT NULL,
      PRIMARY KEY(origin,principal,server,channel,message_id))''');
    await db.customStatement('''CREATE INDEX IF NOT EXISTS raft_history_sequence
      ON raft_history_rows(origin,principal,server,channel,seq_key)''');
    await db.customStatement('''CREATE INDEX IF NOT EXISTS raft_history_receipts
      ON raft_history_rows(origin,principal,server,channel,tombstone,revision DESC,message_id DESC)''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS raft_history_ranges (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      channel TEXT NOT NULL, lower_key TEXT NOT NULL, upper_key TEXT NOT NULL,
      verified INTEGER NOT NULL,
      PRIMARY KEY(origin,principal,server,channel,lower_key,upper_key))''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS raft_history_clock (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      revision INTEGER NOT NULL, PRIMARY KEY(origin,principal,server))''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS raft_history_resume (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      sequence TEXT NOT NULL, PRIMARY KEY(origin,principal,server))''');
    await db.customStatement(
      '''CREATE TABLE IF NOT EXISTS raft_history_compat_write (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      PRIMARY KEY(origin,principal,server))''',
    );
    await db.customStatement('''CREATE TABLE IF NOT EXISTS raft_history_checks (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      channel TEXT NOT NULL, request TEXT NOT NULL, verified INTEGER NOT NULL,
      PRIMARY KEY(origin,principal,server,channel,request))''');
    await SqliteHistorySummaries.create(db);
    await db.customStatement('''CREATE TRIGGER IF NOT EXISTS raft_history_position_purge
      AFTER DELETE ON workspace_cache WHEN OLD.kind='message-history'
      BEGIN
        DELETE FROM workspace_cache WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND kind='history-anchor' AND id=OLD.id;
      END''');
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS raft_history_checks_purge
      AFTER DELETE ON workspace_cache WHEN OLD.kind='message-history'
      BEGIN
        DELETE FROM raft_history_checks WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND channel=OLD.id;
      END''',
    );
    // Previous versions refuse a cached thread by deleting its JSON window.
    // Cascade that explicit old-version deletion to the additive history too.
    // New-version shadow LRU writes use a transaction-local guard, so the old
    // 120-window limit cannot evict the new accepted per-message history.
    await db.customStatement(
      """CREATE TRIGGER IF NOT EXISTS raft_history_old_window_purge
      AFTER DELETE ON workspace_cache
      WHEN OLD.kind IN ('window','thread-window') AND NOT EXISTS (
        SELECT 1 FROM raft_history_compat_write WHERE origin=OLD.origin
          AND principal=OLD.principal AND server=OLD.server)
      BEGIN
        DELETE FROM workspace_cache WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND kind='message-history' AND (
            (OLD.kind='window' AND (id=OLD.id OR json_extract(payload,'\$.parentChannelId')=OLD.id)) OR
            (OLD.kind='thread-window' AND json_extract(payload,'\$.parentMessageId')=OLD.id));
      END""",
    );
    // The previous client's account/server/channel deletion SQL deletes these
    // markers too. Its logout/revocation therefore purges additive history.
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS raft_history_legacy_purge
      AFTER DELETE ON workspace_cache WHEN OLD.kind='message-history'
      BEGIN
        DELETE FROM raft_history_rows WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND channel=OLD.id;
        DELETE FROM raft_history_ranges WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND channel=OLD.id;
        DELETE FROM raft_history_clock WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND NOT EXISTS (
            SELECT 1 FROM workspace_cache WHERE origin=OLD.origin AND principal=OLD.principal
              AND server=OLD.server AND kind='message-history');
        DELETE FROM raft_history_resume WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND NOT EXISTS (
            SELECT 1 FROM workspace_cache WHERE origin=OLD.origin AND principal=OLD.principal
              AND server=OLD.server AND kind='message-history');
      END''',
    );
    await db.customStatement(
      """CREATE TRIGGER IF NOT EXISTS raft_history_denial_cleanup
      AFTER DELETE ON workspace_cache WHEN OLD.kind='message-history-denied'
      BEGIN
        DELETE FROM raft_history_clock WHERE origin=OLD.origin AND principal=OLD.principal
          AND server=OLD.server AND NOT EXISTS (
            SELECT 1 FROM workspace_cache WHERE origin=OLD.origin AND principal=OLD.principal
              AND server=OLD.server AND kind IN ('message-history','message-history-denied'));
      END""",
    );
    await capacity.openNow();
  }

  @override
  Future<bool> wasEvicted(MessageHistoryScope scope, {BigInt? before, BigInt? after, String? target}) => order(() async {
    await _ready();
    final marker = await _marker(scope);
    if (marker == null || marker['authority'] != scope.authority || await _denial(scope) >= 0) return false;
    if (target != null) {
      final row = (await _existing(scope, [target]))[target];
      return row?.read<int>('tombstone') == 2 || row == null && marker['evictionSequence'] != null;
    }
    if (before == null && after == null) return false;
    final rows = await _query(
      'SELECT tombstone FROM raft_history_rows WHERE $_where AND seq_key${before != null ? '<' : '>'}? ORDER BY seq_key ${before != null ? 'DESC' : 'ASC'} LIMIT 1',
      [...scope.key, historySequenceKey(before ?? after!)],
    );
    return rows.isNotEmpty && rows.single.read<int>('tombstone') == 2;
  });

  @override
  Future<DateTime?> lastVerified(
    MessageHistoryScope scope,
    String queryKey,
  ) => order(() async {
    await _ready();
    final marker = await _marker(scope);
    if (marker == null ||
        marker['authority'] != scope.authority ||
        await _denial(scope) >= 0) {
      return null;
    }
    final rows = await _query(
      'SELECT verified FROM raft_history_checks WHERE $_where AND request=?',
      [...scope.key, queryKey],
    );
    return rows.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            rows.single.read<int>('verified'),
          );
  });

  @override
  Future<Map<String, Map<String, dynamic>?>> projections(
    MessageHistoryScope scope,
    Iterable<String> ids,
  ) => order(() async {
    await _ready();
    final marker = await _marker(scope);
    if (marker == null ||
        marker['authority'] != scope.authority ||
        await _denial(scope) >= 0) {
      return {};
    }
    final rows = await _existing(scope, ids);
    final live = rows.values
        .where((row) => row.read<int>('tombstone') == 0)
        .toList();
    final payloads = await decodeWorkspaceTranslations([
      for (final row in live) row.read<String>('payload'),
    ]);
    return {
      for (final row in rows.values.where(
        (row) => row.read<int>('tombstone') != 0,
      ))
        row.read<String>('message_id'): null,
      for (var i = 0; i < live.length; i++)
        live[i].read<String>('message_id'): payloads[i],
    };
  });

  @override
  Future<int> migrateLegacy(MessageHistoryScope scope, {int limit = 4}) =>
      order(() async {
        await _ready();
        if (limit < 1 || limit > 4) throw ArgumentError.value(limit, 'limit');
        dynamic progress;
        try {
          progress = await readLegacy(
            scope.origin,
            scope.principal,
            '',
            'message-history-migration',
            '',
          );
        } on FormatException {
          // A damaged progress record restarts bounded, idempotent imports.
        }
        final value = progress is Map ? progress['lastRowid'] : null;
        final cursor = value is int && value >= 0 ? value : 0;
        final batch = await _query(
          "SELECT rowid,server,kind,id,payload FROM workspace_cache WHERE origin=? AND principal=? AND kind IN ('window','thread-window') AND rowid>? ORDER BY rowid LIMIT ?",
          [scope.origin, scope.principal, cursor, limit],
        );
        if (batch.isEmpty) return 0;
        await db.transaction(() async {
          for (final row in batch) {
            dynamic value;
            try {
              value = await decodeWorkspaceCache(row.read<String>('payload'));
            } on FormatException {
              continue; // Preserve the bad record; do not pin the scan cursor.
            }
            if (value is! Map) continue;
            await _importWindow(
              scope.origin,
              scope.principal,
              row.read<String>('server'),
              row.read<String>('kind'),
              row.read<String>('id'),
              Map<String, dynamic>.from(value),
              migration: true,
            );
          }
          await writeLegacy(
            scope.origin,
            scope.principal,
            '',
            'message-history-migration',
            '',
            {'version': 1, 'lastRowid': batch.last.read<int>('rowid')},
          );
        });
        return batch.length;
      });

  @override
  Future<MessageHistoryScope?> knownScope(
    String origin,
    String principal,
    String server,
    String channel,
  ) => order(() async {
    await _ready();
    final probe = MessageHistoryScope(
      origin: origin,
      principal: principal,
      server: server,
      channel: channel,
      parentChannel: channel,
      authority: '',
    );
    final marker = await _marker(probe);
    if (marker == null) return null;
    final scope = MessageHistoryScope(
      origin: origin,
      principal: principal,
      server: server,
      channel: channel,
      parentChannel: marker['parentChannelId'] as String,
      authority: marker['authority'] as String,
      parentMessage: marker['parentMessageId'] as String?,
    );
    return await _denial(scope) >= 0 ? null : scope;
  });

  @override
  Future<List<(MessageHistoryScope, BigInt)>> savedRanges(String origin, String principal, String server) async {
    final candidates = await order(() async {
      await _ready();
      return _query('SELECT channel,min(seq_key) AS oldest FROM raft_history_rows WHERE origin=? AND principal=? AND server=? AND tombstone=0 GROUP BY channel', [origin, principal, server]);
    });
    final result = <(MessageHistoryScope, BigInt)>[];
    for (final row in candidates) {
      final scope = await knownScope(origin, principal, server, row.read<String>('channel'));
      if (scope != null) result.add((scope, BigInt.parse(row.read<String>('oldest'))));
    }
    return result;
  }

  @override
  Future<BigInt> resumeSequence(MessageHistoryScope scope) => order(() async {
    await _ready();
    final rows = await _query(
      'SELECT sequence FROM raft_history_resume WHERE origin=? AND principal=? AND server=?',
      [scope.origin, scope.principal, scope.server],
    );
    return rows.isEmpty
        ? BigInt.zero
        : BigInt.parse(rows.single.read<String>('sequence'));
  });

  @override
  Future<void> checkpoint(
    MessageHistoryScope scope,
    BigInt sequence, {
    bool initializeOnly = false,
  }) => order(() async {
    await _ready();
    sequence = receiver.checkpointLimit(scope, sequence);
    final pending = receiver.hasPending(scope);
    if (sequence <= BigInt.zero) return;
    if (scope.channel.isNotEmpty) {
      if (await _denial(scope) >= 0) return;
      final marker = await _marker(scope);
      if (marker == null || marker['authority'] != scope.authority) return;
    }
    await db.customStatement(
      'INSERT INTO raft_history_resume(origin,principal,server,sequence) VALUES(?,?,?,?) '
      '${initializeOnly && !pending ? 'ON CONFLICT DO NOTHING' : 'ON CONFLICT(origin,principal,server) DO UPDATE SET sequence=${pending ? 'min' : 'max'}(sequence,excluded.sequence)'}',
      [
        scope.origin,
        scope.principal,
        scope.server,
        historySequenceKey(sequence),
      ],
    );
  });

  Future<int> _denial(MessageHistoryScope scope) async {
    final rows = await _query(
      "SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND id IN (?,?)",
      [
        scope.origin,
        scope.principal,
        scope.server,
        denialKind,
        scope.channel,
        scope.parentChannel,
      ],
    );
    var revision = -1;
    for (final row in rows) {
      final value = await decodeWorkspaceCache(row.read<String>('payload'));
      final held = value is Map ? value['revision'] : null;
      if (held is int && held > revision) revision = held;
    }
    return revision;
  }

  /// Called inside the cache's ordered operation, never through a second queue.
  Future<void> revokeChannelNow(
    String origin,
    String principal,
    String server,
    String channel,
    Future<void> Function() purgeLegacy,
  ) async {
    await _ready();
    final probe = MessageHistoryScope(
      origin: origin,
      principal: principal,
      server: server,
      channel: channel,
      parentChannel: channel,
      authority: '',
    );
    final previous = await _revision(probe);
    final descendants = await _query(
      "SELECT id FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND json_extract(payload,'\$.parentChannelId')=?",
      [origin, principal, server, markerKind, channel],
    );
    final ids = {
      channel,
      for (final row in descendants) row.read<String>('id'),
    };
    await db.transaction(() async {
      await purgeLegacy();
      final revision = previous + 1;
      await db.customStatement(
        "INSERT INTO raft_history_clock(origin,principal,server,revision) VALUES(?,?,?,?) ON CONFLICT(origin,principal,server) DO UPDATE SET revision=max(revision,excluded.revision)",
        [origin, principal, server, revision],
      );
      for (final id in ids) {
        await db.customStatement(
          "INSERT INTO workspace_cache(origin,principal,server,kind,id,payload) VALUES(?,?,?,?,?,?) ON CONFLICT(origin,principal,server,kind,id) DO UPDATE SET payload=excluded.payload",
          [
            origin,
            principal,
            server,
            denialKind,
            id,
            jsonEncode({'revision': revision}),
          ],
        );
      }
      receiver.revokeScopes(origin, principal, server, ids);
    });
  }

  Future<Map<String, dynamic>?> _marker(MessageHistoryScope scope) async {
    final rows = await _query(
      'SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND id=?',
      [scope.origin, scope.principal, scope.server, markerKind, scope.channel],
    );
    if (rows.isEmpty) return null;
    final value = await decodeWorkspaceCache(
      rows.single.read<String>('payload'),
    );
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> _setMarker(
    MessageHistoryScope scope,
    Map<String, dynamic> value,
  ) async {
    final payload = await encodeWorkspaceCache(value);
    await db.customStatement(
      '''INSERT INTO workspace_cache
      (origin,principal,server,kind,id,payload) VALUES(?,?,?,?,?,?)
      ON CONFLICT(origin,principal,server,kind,id) DO UPDATE SET payload=excluded.payload''',
      [
        scope.origin,
        scope.principal,
        scope.server,
        markerKind,
        scope.channel,
        payload,
      ],
    );
  }

  Future<Map<String, dynamic>?> _scope(
    MessageHistoryScope scope, {
    bool create = false,
  }) async {
    var marker = await _marker(scope);
    var floor = (marker?['permissionFloor'] as int?) ?? 0;
    if (marker != null &&
        (marker['authority'] != scope.authority ||
            marker['parentChannelId'] != scope.parentChannel)) {
      floor = await _revision(scope) + 1;
      await db.customStatement(
        'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND id=?',
        [
          scope.origin,
          scope.principal,
          scope.server,
          markerKind,
          scope.channel,
        ],
      );
      await db.customStatement(
        'INSERT INTO raft_history_clock(origin,principal,server,revision) VALUES(?,?,?,?) ON CONFLICT(origin,principal,server) DO UPDATE SET revision=max(revision,excluded.revision)',
        [scope.origin, scope.principal, scope.server, floor],
      );
      marker = null;
    }
    if (marker == null && create) {
      marker = {
        'version': 1,
        'windowKind': 'tail',
        'authority': scope.authority,
        'channelId': scope.channel,
        'parentChannelId': scope.parentChannel,
        'hasMore': true,
        'historyLimited': false,
        'windowSize': 50,
        'permissionFloor': floor,
        if (scope.parentMessage != null) 'parentMessageId': scope.parentMessage,
        if (scope.parentMessage != null) 'threadChannelId': scope.channel,
      };
      await _setMarker(scope, marker);
    }
    return marker;
  }

  Future<int> _revision(
    MessageHistoryScope scope, {
    bool advance = false,
  }) async {
    final key = [scope.origin, scope.principal, scope.server];
    if (advance) {
      await db.customStatement(
        '''INSERT INTO raft_history_clock
        (origin,principal,server,revision) VALUES(?,?,?,1)
        ON CONFLICT(origin,principal,server) DO UPDATE SET revision=revision+1''',
        key,
      );
    }
    final rows = await _query(
      'SELECT revision FROM raft_history_clock WHERE origin=? AND principal=? AND server=?',
      key,
    );
    return rows.isEmpty ? 0 : rows.single.read<int>('revision');
  }

  @override
  Future<int> revision(MessageHistoryScope scope) => order(() async {
    await _ready();
    if (await _denial(scope) < 0) await _scope(scope, create: true);
    return _revision(scope);
  });

  @override
  Future<int> receiverRevision(MessageHistoryScope scope) => order(() async {
    await _ready();
    return _revision(scope);
  });

  Map<String, dynamic>? _valid(Map<String, dynamic> row, String channel) {
    if (row['id'] is! String || row['channelId'] != channel) return null;
    try {
      historySequenceKey(row['seq']);
    } on FormatException {
      return null;
    }
    return row;
  }

  Future<Map<String, QueryRow>> _existing(
    MessageHistoryScope scope,
    Iterable<String> ids,
  ) async {
    final unique = ids.toSet().toList(), result = <String, QueryRow>{};
    for (var start = 0; start < unique.length; start += 200) {
      final part = unique.skip(start).take(200).toList();
      final rows = await _query(
        'SELECT * FROM raft_history_rows WHERE $_where AND message_id IN (${List.filled(part.length, '?').join(',')})',
        [...scope.key, ...part],
      );
      for (final row in rows) {
        result[row.read<String>('message_id')] = row;
      }
    }
    return result;
  }

  Future<void> _put(
    MessageHistoryScope scope,
    Iterable<Map<String, dynamic>> values,
    int revision, {
    int? maximumPreviousRevision,
    bool onlyNew = false,
    bool updateOnly = false,
    bool complete = false,
  }) async {
    final incoming = [
      for (final row in values)
        if (_valid(row, scope.channel) != null) row,
    ];
    if (incoming.isEmpty) return;
    final existing = await _existing(
      scope,
      incoming.map((m) => m['id'] as String),
    );
    final evictionSequence = onlyNew ? ((await _marker(scope))?['evictionSequence'] as String?) : null;
    final previousIds = existing.keys.toList();
    final previousRows = complete
        ? const <Map<String, dynamic>>[]
        : await decodeWorkspaceTranslations([
            for (final id in previousIds) existing[id]!.read<String>('payload'),
          ]);
    final previous = {
      for (var i = 0; i < previousIds.length; i++)
        if (!complete) previousIds[i]: previousRows[i],
    };
    final accepted = <Map<String, dynamic>>[];
    for (final row in incoming) {
      final old = existing[row['id']];
      if (onlyNew && (old != null || evictionSequence != null && historySequenceKey(row['seq']).compareTo(evictionSequence) <= 0) ||
          updateOnly && (old == null || old.read<int>('tombstone') != 0)) {
        continue;
      }
      if (maximumPreviousRevision != null &&
          old != null &&
          old.read<int>('revision') > maximumPreviousRevision) {
        continue;
      }
      accepted.add(
        complete
            ? Map<String, dynamic>.from(row)
            : mergeMessageProjection(previous[row['id']], row),
      );
    }
    final payloads = await encodeWorkspaceTranslations(accepted);
    final sizes = [for (final payload in payloads) utf8.encode(payload).length];
    var added = 0;
    for (var i = 0; i < accepted.length; i++) {
      added +=
          sizes[i] - (existing[accepted[i]['id']]?.read<int>('byte_size') ?? 0);
    }
    await capacity.admitNow(scope, added);
    final touched = now().millisecondsSinceEpoch;
    await db.batch((batch) {
      for (var i = 0; i < accepted.length; i++) {
        final row = accepted[i], payload = payloads[i];
        batch.customStatement(
          '''INSERT INTO raft_history_rows
          ($_columns,message_id,seq_key,payload,revision,tombstone,byte_size,touched)
          VALUES(?,?,?,?,?,?,?,?,0,?,?)
          ON CONFLICT(origin,principal,server,channel,message_id) DO UPDATE SET
          seq_key=excluded.seq_key,payload=excluded.payload,revision=excluded.revision,
          tombstone=0,byte_size=excluded.byte_size,touched=excluded.touched''',
          [
            ...scope.key,
            row['id'],
            historySequenceKey(row['seq']),
            payload,
            revision,
            sizes[i],
            touched,
          ],
        );
      }
    });
    capacity.changed(scope, added);
    memory.changed();
  }

  @override
  Future<bool> acceptEvents(
    MessageHistoryScope scope,
    Iterable<Map<String, dynamic>> rows, {
    bool updateOnly = false,
    int? requestedRevision,
    bool live = false,
  }) => order(() async {
    await _ready();
    return db.transaction(() async {
      if (await _denial(scope) >= 0) return false;
      final previousMarker = await _marker(scope);
      if (requestedRevision != null &&
          (((previousMarker?['permissionFloor'] as int?) ?? 0) > requestedRevision ||
            ((previousMarker?['evictionRevision'] as int?) ?? 0) > requestedRevision)) {
        return false;
      }
      final marker = await _scope(scope, create: !updateOnly);
      if (marker == null) return false;
      final revision = await _revision(scope, advance: true);
      // A partial update can omit seq; merge it with the persisted projection.
      final materialized = <Map<String, dynamic>>[];
      final values = rows.toList();
      final old = await _existing(scope, values.map((m) => '${m['id']}'));
      for (final row in values) {
        final prior = old[row['id']];
        if (updateOnly &&
            (prior == null || prior.read<int>('tombstone') != 0)) {
          continue;
        }
        final decoded = prior == null
            ? null
            : await decodeWorkspaceCache(prior.read<String>('payload'));
        final merged = mergeMessageProjection(
          decoded is Map ? Map<String, dynamic>.from(decoded) : null,
          row,
        );
        if (_valid(merged, scope.channel) != null) materialized.add(merged);
      }
      if (!updateOnly && materialized.length != values.length) return false;
      await _put(scope, materialized, revision, updateOnly: updateOnly);
      var tail = BigInt.tryParse('${marker['tailSequence']}') ?? BigInt.zero;
      final follow = live && !updateOnly && marker['windowKind'] == 'tail';
      for (final row in materialized) {
        final next = BigInt.parse('${row['seq']}');
        if (follow && next > tail) {
          tail = await _extendTail(scope, tail, row);
        } else {
          final key = historySequenceKey(next);
          await _range(scope, key, key);
        }
      }
      if (!updateOnly && materialized.isNotEmpty) {
        final highest = materialized
            .map((m) => BigInt.parse('${m['seq']}'))
            .reduce((a, b) => a > b ? a : b);
        final tail =
            BigInt.tryParse('${marker['tailSequence']}') ?? BigInt.zero;
        await _setMarker(scope, {
          ...marker,
          'knownEmpty': false,
          'windowKind': 'tail',
          if (marker['windowKind'] == 'context')
            'tailFloor': historySequenceKey(highest),
          'tailSequence': '${highest > tail ? highest : tail}',
        });
      }
      await HistoryShadows(db).refresh(scope);
      return true;
    });
  });

  /// A row that arrives live after the saved tail. Sequences are server-wide,
  /// so a channel's own numbers are sparse, and its live room delivers every
  /// one of its messages in order: when the tail is proved through its own
  /// row, nothing else can sit between it and the new row, so the proof grows
  /// to cover it instead of leaving a gap for history to fill.
  Future<BigInt> _extendTail(
    MessageHistoryScope scope,
    BigInt tail,
    Map<String, dynamic> row,
  ) async {
    final next = BigInt.parse('${row['seq']}');
    // A row the device declined to keep cannot be covered by the proof.
    final flush =
        (await _query(
          'SELECT 1 FROM raft_history_rows WHERE $_where AND message_id=? AND tombstone=0',
          [...scope.key, row['id']],
        )).isNotEmpty &&
        (await _query(
          'SELECT 1 FROM raft_history_ranges WHERE $_where AND upper_key=?',
          [...scope.key, historySequenceKey(tail)],
        )).isNotEmpty;
    await _range(
      scope,
      historySequenceKey(flush ? tail + BigInt.one : next),
      historySequenceKey(next),
    );
    return next;
  }

  Future<void> _range(
    MessageHistoryScope scope,
    String lower,
    String upper,
  ) async {
    final before = await _query(
      'SELECT lower_key,upper_key,verified FROM raft_history_ranges WHERE $_where AND lower_key<=? ORDER BY lower_key DESC LIMIT 1',
      [...scope.key, lower],
    );
    final neighbours = <QueryRow>[
      if (before.isNotEmpty &&
          BigInt.parse(before.single.read<String>('upper_key')) >=
              BigInt.parse(lower) - BigInt.one)
        before.single,
      ...await _query(
        'SELECT lower_key,upper_key,verified FROM raft_history_ranges WHERE $_where AND lower_key>? AND lower_key<=? ORDER BY lower_key',
        [
          ...scope.key,
          lower,
          historySequenceKey(
            BigInt.parse(upper) == historyMaxSequence
                ? historyMaxSequence
                : BigInt.parse(upper) + BigInt.one,
          ),
        ],
      ),
    ];
    var verified = now().millisecondsSinceEpoch;
    for (final row in neighbours) {
      final lo = row.read<String>('lower_key'),
          hi = row.read<String>('upper_key');
      if (lo.compareTo(lower) < 0) lower = lo;
      if (hi.compareTo(upper) > 0) upper = hi;
      final stamp = row.read<int>('verified');
      if (stamp < verified) verified = stamp;
      await db.customStatement(
        'DELETE FROM raft_history_ranges WHERE $_where AND lower_key=? AND upper_key=?',
        [...scope.key, lo, hi],
      );
    }
    await db.customStatement(
      '''INSERT INTO raft_history_ranges
      ($_columns,lower_key,upper_key,verified) VALUES(?,?,?,?,?,?,?)
      ON CONFLICT(origin,principal,server,channel,lower_key,upper_key)
      DO UPDATE SET verified=excluded.verified''',
      [...scope.key, lower, upper, verified],
    );
    final unchanged = neighbours.length == 1 &&
      neighbours.single.read<String>('lower_key') == lower &&
      neighbours.single.read<String>('upper_key') == upper;
    if (!unchanged) _memoryZone.run(() => gaps.changed(scope));

  }

  @override
  Future<Map<String, dynamic>?> readContext(
    MessageHistoryScope scope,
    String messageId, {
    int radius = 15,
  }) => order(() async {
    await _ready();
    if (radius < 0 || radius > 100 || await _denial(scope) >= 0) return null;
    final marker = await _marker(scope);
    if (marker == null || marker['authority'] != scope.authority) return null;
    final target = await _existing(scope, [messageId]);
    final row = target[messageId];
    if (row == null || row.read<int>('tombstone') != 0) return null;
    final sequence = BigInt.parse(row.read<String>('seq_key'));
    final older = await _readPage(
      scope,
      before: sequence + BigInt.one,
      limit: radius + 1,
      fragments: radius == 0,
    );
    final newer = radius == 0
        ? null
        : await _readPage(
            scope,
            after: sequence,
            limit: radius,
            fragments: false,
          );
    if (radius > 0 && (older == null || newer == null)) return null;
    final targetRow = (await decodeWorkspaceTranslations([
      row.read<String>('payload'),
    ])).single;
    return MessageHistoryPage(
      {
        'messages': [
          if (older == null) targetRow else ...older.rows,
          ...?newer?.rows,
        ],
        'threadSummariesByParentMessageId': {
          ...await _summaries(scope, [targetRow]),
          ...?older?.summaries,
          ...?newer?.summaries,
        },
        'targetMessageId': messageId,
        'channelId': scope.channel,
        'hasOlder': older?.hasMore ?? true,
        'hasNewer': newer?.hasMore ?? true,
        'historyLimited': marker['historyLimited'] == true,
      },
      scope: scope,
      revision: row.read<int>('revision'),
      before: null,
      after: null,
      local: true,
      focused: true,
      target: messageId,
      verifiedAt: older?.verifiedAt ?? newer?.verifiedAt,
    );
  });

  @override
  Future<LocalMessageHistoryPage?> readPage(
    MessageHistoryScope scope, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) => order(() async {
    await _ready();
    return _readPage(scope, before: before, after: after, limit: limit);
  });

  Future<LocalMessageHistoryPage?> _readPage(
    MessageHistoryScope scope, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
    bool fragments = false,
  }) async {
    if (limit < 1 || limit > 500 || before != null && after != null) {
      throw ArgumentError('Invalid history page.');
    }
    if (await _denial(scope) >= 0) return null;
    final marker = await _scope(scope);
    if (marker == null) return null;
    if (marker['knownEmpty'] == true) {
      return LocalMessageHistoryPage(
        const [],
        hasMore: false,
        historyLimited: marker['historyLimited'] == true,
        verifiedAt: DateTime.fromMillisecondsSinceEpoch(
          (marker['verified'] as int?) ?? 0,
        ),
      );
    }
    final ordered = await _query(
      'SELECT seq_key FROM raft_history_rows WHERE $_where AND tombstone=0 ORDER BY seq_key DESC LIMIT 1',
      scope.key,
    );
    if (ordered.isEmpty) return null;
    final latest = ordered.single.read<String>('seq_key');
    final target = after != null
        ? historySequenceKey(after + BigInt.one)
        : before == null
        ? (after == null &&
                  marker['tailSequence'] is String &&
                  marker['tailSequence'] != '0'
              ? historySequenceKey(marker['tailSequence'])
              : latest)
        : historySequenceKey(before - BigInt.one);
    if (after != null && after >= BigInt.parse(latest)) {
      if (BigInt.tryParse('${marker['tailSequence']}') !=
          BigInt.parse(latest)) {
        return null;
      }
      return LocalMessageHistoryPage(
        const [],
        hasMore: false,
        historyLimited: marker['historyLimited'] == true,
        verifiedAt: DateTime.fromMillisecondsSinceEpoch(
          (marker['verified'] as int?) ?? 0,
        ),
      );
    }
    if (before == null && after == null) {
      if (marker['windowKind'] == 'context') return null;
      final rows = await _query(
        'SELECT payload,seq_key FROM raft_history_rows WHERE $_where AND tombstone=0 AND seq_key>=? AND seq_key<=? ORDER BY seq_key DESC,message_id DESC LIMIT ?',
        [
          ...scope.key,
          marker['tailFloor'] as String? ?? historySequenceKey(BigInt.zero),
          target,
          limit + 1,
        ],
      );
      final ranges = await _query(
        'SELECT lower_key,upper_key,verified FROM raft_history_ranges WHERE $_where AND lower_key<=? AND upper_key>=?',
        [...scope.key, historySequenceKey(BigInt.zero), target],
      );
      // Socket events prove individual rows, not continuity across sparse
      // sequence numbers. Present all retained tail rows without converting
      // those gaps into a successful cached pagination read.
      final complete = ranges.isNotEmpty;
      final stamp = complete ? ranges.single.read<int>('verified') : 0;
      final decoded = await decodeWorkspaceTranslations(
        rows.take(limit).map((r) => r.read<String>('payload')).toList().reversed.toList(),
      );
      await _touchRows(scope, decoded);
      return LocalMessageHistoryPage(
        decoded,
        hasMore:
            marker['historyLimited'] != true &&
            (rows.length > limit || !complete),
        historyLimited: marker['historyLimited'] == true,
        verifiedAt: DateTime.fromMillisecondsSinceEpoch(stamp),
        summaries: await _summaries(scope, decoded),
      );
    }
    // Stored intervals are disjoint and non-adjacent. The nearest preceding
    // lower bound is the only interval that can cover this cursor; do not
    // load every sparse event interval into the UI isolate.
    final ranges = await _query(
      'SELECT lower_key,upper_key,verified FROM raft_history_ranges WHERE $_where AND lower_key<=? ORDER BY lower_key DESC LIMIT 1',
      [...scope.key, target],
    );
    if (ranges.isEmpty) return null;
    final range = ranges.single;
    final lower = range.read<String>('lower_key'),
        high = range.read<String>('upper_key');
    if (high.compareTo(target) < 0) return null;
    final verified = range.read<int>('verified');
    final forward = after != null;
    final rows = await _query(
      'SELECT payload FROM raft_history_rows WHERE $_where AND tombstone=0 AND seq_key>=? AND seq_key<=? ORDER BY seq_key ${forward ? 'ASC' : 'DESC'},message_id ${forward ? 'ASC' : 'DESC'} LIMIT ?',
      [
        ...scope.key,
        forward ? target : lower,
        forward ? high : target,
        limit + 1,
      ],
    );
    final hasMore =
        marker['historyLimited'] != true &&
        (rows.length > limit ||
            (forward
                ? high.compareTo(latest) < 0
                : BigInt.parse(lower) > BigInt.zero));
    // A short fragment before an unproven gap is not a complete requested
    // page. Fetch that range instead of turning the fragment into a false end.
    if (!fragments &&
        (before != null || after != null) &&
        rows.length < limit &&
        hasMore) {
      return null;
    }
    final payloads = rows
        .take(limit)
        .map((r) => r.read<String>('payload'))
        .toList();
    final decoded = await decodeWorkspaceTranslations(
      forward ? payloads : payloads.reversed.toList(),
    );
    await _touchRows(scope, decoded);
    return LocalMessageHistoryPage(
      decoded,
      hasMore: hasMore,
      historyLimited: marker['historyLimited'] == true,
      verifiedAt: DateTime.fromMillisecondsSinceEpoch(verified),
      summaries: await _summaries(scope, decoded),
    );
  }

  /// Reply previews of the parents among [rows], read with the rows.
  Future<Map<String, dynamic>> _summaries(
    MessageHistoryScope scope,
    Iterable<Map<String, dynamic>> rows,
  ) => SqliteHistorySummaries.read(
    db,
    scope.origin,
    scope.principal,
    scope.server,
    scope.channel,
    rows.map((row) => row['id']),
  );

  @override
  Future<void> saveSummaries(
    MessageHistoryScope scope,
    Map<String, dynamic> summaries,
  ) => order(() async {
    await _ready();
    final marker = await _marker(scope);
    if (marker == null ||
        marker['authority'] != scope.authority ||
        await _denial(scope) >= 0) {
      return;
    }
    await db.transaction(
      () => SqliteHistorySummaries.write(db, scope, summaries),
    );
  });

  Future<void> _touchRows(MessageHistoryScope scope, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final stamp = now().millisecondsSinceEpoch;
    // Repeated paints/reads do not cause a write for every cache hit.
    await db.customStatement(
      'UPDATE raft_history_rows SET touched=? WHERE $_where AND touched<? AND message_id IN (${List.filled(rows.length, '?').join(',')})',
      [stamp, ...scope.key, stamp - const Duration(minutes: 1).inMilliseconds,
        for (final row in rows) row['id']],
    );
  }

  @override
  Future<Map<String, dynamic>> reconcilePage(
    MessageHistoryScope scope,
    Map<String, dynamic> page, {
    required int requestedRevision,
    BigInt? before,
    BigInt? after,
    bool focused = false,
  }) => order(() async {
    await _ready();
    final marker = await _marker(scope);
    if (marker == null ||
        marker['authority'] != scope.authority ||
        await _denial(scope) >= 0) {
      return page;
    }
    if (((marker['evictionRevision'] as int?) ?? 0) > requestedRevision) {
      throw const HistoryReadRetired();
    }
    final rows = page['messages'];
    if (rows is! List) return page;
    final values = [
      for (final m in rows)
        if (m is Map) Map<String, dynamic>.from(m),
    ];
    final previous = await _existing(scope, values.map((m) => '${m['id']}'));
    final merged = <Map<String, dynamic>>[];
    for (final row in values) {
      final current = previous[row['id']];
      if (current != null &&
          current.read<int>('revision') > requestedRevision) {
        if (current.read<int>('tombstone') == 0) {
          merged.add(
            Map<String, dynamic>.from(
              await decodeWorkspaceCache(current.read<String>('payload'))
                  as Map,
            ),
          );
        }
      } else {
        merged.add(row);
      }
    }
    final seqs = values.map((m) => BigInt.parse('${m['seq']}')).toList()
      ..sort();
    final lower = after != null
        ? after + BigInt.one
        : seqs.isEmpty
        ? BigInt.zero
        : seqs.first;
    final upper = before != null
        ? before - BigInt.one
        : focused
        ? seqs.isEmpty
              ? BigInt.zero
              : seqs.last
        : historyMaxSequence;
    final arrivals = await _query(
      'SELECT payload FROM raft_history_rows WHERE $_where AND revision>? AND tombstone=0 AND seq_key>=? AND seq_key<=? ORDER BY seq_key',
      [
        ...scope.key,
        requestedRevision,
        historySequenceKey(lower),
        historySequenceKey(upper),
      ],
    );
    final ids = merged.map((m) => m['id']).toSet();
    for (final row in await decodeWorkspaceTranslations(
      arrivals.map((r) => r.read<String>('payload')).toList(),
    )) {
      if (ids.add(row['id'])) merged.add(row);
    }
    merged.sort(
      (a, b) =>
          BigInt.parse('${a['seq']}').compareTo(BigInt.parse('${b['seq']}')),
    );
    return {...page, 'messages': merged};
  });

  @override
  Future<void> acceptPage(MessageHistoryPage page) => order(() async {
    if (page.local) return;
    await _ready();
    await db.transaction(() async {
      final scope = page.scope;
      final deniedAt = await _denial(scope);
      if (deniedAt > page.revision) return;
      final existing = await _marker(scope);
      if (((existing?['evictionRevision'] as int?) ?? 0) > page.revision) return;
      if (existing != null &&
          (existing['authority'] != scope.authority ||
              ((existing['permissionFloor'] as int?) ?? 0) > page.revision)) {
        return;
      }
      final marker = await _scope(scope, create: true);
      await db.customStatement(
        'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND id IN (?,?)',
        [
          scope.origin,
          scope.principal,
          scope.server,
          denialKind,
          scope.channel,
          scope.parentChannel,
        ],
      );
      final remote = page.remotePage ?? page;
      final raw = remote['messages'];
      if (raw is! List) return;
      final rows = [
        for (final m in raw)
          if (m is Map &&
              _valid(Map<String, dynamic>.from(m), scope.channel) != null)
            Map<String, dynamic>.from(m),
      ];
      if (rows.length != raw.length) return;
      final revision = await _revision(scope, advance: true);
      final sequences = rows.map((m) => BigInt.parse('${m['seq']}')).toList()
        ..sort();
      final limited = remote['historyLimited'] == true;
      final exhausted =
          !limited &&
          (page.focused
              ? remote['hasOlder'] == false
              : rows.length < page.limit);
      final lower = page.after != null
          ? page.after! + BigInt.one
          : exhausted
          ? BigInt.zero
          : sequences.isEmpty
          ? BigInt.zero
          : sequences.first;
      final upper = page.before != null
          ? page.before! - BigInt.one
          : sequences.isEmpty
          ? BigInt.zero
          : sequences.last;
      final deleteUpper =
          !page.focused && page.before == null && page.after == null
          ? historyMaxSequence
          : upper;
      final localRange = limited ? const <QueryRow>[] : await _query(
        'SELECT payload FROM raft_history_rows WHERE $_where AND tombstone=0 AND seq_key>=? AND seq_key<=? ORDER BY seq_key LIMIT ?',
        [...scope.key, historySequenceKey(lower), historySequenceKey(deleteUpper), rows.length + 1],
      );
      final localBodies = await decodeWorkspaceTranslations(localRange.map((r) => r.read<String>('payload')).toList());
      final unchanged = !limited && HistoryRangeDigest(rows).matches(HistoryRangeDigest(localBodies));
      if (limited) {
        await db.customStatement(
          'DELETE FROM raft_history_rows WHERE $_where',
          scope.key,
        );
        await db.customStatement(
          'DELETE FROM raft_history_ranges WHERE $_where',
          scope.key,
        );
      } else if (!unchanged) {
        final ids = rows.map((m) => m['id'] as String).toList();
        final except = ids.isEmpty
            ? ''
            : ' AND message_id NOT IN (${List.filled(ids.length, '?').join(',')})';
        await db.customStatement(
          "UPDATE raft_history_rows SET tombstone=1,revision=?,payload='{}',byte_size=0 WHERE $_where AND seq_key>=? AND seq_key<=? AND revision<=?$except",
          [
            revision,
            ...scope.key,
            historySequenceKey(lower),
            historySequenceKey(deleteUpper),
            page.revision,
            ...ids,
          ],
        );
      }
      if (!unchanged) {
        await _put(
          scope, rows, revision,
          maximumPreviousRevision: limited ? null : page.revision,
          complete: true,
        );
        await HistoryShadows(db).refresh(scope);
      }
      // The page is the authority for the parents it carries: a parent
      // without a summary here has none now. A response without the field
      // (older server) says nothing either way.
      final wireSummaries = remote['threadSummariesByParentMessageId'];
      if (wireSummaries is Map && scope.parentMessage == null) {
        await SqliteHistorySummaries.write(
          db,
          scope,
          wireSummaries,
          absent: [for (final row in rows) row['id'] as String],
        );
      }
      if (lower <= upper) {
        await _range(
          scope,
          historySequenceKey(lower),
          historySequenceKey(upper),
        );
      }
      await _setMarker(scope, {
        ...?marker,
        'permissionFloor':
            deniedAt > ((marker?['permissionFloor'] as int?) ?? 0)
            ? deniedAt
            : ((marker?['permissionFloor'] as int?) ?? 0),
        'historyLimited': limited,
        if (!page.focused && page.before == null && page.after == null)
          'tailSequence': sequences.isEmpty ? '0' : '${sequences.last}',
        if (!page.focused && page.before == null && page.after == null)
          'windowKind': 'tail',
        if (!page.focused && page.before == null && page.after == null)
          'tailFloor': null,
        if (page.focused && marker?['tailSequence'] == null)
          'windowKind': 'context',
        'knownEmpty':
            !page.focused &&
            rows.isEmpty &&
            page.before == null &&
            page.after == null,
        'verified': now().millisecondsSinceEpoch,
      });
      await db.customStatement(
        '''INSERT INTO raft_history_checks ($_columns,request,verified)
        VALUES(?,?,?,?,?,?) ON CONFLICT(origin,principal,server,channel,request)
        DO UPDATE SET verified=excluded.verified''',
        [...scope.key, page.queryKey, now().millisecondsSinceEpoch],
      );
    });
  });

  @override
  Future<void> importWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    Map<String, dynamic> snapshot,
  ) => order(() async {
    await _ready();
    await _importWindow(origin, principal, server, kind, id, snapshot);
  });

  Future<bool> _importWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    Map<String, dynamic> snapshot, {
    bool migration = false,
  }) async {
    final channel = kind == 'thread-window' ? snapshot['threadChannelId'] : id;
    final authority = snapshot['authority'],
        parent = snapshot['parentChannelId'];
    final raw = snapshot['messages'];
    if (channel is! String ||
        authority is! String ||
        parent is! String ||
        raw is! List ||
        snapshot['windowKind'] != 'tail' ||
        snapshot['version'] != 1 ||
        kind == 'window' && parent != channel) {
      return false;
    }
    // Generic workspace-cache values do not carry the message-window
    // contract. Keep their original codec/size semantics on the legacy path.
    if (raw.any(
      (row) =>
          row is! Map ||
          row.keys.any((key) => key is! String) ||
          _valid(Map<String, dynamic>.from(row), channel) == null,
    )) {
      return false;
    }
    final scope = MessageHistoryScope(
      origin: origin,
      principal: principal,
      server: server,
      channel: channel,
      parentChannel: parent,
      authority: authority,
      parentMessage: kind == 'thread-window' ? id : null,
    );
    final existing = await _marker(scope);
    if (await _denial(scope) >= 0 ||
        existing != null && (migration || existing['authority'] != authority)) {
      return false;
    }
    await db.transaction(() async {
      final marker = await _scope(scope, create: true);
      await _put(
        scope,
        [
          for (final m in raw)
            if (m is Map) Map<String, dynamic>.from(m),
        ],
        await _revision(scope, advance: true),
        onlyNew: true,
      );
      // Reply previews live beside their parent rows, not in the marker.
      // A marker from before the table moves its previews over first.
      if (kind == 'window') {
        for (final held in [
          marker?['threadSummaries'],
          snapshot['threadSummaries'],
        ]) {
          if (held is Map) await SqliteHistorySummaries.write(db, scope, held);
        }
      }
      await _setMarker(
        scope,
        {
          ...?marker,
          ...snapshot,
          'messages': <dynamic>[],
          'windowSize': raw.length.clamp(50, 500),
          'channelId': channel,
          if (kind == 'thread-window') 'parentMessageId': id,
        }..remove('threadSummaries'),
      );
    });
    return true;
  }

  /// The new client supplies all accepted rows; the rollback snapshot keeps
  /// its original 500-row bound and legacy window-count eviction policy.
  Future<void> writeWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) => order(() async {
    await _ready();
    if (value is Map) {
      final snapshot = Map<String, dynamic>.from(value);
      final channel = kind == 'thread-window'
          ? snapshot['threadChannelId']
          : id;
      final parent = snapshot['parentChannelId'];
      if (channel is String && parent is String) {
        final probe = MessageHistoryScope(
          origin: origin,
          principal: principal,
          server: server,
          channel: channel,
          parentChannel: parent,
          authority: '${snapshot['authority']}',
        );
        final marker = await _marker(probe);
        if (await _denial(probe) >= 0 ||
            marker != null && marker['authority'] != snapshot['authority']) {
          return;
        }
      }
      final indexed = await _importWindow(
        origin,
        principal,
        server,
        kind,
        id,
        snapshot,
      );
      final rows = snapshot['messages'];
      if (indexed && rows is List && rows.length > 500) {
        value = {
          ...snapshot,
          'messages': rows.skip(rows.length - 500).toList(),
        };
      }
    }
    if (value == null) {
      await writeLegacy(origin, principal, server, kind, id, value);
    } else {
      await db.transaction(() async {
        await db.customStatement(
          'INSERT INTO raft_history_compat_write VALUES(?,?,?)',
          [origin, principal, server],
        );
        await writeLegacy(origin, principal, server, kind, id, value);
        await db.customStatement(
          'DELETE FROM raft_history_compat_write WHERE origin=? AND principal=? AND server=?',
          [origin, principal, server],
        );
      });
    }
  });

  @override
  Future<Map<String, dynamic>?> readWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) => order(() async {
    await _ready();
    _scheduleMigration(
      MessageHistoryScope(
        origin: origin,
        principal: principal,
        server: server,
        channel: id,
        parentChannel: id,
        authority: '',
      ),
    );
    Future<Map<String, dynamic>?> markerWindow() async {
      final records = await _query(
        "SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND ${kind == 'window' ? 'id=?' : "json_extract(payload,'\$.parentMessageId')=?"}",
        [origin, principal, server, markerKind, id],
      );
      if (records.length != 1) return null;
      final marker = Map<String, dynamic>.from(
        await decodeWorkspaceCache(records.single.read<String>('payload'))
            as Map,
      );
      final scope = MessageHistoryScope(
        origin: origin,
        principal: principal,
        server: server,
        channel: marker['channelId'] as String,
        parentChannel: marker['parentChannelId'] as String,
        authority: marker['authority'] as String,
      );
      final local = await _readPage(
        scope,
        limit: (marker['windowSize'] as int?) ?? 50,
      );
      return local == null
          ? null
          : {
              ...marker,
              'messages': local.rows,
              'hasMore': local.hasMore,
              'historyLimited': local.historyLimited,
              // Markers written before previews had their own table still
              // carry them; the table wins where it has the parent.
              'threadSummaries': {
                if (marker['threadSummaries'] case final Map old)
                  ...Map<String, dynamic>.from(old),
                ...local.summaries,
              },
            };
    }

    // A migrated conversation reads indexed rows without decoding its entire
    // 500-row rollback snapshot on every visit.
    final present = await markerWindow();
    if (present != null) return present;
    final legacy = await readLegacy(origin, principal, server, kind, id);
    if (legacy is! Map) return null;
    final channel = kind == 'thread-window' ? legacy['threadChannelId'] : id;
    final parent = legacy['parentChannelId'];
    if (channel is! String || parent is! String) {
      return Map<String, dynamic>.from(legacy);
    }
    final scope = MessageHistoryScope(
      origin: origin,
      principal: principal,
      server: server,
      channel: channel,
      parentChannel: parent,
      authority: '${legacy['authority']}',
    );
    if (await _denial(scope) >= 0) return null;
    await _importWindow(
      origin,
      principal,
      server,
      kind,
      id,
      Map<String, dynamic>.from(legacy),
      migration: true,
    );
    return await markerWindow() ?? Map<String, dynamic>.from(legacy);
  });

  /// The single SELECT uses a read executor; it cannot observe partial writes.
  Future<CommittedHistoryWindow?> peekCommittedWindow(
    String origin, String principal, String server, String kind, String id,
  ) async {
    final positionsUnchanged = _positions.unchangedGuard();
    await _ready();
    _scheduleMigration(MessageHistoryScope(origin: origin, principal: principal,
      server: server, channel: id, parentChannel: id, authority: ''));
    return SqliteCommittedHistoryReads.read(db, origin, principal, server, kind, id,
      positionsUnchanged: positionsUnchanged);
  }

  /// Retain IDs only while queued. LRU maintenance must not delay first paint.
  void touchCommittedWindow(MessageHistoryScope scope, List<String> ids,
      {required bool Function() current}) {
    if (ids.isEmpty || _closed) return;
    unawaited(order(() async {
      if (_closed || !current()) return;
      final stamp = now().millisecondsSinceEpoch;
      await db.customStatement(
        'UPDATE raft_history_rows SET touched=? WHERE $_where AND touched<? AND message_id IN (${List.filled(ids.length, '?').join(',')})',
        [stamp, ...scope.key, stamp - const Duration(minutes: 1).inMilliseconds, ...ids],
      );
    }).catchError((Object _) { /* Best-effort LRU; the read is already accepted. */ }));
  }
}
