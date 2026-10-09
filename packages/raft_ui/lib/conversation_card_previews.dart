import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Conversation activation')
Widget conversationActivationPreview() => const _ActivationPreview();

class _ActivationPreview extends StatefulWidget {
  const _ActivationPreview();
  @override
  State<_ActivationPreview> createState() => _ActivationPreviewState();
}

class _ActivationPreviewState extends State<_ActivationPreview> {
  String result = 'Activate with mouse, keyboard, or the nested action.';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftConversationCard(
          semanticLabel: 'Example activity row',
          onOpen: () => setState(() => result = 'Opened'),
          onActivate: (detail) => setState(() => result = 'Activation $detail'),
          actions: RaftIconButton(
            glyph: RaftGlyph.check,
            tooltip: 'Done',
            onPressed: () => setState(() => result = 'Nested action'),
          ),
          child: const SizedBox(
            height: 64,
            child: Text('An accepted conversation'),
          ),
        ),
        Text(result),
      ],
    ),
  );
}
