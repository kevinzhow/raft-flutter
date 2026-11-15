// Web components/agent/ActivityOperatorEvents.tsx + operatorEventsTimeline.ts
// (#proj-runtime:#51): what people did to an agent (start, stop, restart,
// reset, Stop Current Turn, migration, model change) and Raft's own restarts,
// as thin system lines between the Activity overview's turns. Three or more in
// a row fold into one line; Raft's own restarts are fainter and name no one.
// `GET /agents/:id/operator-events` is manager-only: a 403 (or an older server
// without the route) leaves the overview with the turns alone.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;

/// `OPERATOR_EVENTS_FOLD_AT`: runs of this many lines or more fold.
const operatorEventsFoldAt = 3;

/// The kinds the overview words (`AgentOperatorEventKind`).
const _kinds = {
  'start',
  'stop',
  'restart',
  'reset_session',
  'reset_full',
  'turn_stopped',
  'migration_started',
  'migration_cancelled',
  'config_changed',
  'system_restart',
};

/// One `AgentOperatorEventView`.
class AgentOperatorEvent {
  const AgentOperatorEvent({
    required this.id,
    required this.at,
    required this.kind,
    required this.system,
    this.actorName,
    this.details = const {},
  });

  /// Epoch ms.
  final num at;
  final String id, kind;

  /// `actor.kind == system`: Raft's own restart, named to no one.
  final bool system;

  /// A user actor's name; null is a person the server no longer names.
  final String? actorName;
  final Map<String, String> details;

  static AgentOperatorEvent? tryParse(Object? json) {
    if (json is! Map ||
        json['id'] is! String ||
        json['at'] is! num ||
        !_kinds.contains(json['kind'])) {
      return null;
    }
    final actor = json['actor'];
    final details = json['details'];
    return AgentOperatorEvent(
      id: json['id'] as String,
      at: json['at'] as num,
      kind: json['kind'] as String,
      system: actor is Map && actor['kind'] == 'system',
      actorName: actor is Map && actor['name'] is String
          ? actor['name'] as String
          : null,
      details: {
        if (details is Map)
          for (final e in details.entries)
            if (e.value is String) '${e.key}': e.value as String,
      },
    );
  }

  /// `data.events` of a page, any order; absent or malformed is none.
  static List<AgentOperatorEvent> parsePage(Object? result) => [
    if (result is Map)
      for (final e in result['events'] as List? ?? const [])
        ?AgentOperatorEvent.tryParse(e),
  ];
}

/// Web `operatorEventText`.
String operatorEventText(BuildContext context, AgentOperatorEvent event) {
  final actor = event.system
      ? ''
      : event.actorName ?? raftText(context, 'Someone');
  String f(String source, [Map<String, Object?> extra = const {}]) =>
      raftFormat(context, source, {'actor': actor, ...extra});
  final d = event.details;
  return switch (event.kind) {
    'start' => f('{actor} started the agent'),
    'stop' => f('{actor} stopped the agent'),
    'restart' => f('{actor} restarted the agent'),
    'reset_session' => f('{actor} reset the session and restarted'),
    'reset_full' => f('{actor} reset the agent, workspace included'),
    'turn_stopped' => f('{actor} stopped the current turn'),
    'migration_started' =>
      d['fromComputer'] != null && d['toComputer'] != null
          ? f('{actor} started moving the agent from {from} to {to}', {
              'from': d['fromComputer'],
              'to': d['toComputer'],
            })
          : f('{actor} started moving the agent to another computer'),
    'migration_cancelled' => f('{actor} cancelled the move'),
    'config_changed' =>
      d['afterModel'] != null && d['beforeModel'] != null
          ? f('{actor} changed the model: {before} → {after}', {
              'before': d['beforeModel'],
              'after': d['afterModel'],
            })
          : d['afterRuntime'] != null && d['beforeRuntime'] != null
          ? f('{actor} changed the runtime: {before} → {after}', {
              'before': d['beforeRuntime'],
              'after': d['afterRuntime'],
            })
          : f("{actor} changed the agent's settings"),
    _ => raftText(context, 'Raft restarted the agent after failed starts'),
  };
}

