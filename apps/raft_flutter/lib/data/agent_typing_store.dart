import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show AgentTypingEvent, LiveEvent;

// Agent typing line (Web 1.24 store/agentTypingStore.ts, raft-design 0042):
// who is about to post where. Fed by the server's `agent:typing` event (to
// the conversation's own room). One entry per live tool call (agent + call
// id), kept per channel in the order the calls started, so faces and names
// never reshuffle on a refresh. An entry leaves on its `end`, when its
// deadline passes (one timer for the earliest deadline, none while empty),
// when the agent's message lands there, and on reconnect (the server re-sends
// live calls on refresh).
//
// It reads the client's event stream itself while something shows a typing
// line, so the realtime plumbing needs no change for it.

/// shared/agentTyping.ts `AGENT_TYPING_TTL_MS`.
const agentTypingTtl = Duration(seconds: 20);

/// Calls kept as "posted, ignore its starts"; the oldest goes past this.
const agentTypingClearedCallsMax = 128;

@immutable
class AgentTypingEntry {
  const AgentTypingEntry({
    required this.agentId,
    required this.callId,
    required this.channelId,
    required this.parentMessageId,
    required this.startedAt,
    required this.deadline,
  });
  final String agentId, callId, channelId;
  final String? parentMessageId;

  /// Local ms of the call's first `start`, and after which it is dropped.
  final int startedAt, deadline;
}

/// `expiresAt` is the server's clock: a remaining time outside (0, TTL] falls
/// back to the TTL from now.
int localTypingDeadline(int expiresAt, int now) {
  final remaining = expiresAt - now;
  final ttl = agentTypingTtl.inMilliseconds;
  return now + (remaining > 0 && remaining <= ttl ? remaining : ttl);
}

