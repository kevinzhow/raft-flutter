// The "External setup" block of an external agent's page (Web v1.24
// features/agent/ExternalAgentConnectionCard.tsx, mounted at
// AgentProfileInfo.tsx): one status line in four states, the steps for how it
// connects (open until it has signed in, folded behind "How it connects"
// after), the link that switches the method, and the credentials for whoever
// may make them. The parts are in external_agent_parts.dart; the app owns the
// status read, the poll and every credential request.
import 'package:flutter/material.dart';

import 'card.dart';
import 'external_agent_parts.dart';
import 'list_items.dart' show RaftSectionEyebrow;
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/badge.dart';
import 'raft/button.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'recipes/badge.g.dart'
    show RaftBadgeRecipeAppearance, RaftBadgeRecipeVariant;
import 'icons.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// The eyebrow every external setup block opens with.
class RaftExternalEyebrow extends StatelessWidget {
  const RaftExternalEyebrow({super.key});
  @override
  Widget build(BuildContext context) => RaftCssText(
    raftText(context, 'External setup'),
    style: RaftSectionEyebrow.style(RaftTokens.of(context)),
  );
}

/// The section of a connectable external agent: eyebrow, [status], the
/// method switch ([switchLabel] null while connected) and [steps] (null when
/// folded), then [below] (credentials and their notices).
class RaftExternalConnectionSection extends StatelessWidget {
  const RaftExternalConnectionSection({
    super.key,
    required this.status,
    this.steps,
    this.switchLabel,
    this.onSwitch,
    this.below = const [],
    this.method = RaftExternalMethod.existingAgent,
  });
  final Widget status;
  final Widget? steps;
  final RaftExternalMethod method;

  /// English source of "Build it with the SDK instead" / "Use an existing
  /// agent instead"; null hides the link.
  final String? switchLabel;
  final VoidCallback? onSwitch;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('external-agent-connection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const RaftExternalEyebrow(),
            status,
            if (steps != null)
              Column(
                key: ValueKey('external-agent-method-${method.name}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (switchLabel != null)
                    RaftExternalSwitchLink(
                      key: const ValueKey('external-agent-switch'),
                      label: switchLabel!,
                      onPressed: onSwitch,
                    ),
                  steps!,
                ],
              ),
          ],
        ),
        ...below,
      ],
    );
  }
}

/// The credential block of the steps (Web `credentialStep`): the secret just
/// made, shown once; else the Create credential button; or who to ask.
class RaftExternalCredentialStep extends StatelessWidget {
  const RaftExternalCredentialStep({
    super.key,
    required this.name,
    this.secret,
    this.secretKey,
    this.sdk = false,
    this.createLabel = 'Create credential',
    this.showShownBefore = false,
    this.busy = false,
    this.loading = false,
    this.createError = false,
    this.showHint = true,
    this.onCreate,
  });

  /// The line under the secret (where the program reads it, or never to put
  /// it in a command); the connected page shows the secret without it.
  final bool showHint;

  /// The agent's name (not a catalog source).
  final String name;

  /// The secret of a credential made a moment ago; held in state only.
  final String? secret;
  final Key? secretKey;

  /// The SDK reads the credential from an environment variable; an existing
  /// agent is asked for it.
  final bool sdk;

  /// English source of the button ("Create credential" / "Create new
  /// credential").
  final String createLabel;
  final bool showShownBefore, busy, loading, createError;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final warning = t.scale(
      RaftTypeScale.footnote,
      weight: FontWeight.w600,
      color: t.colors['warning-strong'],
    );
    return Column(
      key: const ValueKey('external-agent-credential-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (secret != null) ...[
          RaftExternalNote(
            raftFormat(
              context,
              "Shown once. Anyone with it can act as {name}; revoke it on {name}'s page.",
              {'name': name},
            ),
          ),
          RaftExternalCopyField(
            key: secretKey ?? const ValueKey('external-agent-new-credential'),
            text: secret!,
            copyKey: const ValueKey('external-agent-new-credential-copy'),
          ),
          if (showHint)
            RaftExternalNote(
              raftText(
                context,
                sdk
                    ? 'Your program reads it from RAFT_AGENT_CREDENTIAL.'
                    : 'Never put it in a command or a file.',
              ),
              small: true,
            ),
        ] else ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RaftButton(
              key: const ValueKey('external-agent-create-credential'),
              label: raftText(context, createLabel),
              glyph: RaftGlyph.plus,
              uiVariant: RaftButtonVariant.outline,
              uiSize: RaftButtonSize.md,
              busy: busy,
              onPressed: loading || busy ? null : onCreate,
            ),
          ),
          if (showShownBefore)
            RaftExternalNote(
              raftFormat(
                context,
                "The one shown when {name} was created can't be shown again.",
                {'name': name},
              ),
              small: true,
            ),
        ],
        if (createError)
          Semantics(
            liveRegion: true,
            child: RaftCssText(
              raftText(
                context,
                "Raft couldn't create a credential. Try again.",
              ),
              key: const ValueKey('external-agent-create-error'),
              style: warning,
            ),
          ),
      ],
    );
  }
}

/// The section of a cloud-hosted external agent (Web: the Card with the
/// connected / waiting badge and the hosted runtime's status in it).
class RaftExternalHostedSection extends StatelessWidget {
  const RaftExternalHostedSection({
    super.key,
    required this.connected,
    required this.child,
  });
  final bool connected;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('external-setup'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      const RaftExternalEyebrow(),
      RaftCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: RaftBadge(
                key: const ValueKey('external-setup-state'),
                label: raftText(
                  context,
                  connected ? 'Connected' : 'Waiting for sign-in',
                ),
                appearance: RaftBadgeRecipeAppearance.soft,
                variant: connected
                    ? RaftBadgeRecipeVariant.success
                    : RaftBadgeRecipeVariant.muted,
                leading: RaftStatusDot(
                  activity: connected
                      ? RaftActivityTone.online
                      : RaftActivityTone.offline,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ],
  );
}
