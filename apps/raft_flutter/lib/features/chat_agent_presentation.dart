import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'message_reference_directory.dart';
import 'private_route_guard.dart';

class LiveAgentWork {
  const LiveAgentWork(this.agentId, this.activity, this.text, this.createdAt);
  final String agentId, activity, text;
  final int createdAt;
}

/// Source liveAgentActivity.ts: only real working/thinking signals, terminal
/// clear, heartbeat refresh in place, bounded20 items and90s safety expiry.
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
  List<LiveAgentWork> items = [];
  final sequences = <String, BigInt>{};
  Map<String, dynamic>? agent(String id) =>
      directory.agents.where((a) => a['id'] == id).firstOrNull;
  String? modelLabel(String id) {
    if (directory.scope != directoryAuthority(w) || !w.can('viewAgents')) {
      return null;
    }
    final value = agent(id)?['model'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  LiveAgentWork? get latest => items
      .where(
        (i) =>
            clock().millisecondsSinceEpoch - i.createdAt < 90000 &&
            agent(i.agentId) != null,
      )
      .firstOrNull;
  void changed() {
    if (ended) return;
    final next = directoryAuthority(w);
    if (scope != next) {
      scope = next;
      items = [];
      sequences.clear();
      expiry?.cancel();
    }
    items = items
        .where(
          (i) =>
              directory.scope == directoryAuthority(w) &&
              agent(i.agentId) != null,
        )
        .toList();
    notifyListeners();
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
    final now = clock().millisecondsSinceEpoch;
    final timestamp =
        data['timestamp'] is num && (data['timestamp'] as num).isFinite
        ? (data['timestamp'] as num).toInt()
        : now;
    if (timestamp > now + 300000) return;
    items = items.where((i) => now - i.createdAt < 90000).toList();
    if (!['working', 'thinking'].contains(activity)) {
      items.removeWhere((i) => i.agentId == id);
    } else {
      final detail = '${data['detail'] ?? ''}'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final kind = data['detailKind'];
      final text = switch (kind) {
        'delivery_unconsumed' => 'Messages delivered, runtime not responding',
        'wake_crash_loop_blocked' => 'Automatic wake paused — start manually',
        'terminal_failure_paused' =>
          detail.isEmpty
              ? 'Automatic wake paused after repeated runtime failures — a manual start lifts it'
              : detail,
        'starting' || 'runtime_starting' => 'Starting…',
        'compacting_context' => 'Compacting context…',
        _ =>
          activity == 'thinking'
              ? 'Thinking…'
              : detail.isEmpty
              ? 'Working…'
              : detail,
      };
      final row = LiveAgentWork(
        id,
        activity as String,
        text.length <= 140 ? text : '${text.substring(0, 139).trimRight()}…',
        timestamp,
      );
      if (data['isHeartbeat'] == true || data['isRefreshOnly'] == true) {
        final index = items.indexWhere((i) => i.agentId == id);
        if (index >= 0) items[index] = row;
      } else if (items.isEmpty ||
          items.first.agentId != id ||
          items.first.text != row.text ||
          (items.first.createdAt - timestamp).abs() >= 2000) {
        items = [row, ...items.where((i) => i.agentId != id)].take(20).toList();
      }
    }
    expiry?.cancel();
    if (items.isNotEmpty) {
      final oldest = items
          .map((i) => i.createdAt)
          .reduce((a, b) => a < b ? a : b);
      expiry = Timer(
        Duration(milliseconds: (oldest + 90050 - now).clamp(1, 90050)),
        prune,
      );
    }
    notifyListeners();
  }

  void prune() {
    final now = clock().millisecondsSinceEpoch;
    items = items.where((i) => now - i.createdAt < 90000).toList();
    expiry?.cancel();
    if (items.isNotEmpty) {
      final oldest = items
          .map((i) => i.createdAt)
          .reduce((a, b) => a < b ? a : b);
      expiry = Timer(
        Duration(milliseconds: (oldest + 90050 - now).clamp(1, 90050)),
        prune,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    ended = true;
    expiry?.cancel();
    events?.cancel();
    w.removeListener(changed);
    directory.removeListener(changed);
    items = [];
    sequences.clear();
    super.dispose();
  }
}
