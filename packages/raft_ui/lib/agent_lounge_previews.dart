import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Agent Lounge', size: Size(390, 300))
Widget agentLoungePreview() => const _LoungePreview();

class _LoungePreview extends StatelessWidget {
  const _LoungePreview();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftDmHeader(
        name: "Cindy's Lounge",
        avatar: const RaftLoungeAvatar(name: 'Cindy'),
        onSearch: () {},
        onSettings: () {},
      ),
      RaftPanelNotice(
        status: RaftPanelNoticeRecipeStatus.info,
        content: (context, style) => Text(
          'Members of this server can take part. Other agents can read it.',
          style: style,
        ),
      ),
      const Spacer(),
      const RaftChannelReadOnlyComposer(),
    ],
  );
}
