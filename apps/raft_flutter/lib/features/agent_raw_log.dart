// Web v1.24 AgentActivityLog.tsx `RawActivityLog`: the Activity tab's Raw log.
// [AgentActivityLogSource] holds the agent's live activity window (Web
// `agentStore.trajectoryLogs[agentId]`), shared by the Overview, the Raw log
// and the Subagents view; [AgentRawLog] renders it as rows that follow the
// newest entry.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/workspace_controller.dart';
import 'agent_activity_refs.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'agent_subagent_groups.dart';
import 'agent_trajectory_log.dart';
import 'icu_message.dart';
import 'tool_display.dart';

/// Last accepted activity window of one agent, kept in the controller's
/// server-identity-bound cache. The Activity tab opens with it at its first
/// frame and a reload replaces it in place.
class AgentActivitySnapshot {
  bool loaded = false;
  List<Map<String, dynamic>> entries = [];
}

String _cacheKey(String agentId) => 'activity/$agentId';

/// The agent's live activity window the Activity tab holds (Web
/// `getActivityLog`); empty until that tab was opened.
List<Map<String, dynamic>> agentCachedActivityEntries(
  WorkspaceController w,
  String agentId,
) {
  final snapshot = w.agentTabCache.peek(_cacheKey(agentId));
  return snapshot is AgentActivitySnapshot ? snapshot.entries : const [];
}

// A row's key is the entry's own: the merge keeps each entry the same object
// across live appends and reloads, but the entries carry no id, and their place
// in the list shifts by one on every step once the log is at its 500-entry
// limit. Keyed by place, every row would remount on each new step (and a
// reader's place, and an expanded row, would go with it). Web
// `trajectoryEntryKey`.
final _entryKeys = Expando<String>('trajectoryEntryKey');
var _nextEntryKey = 0;
String trajectoryEntryKey(Map<String, dynamic> row) =>
    _entryKeys[row] ??= 'entry-${_nextEntryKey++}';

/// The agent's activity window: loads `/agents/:id/activity-log`, merges the
/// live `agent:activity` entries, and reloads on reconnect (Web
/// `loadTrajectoryLog`, `registerActivityTrajectoryLiveReload` and
/// `registerActivityTrajectoryReconnectReload`).
class AgentActivityLogSource extends ChangeNotifier {
  AgentActivityLogSource({
    required this.controller,
    required this.agentId,
    List<Map<String, dynamic>> initialEntries = const [],
  }) {
    _openingScope = _scope;
    _snapshot = _openSnapshot();
    _entries = mergeAgentTrajectoryLog(
      _snapshot.entries,
      admittedAgentTrajectoryRows(initialEntries),
    );
    _snapshot.entries = _entries;
    controller.addListener(_scopeChanged);
    _listenEvents();
  }

  final WorkspaceController controller;
  final String agentId;

  late String _openingScope;
  late AgentActivitySnapshot _snapshot;
  List<Map<String, dynamic>> _entries = [];
  StreamSubscription<RaftEvent>? _events;
  Timer? _reloadTimer;
  int _revision = 0;
  bool _active = true, _reloadWhenActive = false, _disposed = false;

  /// The window, oldest first, at most 500 rows.
  List<Map<String, dynamic>> get entries => _entries;

  /// The rows the raw log shows (hidden tool starts and the freshness-hold
  /// status rows left out).
  List<Map<String, dynamic>> get visibleEntries {
    if (!identical(_visibleFrom, _entries)) {
      _visible = [
        for (final row in _entries)
          if (isVisibleTrajectoryRow(row)) row,
      ];
      _visibleFrom = _entries;
    }
    return _visible;
  }

  List<Map<String, dynamic>> _visible = const [];
  List<Map<String, dynamic>>? _visibleFrom;

  /// A read has been accepted (or a snapshot of one was kept).
  bool get loaded => _snapshot.loaded;

  List<SubagentGroup>? _groups;
  List<Map<String, dynamic>>? _groupsFrom;
  String? Function(Map<String, dynamic>)? _keyOf;

  /// The subagent runs in the window, running first, then newest.
  List<SubagentGroup> get subagents {
    _foldSubagents();
    return _groups!;
  }

