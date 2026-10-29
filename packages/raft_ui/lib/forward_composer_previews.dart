import 'package:flutter/material.dart';

import 'raft_ui.dart';

/// API-free preview of the shared target picker, including a large lazy list.
Widget incomingShareTargetsPreview() => const _Targets();

class _Targets extends StatefulWidget {
  const _Targets();
  @override
  State<_Targets> createState() => _TargetsState();
}

class _TargetsState extends State<_Targets> {
  final search = TextEditingController(), focus = FocusNode();
  int? selected;
  @override
  void dispose() {
    search.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftForwardPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftForwardPageHeader(
          leading: RaftForwardIconAction(
            glyph: RaftGlyph.arrowLeft,
            tooltip: 'Back',
            onPressed: () {},
          ),
          title: 'Select destinations',
          subtitle: selected == null
              ? 'Sharing 3 files'
              : 'Add to #channel-$selected',
        ),
        Expanded(
          child: RaftForwardTargetsBody(
            leading: [
              RaftForwardServerChips(
                semanticLabel: 'Server',
                names: const {'a': 'Myoland', 'b': 'Raft Community'},
                selected: 'a',
                onSelected: (_) {},
              ),
            ],
            search: RaftForwardSearchInput(
              controller: search,
              focusNode: focus,
              placeholder: 'Search targets',
              onChanged: (_) => setState(() {}),
            ),
            label: 'Recent',
            itemCount: search.text.isEmpty ? 10000 : 5,
            itemBuilder: (_, index) => RaftForwardTargetRow(
              icon: raftForwardTargetIcon(
                name: 'channel-$index',
                type: 'channel',
              ),
              label: 'channel-$index',
              selected: selected == index,
              checkbox: false,
              onTap: () => setState(() => selected = index),
            ),
          ),
        ),
      ],
    ),
  );
}
