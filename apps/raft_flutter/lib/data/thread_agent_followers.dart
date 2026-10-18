import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

/// Current-server transport and identity needed by thread follower rosters.
abstract interface class ThreadAgentFollowersAuthority {
  RaftClient get client;
  RaftRecord? get server;
}

/// Web `ThreadAgentFollower`: one agent following a thread.
@immutable
class ThreadAgentFollower {
  const ThreadAgentFollower(this.json);
  final Map<String, dynamic> json;
  String get id => '${json['id']}';
  String get name => '${json['name'] ?? ''}';
  String? get displayName => json['displayName'] as String?;

  /// Web: `agent.displayName || agent.name`.
  String get label {
    final display = displayName;
    return display != null && display.isNotEmpty ? display : name;
  }

  String get status => '${json['status'] ?? ''}';
  String? get avatarUrl => json['avatarUrl'] as String?;
  bool get isCurrentServer => json['isCurrentServer'] != false;
  bool get canRemove => json['canRemove'] != false;

  /// Web `agent.serverName || agent.serverSlug`.
  String? get serverLabel {
    final name = json['serverName'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final slug = json['serverSlug'] as String?;
    return slug != null && slug.isNotEmpty ? slug : null;
  }
}

/// Web `ThreadAgentFollowerRoster`.
@immutable
class ThreadAgentFollowerRoster {
  const ThreadAgentFollowerRoster({
    this.agents = const [],
    this.canManage = false,
    this.loading = false,
    this.loaded = false,
    this.error = false,
  });
  final List<ThreadAgentFollower> agents;
  final bool canManage, loading, loaded, error;
  ThreadAgentFollowerRoster copyWith({
    List<ThreadAgentFollower>? agents,
    bool? canManage,
    bool? loading,
    bool? loaded,
    bool? error,
  }) => ThreadAgentFollowerRoster(
    agents: agents ?? this.agents,
    canManage: canManage ?? this.canManage,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    error: error ?? this.error,
  );
}

/// Web `threadAgentFollowerStore`: per thread-channel rosters of the agents
/// following a thread, shared across presentations of the current identity.
class ThreadAgentFollowers extends ChangeNotifier {
  ThreadAgentFollowers(this.w) {
    _events = w.client.events.listen(_event);
  }
  final ThreadAgentFollowersAuthority w;
  final Map<String, ThreadAgentFollowerRoster> _rosters = {};
  late final StreamSubscription<RaftEvent> _events;
  Object? _identity;
  int _epoch = 0, _serial = 0;
  final Map<String, int> _reads = {};
  bool _disposed = false;

  // `requestThreadAgentFollowers`: coalesce the requests of one frame.
  final Map<String, bool> _queued = {};
  bool _flushing = false;

  int _scope() {
    final identity = (
      w.client.origin,
      w.client.user?.id,
      w.client.generation,
      w.client.serverId,
      w.server?.id,
      w.server?.string('role'),
    );
    if (identity != _identity) {
      _identity = identity;
      _epoch++;
      _rosters.clear();
      _queued.clear();
      _reads.clear();
    }
    return _epoch;
  }

  bool _current(int epoch) => !_disposed && _scope() == epoch;

  void _event(RaftEvent event) {
    if (_disposed || event.name != 'thread:followers-updated') return;
    _scope();
    final payload = event.payload;
    final id = payload is Map ? payload['threadChannelId'] : null;
    // SocketBridge refreshes rosters even with no mounted popover. Unopened
    // threads need no cache entry: their first view loads the current roster.
    if (id is String && (_rosters.containsKey(id) || _queued.containsKey(id))) {
      request(id, force: true);
    }
  }

  ThreadAgentFollowerRoster? roster(String threadChannelId) {
    _scope();
    return _rosters[threadChannelId];
  }