  /// The group key a row's lineage belongs to ([SubagentGroup.key]).
  String? subagentKeyOfRow(Map<String, dynamic> lineage) {
    _foldSubagents();
    final key = _keyOf!(lineage);
    return key != null && _groups!.any((g) => g.key == key) ? key : null;
  }

  void _foldSubagents() {
    if (identical(_groupsFrom, _entries)) return;
    _groups = groupSubagents(_entries);
    _keyOf = subagentKeyResolver(_entries);
    _groupsFrom = _entries;
  }

  String get _scope =>
      '${controller.client.origin}|${controller.client.generation}|${controller.client.user?.id}|${controller.client.serverId}|${controller.server?.id}|${controller.server?.string('role')}|$agentId';

  AgentActivitySnapshot _openSnapshot() => controller.agentTabCache.putIfAbsent(
    _cacheKey(agentId),
    AgentActivitySnapshot.new,
  ) as AgentActivitySnapshot;

  /// Whether the tab is on screen: an inactive tab defers its reload.
  void setActive(bool active) {
    final was = _active;
    _active = active;
    if (active && (!was || _reloadWhenActive)) {
      _reloadWhenActive = false;
      unawaited(reload());
    }
  }

  void _listenEvents() {
    _events = controller.client.events.listen((e) {
      if (e.name == 'connected') {
        _scheduleReload();
        return;
      }
      if (e.name != 'agent:activity' ||
          e.payload is! Map ||
          (e.payload as Map)['agentId'] != agentId) {
        return;
      }
      final payload = e.payload as Map;
      if (payload['isHeartbeat'] == true ||
          payload['isRefreshOnly'] == true ||
          (payload['sourceServerId'] != null &&
              payload['sourceServerId'] != controller.server?.id)) {
        return;
      }
      final raw = payload['entries'];
      if (raw is List && raw.isNotEmpty && payload['timestamp'] is num) {
        final rows = admittedAgentTrajectoryRows([
          for (final entry in raw.whereType<Map>())
            {
              'timestamp': payload['timestamp'],
              'entry': entry,
              for (final key in [
                'serverSeq',
                'launchId',
                'clientSeq',
                'probeId',
              ])
                if (payload[key] != null) key: payload[key],
            },
        ]);
        if (!_disposed && _openingScope == _scope) {
          _entries = mergeAgentTrajectoryLog(_entries, rows);
          _snapshot.entries = _entries;
          notifyListeners();
        }
      } else {
        _scheduleReload();
      }
    });
  }

  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_disposed && _openingScope == _scope) unawaited(reload());
    });
  }

  void _scopeChanged() {
    if (_openingScope == _scope) return;
    _openingScope = _scope;
    _revision++;
    _reloadTimer?.cancel();
    _snapshot = _openSnapshot();
    _entries = _snapshot.entries;
    notifyListeners();
    unawaited(reload());
  }

  /// Web `loadTrajectoryLog`: a refresh replaces nothing already shown; a
  /// failed read keeps what is there.
  Future<void> reload() async {
    if (_disposed) return;
    if (!_active) {
      _reloadWhenActive = true;
      return;
    }
    final captured = _scope, owner = controller, revision = ++_revision;
    try {
      final result = await owner.query(
        '/agents/$agentId/activity-log',
        query: {'limit': '50'},
      );
      if (_disposed ||
          revision != _revision ||
          captured != _scope ||
          !identical(owner, controller)) {
        return;
      }
      _entries = mergeAgentTrajectoryLog(
        _entries,
        admittedAgentTrajectoryRows(result),
      );
      _snapshot
        ..entries = _entries
        ..loaded = true;
      notifyListeners();
    } catch (_) {
      // The log has no error state of its own: before the first read and after
      // a failed one it is the same empty state.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    controller.removeListener(_scopeChanged);
    _reloadTimer?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }
}

/// AgentDetailPanel activity tab: `/agents/:id/activity-log` rendered as
/// AgentActivityLog rows. The pane owns the source for the whole Activity tab;
/// this wrapper opens one for a host that mounts the raw log on its own.
class AgentActivityTab extends StatefulWidget {
  const AgentActivityTab({
    super.key,
    required this.controller,
    required this.agentId,
    this.initialEntries = const [],
  });
  final WorkspaceController controller;
  final String agentId;
  final List<Map<String, dynamic>> initialEntries;
  @override
  State<AgentActivityTab> createState() => _AgentActivityTabState();
}

