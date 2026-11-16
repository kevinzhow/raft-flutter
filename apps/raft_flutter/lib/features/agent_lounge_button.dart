// The profile's Lounge entry (Web v1.24 components/agent/AgentProfileOverflowMenu.tsx
// `onOpenLounge`, AgentDetailPanel.tsx:660): an icon button (Users, tooltip
// "Lounge") among the header's inline commands and an item of the overflow
// menu, offered when the server has Lounges on, the viewer is not a Guest and
// the agent offers one (not deleted, not someone's personal assistant).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_lounge.dart';

/// Rebuilds the profile when the server's Lounge flag is first known or turns
/// over, so the entry appears (or goes) without the profile being reopened.
mixin AgentLoungeListener<T extends StatefulWidget> on State<T> {
  WorkspaceController get loungeWorkspace;
  AgentLoungeFlag? _loungeFlag;

  @override
  void initState() {
    super.initState();
    _watchLounge();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _watchLounge();
  }

  void _watchLounge() {
    final flag = AgentLoungeFlag.of(loungeWorkspace);
    if (identical(flag, _loungeFlag)) return;
    _loungeFlag?.removeListener(_loungeChanged);
    _loungeFlag = flag..addListener(_loungeChanged);
  }

  void _loungeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loungeFlag?.removeListener(_loungeChanged);
    super.dispose();
  }
}

/// The overflow menu's Lounge item, or null where the entry is not offered.
RaftMenuEntry? agentLoungeMenuEntry(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> agent,
) => !canOpenAgentLounge(w, agent)
    ? null
    : RaftMenuEntry(
        label: raftText(context, 'Lounge'),
        glyph: RaftGlyph.users,
        onPressed: () => openAgentLounge(context, w, '${agent['id']}'),
      );

/// The header's inline Lounge button, or null where the entry is not offered.
Widget? agentLoungeInlineAction(
  BuildContext context,
  WorkspaceController w,
  Map<String, dynamic> agent,
) => !canOpenAgentLounge(w, agent)
    ? null
    : raftConversationHeaderAction(
        key: const Key('agent-profile-inline-lounge'),
        glyph: RaftGlyph.users,
        tooltip: raftText(context, 'Lounge'),
        onPressed: () => openAgentLounge(context, w, '${agent['id']}'),
      );
