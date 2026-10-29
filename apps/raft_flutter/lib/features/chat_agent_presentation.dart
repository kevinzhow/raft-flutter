import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart' show agentActivityText;
import 'message_reference_directory.dart';
import 'private_route_guard.dart';

/// Spec working-agents timing: an agent stays listed for [graceMs] after it
/// goes idle, and is dropped when no signal came for [signalExpiryMs].
const liveAgentGraceMs = 5000;
const liveAgentSignalExpiryMs = 90000;

/// One agent's current work. [createdAt] is the newest signal's timestamp,
/// [startedAt] when the agent started working (kept while it keeps working or
/// pauses within the grace period) and orders the list; [idleAt] is set while
/// the agent is in the grace period after going idle.
class LiveAgentWork {
  const LiveAgentWork(
    this.agentId,
    this.activity,
    this.text,
    this.createdAt, {
    int? startedAt,
    this.idleAt,
  }) : startedAt = startedAt ?? createdAt;
  final String agentId, activity, text;
  final int createdAt, startedAt;
  final int? idleAt;

  /// Still listed at [now] (ms since epoch).
  bool listedAt(int now) => idleAt == null
      ? now - createdAt < liveAgentSignalExpiryMs
      : now - idleAt! < liveAgentGraceMs &&
            now - createdAt < liveAgentSignalExpiryMs;

  /// When this entry stops being listed if nothing else happens.
  int get expiresAt => idleAt == null
      ? createdAt + liveAgentSignalExpiryMs
      : (idleAt! + liveAgentGraceMs).clamp(
          0,
          createdAt + liveAgentSignalExpiryMs,
        );

  LiveAgentWork idle(int at) => LiveAgentWork(
    agentId,
    activity,
    text,
    createdAt,
    startedAt: startedAt,
    idleAt: at,
  );
}

/// Source liveAgentActivity.ts: only real working/thinking signals, terminal
/// clear, heartbeat refresh in place, bounded 20 items and 90s safety expiry,
/// plus the Raft Design System's working-agents rules: the list is ordered by
/// when each agent started and keeps that order while the work goes on; an
/// agent that goes idle stays for a 5 second grace period (agents pause
/// between steps); an agent that stops (error, offline) leaves at once.
/// Directory authority and sender IDs come from current permission-checked GET.
/// Like Source useClearLiveAgentActivityOnServerChange, items are server-level:
/// they clear only on a server-level identity change ([directoryAuthority]),
/// never on a channel switch, thread open or channel capability refresh.
class ChatAgentPresentation extends ChangeNotifier {
  ChatAgentPresentation(this.w, this.directory, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    directory.addListener(changed);
    w.addListener(changed);
    events = w.client.events.listen(event);
    changed();
  }
  final WorkspaceController w;
  final MessageReferenceDirectory directory;
  final DateTime Function() clock;
  StreamSubscription<RaftEvent>? events;
  Timer? expiry;
  String? scope;
  bool ended = false;

  /// Every tracked agent in the order it started (including entries whose
  /// grace period or signal window has passed but have not been pruned yet).
  List<LiveAgentWork> items = [];
  final sequences = <String, BigInt>{};
  String _publishedSignature = '';
  final _rowTexts = <String, ValueNotifier<String?>>{};

  int get _now => clock().millisecondsSinceEpoch;

  /// The agents shown now, in the order they started.
  List<LiveAgentWork> get working {
    final now = _now;
    return [
      for (final item in items)
        if (item.listedAt(now) && agent(item.agentId) != null) item,
    ];
  }

  /// Everything the UI shows, so a heartbeat or an expired-but-hidden entry
  /// never republishes.
  String get _signature => [
    for (final item in working)
      '${item.agentId}\u0000${item.text}\u0000${item.activity}',
  ].join('\u0001');

  void _publish() {
    _publishedSignature = _signature;
    for (final entry in _rowTexts.entries) {
      entry.value.value = _rowText(entry.key);
    }
    notifyListeners();
  }

  /// What the agent's sidebar / Home row shows in place of its runtime, or
  /// null (an external agent keeps its runtime: its presence is estimated and
  /// the activity can outlive it).
  String? _rowText(String agentId) {
    final row = agent(agentId);
    if (row == null ||
        row['external'] == true ||
        row['runtime'] == 'external') {
      return null;
    }
    return working.where((i) => i.agentId == agentId).firstOrNull?.text;
  }

  /// A listenable for one agent's row text; stays valid until [dispose].
  ValueListenable<String?> rowText(String agentId) =>
      _rowTexts.putIfAbsent(agentId, () => ValueNotifier(_rowText(agentId)));

