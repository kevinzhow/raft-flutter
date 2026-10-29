import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:raft_ui/raft_ui.dart' show RaftIdleTimer;

import '../data/history_capacity.dart';
import '../data/message_history.dart';
import '../data/workspace_cache_codec.dart';
import 'message_history.dart' show HistoryOperationOrder;
import 'history_size_counters.dart';
import 'history_evictions.dart';
import 'history_retention.dart';
import 'device_storage.dart';

/// Retention shares the message connection, permission purges and revision
/// fence. Encoded row/key weights include a conservative allocation reserve;
/// [HistoryDiskUsage.databaseBytes] and WAL bytes are actual file sizes.
class SqliteHistoryCapacity implements HistoryCapacity {
  SqliteHistoryCapacity(
    this.db,
    this.order, {
    required this.ready,
    required this.advance,
    required this.now,
    required this.defaultBudget,
    this.automatic = true,
    this.hardLimitEnabled = true,
    this.pending,
    this.availableSpace = availableDeviceStorage,
    this.coverageChanged,
  });
  final GeneratedDatabase db;
  final HistoryOperationOrder order;
  final Future<void> Function() ready;
  final Future<int> Function(MessageHistoryScope) advance;
  final DateTime Function() now;
  final int defaultBudget;
  final bool automatic, hardLimitEnabled;
  final Future<int?> Function(String path) availableSpace;
  final void Function()? coverageChanged;
  late final _counters = HistorySizeCounters(db);
  late final _retention = HistoryRetention(db, now);
  Future<void>? _initializing;
  final _retries = <HistoryAccount, int>{};
  final _retryTimers = <HistoryAccount, RaftIdleTimer>{};
  final Iterable<HistoryProtectedRows> Function()? pending;
  final _owners = <Object, Iterable<HistoryProtectedRows> Function()>{};
  final _pending = <HistoryAccount>{};
  final _dirty = <HistoryAccount, int>{};
  final _blocked = <HistoryAccount>{};
  final _hardFull = <HistoryAccount>{};
  final _refusedBytes = <HistoryAccount, int>{};
  final _unavailable = <HistoryAccount>{};
  final _maintenance = <HistoryAccount, Future<HistoryDiskUsage>>{};
  // Writes call changed() from a Drift transaction zone. A timer created in
  // that zone would later reuse its closed executor. Capture the store's
  // outer zone before any write transaction starts.
  final _backgroundZone = Zone.current;
  final _timer = RaftIdleTimer(yieldToAnimation: false);
  bool _closed = false;
  static const walLimit = 16 << 20;
  static const _scopeWhere =
      'origin=? AND principal=? AND server=? AND channel=?';

  List<Variable> _vars(Iterable<Object> values) => [
    for (final value in values)
      if (value is int) Variable(value) else Variable('$value'),
  ];
  Future<List<QueryRow>> _query(String sql, Iterable<Object> args) =>
      db.customSelect(sql, variables: _vars(args)).get();

  /// Constant-time connection setup; old counters backfill in bounded chunks.
  Future<void> openNow() async {
    await db.customStatement('PRAGMA wal_autocheckpoint=256');
    await db.customStatement('PRAGMA journal_size_limit=$walLimit');
    await _counters.openNow();
    await _retention.migrateNow();
    await db.customStatement(
      '''CREATE TEMP TABLE IF NOT EXISTS history_protected (
      server TEXT NOT NULL, channel TEXT NOT NULL, id TEXT NOT NULL,
      PRIMARY KEY(server,channel,id))''',
    );
    await db.customStatement(
      '''CREATE TEMP TABLE IF NOT EXISTS history_protected_scopes (
      server TEXT NOT NULL, channel TEXT NOT NULL, PRIMARY KEY(server,channel))''',
    );
  }

