import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web `AgentModelLimitsWarning`: the agent's Computer reported that the
/// current session registered at least one Raft default limit for its
/// Built-in custom gateway model (`agent.modelLimits.defaultsReported`). Only a
/// warning: no values and no per-field source are shown, and nothing is shown
/// otherwise (no report never reads as "confirmed").
class AgentModelLimitsWarning extends StatelessWidget {
  const AgentModelLimitsWarning({super.key});

  @override
  Widget build(BuildContext context) => RaftBanner(
    key: const ValueKey('agent-model-limits-defaults-warning'),
    status: RaftBannerRecipeStatus.warning,
    size: RaftBannerRecipeSize.sm,
    glyph: RaftGlyph.triangleAlert,
    title: raftText(context, 'This model may be using Raft default limits'),
    description: raftText(
      context,
      "The Computer has reported that at least one limit for this model wasn't available from a matching catalog entry, so Raft filled it in with a default value. Raft can't yet confirm the limits the current session uses. Check your provider's actual limits. This notice doesn't stop the agent from running. To set them yourself, open this agent's settings and fill in Context window and Max output tokens.",
    ),
  );
}