class _AgentActivityTabState extends State<AgentActivityTab> {
  late AgentActivityLogSource source = _open();

  AgentActivityLogSource _open() => AgentActivityLogSource(
    controller: widget.controller,
    agentId: widget.agentId,
    initialEntries: widget.initialEntries,
  )..reload();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    source.setActive(TickerMode.valuesOf(context).enabled);
  }

  @override
  void didUpdateWidget(AgentActivityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.agentId != widget.agentId) {
      source.dispose();
      source = _open();
      source.setActive(TickerMode.valuesOf(context).enabled);
    }
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AgentRawLog(source: source, onOpenSubagent: null);
}

/// Web `TrajectoryItem`: one row per entry kind, from the entry as the log
/// holds it. [source] resolves a row's subagent (its badge opens it) and is
/// null in a subagent's own view, whose rows carry no lineage.
class AgentLogRowMapper {
  const AgentLogRowMapper({
    required this.controller,
    this.source,
    this.onOpenSubagent,
    this.onOpenTask,
    this.keyByCall = const {},
  });
  final WorkspaceController controller;
  final AgentActivityLogSource? source;
  final ValueChanged<String>? onOpenSubagent;
  final ActivityOpenTask? onOpenTask;

  /// The call that started a subagent, to that subagent's group key.
  final Map<String, String> keyByCall;

  /// An entry of an unknown kind renders nothing (the Web `switch` has no
  /// default).
  RaftActivityLogEntry? entry(
    BuildContext context,
    RaftTokens t,
    SourceTimeFormatter f,
    Map<String, dynamic> item,
  ) {
    final w = controller;
    final entry = item['entry'] is Map
        ? Map<String, dynamic>.from(item['entry'] as Map)
        : <String, dynamic>{};
    final id = trajectoryEntryKey(item);
    final time = f.clock(item['timestamp'], seconds: true).toUpperCase();
    final kind = entry['kind'];
    final text = '${entry['text'] ?? ''}';
    List<InlineSpan> linkify(BuildContext c, String s, TextStyle style) =>
        linkifyActivityRefs(c, w, s, style, onOpenTask: onOpenTask);
    // `SubagentBadge`: lineage-bearing status, tool and system rows only.
    final lineage = subagentLineageOf(item);
    final type = lineage?['subagentType'];
    final badge = lineage == null
        ? null
        : type is String && type.isNotEmpty
        ? raftFormat(context, 'Subagent: {type}', {'type': type})
        : raftText(context, 'Subagent');
    final openKey = lineage == null || onOpenSubagent == null
        ? null
        : source?.subagentKeyOfRow(lineage);
    final onBadgeTap = openKey == null ? null : () => onOpenSubagent!(openKey);
    return switch (kind) {
      'status' => () {
        final activity = '${entry['activityKind'] ?? entry['activity']}';
        final status = agentTrajectoryStatusDisplay(
          activity,
          '${entry['detail'] ?? ''}',
          entry['detailKind'] as String?,
        );
        return RaftActivityLogEntry(
          id: id,
          time: time,
          dot: raftActivityDotColor(t, activity),
          title: raftText(context, status.primary),
          badge: badge,
          onBadgeTap: onBadgeTap,
          inlineDetail: status.secondary,
          linkify: linkify,
          compact: true,
        );
      }(),
      'tool_start' => () {
        final callId = entry['callId'];
        final startsKey = callId is String ? keyByCall[callId] : null;
        return RaftActivityLogEntry(
          id: id,
          time: time,
          dot: t.product.statusBusy,
          title: toolLogLabel('${entry['toolName']}'),
          badge: badge,
          onBadgeTap: onBadgeTap,
          inlineDetail: '${entry['toolInput'] ?? ''}',
          inlineMono: true,
          // The call that started a subagent links to it.
          actionLabel: startsKey == null || onOpenSubagent == null
              ? null
              : raftText(context, 'Open subagent'),
          onAction: startsKey == null || onOpenSubagent == null
              ? null
              : () => onOpenSubagent!(startsKey),
        );
      }(),
      'compaction_started' || 'compaction_finished' => RaftActivityLogEntry(
        id: id,
        time: time,
        dot: kind == 'compaction_started'
            ? t.product.brutalOrange
            : t.product.brutalLime,
        title: raftText(
          context,
          kind == 'compaction_started'
              ? 'Context Compaction Started'
              : 'Context Compaction Finished',
        ),
      ),
      'thinking' || 'text' || 'slock_action' || 'system' => () {
        // A hold is the normal "read the new messages first" step: say how many
        // and where.
        final hold = kind == 'slock_action'
            ? freshnessHoldLabel('${entry['title'] ?? ''}')
            : null;
        final holdDetail = hold == null ? null : parseFreshnessHoldText(text);
        final body = holdDetail == null
            ? text
            : icuText(
                context,
                '{count, plural, one {# new message} other {# new messages}} in {target}',
                {'count': holdDetail.count, 'target': holdDetail.target},
              );
        return RaftActivityLogEntry(
          id: id,
          time: time,
          dot: switch (kind) {
            'thinking' => t.product.statusBusy,
            'text' => t.product.brutalCyan,
            'slock_action' => raftBlue300,
            // A system row that is a subagent's lifecycle reads as that
            // subagent's state, not as an error.
            _ => switch (subagentRowPresence(lineage)) {
              SubagentPresence.busy => raftActivityDotColor(t, 'working'),
              SubagentPresence.online => raftActivityDotColor(t, 'online'),
              SubagentPresence.error || null => t.product.brutalOrange,
            },
          },
          title: switch (kind) {
            'thinking' => raftText(context, 'Thinking'),
            'text' => raftText(context, 'Output'),
            _ =>
              hold != null
                  ? raftText(context, hold)
                  : '${entry['title'] ?? ''}',
          },
          // Web: a `system` row carries the subagent badge too.
          badge: kind == 'system' ? badge : null,
          onBadgeTap: kind == 'system' ? onBadgeTap : null,
          detail: body,
          expandable: body.length > 200,
          // Reference pills only in the structured-metadata kinds; Output and
          // Thinking are free-form agent text.
          linkify: kind == 'slock_action' || kind == 'system' ? linkify : null,
          detailExtra: kind == 'slock_action' || kind == 'system'
              ? activityRefLineExtra(w, body, canOpenTask: onOpenTask != null)
              : 0,
        );
      }(),
      _ => null,
    };
  }
}