  Future<void> _initialize() => _initializing ??= () async {
    while (!_closed) {
      final done = await order(() async {
        await ready();
        return _counters.backfillNow();
      });
      if (done) return;
      // The queue is free here: pages, drafts and permission purges can pass.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw StateError('History maintenance retired.');
  }().whenComplete(() => _initializing = null);

  @override
  void protect(
    Object owner,
    Iterable<HistoryProtectedRows> Function() current,
  ) => _owners[owner] = current;
  @override
  void release(Object owner) {
    _owners.remove(owner);
    for (final account in {..._blocked, ..._unavailable}) {
      _retryLater(account, immediate: true);
    }
  }

  void close() {
    _closed = true;
    _timer.cancel();
    _pending.clear();
    _dirty.clear();
    _blocked.clear();
    _hardFull.clear();
    _refusedBytes.clear();
    _unavailable.clear();
    _maintenance.clear();
    _retries.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _owners.clear();
  }

  void cancel(HistoryAccount account) {
    _pending.remove(account);
    _dirty.remove(account);
    _blocked.remove(account);
    _hardFull.remove(account);
    _refusedBytes.remove(account);
    _unavailable.remove(account);
    _maintenance.remove(account);
    _retries.remove(account);
    _retryTimers.remove(account)?.cancel();
    if (_pending.isEmpty) _timer.cancel();
  }

  Future<void> admitNow(MessageHistoryScope scope, int addedBytes) async {
    if (hardLimitEnabled && addedBytes > 0) {
      final account = HistoryAccount(scope.origin, scope.principal);
      final usage = await _usageNow(account, physical: false);
      final free = await availableSpace(await _pathNow());
      if (usage.budget > 0 &&
              usage.retainedCharge + (addedBytes * 3 + 1) ~/ 2 >
                  usage.budget * 3 ~/ 2 ||
          free != null && free - addedBytes < (1 << 30)) {
        _hardFull.add(account);
        _refusedBytes[account] = addedBytes;
        throw const HistoryCapacityExceeded();
      }
      _hardFull.remove(account);
      _refusedBytes.remove(account);
    }
    if (addedBytes > 0 &&
        _blocked.contains(HistoryAccount(scope.origin, scope.principal))) {
      final a = HistoryAccount(scope.origin, scope.principal);
      final liveHold = [..._owners.values, ?pending].any(
        (read) => read().any(
          (s) =>
              s.account == a &&
              s.server == scope.server &&
              s.channel == scope.channel &&
              s.wholeChannel,
        ),
      );
      if (liveHold || await _retention.holdsNow(scope)) return;
      _retryLater(a);
      throw const HistoryCapacityExceeded();
    }
  }

  /// New body data schedules accounting. Failures use bounded retry backoff.
  void changed(MessageHistoryScope scope, int bytes) {
    if (_closed) return;
    final account = HistoryAccount(scope.origin, scope.principal);
    final previous = _dirty[account];
    final total = _dirty[account] = (previous ?? 0) + math.max(0, bytes);
    if (automatic && (previous == null || total >= (8 << 20))) {
      _pending.add(account);
      if (!_timer.isActive) _schedule();
    }
  }

  void _schedule([Duration delay = const Duration(seconds: 1)]) =>
      _backgroundZone.run(() => _timer.start(delay, _next));

  void _retryLater(HistoryAccount account, {bool immediate = false}) {
    if (_closed || !automatic) return;
    final timer = _retryTimers.putIfAbsent(
      account,
      () => RaftIdleTimer(yieldToAnimation: false),
    );
    if (!immediate && timer.isActive) return;
    final attempt = immediate ? 0 : (_retries[account] ?? 0);
    _retries[account] = math.min(5, attempt + 1);
    final delay = Duration(seconds: immediate ? 1 : math.min(60, 2 << attempt));
    _backgroundZone.run(
      () => timer.start(delay, () async {
        if (_closed) return;
        try {
          await maintain(account);
        } catch (_) {
          // maintain schedules the next bounded retry. Other accounts retain
          // their own write-driven timer and do not wait for this backoff.
        }
      }),
    );
  }

  void _next() async {
    if (_closed || _pending.isEmpty) return;
    final account = _pending.first;
    _pending.remove(account);
    try {
      await maintain(account);
    } catch (_) {
      // Accepted rows and drafts stay; failed maintenance schedules a retry.
    }
    if (!_closed && _pending.isNotEmpty) {
      if (!_timer.isActive) _schedule();
    }
  }

  Future<int> _budgetNow(HistoryAccount a) async {
    final rows = await _query(
      "SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server='' AND kind='history-budget' AND id=''",
      [a.origin, a.principal],
    );
    if (rows.isEmpty) return defaultBudget;
    final value = await decodeWorkspaceCache(
      rows.single.read<String>('payload'),
    );
    return value is int && historyBudgetTiers.contains(value)
        ? value
        : defaultBudget;
  }

  @override
  Future<void> setBudget(HistoryAccount a, int bytes) async {
    if (!historyBudgetTiers.contains(bytes)) {
      throw ArgumentError.value(bytes, 'bytes');
    }
    await order(() async {
      await ready();
      await db.customStatement(
        "INSERT INTO workspace_cache VALUES(?,?,'','history-budget','',?) ON CONFLICT(origin,principal,server,kind,id) DO UPDATE SET payload=excluded.payload",
        [a.origin, a.principal, '$bytes'],
      );
    });
    await maintain(a);
  }

  @override
  Future<void> opened(HistoryAccount a, String server, String channel) =>
      order(() async {
        await ready();
        await _retention.openedNow(a, server, channel);
      });

  @override
  Future<bool> isKept(HistoryAccount a, String server, String channel) =>
      order(() async {
        await ready();
        return (await _query(
          "SELECT 1 FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind='history-kept' AND id=?",
          [a.origin, a.principal, server, channel],
        )).isNotEmpty;
      });
  @override
  Future<void> keep(
    HistoryAccount a,
    String server,
    String channel,
    bool value,
  ) => order(() async {
    await ready();
    if (value) {
      await db.customStatement(
        "INSERT OR IGNORE INTO workspace_cache VALUES(?,?,?,'history-kept',?,'true')",
        [a.origin, a.principal, server, channel],
      );
    } else {
      await db.customStatement(
        "DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind='history-kept' AND id=?",
        [a.origin, a.principal, server, channel],
      );
    }
  });

  @override
  Future<HistoryDiskUsage> usage(HistoryAccount a) async {
    await _initialize();
    final facts = await order(
      () async => (await _usageNow(a), await _pathNow()),
    );
    if (!hardLimitEnabled) return facts.$1;
    final free = await availableSpace(facts.$2);
    final refused = _refusedBytes[a] ?? 0;
    final full =
        facts.$1.budget > 0 &&
            facts.$1.retainedCharge + (refused * 3 + 1) ~/ 2 >=
                facts.$1.budget * 3 ~/ 2 ||
        free != null && free - refused < (1 << 30);
    if (!full) _hardFull.remove(a);
    return facts.$1.withProtectedFull(facts.$1.protectedFull, hardFull: full);
  }

  Future<HistoryDiskUsage> _usageNow(
    HistoryAccount a, {
    bool physical = true,
    bool protectedFull = false,
  }) async {
    final sizes = await _query(
      'SELECT * FROM raft_history_sizes WHERE origin=? AND principal=?',
      [a.origin, a.principal],
    );
    final shadows = await _query(
      'SELECT weight FROM raft_history_cache_sizes WHERE origin=? AND principal=?',
      [a.origin, a.principal],
    );
    final weight = sizes.isEmpty ? 0 : sizes.single.read<int>('weight');
    final payload = sizes.isEmpty ? 0 : sizes.single.read<int>('payload');
    final shadow = shadows.isEmpty ? 0 : shadows.single.read<int>('weight');
    // A conservative allocation reserve covers B-tree/index overhead without
    // scanning the entire shared file. This is an estimate, not exact account
    // ownership of shared pages. Main-file/WAL sizes are displayed separately.
    final estimate = math.max(0, (3 * (weight + shadow) + 1) ~/ 2);
    final budget = await _budgetNow(a);
    final reserve = estimate == 0
        ? 0
        : math.min(walLimit, budget == 0 ? walLimit : budget ~/ 64);
    Future<int> pragma(String name) async =>
        (await _query('PRAGMA $name', [])).single.data.values.single as int;
    final pageSize = await pragma('page_size');
    final free = await pragma('freelist_count') * pageSize;
    var database = 0, wal = 0;
    if (physical) {
      database = await pragma('page_count') * pageSize;
      final path = await _pathNow();
      if (path.isNotEmpty) {
        database = await File(path).length();
        final log = File('$path-wal');
        if (await log.exists()) wal = await log.length();
      }
    }
    return HistoryDiskUsage(
      budget: budget,
      accountBytes: estimate,
      reservedWalBytes: reserve,
      databaseBytes: database,
      walBytes: wal,
      indexBytes: math.max(0, (3 * (weight - payload) + 1) ~/ 2),
      freeBytes: free,
      rows: sizes.isEmpty ? 0 : sizes.single.read<int>('rows'),
      pendingCompaction: free > 0,
      protectedFull: protectedFull || _blocked.contains(a),
      hardFull: _hardFull.contains(a),
    );
  }

  Future<String> _pathNow() async => (await _query('PRAGMA database_list', []))
      .where((row) => row.read<String>('name') == 'main')
      .single
      .read<String>('file');

  @override
  Future<HistoryCompactionPlan> compactionPlan(HistoryAccount a) async {
    await _initialize();
    final facts = await order(() async {
      final path = await _pathNow();
      final mode =
          (await _query('PRAGMA auto_vacuum', [])).single.data.values.single
              as int;
      final size = await _usageNow(a);
      return (path, mode, size.databaseBytes, size.walBytes);
    });
    final full = facts.$1.isNotEmpty && facts.$2 == 0;
    return HistoryCompactionPlan(
      fullVacuum: full,
      requiredBytes: full ? 2 * facts.$3 + facts.$4 + (64 << 20) : 0,
      availableBytes: full ? await availableSpace(facts.$1) : null,
    );
  }

  @override
  Future<HistoryDiskUsage> maintain(
    HistoryAccount a, {
    bool compact = false,
    bool allowFullVacuum = false,
  }) {
    final running = _maintenance[a];
    if (running != null) {
      return compact
          ? running.then(
              (_) =>
                  maintain(a, compact: true, allowFullVacuum: allowFullVacuum),
            )
          : running;
    }
    late final Future<HistoryDiskUsage> result;
    bool current() => !_closed && identical(_maintenance[a], result);
    result =
        _maintain(
          a,
          compact: compact,
          allowFullVacuum: allowFullVacuum,
          current: current,
        ).then(
          (value) {
            if (current()) {
              _unavailable.remove(a);
              if (!value.protectedFull) {
                _retries.remove(a);
                _retryTimers.remove(a)?.cancel();
              }
            }
            return value;
          },
          onError: (Object error, StackTrace stack) {
            if (current()) {
              _unavailable.add(a);
              _retryLater(a);
            }
            Error.throwWithStackTrace(error, stack);
          },
        );
    _maintenance[a] = result;
    return result.whenComplete(() {
      if (identical(_maintenance[a], result)) _maintenance.remove(a);
    });
  }

  Future<HistoryDiskUsage> _maintain(
    HistoryAccount a, {
    required bool compact,
    required bool allowFullVacuum,
    required bool Function() current,
  }) async {
    void live() {
      if (!current()) throw StateError('History maintenance retired.');
    }

    await _initialize();
    await HistoryEvictions(db).cleanAccount(a, order, current);
    live();
    if (compact) {
      final plan = await compactionPlan(a);
      live();
      if (plan.fullVacuum && !allowFullVacuum) {
        throw const HistoryCompactionNeedsConfirmation();
      }
      if (!plan.enoughSpace) throw HistoryCompactionSpaceRequired(plan);
    }
    var measured = await order(() async {
      await ready();
      live();
      try {
        await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      } catch (_) {
        // A busy/failed checkpoint must not disable the counter-based limit.
        _retryLater(a);
      }
      return _usageNow(a, physical: false);
    });
    final budgetAtStart = measured.budget;
    final target =
        measured.budget != 0 && measured.retainedCharge > measured.budget
        ? measured.budget * 8 ~/ 10
        : 0;
    var blocked = false;
    for (
      var round = 0;
      round < 32 && target > 0 && measured.retainedCharge > target;
      round++
    ) {
      if (_closed) break;
      final dropped = await order(() async {
        await ready();
        live();
        return _evictNow(a, measured.retainedCharge - target, budgetAtStart);
      });
      if (dropped < 0) break; // A newer setting retires this eviction goal.
      if (dropped == 0) {
        blocked = true;
        break;
      }
      _backgroundZone.run(() => coverageChanged?.call());
      measured = await order(() => _usageNow(a, physical: false));
    }
    measured = await order(() => _usageNow(a, physical: false));
    live();
    _dirty[a] = 0;
    // The 80% goal yields to protected records. Only an inability to stay
    // within the limit stops subsequent positive-size writes.
    blocked =
        blocked &&
        measured.budget != 0 &&
        measured.retainedCharge > measured.budget;
    if (blocked) {
      _blocked.add(a);
      _retryLater(a);
    } else {
      _blocked.remove(a);
    }
    measured = measured.withProtectedFull(blocked);
    // Admission depends on body counters, so even a failed compaction cannot
    // leave a no-longer-full account stuck behind its previous block.
    var reclaimPending = false;
    if (compact || target > 0 || measured.freeBytes > 0) {
      reclaimPending = await _reclaim(
        a,
        compact: compact,
        allowFullVacuum: allowFullVacuum,
        live: live,
      );
      await order(() async {
        live();
        await db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      });
    }
    if (!blocked &&
        (reclaimPending ||
            measured.budget != 0 &&
                measured.retainedCharge > measured.budget) &&
        !_closed) {
      _pending.add(a);
      if (!_timer.isActive) _schedule();
    }
    // Publish admission state before optional filesystem measurements. A
    // failed file meter cannot prevent the logical quota from being enforced.
    return order(() async {
      live();
      return _usageNow(a, protectedFull: blocked);
    });
  }

  Future<bool> _reclaim(
    HistoryAccount a, {
    required bool compact,
    required bool allowFullVacuum,
    required void Function() live,
  }) async {
    final mode = await order(() async {
      live();
      return (await _query('PRAGMA auto_vacuum', [])).single.data.values.single;
    });
    if (mode == 0) {
      if (!compact || !allowFullVacuum) return false;
      final plan = await compactionPlan(a);
      live();
      if (!plan.enoughSpace) throw HistoryCompactionSpaceRequired(plan);
      await order(() async {
        live();
        if ((await _pathNow()).isEmpty) return;
        await db.customStatement('PRAGMA auto_vacuum=INCREMENTAL');
        await db.customStatement('VACUUM');
      });
      return false;
    }
    for (var round = 0; round < 32; round++) {
      final counts = await order(() async {
        live();
        Future<int> free() async =>
            (await _query(
                  'PRAGMA freelist_count',
                  [],
                )).single.data.values.single
                as int;
        final before = await free();
        if (before == 0) return (0, 0);
        await db.customStatement('PRAGMA incremental_vacuum(128)');
        return (before, await free());
      });
      if (counts.$2 == 0 || counts.$2 >= counts.$1) return false;
      if (round < 31) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    return true; // Continue later without holding up pages or draft writes.
  }

  Future<int> _evictNow(
    HistoryAccount a,
    int neededBytes,
    int expectedBudget,
  ) async {
    await db.customStatement(
      '''CREATE INDEX IF NOT EXISTS raft_history_lru
      ON raft_history_rows(origin,principal,touched,server,channel,message_id)''',
    );
    return db.transaction(() async {
      if (await _budgetNow(a) != expectedBudget) return -1;
      await db.customStatement('DELETE FROM history_protected');
      await db.customStatement('DELETE FROM history_protected_scopes');
      final held = <(String, String, String)>{};
      final entire = await _retention.protectedNow(a);
      for (final read in [..._owners.values, ?pending]) {
        for (final scope in read()) {
          if (scope.account != a) continue;
          if (scope.wholeChannel) entire.add((scope.server, scope.channel));
          for (final id in scope.ids) {
            held.add((scope.server, scope.channel, id));
          }
        }
      }
      await db.batch((batch) {
        for (final key in held) {
          batch.customStatement('INSERT INTO history_protected VALUES(?,?,?)', [
            key.$1,
            key.$2,
            key.$3,
          ]);
        }
        for (final key in entire) {
          batch.customStatement(
            'INSERT INTO history_protected_scopes VALUES(?,?)',
            [key.$1, key.$2],
          );
        }
      });
      final available = await _query(
        '''SELECT r.server,r.channel,r.message_id,r.seq_key,r.byte_size FROM raft_history_rows r
        WHERE r.origin=? AND r.principal=? AND r.tombstone=0
        AND NOT EXISTS (SELECT 1 FROM history_protected p WHERE p.server=r.server
          AND p.channel=r.channel AND p.id=r.message_id)
        AND NOT EXISTS (SELECT 1 FROM history_protected_scopes p WHERE p.server=r.server
          AND p.channel=r.channel)
        AND NOT EXISTS (SELECT 1 FROM workspace_cache k WHERE k.origin=r.origin
          AND k.principal=r.principal AND k.server=r.server
          AND k.kind='history-kept' AND k.id=r.channel)
        AND NOT EXISTS (SELECT 1 FROM workspace_cache d WHERE d.origin=r.origin
          AND d.principal=r.principal AND d.kind='draft'
          AND instr(d.payload,r.message_id)>0)
        AND NOT EXISTS (SELECT 1 FROM workspace_cache p WHERE p.origin=r.origin
          AND p.principal=r.principal AND p.server=r.server AND p.kind='history-anchor'
          AND p.id=r.channel AND json_extract(p.payload,'\$.messageId')=r.message_id)
        ORDER BY r.touched,r.server,r.channel,r.message_id LIMIT 200''',
        [a.origin, a.principal],
      );
      final candidates = <QueryRow>[];
      var freed = 0;
      for (final row in available) {
        candidates.add(row);
        freed += (3 * row.read<int>('byte_size') + 1) ~/ 2;
        if (freed >= neededBytes) break;
      }
      final groups = <(String, String), List<QueryRow>>{};
      for (final row in candidates) {
        groups
            .putIfAbsent((
              row.read<String>('server'),
              row.read<String>('channel'),
            ), () => [])
            .add(row);
      }
      for (final entry in groups.entries) {
        final server = entry.key.$1, channel = entry.key.$2;
        final markers = await _query(
          "SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind='message-history' AND id=?",
          [a.origin, a.principal, server, channel],
        );
        final marker = markers.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(
                await decodeWorkspaceCache(
                  markers.single.read<String>('payload'),
                ) as Map,
              );
        final scope = MessageHistoryScope(
          origin: a.origin,
          principal: a.principal,
          server: server,
          channel: channel,
          parentChannel: marker['parentChannelId'] as String? ?? channel,
          authority: marker['authority'] as String? ?? '',
        );
        final revision = await advance(scope);
        final ids = entry.value
            .map((r) => r.read<String>('message_id'))
            .toList();
        // Retain a lightweight eviction receipt. It fences older in-flight
        // responses, distinguishes a reclaimed page from a never-seen page,
        // and prevents rollback shadows from silently repopulating it.
        await db.customStatement(
          "UPDATE raft_history_rows SET tombstone=2,payload='{}',byte_size=0,revision=? WHERE $_scopeWhere AND message_id IN (${List.filled(ids.length, '?').join(',')})",
          [revision, ...scope.key, ...ids],
        );
        final sequences =
            entry.value.map((r) => r.read<String>('seq_key')).toList()..sort();
        await _invalidateNow(scope, sequences.first, sequences.last);
        await _shadowNow(scope, ids.toSet());
        await HistoryEvictions(db).trimNow(scope);
      }
      await db.customStatement('DELETE FROM history_protected');
      await db.customStatement('DELETE FROM history_protected_scopes');
      return candidates.length;
    });
  }

  Future<void> _invalidateNow(
    MessageHistoryScope scope,
    String lower,
    String upper,
  ) async {
    final prior = await _query(
      'SELECT lower_key,upper_key,verified FROM raft_history_ranges WHERE $_scopeWhere AND lower_key<=? ORDER BY lower_key DESC LIMIT 1',
      [...scope.key, lower],
    );
    final affected = [
      if (prior.isNotEmpty &&
          prior.single.read<String>('upper_key').compareTo(lower) >= 0)
        prior.single,
      ...await _query(
        'SELECT lower_key,upper_key,verified FROM raft_history_ranges WHERE $_scopeWhere AND lower_key>? AND lower_key<=?',
        [...scope.key, lower, upper],
      ),
    ];
    for (final range in affected) {
      final lo = range.read<String>('lower_key'),
          hi = range.read<String>('upper_key'),
          stamp = range.read<int>('verified');
      await db.customStatement(
        'DELETE FROM raft_history_ranges WHERE $_scopeWhere AND lower_key=? AND upper_key=?',
        [...scope.key, lo, hi],
      );
      Future<void> put(String first, String last) => db.customStatement(
        'INSERT INTO raft_history_ranges VALUES(?,?,?,?,?,?,?)',
        [...scope.key, first, last, stamp],
      );
      if (lo.compareTo(lower) < 0) {
        await put(lo, historySequenceKey(BigInt.parse(lower) - BigInt.one));
      }
      if (hi.compareTo(upper) > 0) {
        await put(historySequenceKey(BigInt.parse(upper) + BigInt.one), hi);
      }
    }
    await db.customStatement(
      'DELETE FROM raft_history_checks WHERE $_scopeWhere',
      scope.key,
    );
  }

  Future<void> _shadowNow(
    MessageHistoryScope scope,
    Set<String> removed,
  ) async {
    final shadows = await _query(
      "SELECT rowid,payload FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND ((kind='window' AND id=?) OR (kind='thread-window' AND CASE WHEN json_valid(payload) THEN json_extract(payload,'\$.threadChannelId') END=?))",
      [
        scope.origin,
        scope.principal,
        scope.server,
        scope.channel,
        scope.channel,
      ],
    );
    for (final record in shadows) {
      final raw = await decodeWorkspaceCache(record.read<String>('payload'));
      if (raw is! Map ||
          raw['version'] != 1 ||
          raw['windowKind'] != 'tail' ||
          raw['authority'] != scope.authority ||
          raw['messages'] is! List) {
        continue;
      }
      final rows = (raw['messages'] as List)
          .where((r) => r is! Map || !removed.contains(r['id']))
          .toList();
      if (rows.length == (raw['messages'] as List).length) continue;
      final payload = await encodeWorkspaceCache({
        ...raw,
        'messages': rows,
        'hasMore': true,
      });
      await db.customStatement(
        'UPDATE workspace_cache SET payload=? WHERE rowid=?',
        [payload, record.read<int>('rowid')],
      );
    }
  }
}
