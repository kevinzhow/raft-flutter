import 'package:drift/drift.dart';

import '../data/history_capacity.dart';
import '../data/history_retention_policy.dart';
import '../data/message_history.dart';
import '../data/workspace_cache_codec.dart';

/// Persistent automatic holds are read in the same transaction as eviction.
/// No body is scanned and no network or authorization is inferred here.
class HistoryRetention {
  HistoryRetention(this.db, this.now);
  final GeneratedDatabase db;
  final DateTime Function() now;
  static const grace = Duration(days: 7);

  Future<void> openedNow(HistoryAccount a, String server, String channel) =>
      db.customStatement(
        "INSERT INTO workspace_cache VALUES(?,?,?,'history-visited',?,?) ON CONFLICT(origin,principal,server,kind,id) DO UPDATE SET payload=excluded.payload",
        [
          a.origin,
          a.principal,
          server,
          channel,
          '${now().millisecondsSinceEpoch}',
        ],
      );

  Future<void> migrateNow() async {
    // The old flag becomes a seven-day grace visit exactly once. Keep the
    // marker until its replacement is committed; restart cannot reset grace.
    await db.transaction(() async {
      await db.customStatement(
        "INSERT OR IGNORE INTO workspace_cache(origin,principal,server,kind,id,payload) SELECT origin,principal,server,'history-visited',id,? FROM workspace_cache WHERE kind='history-kept'",
        ['${now().millisecondsSinceEpoch}'],
      );
      await db.customStatement(
        "DELETE FROM workspace_cache WHERE kind='history-kept'",
      );
    });
  }

  Future<Set<(String, String)>> protectedNow(HistoryAccount a) async {
    final records = await db
        .customSelect(
          "SELECT server,kind,id,payload FROM workspace_cache WHERE origin=? AND principal=? AND kind IN ('history-visited','history-kept','draft','unread','sidebar-order','channels','message-history')",
          variables: [Variable(a.origin), Variable(a.principal)],
        )
        .get();
    final held = <(String, String)>{};
    final pins = <String, Map<String, dynamic>>{};
    final channels = <String, List<Map<String, dynamic>>>{};
    final threads = <(String, String), (String, String?)>{};
    final drafts = <(String, String)>{};
    final stamp = now().millisecondsSinceEpoch;
    for (final record in records) {
      final server = record.read<String>('server'),
          kind = record.read<String>('kind'),
          id = record.read<String>('id');
      final value = await decodeWorkspaceCache(record.read<String>('payload'));
      switch (kind) {
        case 'history-kept':
          held.add((server, id));
        case 'history-visited':
          // A clock moved backwards must never make recently opened data
          // eligible. Sequence ordering and verification do not use this time.
          if (value is int && stamp - value <= grace.inMilliseconds) {
            held.add((server, id));
          }
        case 'draft':
          if (value is Map &&
              ((value['text'] as String? ?? '').isNotEmpty ||
                  (value['files'] as List? ?? const []).isNotEmpty)) {
            drafts.add((server, value['channelId'] as String? ?? id));
          }
        case 'unread':
          if (value is Map) {
            for (final entry in value.entries) {
              if (entry.value is num && entry.value > 0) {
                held.add((server, '${entry.key}'));
              }
            }
          }
        case 'sidebar-order':
          if (value is Map) pins[server] = Map<String, dynamic>.from(value);
        case 'channels':
          if (value is Map) {
            channels[server] = [
              for (final key in ['channels', 'dms'])
                for (final row
                    in (value[key] as List? ?? const []).whereType<Map>())
                  Map<String, dynamic>.from(row),
            ];
          }
        case 'message-history':
          if (value is Map && value['parentChannelId'] is String) {
            threads[(server, id)] = (
              value['parentChannelId'] as String,
              value['parentMessageId'] as String?,
            );
          }
      }
    }
    for (final entry in pins.entries) {
      held.addAll(
        historyPinnedChannels(
          entry.value,
          channels[entry.key] ?? const [],
        ).map((id) => (entry.key, id)),
      );
    }
    for (final draft in drafts) {
      if (draft.$2.startsWith('thread:')) {
        final parent = draft.$2.substring('thread:'.length);
        for (final entry in threads.entries) {
          if (entry.key.$1 == draft.$1 && entry.value.$2 == parent) {
            held.add(entry.key);
          }
        }
      } else {
        held.add(draft);
      }
    }
    // Parent holds protect its saved thread conversations too.
    for (final entry in threads.entries) {
      if (held.contains((entry.key.$1, entry.value.$1))) held.add(entry.key);
    }
    return held;
  }

  Future<bool> holdsNow(MessageHistoryScope scope) async =>
      (await protectedNow(HistoryAccount(scope.origin, scope.principal)))
          .contains((scope.server, scope.channel));
}
