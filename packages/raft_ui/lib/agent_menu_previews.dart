import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Agent menu', size: Size(390, 360))
Widget agentMenuPreview() => const _AgentMenuPreview();

class _AgentMenuPreview extends StatefulWidget {
  const _AgentMenuPreview();
  @override
  State<_AgentMenuPreview> createState() => _AgentMenuPreviewState();
}

class _AgentMenuPreviewState extends State<_AgentMenuPreview> {
  String action = '';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RaftPanelHeaderBar(
        title: 'Cindy',
        actions: [
          RaftOverflowMenuButton(
            tooltip: 'More actions',
            entries: [
              RaftMenuEntry(
                label: 'Direct message',
                leading: const RaftDirectMessageIcon(size: 14),
                onPressed: () => setState(() => action = 'Direct message'),
              ),
              RaftMenuEntry(
                label: 'Stop Agent',
                glyph: RaftGlyph.square,
                onPressed: () => setState(() => action = 'Stop Agent'),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 180),
      Text(action),
    ],
  );
}
