import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/workspace_cache.dart';

class DriftWorkspaceCache extends GeneratedDatabase implements WorkspaceCache {
  DriftWorkspaceCache(super.executor);
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
      ),
    );
  }

  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''CREATE TABLE workspace_cache (
      origin TEXT NOT NULL, principal TEXT NOT NULL, server TEXT NOT NULL,
      kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY (origin, principal, server, kind, id))''');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA secure_delete = ON');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
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
  @override
  Future<dynamic> read(
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
    return row == null ? null : jsonDecode(row.read<String>('payload'));
  }

  @override
  Future<void> write(
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
      await customStatement(
        'INSERT INTO workspace_cache (origin,principal,server,kind,id,payload) VALUES (?,?,?,?,?,?) ON CONFLICT(origin,principal,server,kind,id) DO UPDATE SET payload=excluded.payload',
        [origin, principal, server, kind, id, jsonEncode(_cacheSafe(value))],
      );
    }
  }

  @override
  Future<void> revokeChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) async {
    await customStatement(
      'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND (id=? OR id=? OR json_extract(payload,\'\$.channelId\')=? OR json_extract(payload,\'\$.parentChannelId\')=?)',
      [origin, principal, server, channel, 'thread:$channel', channel, channel],
    );
  }

  @override
  Future<void> clearAccount(String origin, String principal) async {
    await customStatement(
      'DELETE FROM workspace_cache WHERE origin=? AND principal=?',
      [origin, principal],
    );
  }

  @override
  Future<void> revokeServer(
    String origin,
    String principal,
    String server,
  ) async {
    await customStatement(
      'DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=?',
      [origin, principal, server],
    );
  }

  static dynamic _cacheSafe(dynamic value) {
    if (value is Map) {
      return {
        for (final e in value.entries)
          if (!{
            'accessToken',
            'refreshToken',
            'apiKey',
            'bootstrapToken',
            'previewToken',
            'providerSecret',
            'clientSecret',
            'authorization',
            'signedUrl',
            'downloadUrl',
            'uploadUrl',
          }.contains(e.key))
            e.key.toString(): _cacheSafe(e.value),
      };
    }
    if (value is List) return value.map(_cacheSafe).toList();
    if (value is String &&
        (value.contains('X-Amz-') ||
            value.contains('Signature=') ||
            value.contains('access_token=') ||
            RegExp(
              r'(?:[?&])(?:token|previewToken|bootstrapToken|refresh_token|api_key)=',
              caseSensitive: false,
            ).hasMatch(value))) {
      return null;
    }
    return value;
  }
}
