import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

const _labels = RaftActivityFilterLabels(
  filter: 'Filter',
  menu: 'Filter inbox',
  clear: 'Clear filter',
  markAllRead: 'Mark all read',
  markAllReadTooltip: 'Mark all read',
  choices: {
    RaftActivityFilterChoice.all: 'All',
    RaftActivityFilterChoice.unread: 'Unread',
    RaftActivityFilterChoice.mentions: 'Mentions',
    RaftActivityFilterChoice.pinned: 'Pinned',
    RaftActivityFilterChoice.saved: 'Saved',
    RaftActivityFilterChoice.artifacts: 'Artifacts',
  },
);

class _Bar extends StatefulWidget {
  const _Bar(this.initial);
  final RaftActivityFilterChoice initial;
  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  late RaftActivityFilterChoice choice = widget.initial;
  @override
  Widget build(BuildContext context) => RaftActivityFilterBar(
    choice: choice,
    onChoice: (c) => setState(() => choice = c),
    labels: _labels,
    showMarkAllRead: true,
    onMarkAllRead: () {},
  );
}

@RaftPreviews('Activity filter bar', size: Size(640, 120))
Widget activityFilterBarPreview() => const _Bar(RaftActivityFilterChoice.all);

@RaftPreviews('Activity filter bar, chip', size: Size(640, 120))
Widget activityFilterBarChipPreview() =>
    const _Bar(RaftActivityFilterChoice.mentions);

@RaftPreviews('Activity filter bar, narrow', size: Size(390, 120))
Widget activityFilterBarNarrowPreview() =>
    const _Bar(RaftActivityFilterChoice.unread);
