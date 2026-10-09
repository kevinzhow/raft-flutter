import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Source selection toolbar', size: Size(390, 320))
Widget selectionToolbarPreview() => const _SelectionPreview();

class _SelectionPreview extends StatefulWidget {
  const _SelectionPreview();
  @override
  State<_SelectionPreview> createState() => _SelectionPreviewState();
}

class _SelectionPreviewState extends State<_SelectionPreview> {
  int selected = 2;
  String result = 'Ready';
  bool busy = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(result),
      RaftButton(
        label: 'Toggle rendering',
        onPressed: () => setState(() => busy = !busy),
      ),
      const Spacer(),
      RaftSelectionToolbar(
        selected: selected,
        total: 3,
        busy: busy,
        onExit: () => setState(() {
          selected = 0;
          result = 'Cancelled';
        }),
        onSelectAll: () => setState(() => selected = 3),
        onCopyLinks: () => setState(() => result = 'Copied links'),
        onForward: () => setState(() => result = 'Forward'),
        onCopyMarkdown: () => setState(() => result = 'Copied MD'),
        onPreview: () => setState(() => result = 'Generate image'),
      ),
    ],
  );
}
