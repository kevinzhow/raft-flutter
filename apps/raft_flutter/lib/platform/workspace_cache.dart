import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/workspace_cache.dart';
import '../data/message_history.dart';
import '../data/cache_read_versions.dart';
import '../data/cached_history_window.dart';
import 'message_history.dart';
import '../data/workspace_cache_codec.dart';

/// On-device workspace cache (see [WorkspaceCache] for the validity rule).
class DriftWorkspaceCache extends GeneratedDatabase
    implements WorkspaceCache, MessageHistoryProvider, CommittedWorkspaceCache {
  DriftWorkspaceCache(
    super.executor, {
    this.windowRetention = 120,
    this.translationRetention = 2000,
    this.historyClock,
    this.historyBudget,
    this.historyHardLimitEnabled = true,
    this.historyAvailableSpace,
    this.automaticHistoryMaintenance = true,
    this.messageHistoryEnabled = const bool.fromEnvironment(
      'RAFT_LOCAL_MESSAGE_HISTORY',
      defaultValue: true,
    ),
  });

  final DateTime Function()? historyClock;
  /// An explicit budget also permits small, real-file capacity fixtures.
  final int? historyBudget;
  @visibleForTesting
  final bool historyHardLimitEnabled;
  final Future<int?> Function(String)? historyAvailableSpace;
  @visibleForTesting
  final bool automaticHistoryMaintenance;
  @override
  final bool messageHistoryEnabled;

  @override
  late final SqliteMessageHistory messageHistory = SqliteMessageHistory(
    this,
    _ordered,
    readLegacy: _read,
    writeLegacy: _write,
    now: historyClock,
    historyBudget: historyBudget ??
        (switch (defaultTargetPlatform) {
          TargetPlatform.android || TargetPlatform.iOS => 1 << 30,
          _ => 2 << 30,
        }),
    automaticMaintenance: automaticHistoryMaintenance,
    hardLimitEnabled: historyHardLimitEnabled,
    historyAvailableSpace: historyAvailableSpace,
  );

  /// Message/thread windows kept per account and server. Every write moves a
  /// row to the newest rowid, so the oldest-written (least recently
  /// visited) windows are evicted first.
  final int windowRetention;
  static const _windowKinds = {'window', 'thread-window'};

  /// Message translations kept per account and server. A write (including
  /// the touch of an entry shown again) moves it to the newest rowid, so the
  /// least recently used entries are evicted first.
  final int translationRetention;
  static Future<DriftWorkspaceCache> open() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'raft'));
    await dir.create(recursive: true);
    if (Platform.isLinux) {
      final result = await Process.run('chmod', ['700', dir.path]);
      if (result.exitCode != 0) {
        throw FileSystemException(
          'Cannot protect local workspace cache',
          dir.path,
        );
      }
    }
    return DriftWorkspaceCache(
      NativeDatabase.createInBackground(
        File(p.join(dir.path, 'workspace.sqlite')),
        readPool: 1,
      ),
    );
  }

  // Serialization may await an isolate. Keep writes and permission purges in
  // call order so a pending encode cannot re-create data after revocation.
  Future<void> _operations = Future<void>.value();
  Future<void>? _closing;
  final _readVersions = CacheReadVersions();
  final _committedReads = <Future<dynamic>>{};

  Future<T> _ordered<T>(Future<T> Function() action) {
    if (_closing != null) return Future<T>.error(StateError('Cache is closed'));
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<void> close() {
    _readVersions.close();
    return _closing ??= _closeAfterOperations();
  }

  Future<void> _closeAfterOperations() async {
    messageHistory.stop();
    await _operations;
    await Future.wait([
      for (final read in _committedReads)
        read.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    ]);
    await super.close();
  }

  @override
  Future<List<Map<String, dynamic>>> readTranslations(
    String origin,
    String principal,
    String server,
  ) => _ordered(() => _readTranslations(origin, principal, server));

  @override
  Future<void> writeTranslations(
    String origin,
    String principal,
    String server,
    List<Map<String, dynamic>> entries,
  ) => _ordered(() => _writeTranslations(origin, principal, server, entries));

  @override
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) => messageHistoryEnabled && _windowKinds.contains(kind)
      ? messageHistory.readWindow(origin, principal, server, kind, id)
      : _ordered(() => _read(origin, principal, server, kind, id));

  @override
  Future<dynamic> readCommittedWindow(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) {
    if (!messageHistoryEnabled || !_windowKinds.contains(kind)) {
      return read(origin, principal, server, kind, id);
    }
    final reading = _readCommittedWindow(origin, principal, server, kind, id);
    _committedReads.add(reading);
    reading.then<void>((_) => _committedReads.remove(reading),
      onError: (Object _, StackTrace _) => _committedReads.remove(reading));
    return reading;
  }

  Future<dynamic> _readCommittedWindow(
    String origin, String principal, String server, String kind, String id,
  ) async {
    final ticket = _readVersions.ticket;
    final current = _readVersions.validator(ticket, origin, principal, server, [id]);
    if (!current()) return null;
    final snapshot = await messageHistory.peekCommittedWindow(
      origin, principal, server, kind, id,
    );
    if (snapshot == null) {
      if (!current()) return null;
      // Context snapshots and unmigrated windows retain the ordered import path.
      final saved = await read(origin, principal, server, kind, id);
      return _readVersions.current(ticket, origin, principal, server, [id, if (saved is Map) ...[
        '${saved['channelId']}', '${saved['parentChannelId']}',
      ]]) ? saved : null;
    }
    final scope = snapshot.scope;
    final valid = _readVersions.validator(ticket, origin, principal, server,
      [scope.channel, scope.parentChannel]);
    if (!valid()) return null;
    messageHistory.touchCommittedWindow(scope, [
      for (final row in snapshot.value['messages'] as List)
        if (row['id'] case final String id) id,
    ], current: valid);
    return CachedHistoryWindow(snapshot.value, scope: scope,
      positionAbsent: !snapshot.hasPosition,
      positionsUnchanged: snapshot.positionsUnchanged, current: valid);
  }

  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) => messageHistoryEnabled && _windowKinds.contains(kind)
      ? messageHistory.writeWindow(origin, principal, server, kind, id, value)
      : _ordered(() => _write(origin, principal, server, kind, id, value));

  @override
  Future<void> revokeChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) {
    final complete = _readVersions.invalidateChannel(origin, principal, server, channel);
    return _ordered(() => _revokeChannel(origin, principal, server, channel))
        .whenComplete(complete);
  }

  @override
  Future<void> clearAccount(String origin, String principal) {
    final complete = _readVersions.invalidateAccount(origin, principal);
    return _ordered(() => _clearAccount(origin, principal)).whenComplete(complete);
  }

  @override
  Future<void> revokeServer(String origin, String principal, String server) {
    final complete = _readVersions.invalidateServer(origin, principal, server);
    return _ordered(() => _revokeServer(origin, principal, server)).whenComplete(complete);
  }

  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo> get allTables => const [];

  /// v1: `workspace_cache`. v2: `message_translations`, one row per message
  /// (Web translationStore entries are keyed by message id; the payload
  /// carries the target language and the original content it is valid for).
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('PRAGMA auto_vacuum=INCREMENTAL');
      await customStatement('''CREATE TABLE workspace_cache (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY (origin, principal, server, kind, id))''');
      await _createTranslations();
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) await _createTranslations();
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA secure_delete = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
  Future<void> _createTranslations() =>
      customStatement('''CREATE TABLE IF NOT EXISTS message_translations (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      message_id TEXT NOT NULL, channel_id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY (origin, principal, server, message_id))''');

  Future<List<Map<String, dynamic>>> _readTranslations(
    String origin,
    String principal,
    String server,
  ) async {
    final rows = await customSelect(
      'SELECT payload FROM message_translations WHERE origin=? AND principal=? AND server=? ORDER BY rowid DESC LIMIT ?',
      variables: [
        Variable(origin),
        Variable(principal),
        Variable(server),
        Variable(translationRetention),
      ],
    ).get();
    return decodeWorkspaceTranslations([
      for (final row in rows) row.read<String>('payload'),
    ]);
  }

  Future<void> _writeTranslations(
    String origin,
    String principal,
    String server,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
    final payloads = await encodeWorkspaceTranslations(entries);
    await transaction(() async {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        // REPLACE gives the row a new rowid: rowid order is last-use order.
        await customStatement(
          'INSERT OR REPLACE INTO message_translations (origin,principal,server,message_id,channel_id,payload) VALUES (?,?,?,?,?,?)',
          [
            origin,
            principal,
            server,
            '${entry['messageId']}',
            '${entry['channelId'] ?? ''}',
            payloads[index],
          ],
        );
      }
      await customStatement(
        'DELETE FROM message_translations WHERE origin=? AND principal=? AND server=? AND rowid NOT IN (SELECT rowid FROM message_translations WHERE origin=? AND principal=? AND server=? ORDER BY rowid DESC LIMIT ?)',
        [
          origin,
          principal,
          server,
          origin,
          principal,
          server,
          translationRetention,
        ],
      );
    });
  }

  List<Variable> _key(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) => [
    Variable(origin),
    Variable(principal),
    Variable(server),
    Variable(kind),
    Variable(id),
  ];
  Future<dynamic> _read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  ) async {
    final row = await customSelect(
      'SELECT payload FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND id=?',
      variables: _key(origin, principal, server, kind, id),
    ).getSingleOrNull();
    return row == null
        ? null
        : decodeWorkspaceCache(row.read<String>('payload'));
  }

  Future<void> _write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (value == null) {
      await customStatement(
        'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND id=?',
        [origin, principal, server, kind, id],
      );
    } else {
      final payload = await encodeWorkspaceCache(value);
      // Explicit deletion preserves the LRU rowid behavior and invokes the
      // retention counters on SQLite connections with recursive triggers off.
      await transaction(() async {
        await customStatement(
          'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind=? AND id=?',
          [origin, principal, server, kind, id],
        );
        await customStatement(
          'INSERT INTO workspace_cache (origin,principal,server,kind,id,payload) VALUES (?,?,?,?,?,?)',
          [origin, principal, server, kind, id, payload],
        );
      });
      if (_windowKinds.contains(kind)) {
        await customStatement(
          'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind IN (\'window\',\'thread-window\') AND rowid NOT IN (SELECT rowid FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind IN (\'window\',\'thread-window\') ORDER BY rowid DESC LIMIT ?)',
          [
            origin,
            principal,
            server,
            origin,
            principal,
            server,
            windowRetention,
          ],
        );
      }
    }
  }

  Future<void> _revokeChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) => messageHistory.revokeChannelNow(
    origin,
    principal,
    server,
    channel,
    () => _purgeLegacyChannel(origin, principal, server, channel),
  );

  Future<void> _purgeLegacyChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) async {
    await customStatement(
      'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND (id=? OR id=? OR json_extract(payload,\'\$.channelId\')=? OR json_extract(payload,\'\$.parentChannelId\')=? OR json_extract(payload,\'\$.threadChannelId\')=?)',
      [
        origin,
        principal,
        server,
        channel,
        'thread:$channel',
        channel,
        channel,
        channel,
      ],
    );
    await customStatement(
      'DELETE FROM message_translations WHERE origin=? AND principal=? AND server=? AND channel_id=?',
      [origin, principal, server, channel],
    );
  }

  Future<void> _clearAccount(String origin, String principal) async {
    messageHistory.cancelAccount(origin, principal);
    await customStatement(
      'DELETE FROM workspace_cache WHERE origin=? AND principal=?',
      [origin, principal],
    );
    await customStatement(
      'DELETE FROM message_translations WHERE origin=? AND principal=?',
      [origin, principal],
    );
  }

  Future<void> _revokeServer(
    String origin,
    String principal,
    String server,
  ) async {
    messageHistory.receiver.clearServer(origin, principal, server);
    await customStatement(
      'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=?',
      [origin, principal, server],
    );
    await customStatement(
      'DELETE FROM message_translations WHERE origin=? AND principal=? AND server=?',
      [origin, principal, server],
    );
  }
}
