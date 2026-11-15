import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

// Web AgentActivityLog (v1.24.0): the Activity tab's Subagents view, its list
// of running and ended subagents and one subagent's detail head.

Widget _chip(
  String label,
  RaftSubagentChipTone tone,
  RaftSubagentChipLight light,
) => RaftSubagentStateChip(label: label, tone: tone, light: light);

@RaftPreviews('Subagents list', size: Size(420, 520))
Widget subagentsListPreview() => RaftSubagentsList(
  running: [
    RaftSubagentRowData(
      id: 'run',
      title: 'Write the tests',
      time: '9:42 AM',
      facts: 'worker · 3 steps · now: Running command',
      chip: _chip(
        'Working',
        RaftSubagentChipTone.busy,
        RaftSubagentChipLight.busy,
      ),
    ),
  ],
  ended: [
    RaftSubagentRowData(
      id: 'done',
      title: 'Audit the parser',
      time: '9:12 AM',
      facts: 'explorer · 1 step · took 41s',
      chip: _chip(
        'Done',
        RaftSubagentChipTone.success,
        RaftSubagentChipLight.done,
      ),
    ),
    RaftSubagentRowData(
      id: 'limit',
      title: 'Refactor the importer and keep every call site compiling',
      time: '9:02 AM',
      facts: '12 steps · took 6m 3s',
      chip: _chip(
        'Limit reached',
        RaftSubagentChipTone.warning,
        RaftSubagentChipLight.error,
      ),
    ),
    RaftSubagentRowData(
      id: 'stopped',
      title: 'Subagent',
      time: '8:50 AM',
      facts: '2 steps · took 8s',
      chip: _chip(
        'Stopped',
        RaftSubagentChipTone.muted,
        RaftSubagentChipLight.offline,
      ),
    ),
  ],
  runningLabel: 'Running',
  endedLabel: 'Ended',
  footer: "Lists the subagents in this agent's recent activity.",
  onOpen: (_) {},
);

@RaftPreviews('Subagent detail', size: Size(420, 360))
Widget subagentDetailPreview() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    RaftSubagentDetailHead(
      title: 'Write the tests',
      chip: _chip(
        'Working',
        RaftSubagentChipTone.busy,
        RaftSubagentChipLight.busy,
      ),
      backLabel: 'Back to subagents',
      onBack: () {},
      stopLabel: 'Stop subagent',
      onStop: () {},
    ),
    const RaftSubagentFacts(
      entries: [
        RaftDescriptionEntry('Type', 'worker'),
        RaftDescriptionEntry('Started', '9:42:07 AM'),
        RaftDescriptionEntry('Duration', 'running for 2m 5s · 3 steps'),
      ],
    ),
  ],
);

@RaftPreviews('Follow newest log', size: Size(420, 360))
Widget followNewestLogPreview() => SizedBox(
  height: 320,
  child: RaftFollowNewestList(
    rowKeys: [for (var i = 0; i < 24; i++) 'row-$i'],
    semanticLabel: 'Activity',
    newStepsLabel: (count) => '$count new steps',
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    itemBuilder: (context, i) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text('Step ${i + 1}'),
    ),
  ),
);
