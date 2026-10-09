import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Selection copy toast', size: Size(390, 240))
Widget selectionCopyToastPreview() => const _ToastPreview();

class _ToastPreview extends StatefulWidget {
  const _ToastPreview();
  @override
  State<_ToastPreview> createState() => _ToastPreviewState();
}

class _ToastPreviewState extends State<_ToastPreview> {
  final controller = RaftToastController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftToastPortal(
    controller: controller,
    child: Column(
      children: [
        RaftButton(
          label: 'Copy MD',
          onPressed: () => controller.show('Copied Markdown'),
        ),
        RaftButton(label: 'Clear feedback', onPressed: controller.clear),
        const Text('Hover feedback to pause its five-second timeout.'),
      ],
    ),
  );
}
