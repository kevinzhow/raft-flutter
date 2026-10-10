import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'resource_row_reconcile.dart' show rowDeepEquals;
import 'source_task_bucket.dart';
import 'task_board_reconcile.dart' show mergeTaskFields;
import 'workspace_controller.dart';

const messageTaskStatuses = [
  'todo',
  'in_progress',
  'in_review',
  'done',
  'closed',
];

/// Client principal and server: shared by every controller on one client.
String _principal(RaftClient client) => jsonEncode([
  client.origin,
  client.generation,
  client.user?.id,
  client.serverId,
]);

/// Principal, server and role that accepted the cached task references. A
/// change here drops every channel bucket; nothing else does.
String messageTaskIdentity(WorkspaceController w) =>
    jsonEncode([_principal(w.client), w.server?.string('role')]);

RaftChannel? _channel(WorkspaceController w, String channelId) =>
    w.channel?.id == channelId
    ? w.channel
    : [...w.channels, ...w.dms].where((c) => c.id == channelId).firstOrNull;

/// The channel record's authority fields (Source loadTasks bucket key).
String messageTaskChannelAuthority(WorkspaceController w, String channelId) {
  final channel = _channel(w, channelId);
  return jsonEncode([
    channel?.joined,
    channel?.archived,
    channel?.json['channelCapabilities'],
  ]);
}

/// A complete channel task row that may be shown on its message.
bool acceptedMessageTask(Object? raw, String channelId) =>
    raw is Map &&
    raw['channelId'] == channelId &&
    raw['messageId'] is String &&
    raw['id'] is String &&
    raw['taskNumber'] is int &&
    raw['title'] is String &&
    messageTaskStatuses.contains(raw['status']);

class _Bucket {
  Map<String, Map<String, dynamic>> byMessage = const {};
  bool loaded = false, stale = true;
  DateTime? acceptedAt;
  int ticket = 0, inFlight = 0;

  /// Live task facts (null = deleted) received while a read is in flight;
  /// they are applied over its response.
  final touched = <String, Map<String, dynamic>?>{};
}

final _caches = Expando<MessageTaskCache>();

/// Channel task references by message, kept per client for the bound
/// principal/server/role identity (Source taskStore keeps channel buckets
/// across navigation). Channel switches, thread opens, reconnects and task
/// events never clear it: task:* events patch the single task in place and
/// stale buckets are revalidated in the background, so a chip that is on
/// screen keeps its place. This is presentation data, never an authorization:
/// readers check the identity and the channel permission on every read.
class MessageTaskCache extends ChangeNotifier {
  MessageTaskCache._(this.client) {
    // Lives as long as the client, whose stream owns the subscription.
    client.events.listen(_event);
  }

  factory MessageTaskCache.of(RaftClient client) =>
      _caches[client] ??= MessageTaskCache._(client);

  /// A bucket older than this is revalidated in the background when shown.
  static const maxAge = Duration(minutes: 5);

  final RaftClient client;
  String? _principalKey;

  /// Channel buckets by role identity. Controllers sharing this client may
  /// briefly hold different roles; each reads only its own identity.
  final _scopes = <String, Map<String, _Bucket>>{};
  Iterable<_Bucket> get _all => _scopes.values.expand((s) => s.values);

  /// Bind to [w]'s identity. A principal change (account, session or server
  /// on this client) drops every bucket.
  Map<String, _Bucket> _bind(WorkspaceController w) {
    final principal = _principal(client);
    if (_principalKey != principal) {
      final had = _all.any((b) => b.loaded);
      _principalKey = principal;
      _scopes.clear();
      if (had) notifyListeners();
    }
    final identity = messageTaskIdentity(w);
    var scope = _scopes.remove(identity);
    if (scope == null) {
      // A new role on the same principal starts empty. The other role's
      // buckets serve only controllers still holding that role, and are
      // revalidated before they are trusted again.
      scope = {};
      for (final bucket in _all) {
        bucket.stale = true;
      }
    }
    _scopes[identity] = scope;
    while (_scopes.length > 2) {
      _scopes.remove(_scopes.keys.first);
    }
    return scope;
  }

