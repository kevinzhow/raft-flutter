import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Personal, local convenience state. No entity labels, messages or API payloads
/// are retained. Source: searchHome.ts at pinned Web26f77ef.
abstract interface class SearchMemoryStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesSearchMemoryStorage implements SearchMemoryStorage {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
  }
}

class SearchMemoryScope {
  const SearchMemoryScope(this.origin, this.serverId, this.principalId);
  final String origin, serverId, principalId;
  String get key =>
      'raft:search-memory:${jsonEncode([origin, serverId, principalId])}';
}

class SearchStateSnapshot {
  const SearchStateSnapshot({
    this.query = '',
    this.channelId,
    this.senderKey,
    this.scopes = const [],
    this.range = 'any',
    this.sort = 'relevance',
  });
  final String query, range, sort;
  final String? channelId, senderKey;
  final List<String> scopes;
  Map<String, dynamic> toJson() => {
    'q': query,
    'channelId': channelId,
    'senderKey': senderKey,
    'scopes': scopes,
    'range': range,
    'sort': sort,
  };
  factory SearchStateSnapshot.fromJson(dynamic raw) {
    final row = raw is Map ? raw : const {};
    String? identifier(dynamic value) =>
        value is String && value.trim().isNotEmpty && value.trim().length <= 200
        ? value.trim()
        : null;
    final sender = identifier(row['senderKey']);
    return SearchStateSnapshot(
      query: row['q'] is String ? (row['q'] as String).trim() : '',
      channelId: identifier(row['channelId']),
      senderKey:
          sender != null && RegExp(r'^(user|agent):[^:]+$').hasMatch(sender)
          ? sender
          : null,
      scopes: List.unmodifiable(
        row['scopes'] is List
            ? (row['scopes'] as List)
                  .whereType<String>()
                  .where(
                    (s) => const ['mentioned', 'humans', 'agents'].contains(s),
                  )
                  .toSet()
            : const <String>{},
      ),
      range: const ['any', 'today', '7d', '30d'].contains(row['range'])
          ? row['range'] as String
          : 'any',
      sort: row['sort'] == 'recent' ? 'recent' : 'relevance',
    );
  }
}

List<String> normalizeSearchHistory(dynamic raw) {
  if (raw is! List) return const [];
  final seen = <String>{}, values = <String>[];
  for (final value in raw.whereType<String>()) {
    final trimmed = value.trim();
    final query = trimmed.substring(0, math.min(200, trimmed.length));
    if (query.isNotEmpty && seen.add(query.toLowerCase())) values.add(query);
    if (values.length == 15) break;
  }
  return List.unmodifiable(values);
}

const searchUsageWindow = Duration(days: 90);
const searchUsageHalfLife = Duration(days: 7);
final _usageKey = RegExp(r'^(channel|agent|human):[^:]{1,200}$');

Map<String, List<int>> normalizeSearchUsage(dynamic raw, DateTime now) {
  if (raw is! Map) return const {};
  final minimum = now.subtract(searchUsageWindow).millisecondsSinceEpoch;
  final maximum = now.add(const Duration(minutes: 5)).millisecondsSinceEpoch;
  final entries = <MapEntry<String, List<int>>>[];
  for (final entry in raw.entries) {
    if (entry.key is! String ||
        !_usageKey.hasMatch(entry.key) ||
        entry.value is! List) {
      continue;
    }
    final times =
        (entry.value as List)
            .whereType<num>()
            .where((n) => n.isFinite && n >= minimum && n <= maximum)
            .map((n) => n.toInt())
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (times.isNotEmpty) {
      entries.add(MapEntry(entry.key, List.unmodifiable(times.take(24))));
    }
  }
  entries.sort((a, b) {
    final date = b.value.first.compareTo(a.value.first);
    return date == 0 ? a.key.compareTo(b.key) : date;
  });
  return Map.unmodifiable(Map.fromEntries(entries.take(64)));
}

double searchUsageScore(List<int> times, DateTime now) =>
    times.fold(0.0, (score, time) {
      final age = now.millisecondsSinceEpoch - time;
      if (age > searchUsageWindow.inMilliseconds ||
          age < -const Duration(minutes: 5).inMilliseconds) {
        return score;
      }
      return score +
          math
              .pow(2, -math.max(0, age) / searchUsageHalfLife.inMilliseconds)
              .toDouble();
    });

