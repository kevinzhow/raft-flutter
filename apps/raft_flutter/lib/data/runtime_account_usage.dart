// Web utils/runtimeAccountUsageClient.ts: the private runtime-account usage
// snapshot a Computer reports per provider. Reads are cached for 60s and
// coalesced; refreshes share a 120s cooldown window per subject. v1.24: an
// `unsupported` read (this Computer's daemon reads no usage for it), only
// well-formed snapshots kept, a listener per landed read (the rack's meters
// follow what a card just fetched), and a limit reset's snapshot stored.
import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'runtime_auth.dart' show runtimeUsageRequestHeaders;

/// RUNTIME_ACCOUNT_USAGE_PROVIDERS; `kimi-sdk` reads the `kimi` provider.
String? runtimeUsageProvider(String runtimeId) => switch (runtimeId) {
  'claude' || 'codex' || 'grok' || 'antigravity' => runtimeId,
  'kimi' || 'kimi-sdk' => 'kimi',
  _ => null,
};

String runtimeUsageProviderName(String provider) => switch (provider) {
  'claude' => 'Claude',
  'codex' => 'Codex',
  'grok' => 'Grok',
  'antigravity' => 'Antigravity',
  _ => 'Kimi',
};

/// A snapshot in the shape every usage view relies on (its `accounts` a
/// list), or null (withValidSnapshot / readResultOf).
Map<String, dynamic>? runtimeUsageSnapshotOf(Object? value) =>
    value is Map && value['accounts'] is List
    ? Map<String, dynamic>.from(value)
    : null;

/// `{state: missing|unsupported|fresh|stale, snapshot}`.
class RuntimeUsageRead {
  const RuntimeUsageRead(this.state, this.snapshot);
  factory RuntimeUsageRead.fromJson(dynamic value) {
    final map = value is Map ? value : const {};
    final state = map['state'];
    if (state == 'unsupported') {
      return const RuntimeUsageRead('unsupported', null);
    }
    final snapshot = runtimeUsageSnapshotOf(map['snapshot']);
    if ((state == 'fresh' || state == 'stale') && snapshot != null) {
      return RuntimeUsageRead(state as String, snapshot);
    }
    return const RuntimeUsageRead('missing', null);
  }
  final String state;
  final Map<String, dynamic>? snapshot;

  /// No snapshot to show (missing, or `unsupported`).
  bool get missing => snapshot == null;
  bool get unsupported => state == 'unsupported';

  /// isAttention: a stale snapshot, or an account / window not `ok`.
  bool get attention {
    if (missing) return false;
    if (state == 'stale') return true;
    for (final account in (snapshot!['accounts'] as List? ?? const [])) {
      if (account is! Map) continue;
      if (account['health'] != 'ok') return true;
      for (final window in (account['windows'] as List? ?? const [])) {
        if (window is Map && window['status'] != 'ok') return true;
      }
    }
    return false;
  }
}

/// `{accepted, state: requested|cooldown|computer_offline|fresh|timeout|
/// unsupported, snapshot?}` (FLD-117 RuntimeAccountUsageRefreshResult).
class RuntimeUsageRefresh {
  const RuntimeUsageRefresh(this.accepted, this.state, [this.snapshot]);
  factory RuntimeUsageRefresh.fromJson(dynamic value) {
    final map = value is Map ? value : const {};
    return RuntimeUsageRefresh(
      map['accepted'] == true,
      '${map['state'] ?? 'computer_offline'}',
      runtimeUsageSnapshotOf(map['snapshot']),
    );
  }
  final bool accepted;
  final String state;
  final Map<String, dynamic>? snapshot;
}

class RuntimeAccountUsageClient {
  RuntimeAccountUsageClient({
    required this.get,
    required this.post,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static const cacheFor = Duration(seconds: 60);
  static const cooldown = Duration(seconds: 120);

  final Future<dynamic> Function(String path) get;
  final Future<dynamic> Function(String path, Map<String, dynamic> body) post;
  final DateTime Function() now;
  final _cache = <String, (RuntimeUsageRead, DateTime)>{};
  final _reads = <String, Future<RuntimeUsageRead>>{};
  final _refreshes = <String, Future<RuntimeUsageRefresh>>{};
  final _refreshStartedAt = <String, DateTime>{};
  final _listeners = <void Function()>{};

  /// Calls [listener] whenever a read result lands in the cache.
  void Function() subscribe(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _store(String key, RuntimeUsageRead value) {
    _cache[key] = (value, now().add(cacheFor));
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  /// Puts a snapshot the Computer just read (after a limit reset) into the
  /// read cache, as a manual refresh does.
  void storeSnapshot(
    String server,
    String machine,
    String provider,
    Map<String, dynamic> snapshot,
  ) => _store(
    _key(server, machine, provider),
    RuntimeUsageRead('fresh', snapshot),
  );

  static String _key(String server, String machine, String provider) =>
      '$server\u0000$machine\u0000$provider';

  /// The cached value for first paint, if still fresh.
  RuntimeUsageRead? cached(String server, String machine, String provider) {
    final hit = _cache[_key(server, machine, provider)];
    return hit != null && hit.$2.isAfter(now()) ? hit.$1 : null;
  }

  Future<RuntimeUsageRead> read(
    String server,
    String machine,
    String provider,
  ) {
    final key = _key(server, machine, provider);
    final hit = cached(server, machine, provider);
    if (hit != null) return Future.value(hit);
    final pending = _reads[key];
    if (pending != null) return pending;
    late final Future<RuntimeUsageRead> request;
    request =
        RaftClient.runWithHeaders(
              runtimeUsageRequestHeaders,
              () => get(
                '/servers/$server/machines/$machine/runtime-account-usage/$provider',
              ),
            )
            .then((value) {
              final read = RuntimeUsageRead.fromJson(value);
              _store(key, read);
              return read;
            })
            .whenComplete(() {
              if (identical(_reads[key], request)) _reads.remove(key);
            });
    return _reads[key] = request;
  }

  Future<RuntimeUsageRefresh> refresh(
    String server,
    String machine,
    String provider,
    String reason,
  ) {
    final key = _key(server, machine, provider);
    final pending = _refreshes[key];
    if (pending != null) return pending;
    final last = _refreshStartedAt[key];
    if (last != null && now().difference(last) < cooldown) {
      return Future.value(const RuntimeUsageRefresh(false, 'cooldown'));
    }
    _refreshStartedAt[key] = now();
    late final Future<RuntimeUsageRefresh> request;
    request =
        RaftClient.runWithHeaders(
              runtimeUsageRequestHeaders,
              () => post(
                '/servers/$server/machines/$machine/runtime-account-usage/$provider/refresh',
                {'reason': reason},
              ),
            )
            .then((value) {
              final result = RuntimeUsageRefresh.fromJson(value);
              if (result.state == 'fresh' && result.snapshot != null) {
                _store(key, RuntimeUsageRead('fresh', result.snapshot));
              }
              return result;
            })
            .whenComplete(() {
              if (identical(_refreshes[key], request)) _refreshes.remove(key);
            });
    return _refreshes[key] = request;
  }

  /// Time left before another refresh is allowed (zero when open).
  Duration cooldownRemaining(String server, String machine, String provider) {
    final last = _refreshStartedAt[_key(server, machine, provider)];
    if (last == null) return Duration.zero;
    final left = cooldown - now().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  void invalidate(String server, String machine, String provider) =>
      _cache.remove(_key(server, machine, provider));
}
