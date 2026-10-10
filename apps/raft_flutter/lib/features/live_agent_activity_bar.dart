import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/personal_presentation.dart';
import 'chat_agent_presentation.dart';
import 'public_avatar_url.dart';

/// Component layer: source ConnectedLiveAgentActivityBar / actual raft-ui
/// LiveAgentActivityBar recipe. The fixed busy light is index.css status-busy.
class RaftLiveActivityRecipe {
  const RaftLiveActivityRecipe(this.t);
  final RaftTokens t;
  static const inset = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const busy = Color(0xffffd440);
  Color get background => t.panel;
  TextStyle get text =>
      RaftTypography.body(t, size: 12, line: 16, color: t.strong);
}

class NativeLiveAgentActivityBar extends StatelessWidget {
  const NativeLiveAgentActivityBar({
    super.key,
    required this.activities,
    required this.presentation,
    required this.origin,
  });
  final ChatAgentPresentation activities;
  final PersonalPresentationStore presentation;
  final String origin;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([activities, presentation]),
    builder: (context, _) {
      final latest = activities.latest;
      if (!presentation.value.liveActivity || latest == null) {
        return const SizedBox.shrink();
      }
      final agent = activities.agent(latest.agentId);
      if (agent == null) return const SizedBox.shrink();
      final r = RaftLiveActivityRecipe(RaftTokens.of(context));
      return Semantics(
        container: true,
        liveRegion: true,
        label:
            '${agent['displayName'] ?? agent['name'] ?? ''}: ${raftText(context, latest.text)}',
        child: Container(
          key: const Key('live-agent-activity-bar'),
          padding: RaftLiveActivityRecipe.inset,
          decoration: BoxDecoration(
            color: r.background,
            border: Border(top: BorderSide(color: r.t.line)),
          ),
          child: Row(
            children: [
              RaftAvatar(
                name: '${agent['displayName'] ?? agent['name'] ?? ''}',
                kind: RaftAvatarKind.agent,
                size: 20,
                imageUrl: raftPublicAvatarUrl(
                  origin,
                  agent['avatarUrl'] as String?,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: RaftLiveActivityRecipe.busy,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: r.t.brutal ? r.t.strong : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RaftTooltip(
                  message: raftText(context, latest.text),
                  onlyWhenTruncated: true,
                  child: Text(
                    raftText(context, latest.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: r.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
