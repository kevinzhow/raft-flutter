import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

const _rows = [
  RaftTaskChipRow(
    id: 'a',
    number: 25,
    title: 'Write the release notes for the Tasks page and send them round',
    status: 'in_progress',
    assigneeName: 'Bob',
    ref: '#design:#25',
    channelName: 'design',
    replyCount: 3,
    unread: true,
  ),
  RaftTaskChipRow(
    id: 'b',
    number: 26,
    title: 'Park the rest',
    status: 'backlog',
    ref: '#design:#26',
    channelName: 'design',
  ),
  RaftTaskChipRow(
    id: 'c',
    number: 7,
    title: 'Ship it',
    status: 'done',
    assigneeName: 'Alice',
    assigneeIsViewer: true,
    ref: '#ops:#7',
    channelName: 'ops',
  ),
];

class _PageList extends StatefulWidget {
  const _PageList({this.selected = const {}});
  final Set<String> selected;
  @override
  State<_PageList> createState() => _PageListState();
}

class _PageListState extends State<_PageList> {
  late final Set<String> selected = {...widget.selected};
  String? current = 'c';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: RaftTaskPageList(
      tasks: _rows,
      showChannel: true,
      showUnassigned: true,
      unassignedLabel: 'Unassigned',
      currentTaskId: current,
      onOpen: (row) => setState(() => current = row.id),
      selection: RaftTaskRowSelection(
        selecting: selected.isNotEmpty,
        isSelected: selected.contains,
        onSelect: (row, {required range}) => setState(() {
          if (!selected.remove(row.id)) selected.add(row.id);
        }),
      ),
    ),
  );
}

@RaftPreviews('Task page rows, wide', size: Size(720, 300))
Widget taskPageListWidePreview() => const _PageList();

@RaftPreviews('Task page rows, narrow, selecting', size: Size(360, 380))
Widget taskPageListNarrowPreview() => const _PageList(selected: {'a'});

@RaftPreviews('Task card, current and selected', size: Size(360, 420))
Widget taskCardSelectionPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    spacing: 12,
    children: [
      RaftTaskCard(
        title: 'An ordinary card',
        number: '25',
        status: 'todo',
        onTap: () {},
      ),
      RaftTaskCard(
        title: 'Open beside the board',
        number: '26',
        status: 'in_progress',
        current: true,
        onTap: () {},
      ),
      RaftTaskCard(
        title: 'Picked for a bulk action',
        number: '27',
        status: 'done',
        selected: true,
        onTap: () {},
      ),
    ],
  ),
);

List<RaftSelectionBarAction> _actions() => [
  RaftSelectionBarAction(
    id: 'status',
    label: 'Status',
    glyph: RaftGlyph.circleDot,
    menuEntries: [
      RaftMenuEntry(label: 'Todo', onPressed: () {}),
      RaftMenuEntry(label: 'Done', onPressed: () {}),
    ],
    moreEntries: [RaftMenuEntry(label: 'Status', onPressed: () {})],
  ),
  RaftSelectionBarAction(
    id: 'assignee',
    label: 'Assignee',
    glyph: RaftGlyph.user,
    onOpen: (_) {},
    moreEntries: [RaftMenuEntry(label: 'Assignee', onPressed: () {})],
  ),
  RaftSelectionBarAction(
    id: 'follow',
    label: 'Follow',
    glyph: RaftGlyph.followThread,
    secondary: true,
    onPressed: () {},
  ),
  RaftSelectionBarAction(
    id: 'delete',
    label: 'Delete',
    glyph: RaftGlyph.trash2,
    secondary: true,
    onPressed: () {},
  ),
];

Widget _bar(double width) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    height: 120,
    child: Stack(
      children: [
        RaftSelectionBarDock(
          child: RaftSelectionBar(
            count: 3,
            semanticLabel: 'Selected tasks',
            actions: _actions(),
            onClear: () {},
          ),
        ),
      ],
    ),
  ),
);

@RaftPreviews('Selection bar, wide', size: Size(720, 140))
Widget selectionBarWidePreview() => _bar(700);

@RaftPreviews(
  'Selection bar, medium (secondary actions in More)',
  size: Size(520, 140),
)
Widget selectionBarMediumPreview() => _bar(500);

@RaftPreviews('Selection bar, narrow (labels gone)', size: Size(320, 140))
Widget selectionBarNarrowPreview() => _bar(300);
