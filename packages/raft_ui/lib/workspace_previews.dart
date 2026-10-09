import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Workspace mode', size: Size(390, 160))
Widget workspaceModePreview() => const _Mode();

class _Mode extends StatefulWidget {
  const _Mode();
  @override
  State<_Mode> createState() => _ModeState();
}

class _ModeState extends State<_Mode> {
  bool enabled = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: RaftWorkspaceModeCard(
      enabled: enabled,
      onChanged: (v) => setState(() => enabled = v),
    ),
  );
}

@RaftPreviews('Workspace editor groups', size: Size(1080, 680))
Widget workspaceEditorGroupsPreview() => const _Editors();

class _Editors extends StatefulWidget {
  const _Editors();
  @override
  State<_Editors> createState() => _EditorsState();
}

class _EditorsState extends State<_Editors> {
  String selected = 'general';
  bool split = false;
  List<double> weights = [1, 1];
  @override
  Widget build(BuildContext context) {
    final tabs = [
      for (final id in ['general', 'design'])
        RaftEditorTab(
          id: id,
          label: '#$id',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: ValueKey(id),
              decoration: InputDecoration(hintText: 'Draft for $id'),
            ),
          ),
        ),
    ];
    return RaftEditorGroups(
      groups: split
          ? [
              RaftEditorGroup(id: 'one', tabs: [tabs[0]], selected: 'general'),
              RaftEditorGroup(id: 'two', tabs: [tabs[1]], selected: 'design'),
            ]
          : [RaftEditorGroup(id: 'one', tabs: tabs, selected: selected)],
      onSelect: (_, id) => setState(() => selected = id),
      onClose: (_) => setState(() => split = false),
      onMove: (_, __) => setState(() => split = false),
      onSplit: (_) => setState(() => split = true),
      weights: split ? weights : [1],
      onWeightsChanged: (v) => setState(() => weights = v),
    );
  }
}