  /// Accepted tasks of [channelId] under [w]'s identity, or null when the
  /// channel has not been loaded for it.
  Map<String, Map<String, dynamic>>? tasks(
    WorkspaceController w,
    String channelId,
  ) {
    if (_principalKey != _principal(client)) return null;
    final bucket = _scopes[messageTaskIdentity(w)]?[channelId];
    return bucket != null && bucket.loaded ? bucket.byMessage : null;
  }

  bool needsRevalidation(WorkspaceController w, String channelId) {
    if (_principalKey != _principal(client)) return true;
    final bucket = _scopes[messageTaskIdentity(w)]?[channelId];
    if (bucket == null || !bucket.loaded || bucket.stale) return true;
    final at = bucket.acceptedAt;
    return at == null || DateTime.now().difference(at) > maxAge;
  }

  /// Revalidate [channelId] at the next read without dropping what is shown.
  void markStale(String channelId) {
    for (final scope in _scopes.values) {
      scope[channelId]?.stale = true;
    }
  }

  /// Reduced channel authority: drop that channel's facts.
  void evict(String channelId) {
    var had = false;
    for (final scope in _scopes.values) {
      if (scope.remove(channelId) case final bucket?) {
        had = had || bucket.loaded;
      }
    }
    if (had) notifyListeners();
  }

  /// Background read of [channelId]'s task bucket. The shown bucket stays in
  /// place until the response is accepted; unchanged tasks keep their
  /// objects. A response is dropped when the identity, the channel authority
  /// or the view permission changed while it was in flight.
  Future<void> revalidate(WorkspaceController w, String channelId) async {
    final identity = messageTaskIdentity(w);
    final scope = _bind(w);
    final bucket = scope.putIfAbsent(channelId, _Bucket.new);
    final ticket = ++bucket.ticket;
    final authority = messageTaskChannelAuthority(w, channelId);
    bucket.inFlight++;
    dynamic result;
    try {
      result = await readSourceTaskBucket(w, channelId);
    } catch (_) {
      // An unavailable directory supplies no task reference, never a fake
      // badge; what is already shown stays until a later read succeeds.
      return;
    } finally {
      bucket.inFlight--;
    }
    if (identity != messageTaskIdentity(w) ||
        !identical(_scopes[identity], scope) ||
        !identical(scope[channelId], bucket) ||
        ticket != bucket.ticket ||
        authority != messageTaskChannelAuthority(w, channelId) ||
        result is! Map ||
        result['tasks'] is! List) {
      return;
    }
    final channel = _channel(w, channelId);
    if (channel != null && !w.can('viewChannel', resource: channel)) {
      evict(channelId);
      return;
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final raw in result['tasks'] as List) {
      if (acceptedMessageTask(raw, channelId)) {
        byId[raw['id']] = Map<String, dynamic>.from(raw);
      }
    }
    for (final MapEntry(key: id, value: fact) in bucket.touched.entries) {
      if (fact == null) {
        byId.remove(id);
      } else {
        final next = byId[id] == null ? fact : mergeTaskFields(byId[id]!, fact);
        if (acceptedMessageTask(next, channelId)) {
          byId[id] = next;
        } else if (fact['channelId'] != null &&
            fact['channelId'] != channelId) {
          byId.remove(id);
        }
      }
    }
    if (bucket.inFlight == 0) bucket.touched.clear();
    final previous = bucket.byMessage;
    final next = <String, Map<String, dynamic>>{};
    for (final task in byId.values) {
      final id = task['messageId'] as String;
      final old = previous[id];
      next[id] = old != null && rowDeepEquals(old, task)
          ? old
          : Map.unmodifiable(task);
    }
    final changed =
        !bucket.loaded ||
        next.length != previous.length ||
        next.entries.any((e) => !identical(previous[e.key], e.value));
    bucket
      ..byMessage = Map.unmodifiable(next)
      ..loaded = true
      ..stale = false
      ..acceptedAt = DateTime.now();
    if (changed) notifyListeners();
  }

