import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Bottom-edge status menu', size: Size(320, 400))
Widget popupCollisionPreview() => const _PopupCollisionPreview();

class _PopupCollisionPreview extends StatefulWidget {
  const _PopupCollisionPreview();
  @override
  State<_PopupCollisionPreview> createState() => _PopupCollisionPreviewState();
}

class _PopupCollisionPreviewState extends State<_PopupCollisionPreview> {
  String selected = 'To do';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('Selected: $selected'),
      const Spacer(),
      Align(
        alignment: Alignment.bottomRight,
        child: RaftInlineBadgeEditor(
          label: selected,
          selectedId: selected,
          background: RaftTokens.of(context).colors['primary-soft']!,
          foreground: RaftTokens.of(context).strong,
          options: const [
            RaftInlineBadgeOption(id: 'To do', label: 'To do'),
            RaftInlineBadgeOption(id: 'In Review', label: 'In Review'),
            RaftInlineBadgeOption(id: 'Done', label: 'Done'),
          ],
          onSelect: (value) => setState(() => selected = value),
        ),
      ),
    ],
  );
}
