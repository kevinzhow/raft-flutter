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

RaftRuntimeUsageData _usage(
  String? state, {
  RaftRuntimeAuthData? auth,
  RaftRuntimeLimitReset? limitReset,
  String? statusText,
  String? resets,
  bool usedUp = true,
}) => RaftRuntimeUsageData(
  provider: 'Claude',
  runtimeName: 'Claude Code',
  runtimeId: 'claude',
  version: '2.1.3',
  state: state,
  updated: '5 minutes ago',
  statusText: statusText,
  auth: auth,
  limitReset: limitReset,
  accounts: [
    RaftRuntimeUsageAccount(
      health: usedUp ? 'rate_limited' : 'ok',
      plan: 'Claude Max',
      identity: 'art****@example.com',
      resetsText: resets,
      windows: [
        const RaftRuntimeUsageWindow(
          label: '5-hour',
          status: 'ok',
          percent: 42,
          reset: 'in 3 hours',
        ),
        RaftRuntimeUsageWindow(
          label: 'Weekly',
          status: usedUp ? 'limit_reached' : 'ok',
          percent: usedUp ? 100 : 20,
          reset: 'in 2 days',
          usedUp: usedUp,
        ),
      ],
    ),
  ],
);

RaftRuntimeAuthData _auth(
  String runtime,
  String? status, {
  RaftRuntimeAuthActionKind action = RaftRuntimeAuthActionKind.none,
  String? account,
  bool perProvider = false,
  bool providerKey = false,
  List<RaftRuntimeAuthProvider> providers = const [],
  bool outline = false,
  String? hint,
  String? unavailableText,
  String? install,
}) => RaftRuntimeAuthData(
  runtime: runtime,
  status: status,
  accountText: account,
  action: action,
  perProvider: perProvider,
  providerKey: providerKey,
  providers: providers,
  outlineAction: outline,
  hint: hint,
  unavailableText: unavailableText,
  installCommand: install,
  onSignIn: () {},
  onSignOut: () {},
  onConnectProvider: () {},
);

Widget _card(RaftRuntimeUsageData data) => SizedBox(
  width: 320,
  child: RaftRuntimeUsageSurface(data: data, onRefresh: () {}, onClose: () {}),
);

@RaftPreviews('Hover card: runtime account usage', size: Size(900, 520))
Widget runtimeUsageCardPreview() => SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final state in ['fresh', 'stale', 'missing'])
          SizedBox(
            width: 280,
            child: RaftRuntimeUsageSurface(
              data: _usage(state),
              onRefresh: () {},
              onClose: () {},
            ),
          ),
      ],
    ),
  ),
);

@RaftPreviews('Hover card: runtime sign-in states', size: Size(1000, 760))
Widget runtimeAuthCardPreview() => SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Signed out: no usage, only the way to sign in.
        _card(
          _usage(
            'fresh',
            auth: _auth(
              'claude',
              'logged_out',
              action: RaftRuntimeAuthActionKind.signIn,
            ),
          ),
        ),
        // Signed in: the account line (usage not naming it), Sign out.
        _card(
          RaftRuntimeUsageData(
            provider: 'Kimi',
            runtimeName: 'Kimi Code',
            runtimeId: 'kimi-sdk',
            state: 'missing',
            auth: _auth(
              'kimi',
              'logged_in',
              account: 'Kimi Pro · k****@example.com',
              action: RaftRuntimeAuthActionKind.signOut,
            ),
          ),
        ),
        // Auth-only card (Qoder).
        _card(
          RaftRuntimeUsageData(
            provider: null,
            runtimeName: 'Qoder',
            runtimeId: 'qoder',
            auth: _auth('qoder', 'logged_in'),
          ),
        ),
        // Per-provider rows (Pi).
        _card(
          RaftRuntimeUsageData(
            provider: null,
            runtimeName: 'Pi',
            runtimeId: 'pi',
            auth: _auth(
              'pi',
              'logged_in',
              perProvider: true,
              action: RaftRuntimeAuthActionKind.addProvider,
              outline: true,
              providers: [
                RaftRuntimeAuthProvider(
                  id: 'anthropic',
                  label: 'Anthropic',
                  detail: 'Subscription account',
                  isKey: false,
                  onSignOut: () {},
                ),
                RaftRuntimeAuthProvider(
                  id: 'openai',
                  label: 'OpenAI',
                  detail: 'API key',
                  isKey: true,
                  onSignOut: () {},
                ),
              ],
            ),
          ),
        ),
        // Provider configured / not (Qwen).
        _card(
          RaftRuntimeUsageData(
            provider: null,
            runtimeName: 'Qwen Code',
            runtimeId: 'qwen',
            auth: _auth(
              'qwen',
              'logged_in',
              providerKey: true,
              outline: true,
              action: RaftRuntimeAuthActionKind.connectProvider,
            ),
          ),
        ),
        _card(
          RaftRuntimeUsageData(
            provider: null,
            runtimeName: 'Qwen Code',
            runtimeId: 'qwen',
            auth: _auth(
              'qwen',
              'logged_out',
              providerKey: true,
              action: RaftRuntimeAuthActionKind.connectProvider,
            ),
          ),
        ),
        // CLI unavailable, with its install command.
        _card(
          RaftRuntimeUsageData(
            provider: null,
            runtimeName: 'Codex CLI',
            runtimeId: 'codex',
            auth: _auth(
              'codex',
              'unavailable',
              action: RaftRuntimeAuthActionKind.unavailable,
              unavailableText: "Install this runtime's command-line tool on the Computer, then use Rescan runtimes on the Computer's page.",
              install: 'npm install -g @openai/codex',
            ),
          ),
        ),
        // Limit reset as the primary action while rate-limited.
        _card(
          _usage(
            'fresh',
            resets: '2 resets left',
            statusText: 'Limits reset.',
            auth: _auth(
              'claude',
              'logged_in',
              action: RaftRuntimeAuthActionKind.signOut,
            ),
            limitReset: RaftRuntimeLimitReset(primary: true, onUse: () {}),
          ),
        ),
      ],
    ),
  ),
);