class SearchMemoryData {
  const SearchMemoryData({
    this.history = const [],
    this.usage = const {},
    this.state = const SearchStateSnapshot(),
  });
  final List<String> history;
  final Map<String, List<int>> usage;
  final SearchStateSnapshot state;
  factory SearchMemoryData.decode(String? encoded, DateTime now) {
    try {
      final raw = encoded == null ? null : jsonDecode(encoded);
      if (raw is! Map) return const SearchMemoryData();
      return SearchMemoryData(
        history: normalizeSearchHistory(raw['history']),
        usage: normalizeSearchUsage(raw['usage'], now),
        state: SearchStateSnapshot.fromJson(raw['state']),
      );
    } catch (_) {
      return const SearchMemoryData();
    }
  }
  String encode() => jsonEncode({
    'version': 1,
    'history': history,
    'usage': usage,
    'state': state.toJson(),
  });
}

/// Optional storage cannot block navigation. In-flight reads never overwrite a
/// newer local edit; serialized writes preserve the last accepted scoped state.
class SearchMemoryStore {
  SearchMemoryStore({SearchMemoryStorage? storage, DateTime Function()? clock})
    : storage = storage ?? PreferencesSearchMemoryStorage(),
      clock = clock ?? DateTime.now;
  final SearchMemoryStorage storage;
  final DateTime Function() clock;
  final Map<String, SearchMemoryData> _data = {};
  final Map<String, int> _revisions = {};
  final Map<String, Future<SearchMemoryData>> _loads = {};
  final Map<String, Future<void>> _writes = {};
  SearchMemoryData current(SearchMemoryScope scope) =>
      _data[scope.key] ?? const SearchMemoryData();
  Future<SearchMemoryData> load(SearchMemoryScope scope) {
    if (_data.containsKey(scope.key)) return Future.value(current(scope));
    return _loads
        .putIfAbsent(scope.key, () async {
          final before = _revisions[scope.key] ?? 0;
          String? encoded;
          try {
            encoded = await storage.read(scope.key);
          } catch (_) {
            /* local convenience */
          }
          if ((_revisions[scope.key] ?? 0) == before) {
            _data[scope.key] = SearchMemoryData.decode(encoded, clock());
          }
          return current(scope);
        })
        .then((_) => current(scope));
  }

  void _replace(SearchMemoryScope scope, SearchMemoryData value) {
    _data[scope.key] = value;
    _revisions[scope.key] = (_revisions[scope.key] ?? 0) + 1;
    final encoded = value.encode();
    _writes[scope.key] = (_writes[scope.key] ?? Future.value()).then((_) async {
      try {
        await storage.write(scope.key, encoded);
      } catch (_) {
        /* keep in-memory state */
      }
    });
  }

  void saveState(SearchMemoryScope scope, SearchStateSnapshot state) {
    final old = current(scope);
    _replace(
      scope,
      SearchMemoryData(
        history: old.history,
        usage: old.usage,
        state: SearchStateSnapshot.fromJson(state.toJson()),
      ),
    );
  }

  void rememberQuery(SearchMemoryScope scope, String query) {
    final old = current(scope),
        history = normalizeSearchHistory([query, ...current(scope).history]);
    _replace(
      scope,
      SearchMemoryData(history: history, usage: old.usage, state: old.state),
    );
  }

  void removeQuery(SearchMemoryScope scope, String query) {
    final old = current(scope);
    _replace(
      scope,
      SearchMemoryData(
        history: List.unmodifiable(
          old.history.where(
            (q) => q.toLowerCase() != query.trim().toLowerCase(),
          ),
        ),
        usage: old.usage,
        state: old.state,
      ),
    );
  }

  void clearHistory(SearchMemoryScope scope) {
    final old = current(scope);
    _replace(scope, SearchMemoryData(usage: old.usage, state: old.state));
  }

  void recordOpen(SearchMemoryScope scope, String key) {
    if (!_usageKey.hasMatch(key)) return;
    final old = current(scope), now = clock();
    _replace(
      scope,
      SearchMemoryData(
        history: old.history,
        usage: normalizeSearchUsage({
          ...old.usage,
          key: [now.millisecondsSinceEpoch, ...?old.usage[key]],
        }, now),
        state: old.state,
      ),
    );
  }

  Future<void> flush() => Future.wait(_writes.values).then((_) {});
}
