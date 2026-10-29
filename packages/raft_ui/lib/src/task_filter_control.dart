// Web `TaskFilterSegmentedControl`
// (packages/web/src/components/task/TaskFilterSegmentedControl.tsx): the
// raft-ui SegmentedControl with the All + five status tabs, each carrying a
// `SegmentedControlCount` when the count is above zero. The Web component has
// no mounted caller today; this is the matching Flutter presentation.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption, RaftSegmentedStyle;

import 'package:flutter/material.dart';

import 'localization.dart';
import 'task.dart';

class RaftTaskFilterControl extends StatelessWidget {
  const RaftTaskFilterControl({
    super.key,
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  /// `all` or a task status.
  final String value;

  /// Task count per tab (`all`, `todo`, ...); zero hides the count.
  final Map<String, int> counts;
  final ValueChanged<String>? onChanged;

  static const tabs = [
    'all',
    'todo',
    'in_progress',
    'in_review',
    'done',
    'closed',
  ];

  @override
  Widget build(BuildContext context) => RaftSegmentedControl<String>(
    legacyStyle: RaftSegmentedStyle.recipe,
    label: raftText(context, 'Filter tasks'),
    value: value,
    onChanged: onChanged,
    items: [
      for (final tab in tabs)
        RaftSegmentedOption(
          value: tab,
          label: tab == 'all' ? 'All' : raftTaskStatusLabel(tab),
          count: (counts[tab] ?? 0) > 0 ? '${counts[tab]}' : null,
        ),
    ],
  );
}
