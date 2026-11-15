// Web v1.24 AgentActivityLog.tsx `SubagentsList` / `SubagentDetail`: the
// Activity tab's Subagents view, folded from the activity the page already
// holds (subagentGroups.ts). Maps the groups onto raft_ui's presentation.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'agent_activity_refs.dart' show ActivityOpenTask;
import 'agent_activity_summaries.dart' show formatTurnDuration;
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'agent_raw_log.dart';
import 'agent_subagent_groups.dart';
import 'agent_trajectory_log.dart' show isVisibleTrajectoryRow;
import 'icu_message.dart';
import 'tool_display.dart';

/// `SUBAGENT_STATE_CHIP`: the English word of a state.
String subagentStateWord(SubagentState state) => switch (state) {
  SubagentState.running => 'Working',
  SubagentState.done => 'Done',
  SubagentState.failed => 'Failed',
  SubagentState.ceiling => 'Limit reached',
  SubagentState.stopped => 'Stopped',
  SubagentState.ended => 'Ended',
};

/// `SubagentStateChip`.
Widget subagentStateChip(BuildContext context, SubagentState state) =>
    RaftSubagentStateChip(
      key: ValueKey('subagent-state-${state.name}'),
      label: raftText(context, subagentStateWord(state)),
      tone: switch (state) {
        SubagentState.running => RaftSubagentChipTone.busy,
        SubagentState.done => RaftSubagentChipTone.success,
        SubagentState.failed ||
        SubagentState.ceiling => RaftSubagentChipTone.warning,
        SubagentState.stopped ||
        SubagentState.ended => RaftSubagentChipTone.muted,
      },
      light: switch (state) {
        SubagentState.running => RaftSubagentChipLight.busy,
        SubagentState.done => RaftSubagentChipLight.done,
        SubagentState.failed ||
        SubagentState.ceiling => RaftSubagentChipLight.error,
        SubagentState.stopped ||
        SubagentState.ended => RaftSubagentChipLight.offline,
      },
    );

/// `useSubagentText`: the title, duration and step count of a group.
class _SubagentText {
  const _SubagentText(this.context);
  final BuildContext context;

  String title(SubagentGroup group) =>
      group.title ??
      group.subagentType ??
      raftTextZh(context, 'Subagent', '子 Agent');

  String duration(SubagentGroup group) => raftFormat(
    context,
    group.state == SubagentState.running
        ? 'running for {duration}'
        : 'took {duration}',
    {
      'duration': formatTurnDuration(
        context,
        (group.endedAt ?? DateTime.now().millisecondsSinceEpoch) -
            group.startedAt,
      ),
    },
  );

  String steps(SubagentGroup group) => icuText(
    context,
    '{count, plural, one {# step} other {# steps}}',
    {'count': group.steps},
  );
}

/// The Subagents view: the list, or one subagent's detail when [openKey] names
/// a group (a key no group has any more reads as the list, like Web).
class AgentSubagentsView extends StatelessWidget {
  const AgentSubagentsView({
    super.key,
    required this.source,
    required this.openKey,
    required this.onOpen,
    required this.onBack,
    this.onStop,
    this.onOpenTask,
  });
  final AgentActivityLogSource source;
  final String? openKey;
  final ValueChanged<String> onOpen;
  final VoidCallback onBack;

  /// Stop one running subagent by its task id; null when the viewer may not.
  final ValueChanged<String>? onStop;
  final ActivityOpenTask? onOpenTask;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: source,
    builder: (context, _) {
      final groups = source.subagents;
      final open = openKey == null
          ? null
          : groups.where((g) => g.key == openKey).firstOrNull;
      return open == null ? _list(context, groups) : _detail(context, open);
    },
  );

  Widget _list(BuildContext context, List<SubagentGroup> groups) {
    if (groups.isEmpty) {
      return ColoredBox(
        color: RaftTokens.of(context).colors['layer-canvas']!,
        child: RaftProductEmptyState(
          key: const ValueKey('subagents-empty'),
          title: raftText(context, 'No subagents right now'),
          description: raftText(
            context,
            "Lists the subagents in this agent's recent activity.",
          ),
          icon: (context, size, color) =>
              RaftIcon(RaftGlyph.bot, size: size, color: color),
        ),
      );
    }
    final text = _SubagentText(context);
    final f = agentTimeFormatter(context, source.controller);
    RaftSubagentRowData row(SubagentGroup group) {
      final facts = [
        if (group.title != null) group.subagentType,
        text.steps(group),
        if (group.state == SubagentState.running && group.lastToolName != null)
          raftFormat(context, 'now: {tool}', {
            'tool': toolLogLabel(group.lastToolName!),
          })
        else
          text.duration(group),
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
      return RaftSubagentRowData(
        id: group.key,
        title: text.title(group),
        time: f.clock(group.startedAt),
        facts: facts,
        chip: subagentStateChip(context, group.state),
      );
    }

    return ColoredBox(
      color: RaftTokens.of(context).colors['layer-canvas']!,
      child: RaftSubagentsList(
        running: [
          for (final g in groups)
            if (g.state == SubagentState.running) row(g),
        ],
        ended: [
          for (final g in groups)
            if (g.state != SubagentState.running) row(g),
        ],
        runningLabel: raftText(context, 'Running'),
        endedLabel: raftText(context, 'Ended'),
        footer: raftText(
          context,
          "Lists the subagents in this agent's recent activity.",
        ),
        onOpen: onOpen,
      ),
    );
  }

  Widget _detail(BuildContext context, SubagentGroup group) {
    final t = RaftTokens.of(context);
    final text = _SubagentText(context);
    final f = agentTimeFormatter(context, source.controller);
    // Only a running subagent of a runtime that can stop one offers Stop.
    final stopTaskId = onStop != null && group.state == SubagentState.running
        ? group.taskId
        : null;
    final mapper = AgentLogRowMapper(
      controller: source.controller,
      onOpenTask: onOpenTask,
    );
    final rows = [
      for (final item in group.items)
        if (isVisibleTrajectoryRow(item)) item,
    ];
    final entries = [
      for (final item in rows) ?mapper.entry(context, t, f, item),
    ];
    return ColoredBox(
      color: t.colors['layer-canvas']!,
      child: Column(
        key: const ValueKey('subagent-detail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSubagentDetailHead(
            title: text.title(group),
            chip: subagentStateChip(context, group.state),
            backLabel: raftText(context, 'Back to subagents'),
            onBack: onBack,
            stopLabel: stopTaskId == null
                ? null
                : raftText(context, 'Stop subagent'),
            onStop: stopTaskId == null ? null : () => onStop!(stopTaskId),
          ),
          Expanded(
            child: Semantics(
              container: true,
              label: text.title(group),
              child: ListView(
                padding: raftScrollPadding(context, EdgeInsets.zero),
                children: [
                  RaftSubagentFacts(
                    entries: [
                      if (group.subagentType != null)
                        RaftDescriptionEntry(
                          raftText(context, 'Type'),
                          group.subagentType!,
                        ),
                      RaftDescriptionEntry(
                        raftTextZh(context, 'Started', '开始于'),
                        f.clock(group.startedAt, seconds: true).toUpperCase(),
                      ),
                      RaftDescriptionEntry(
                        raftText(context, 'Duration'),
                        [text.duration(group), text.steps(group)].join(' · '),
                      ),
                    ],
                  ),
                  Padding(
                    // ds-allow: Web `px-(--surface-inset) py-3 max-md:px-4`
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          RaftActivityLogRow(
                            entries[i],
                            key: ValueKey(entries[i].id ?? 'row-$i'),
                            first: i == 0,
                            last: i == entries.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