/// The typing reducer for one workspace's client. A plain [Listenable] (not a
/// ChangeNotifier): it lives as long as its client and holds nothing while
/// nobody listens.
class AgentTypingStore implements Listenable {
  AgentTypingStore({
    required this.events,
    required this.serverId,
    int Function()? now,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// The client's realtime events.
  final Stream<RaftEvent> events;

  /// The server whose events count (the client's selected server).
  final String? Function() serverId;
  final int Function() _now;

  static final _stores = Expando<AgentTypingStore>('agent typing');

  /// The store for [client] (one per client).
  static AgentTypingStore of(RaftClient client) => _stores[client] ??=
      AgentTypingStore(events: client.events, serverId: () => client.serverId);

  final _byChannel = <String, List<AgentTypingEntry>>{};
  final _clearedCalls = <String, int>{};
  StreamSubscription<RaftEvent>? _subscription;
  Timer? _expiry;
  String? _server;
  final _listeners = <VoidCallback>[];

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    if (_listeners.length == 1) {
      _subscription = events.listen(receive);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (!_listeners.remove(listener)) return;
    if (_listeners.isEmpty) {
      // Nothing shows a line: stop listening and forget, as a reload would.
      unawaited(_subscription?.cancel());
      _subscription = null;
      _reset();
    }
  }

  void _reset() {
    _expiry?.cancel();
    _expiry = null;
    _byChannel.clear();
    _clearedCalls.clear();
  }

  /// Handles one realtime event.
  void receive(RaftEvent event) {
    switch (event.name) {
      case AgentTypingEvent.name:
        // The wire shape is raft_sync's (`LiveEvent.read`).
        if (LiveEvent.read(event.name, event.payload)
            case final AgentTypingEvent typing
            when typing.serverId == serverId()) {
          apply(typing);
        }
      case 'message:new':
        final message = event.payload;
        if (message is Map) clearForMessage(message);
      case 'connected':
        // A reconnect starts over; the server re-sends live calls.
        clear();
    }
  }

  void _commit() {
    _scheduleExpiry();
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void _checkServer() {
    final server = serverId();
    if (server == _server) return;
    _server = server;
    _reset();
  }

  static String _key(String agentId, String callId) => '$agentId\u0000$callId';

  void _rememberCleared(Iterable<AgentTypingEntry> entries, int now) {
    for (final entry in entries) {
      final key = _key(entry.agentId, entry.callId);
      _clearedCalls.remove(key);
      _clearedCalls[key] = now + agentTypingTtl.inMilliseconds;
    }
    while (_clearedCalls.isNotEmpty &&
        (_clearedCalls.length > agentTypingClearedCallsMax ||
            _clearedCalls.values.first <= now)) {
      _clearedCalls.remove(_clearedCalls.keys.first);
    }
  }

  /// A start for a call whose message already landed: ignored, and it keeps
  /// the call remembered while it repeats.
  bool _isClearedCall(String agentId, String callId, int now) {
    final key = _key(agentId, callId);
    final until = _clearedCalls.remove(key);
    if (until == null || until <= now) return false;
    _clearedCalls[key] = now + agentTypingTtl.inMilliseconds;
    return true;
  }

  void apply(AgentTypingEvent event) {
    _checkServer();
    final entries = _byChannel[event.channelId] ?? const <AgentTypingEntry>[];
    final index = entries.indexWhere(
      (e) => e.agentId == event.agentId && e.callId == event.callId,
    );
    if (!event.started) {
      if (index < 0) return;
      _set(event.channelId, [...entries]..removeAt(index));
      _commit();
      return;
    }
    final now = _now();
    if (index < 0 && _isClearedCall(event.agentId, event.callId, now)) return;
    final deadline = localTypingDeadline(event.expiresAt, now);
    final entry = AgentTypingEntry(
      agentId: event.agentId,
      callId: event.callId,
      channelId: event.channelId,
      parentMessageId: event.parentMessageId,
      startedAt: index < 0 ? now : entries[index].startedAt,
      deadline: deadline,
    );
    // A refresh keeps its place in line with a new deadline.
    _set(
      event.channelId,
      index < 0 ? [...entries, entry] : ([...entries]..[index] = entry),
    );
    _commit();
  }

  void _set(String channelId, List<AgentTypingEntry> entries) {
    if (entries.isEmpty) {
      _byChannel.remove(channelId);
    } else {
      _byChannel[channelId] = entries;
    }
  }

  bool _removeWhere(bool Function(AgentTypingEntry) drop) {
    var changed = false;
    for (final channelId in _byChannel.keys.toList()) {
      final entries = _byChannel[channelId]!;
      final kept = entries.where((e) => !drop(e)).toList();
      if (kept.length == entries.length) continue;
      changed = true;
      _set(channelId, kept);
    }
    return changed;
  }

  /// Web `clearAgentTypingForMessage`: an agent's message landed, so it is no
  /// longer about to post there. A thread reply carries its root in
  /// `conversationContext`; anything else is a post into `channelId`.
  void clearForMessage(Map<dynamic, dynamic> message) {
    if (message['senderType'] != 'agent') return;
    final agentId = message['senderId'], channelId = message['channelId'];
    if (agentId is! String || channelId is! String) return;
    final context = message['conversationContext'];
    final cleared = <AgentTypingEntry>[];
    bool Function(AgentTypingEntry) drop;
    if (context is Map && context['channelType'] == 'thread') {
      final parent = context['parentMessageId'];
      if (parent is! String) return;
      drop = (e) => e.agentId == agentId && e.parentMessageId == parent;
    } else {
      drop = (e) =>
          e.channelId == channelId &&
          e.agentId == agentId &&
          e.parentMessageId == null;
    }
    if (!_removeWhere((e) {
      final gone = drop(e);
      if (gone) cleared.add(e);
      return gone;
    })) {
      return;
    }
    _rememberCleared(cleared, _now());
    _commit();
  }

  void pruneExpired() {
    final now = _now();
    if (_removeWhere((e) => e.deadline <= now)) {
      _commit();
    } else {
      _scheduleExpiry();
    }
  }

  void clear() {
    _clearedCalls.clear();
    if (_byChannel.isEmpty) return;
    _byChannel.clear();
    _commit();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    _expiry = null;
    var next = -1;
    for (final entries in _byChannel.values) {
      for (final entry in entries) {
        if (next < 0 || entry.deadline < next) next = entry.deadline;
      }
    }
    if (next < 0) return;
    // At least a frame later: a deadline already due is pruned on its own
    // turn, never in a tight loop.
    _expiry = Timer(Duration(milliseconds: math.max(16, next - _now())), () {
      _expiry = null;
      pruneExpired();
    });
  }

  /// The agents typing into one conversation (the channel itself when
  /// [parentMessageId] is null, or one thread under it), each once, in the
  /// order they started.
  List<String> typingAgentIds(String? channelId, String? parentMessageId) {
    _checkServer();
    if (channelId == null) return const [];
    final ids = <String>[];
    for (final entry in _byChannel[channelId] ?? const <AgentTypingEntry>[]) {
      if (entry.parentMessageId != parentMessageId) continue;
      if (!ids.contains(entry.agentId)) ids.add(entry.agentId);
    }
    return ids;
  }

  /// Stops listening (tests; the client's store is never disposed).
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _listeners.clear();
    _reset();
  }
}