  Map<String, dynamic>? agent(String id) =>
      directory.agents.where((a) => a['id'] == id).firstOrNull;
  String? modelLabel(String id) {
    if (directory.scope != directoryAuthority(w) || !w.can('viewAgents')) {
      return null;
    }
    final value = agent(id)?['model'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  /// The directory facts the presented items were last checked against.
  Object? checked;

  /// Runs on every workspace and directory notification; notifies only when
  /// the presented items or the identities they render actually change.
  void changed() {
    if (ended) return;
    final next = directoryAuthority(w);
    var dirty = false;
    if (scope != next) {
      scope = next;
      items = [];
      sequences.clear();
      expiry?.cancel();
      dirty = true;
    }
    final facts = (next, directory.scope, directory.revision);
    if (facts != checked) {
      checked = facts;
      dirty = true;
    }
    final kept = items
        .where(
          (i) =>
              directory.scope == directoryAuthority(w) &&
              agent(i.agentId) != null,
        )
        .toList();
    if (kept.length != items.length) dirty = true;
    items = kept;
    if (dirty) _publish();
  }

  void event(RaftEvent event) {
    if (ended ||
        event.name != 'agent:activity' ||
        event.payload is! Map ||
        scope != directoryAuthority(w) ||
        directory.scope != directoryAuthority(w) ||
        !w.can('viewAgents')) {
      return;
    }
    final data = event.payload as Map, id = data['agentId'];
    if (id is! String ||
        agent(id) == null ||
        (data['serverId'] != null && data['serverId'] != w.server?.id)) {
      return;
    }
    final seq = BigInt.tryParse('${data['serverSeq'] ?? ''}');
    if (seq != null && sequences[id] != null && seq <= sequences[id]!) return;
    if (seq != null) sequences[id] = seq;
    final activity = data['activityKind'] ?? data['activity'];
    final now = _now;
    final timestamp =
        data['timestamp'] is num && (data['timestamp'] as num).isFinite
        ? (data['timestamp'] as num).toInt()
        : now;
    if (timestamp > now + 300000) return;
    final index = items.indexWhere((i) => i.agentId == id);
    if (activity == 'working' || activity == 'thinking') {
      // A signal that is already past the safety window never invents a row.
      if (now - timestamp >= liveAgentSignalExpiryMs) return;
      final detail = '${data['detail'] ?? ''}'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final kind = data['detailKind'];
      final text = agentActivityText(
        activity as String,
        detail,
        kind is String ? kind : null,
      );
      final shortText = text.length <= 140
          ? text
          : '${text.substring(0, 139).trimRight()}…';
      final refreshOnly =
          data['isHeartbeat'] == true || data['isRefreshOnly'] == true;
      if (index >= 0) {
        // In place: the agent keeps its start time and its place in the list
        // while it keeps working, or resumes within the grace period.
        final old = items[index];
        items[index] = LiveAgentWork(
          id,
          activity,
          shortText,
          timestamp > old.createdAt ? timestamp : old.createdAt,
          startedAt: old.startedAt,
        );
      } else if (!refreshOnly) {
        items = [...items, LiveAgentWork(id, activity, shortText, timestamp)];
        if (items.length > 20) items = items.sublist(items.length - 20);
      }
    } else if (index >= 0) {
      if (activity == 'online') {
        // Idle: agents pause between steps, so the row stays for the grace
        // period (from the first idle signal).
        if (items[index].idleAt == null) items[index] = items[index].idle(now);
      } else {
        // Stopped (error, offline): it leaves at once.
        items.removeAt(index);
      }
    }
    _schedule();
    if (_signature != _publishedSignature) _publish();
  }

  /// Arms one timer for the next entry to leave (grace end or signal expiry).
  void _schedule() {
    expiry?.cancel();
    if (ended || items.isEmpty) return;
    final now = _now;
    final next = items.map((i) => i.expiresAt).reduce((a, b) => a < b ? a : b);
    expiry = Timer(
      Duration(milliseconds: (next + 50 - now).clamp(1, 90050)),
      prune,
    );
  }

  void prune() {
    final now = _now;
    items = items.where((i) => i.listedAt(now)).toList();
    _schedule();
    // The signature already filters by the clock, so an expired entry that was
    // displayed changes it even before the list is pruned.
    if (_signature != _publishedSignature) _publish();
  }

  @override
  void dispose() {
    ended = true;
    expiry?.cancel();
    events?.cancel();
    w.removeListener(changed);
    directory.removeListener(changed);
    items = [];
    _publishedSignature = '';
    sequences.clear();
    for (final text in _rowTexts.values) {
      text.dispose();
    }
    _rowTexts.clear();
    super.dispose();
  }
}