/// One segment of the overview in time order: a run of turns or a run of events.
sealed class OverviewSegment<T> {
  const OverviewSegment();
}

class TurnsSegment<T> extends OverviewSegment<T> {
  const TurnsSegment(this.turns);
  final List<T> turns;
}

class EventsSegment<T> extends OverviewSegment<T> {
  const EventsSegment(this.events);
  final List<AgentOperatorEvent> events;
}

/// Web `interleaveOperatorEvents`: [turns] (oldest first) and [events] (any
/// order) as segments in time order: each run of events sits before the first
/// turn that started after it. Events after the last turn come back in
/// `after`, for the caller to place before or after the running turn.
({List<OverviewSegment<T>> segments, List<AgentOperatorEvent> after})
interleaveOperatorEvents<T>(
  List<T> turns,
  List<AgentOperatorEvent> events,
  num Function(T turn) startedAt,
) {
  final pending = [...events]..sort((a, b) => a.at.compareTo(b.at));
  final segments = <OverviewSegment<T>>[];
  var index = 0;
  for (final turn in turns) {
    final before = <AgentOperatorEvent>[];
    while (index < pending.length && pending[index].at < startedAt(turn)) {
      before.add(pending[index++]);
    }
    if (before.isNotEmpty) segments.add(EventsSegment<T>(before));
    final last = segments.lastOrNull;
    if (last is TurnsSegment<T>) {
      last.turns.add(turn);
    } else {
      segments.add(TurnsSegment<T>([turn]));
    }
  }
  return (segments: segments, after: pending.sublist(index));
}

/// Reads the page the overview asks for: `since` only while earlier turns are
/// still unloaded (the events as far back as the oldest held turn), else all.
/// Null when the server refuses or has no such route (turns alone).
Future<List<AgentOperatorEvent>?> loadOperatorEvents(
  WorkspaceController w,
  String agentId, {
  num? since,
}) async {
  try {
    final result = await w.query(
      '/agents/$agentId/operator-events',
      query: since == null ? null : {'since': '${since.toInt()}'},
    );
    return AgentOperatorEvent.parsePage(result);
  } catch (_) {
    return null;
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.controller, required this.event});
  final WorkspaceController controller;
  final AgentOperatorEvent event;

  @override
  Widget build(BuildContext context) {
    final line = RaftSystemMessage(
      key: ValueKey('activity-overview-operator-event-${event.id}'),
      timestamp: agentTimeFormatter(context, controller).clock(event.at),
      content: operatorEventText(context, event),
    );
    // Raft's own restarts are fainter than a person's action.
    return event.system ? Opacity(opacity: .6, child: line) : line;
  }
}

/// One run of consecutive events, oldest first.
class OperatorEventLines extends StatefulWidget {
  const OperatorEventLines({
    super.key,
    required this.controller,
    required this.events,
  });
  final WorkspaceController controller;
  final List<AgentOperatorEvent> events;

  @override
  State<OperatorEventLines> createState() => _OperatorEventLinesState();
}

class _OperatorEventLinesState extends State<OperatorEventLines> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    if (events.isEmpty) return const SizedBox.shrink();
    final lines = [
      for (final e in events)
        _EventLine(controller: widget.controller, event: e),
    ];
    if (events.length < operatorEventsFoldAt) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: lines,
      );
    }
    return RaftSystemMessageGroup(
      key: const ValueKey('activity-overview-operator-events-folded'),
      toggleKey: const ValueKey('activity-overview-operator-events-toggle'),
      summary: raftFormat(context, '{count} actions · latest: {latest}', {
        'count': events.length,
        'latest': operatorEventText(context, events.last),
      }),
      expanded: expanded,
      onToggle: () => setState(() => expanded = !expanded),
      children: lines,
    );
  }
}