/// The Raw log: the visible rows of [source], following the newest. With
/// [onOpenSubagent], a row's Subagent badge (and the spawn row's "Open
/// subagent" link) opens that subagent (Web `SubagentLinkContext`).
class AgentRawLog extends StatelessWidget {
  const AgentRawLog({
    super.key,
    required this.source,
    required this.onOpenSubagent,
    this.onOpenTask,
  });
  final AgentActivityLogSource source;
  final ValueChanged<String>? onOpenSubagent;
  final ActivityOpenTask? onOpenTask;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: source,
    builder: (context, _) {
      final t = RaftTokens.of(context);
      final f = agentTimeFormatter(context, source.controller);
      // The row that started a subagent opens it (the first listed, when one
      // call started several).
      final keyByCall = {
        for (final group in source.subagents.reversed)
          if (group.parentToolUseId != null) group.parentToolUseId!: group.key,
      };
      final mapper = AgentLogRowMapper(
        controller: source.controller,
        source: source,
        onOpenSubagent: onOpenSubagent,
        onOpenTask: onOpenTask,
        keyByCall: keyByCall,
      );
      final visible = source.visibleEntries;
      // Web `visibleLog` + an empty EmptyState: the log has no loading or error
      // state of its own; before the first read and after a failed one it is
      // the same "No activity yet" empty state.
      return RaftActivityLogView(
        semanticLabel: raftText(context, 'Activity'),
        newStepsLabel: (count) => icuText(
          context,
          '{count, plural, one {# new step} other {# new steps}}',
          {'count': count},
        ),
        entries: [for (final e in visible) ?mapper.entry(context, t, f, e)],
        onCopy: () => Clipboard.setData(
          ClipboardData(
            text: [
              for (final e in source.entries) '${e['timestamp']} ${e['entry']}',
            ].join('\n'),
          ),
        ),
      );
    },
  );
}
