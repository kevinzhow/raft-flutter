import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Android text selection', size: Size(390, 520))
Widget textSelectionToolbarPreview() => const _SelectionPreview();

@RaftPreviews('Android text selection · large text', size: Size(320, 520))
Widget largeTextSelectionToolbarPreview() => const _SelectionPreview(scale: 2);

class _SelectionPreview extends StatefulWidget {
  const _SelectionPreview({this.scale = 1});
  final double scale;

  @override
  State<_SelectionPreview> createState() => _SelectionPreviewState();
}

class _SelectionPreviewState extends State<_SelectionPreview> {
  String result = 'Tap a menu action, or long-press the message and editor.';

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.android),
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(widget.scale)),
      child: RaftDensityScope(
        density: RaftDensity.touch,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result),
                  const Spacer(),
                  const RaftSelectionArea(
                    child: Text('Raft message · 可以选择的消息文字'),
                  ),
                  const SizedBox(height: 24),
                  const RaftTextInput(initialValue: 'Edit this draft'),
                ],
              ),
            ),
            RaftTextSelectionToolbar.buttonItems(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(195, 240),
                secondaryAnchor: Offset(195, 280),
              ),
              buttonItems: [
                for (final label in [
                  'Cut',
                  'Copy',
                  'Paste',
                  'Select all',
                  'Share',
                ])
                  ContextMenuButtonItem(
                    label: label,
                    onPressed: () => setState(() => result = label),
                  ),
                const ContextMenuButtonItem(
                  label: 'Unavailable',
                  onPressed: null,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