  /// Web: no affordance while the count is unknown or the thread has none; a
  /// failed load still shows the error-only trigger.
  bool visible(String threadChannelId) {
    final r = roster(threadChannelId);
    if (r == null || r.loading && !r.loaded) return false;
    return !(r.loaded && r.agents.isEmpty);
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  /// Web `requestThreadAgentFollowers`.
  void request(String threadChannelId, {bool force = false}) {
    if (_disposed) return;
    _scope();
    _queued[threadChannelId] = (_queued[threadChannelId] ?? false) || force;
    if (_flushing) return;
    _flushing = true;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Coalesces requests into one flush; guarded by _flushing.
    scheduleMicrotask(() {
      _flushing = false;
      if (_disposed) return;
      _scope();
      final entries = Map.of(_queued);
      _queued.clear();
      final cached = [
        for (final e in entries.entries)
          if (!e.value) e.key,
      ];
      final forced = [
        for (final e in entries.entries)
          if (e.value) e.key,
      ];
      if (cached.isNotEmpty) unawaited(load(cached));
      if (forced.isNotEmpty) unawaited(load(forced, force: true));
    });
  }

  Future<void> load(List<String> threadChannelIds, {bool force = false}) async {
    if (_disposed) return;
    final epoch = _scope();
    final ids = {
      for (final id in threadChannelIds)
        if (force ||
            !(_rosters[id]?.loaded ?? false) &&
                !(_rosters[id]?.loading ?? false))
          id,
    }.toList();
    if (ids.isEmpty) return;
    // The mounted server route accepts at most 100 thread IDs per request.
    // A burst may cover many rosters retained from earlier presentations.
    if (ids.length > 100) {
      for (var i = 0; i < ids.length && _current(epoch); i += 100) {
        await load(ids.skip(i).take(100).toList(), force: force);
      }
      return;
    }
    final serial = ++_serial;
    for (final id in ids) {
      _reads[id] = serial;
      _rosters[id] = (_rosters[id] ?? const ThreadAgentFollowerRoster())
          .copyWith(loading: true, error: false);
    }
    _emit();
    var changed = false;
    try {
      final data = await w.client.get(
        '/channels/threads/followers',
        query: {'threadChannelIds': ids.join(',')},
      );
      if (!_current(epoch)) return;
      final rows = <String, Map>{
        for (final row in (data['threads'] as List? ?? const []))
          if (row is Map) '${row['threadChannelId']}': row,
      };
      for (final id in ids) {
        if (_reads[id] != serial) continue;
        changed = true;
        final row = rows[id];
        _rosters[id] = ThreadAgentFollowerRoster(
          agents: [
            for (final agent in (row?['agents'] as List? ?? const []))
              if (agent is Map)
                ThreadAgentFollower(Map<String, dynamic>.from(agent)),
          ],
          canManage: row?['canManage'] == true,
          loaded: true,
        );
      }
    } catch (_) {
      if (!_current(epoch)) return;
      for (final id in ids) {
        if (_reads[id] != serial) continue;
        changed = true;
        _rosters[id] = (_rosters[id] ?? const ThreadAgentFollowerRoster())
            .copyWith(loading: false, loaded: false, error: true);
      }
    }
    if (changed) _emit();
  }

  /// Web `remove`: the undo token, or null when the server did not remove.
  Future<String?> remove(String threadChannelId, String agentId) async {
    if (_disposed) return null;
    final epoch = _scope();
    dynamic data;
    try {
      data = await w.client.request(
        'DELETE',
        '/channels/threads/$threadChannelId/followers/agents/$agentId',
      );
    } catch (_) {
      if (!_current(epoch)) return null;
      rethrow;
    }
    if (!_current(epoch) ||
        data is! Map ||
        data['removed'] != true ||
        data['undoToken'] is! String) {
      return null;
    }
    final current =
        _rosters[threadChannelId] ?? const ThreadAgentFollowerRoster();
    // An earlier read must not put a successfully removed agent back.
    _reads[threadChannelId] = ++_serial;
    _rosters[threadChannelId] = current.copyWith(
      loading: false,
      agents: [
        for (final agent in current.agents)
          if (agent.id != agentId) agent,
      ],
    );
    _emit();
    return data['undoToken'] as String;
  }

  /// Web `restore`: true once the server restored the follower (the roster
  /// reloads).
  Future<bool> restore(
    String threadChannelId,
    String agentId,
    String undoToken,
  ) async {
    if (_disposed) return false;
    final epoch = _scope();
    dynamic data;
    try {
      data = await w.client.request(
        'POST',
        '/channels/threads/$threadChannelId/followers/agents/$agentId/restore',
        data: {'undoToken': undoToken},
      );
    } catch (_) {
      if (!_current(epoch)) return false;
      rethrow;
    }
    if (!_current(epoch) || data is! Map || data['restored'] != true) {
      return false;
    }
    await load([threadChannelId], force: true);
    return _current(epoch);
  }

  @override
  void dispose() {
    _disposed = true;
    _queued.clear();
    unawaited(_events.cancel());
    super.dispose();
  }
}
