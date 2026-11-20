import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

class MessageLinkUnavailable extends StatelessWidget {
  const MessageLinkUnavailable({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RaftTokens.of(context).ui.layerCanvas,
    child: RaftProductEmptyState(
      titleHeading: true,
      title: raftText(context, 'Message not found'),
      description: raftText(
        context,
        "The link may be wrong, or you don't have access to it.",
      ),
      icon: (_, size, color) =>
          RaftIcon(RaftGlyph.searchX, size: size, color: color),
      action: RaftButton(
        key: const ValueKey('message-link-unavailable-back'),
        label: raftText(context, 'Back'),
        uiVariant: RaftButtonVariant.standard,
        onPressed: onBack,
      ),
    ),
  );
}