  void _event(RaftEvent event) {
    switch (event.name) {
      case 'connected' || 'disconnected':
        // Events may have been missed: keep what is shown, revalidate.
        for (final bucket in _all) {
          bucket.stale = true;
        }
        if (event.name == 'connected' && _all.isNotEmpty) {
          notifyListeners();
        }
      case 'channel:removed':
        final payload = event.payload;
        if (payload is Map && payload['channelId'] is String) {
          evict(payload['channelId']);
        }
      case 'task:created' || 'task:updated' || 'task:deleted':
        _patch(event);
    }
  }

  /// Source taskRealtimeSync: upsert or remove the single task by id.
  void _patch(RaftEvent event) {
    final payload = event.payload;
    if (_all.isEmpty) return;
    if (payload is Map &&
        payload['serverId'] is String &&
        payload['serverId'] != client.serverId) {
      return;
    }
    Map<String, dynamic>? task(Object? raw) => raw is Map && raw['id'] is String
        ? Map<String, dynamic>.from(raw)
        : null;
    final patches = <String, Map<String, dynamic>?>{};
    if (payload is Map) {
      switch (event.name) {
        case 'task:created':
          final list = payload['tasks'] is List
              ? payload['tasks'] as List
              : [payload['task']];
          for (final raw in list) {
            if (task(raw) case final next?) patches[next['id']] = next;
          }
        case 'task:updated':
          final next =
              task(payload['task']) ??
              (payload['status'] is String ? task(payload) : null);
          if (next != null) patches[next['id']] = next;
        case 'task:deleted':
          final id =
              payload['taskId'] ??
              task(payload['task'])?['id'] ??
              payload['id'];
          if (id is String) patches[id] = null;
      }
    }
    if (patches.isEmpty) {
      // Unrecognised payload: revalidate in the background instead.
      for (final bucket in _all) {
        bucket.stale = true;
      }
      notifyListeners();
      return;
    }
    var changed = false;
    var stale = false;
    for (final MapEntry(key: id, value: fact) in patches.entries) {
      for (final MapEntry(key: channelId, value: bucket)
          in <MapEntry<String, _Bucket>>[
            for (final scope in _scopes.values) ...scope.entries,
          ]) {
        final existing = bucket.byMessage.values
            .where((row) => row['id'] == id)
            .firstOrNull;
        final belongs =
            fact != null &&
            (fact['channelId'] ?? existing?['channelId']) == channelId;
        if (existing == null && !belongs) continue;
        if (bucket.inFlight > 0) {
          final prior = bucket.touched[id];
          bucket.touched[id] = fact == null
              ? null
              : prior == null
              ? fact
              : mergeTaskFields(prior, fact);
        }
        if (!bucket.loaded) continue;
        final next = fact == null
            ? null
            : existing == null
            ? fact
            : mergeTaskFields(existing, fact);
        final rows = <String, Map<String, dynamic>>{...bucket.byMessage};
        if (existing != null) rows.remove(existing['messageId']);
        if (next != null && acceptedMessageTask(next, channelId)) {
          final key = next['messageId'] as String;
          rows[key] = existing != null && rowDeepEquals(existing, next)
              ? existing
              : Map.unmodifiable(next);
        } else if (next != null && belongs) {
          // A partial new task: keep the known chip, read the full row.
          if (existing != null) rows[existing['messageId']] = existing;
          bucket.stale = true;
          stale = true;
        }
        if (rows.length == bucket.byMessage.length &&
            rows.entries.every(
              (e) => identical(bucket.byMessage[e.key], e.value),
            )) {
          continue;
        }
        bucket.byMessage = Map.unmodifiable(rows);
        changed = true;
      }
    }
    if (changed || stale) notifyListeners();
  }
}
