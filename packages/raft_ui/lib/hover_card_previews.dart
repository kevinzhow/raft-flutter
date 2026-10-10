import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// Opens [card] on its trigger after the first frame (previews have no
/// pointer to hover with).
class _OpenHoverCard extends StatefulWidget {
  const _OpenHoverCard({required this.card, required this.trigger});
  final WidgetBuilder card;
  final Widget trigger;
  @override
  State<_OpenHoverCard> createState() => _OpenHoverCardState();
}

class _OpenHoverCardState extends State<_OpenHoverCard> {
  final controller = RaftHoverCardController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.open(pinned: true);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(-.8, -.9),
    child: RaftHoverCard(
      controller: controller,
      card: widget.card,
      child: widget.trigger,
    ),
  );
}

@RaftPreviews('Hover card: agent profile (avatar / @mention)')
Widget agentProfileHoverCardPreview() => _OpenHoverCard(
  trigger: const RaftAvatarSlot(
    name: 'Cindy',
    slot: RaftAvatarSlotContext.panelHeader,
  ),
  card: (_) => const RaftProfilePreviewCard(
    avatar: RaftAvatarSlot(
      name: 'Cindy',
      slot: RaftAvatarSlotContext.mentionCard,
    ),
    name: 'Cindy',
    subtitle: '@cindy',
    status: RaftProfilePreviewStatus(
      activity: RaftActivityTone.working,
      text: 'Capturing visual testing baselines',
    ),
    facts: [
      RaftProfilePreviewFact('Computer', 'Jiachengs-MacBook-Pro'),
      RaftProfilePreviewFact('Runtime', 'Codex CLI'),
      RaftProfilePreviewFact('Model', 'GPT-5.5'),
      RaftProfilePreviewFact('Reasoning', 'high', capitalize: true),
    ],
    description: 'Keeps the visual testing baselines current.',
    activity: [
      RaftProfilePreviewActivity(
        time: '12:28:01',
        activity: RaftActivityTone.thinking,
        text: 'Planning the capture run',
      ),
      RaftProfilePreviewActivity(
        time: '12:28:09',
        activity: RaftActivityTone.working,
        text: 'Running command',
      ),
    ],
  ),
);

@RaftPreviews('Hover card: member profile and unavailable')
Widget memberProfileHoverCardPreview() => _OpenHoverCard(
  trigger: const RaftAvatarSlot(
    name: 'Artin',
    agent: false,
    slot: RaftAvatarSlotContext.panelHeader,
  ),
  card: (_) => const RaftProfilePreviewCard(
    avatar: RaftAvatarSlot(
      name: 'Artin',
      agent: false,
      slot: RaftAvatarSlotContext.mentionCard,
    ),
    name: 'Artin',
    subtitle: '@artin',
    description: 'Design lead',
  ),
);

@RaftPreviews('Hover popup: reaction reactor names', size: Size(360, 160))
Widget reactionReactorsPreview() => const Center(
  child: RaftReactionReactors(
    emoji: '👍',
    names: ['You', 'Cindy', 'Product UX Designer', 'Artin', 'Mo'],
    hiddenCount: 3,
  ),
);

RaftRuntimeUsageData _usage(String? state) => RaftRuntimeUsageData(
  provider: 'Claude',
  version: '2.1.3',
  state: state,
  updated: '5 minutes ago',
  footer: 'Cached snapshot only',
  accounts: const [
    RaftRuntimeUsageAccount(
      health: 'ok',
      plan: 'Claude Max',
      identity: 'art****@example.com',
      windows: [
        RaftRuntimeUsageWindow(
          label: '5-hour',
          status: 'ok',
          percent: 42,
          reset: 'in 3 hours',
        ),
        RaftRuntimeUsageWindow(
          label: 'Weekly',
          status: 'limit_reached',
          percent: 100,
          reset: 'in 2 days',
        ),
      ],
    ),
  ],
);

@RaftPreviews('Hover card: runtime account usage', size: Size(900, 520))
Widget runtimeUsageCardPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final state in ['fresh', 'stale', 'missing'])
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 280,
            child: RaftRuntimeUsageSurface(
              data: _usage(state),
              onRefresh: () {},
              onClose: () {},
            ),
          ),
        ),
    ],
  ),
);
