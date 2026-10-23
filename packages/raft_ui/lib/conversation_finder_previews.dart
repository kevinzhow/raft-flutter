import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Conversation finder', size: Size(280, 360))
Widget conversationFinderPreview() => const _ConversationFinderPreview();

class _ConversationFinderPreview extends StatefulWidget {
  const _ConversationFinderPreview();
  @override
  State<_ConversationFinderPreview> createState() =>
      _ConversationFinderPreviewState();
}

class _ConversationFinderPreviewState
    extends State<_ConversationFinderPreview> {
  final controller = TextEditingController(text: 'de');
  final focus = FocusNode();
  int active = 0;
  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftConversationFinderField(
            controller: controller,
            focusNode: focus,
            hint: 'Find a conversation…',
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            onTapOutside: () {},
          ),
          Padding(
            padding: RaftConversationFinderMetrics.panelOffset.toPadding(),
            child: RaftConversationFinderPanel(
              children: [
                for (final (i, (label, sub)) in const [
                  ('design', 'Design work'),
                  ('deploy', null),
                  ('Dee', '@dee'),
                ].indexed)
                  RaftConversationFinderRow(
                    leading: const RaftIcon(RaftGlyph.hash, size: 16),
                    label: label,
                    sublabel: sub,
                    active: i == active,
                    onPressed: () {},
                    onHover: () => setState(() => active = i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on Offset {
  EdgeInsets toPadding() => EdgeInsets.fromLTRB(dx, dy, dx, 0);
}
