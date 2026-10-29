// Presentation of the Web external agent setup block on the agent profile
// (packages/web/src/components/agent/AgentDetailPanel.tsx "External setup",
// ExternalAgentToken.tsx, ExternalSetupTabSegmentedControl.tsx): the setup
// state badge, the token manager and the Hermes / Claude Code / Other Agents
// setup steps. The app owns the status read, the credential requests and the
// commands; values and callbacks come in here.
// Tailwind classes written in the JSX are resolved in comments.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption, RaftSegmentedStyle;

import 'package:flutter/material.dart';

import 'agent_profile.dart';
import 'list_items.dart' show RaftSectionEyebrow;
import 'css_pixel_snap.dart';
import 'dialog_card.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/button_variants.g.dart';
import 'recipe_surface.dart' show RaftCssBoxDecoration;
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';

/// `ExternalSetupTab`.
enum RaftExternalSetupTab { hermes, claudeCode, otherAgents }

/// One `externalHermesSetupSteps` / `externalClaudeSetupSteps` entry.
@immutable
class RaftExternalSetupStep {
  const RaftExternalSetupStep({
    required this.title,
    required this.command,
    this.description = '',
  });
  final String title, command, description;
}

/// One row of the token inventory (`Credential`).
@immutable
class RaftExternalCredential {
  const RaftExternalCredential({
    required this.id,
    required this.label,
    required this.masked,
    required this.created,
    required this.revoked,
  });
  final String id;

  /// `credential.name || "Agent token"`.
  final String label;

  /// `maskedToken || id.slice(0, 8)`.
  final String masked;

  /// `Created {date}` already formatted.
  final String created;
  final bool revoked;
}

/// State of the token manager (`ExternalAgentToken`).
@immutable
class RaftExternalTokenState {
  const RaftExternalTokenState({
    this.token = '',
    this.credentials = const [],
    this.loading = true,
    this.listError = false,
    this.confirmId,
    this.revokingId,
    this.revokeError = false,
    this.pending = false,
    this.error = false,
    this.copied = false,
  });

  /// The freshly generated token (the full secret; the field shows it masked).
  final String token;
  final List<RaftExternalCredential> credentials;
  final bool loading, listError, revokeError, pending, error, copied;
  final String? confirmId, revokingId;
}

/// Callbacks of [RaftExternalAgentToken].
class RaftExternalTokenActions {
  const RaftExternalTokenActions({
    required this.onGenerate,
    required this.onCopy,
    required this.onRefresh,
    required this.onRevoke,
    required this.onConfirmRevoke,
    required this.onCancelRevoke,
  });
  final VoidCallback onGenerate, onCopy, onRefresh;
  final ValueChanged<String> onRevoke, onConfirmRevoke;
  final VoidCallback onCancelRevoke;
}

Color _muted(RaftTokens t) => t.colors['foreground-muted']!;

TextStyle _xs(
  RaftTokens t, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  bool mono = false,
}) => TextStyle(
  fontFamily: mono ? t.monoFont : t.headingFont,
  fontFamilyFallback: t.fontFallback,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: weight,
  color: color ?? t.ink,
  leadingDistribution: TextLeadingDistribution.even,
);

RaftRecipeButton _smOutline(
  BuildContext context,
  String label,
  VoidCallback? onPressed, {
  Key? key,
}) => RaftRecipeButton(
  key: key,
  label: raftText(context, label),
  variant: RaftButtonRecipeVariant.outline,
  size: RaftButtonRecipeSize.sm,
  onPressed: onPressed,
  disabled: onPressed == null,
);

/// Web `ExternalAgentToken`: generate / copy a login token and manage the
/// credentials issued for the agent.
class RaftExternalAgentToken extends StatelessWidget {
  const RaftExternalAgentToken({
    super.key,
    required this.state,
    required this.actions,
  });
  final RaftExternalTokenState state;
  final RaftExternalTokenActions actions;

  /// `${token.slice(0, 14)}***${token.slice(-7)}`.
  static String maskToken(String token) =>
      '${token.substring(0, token.length < 14 ? token.length : 14)}***'
      '${token.substring(token.length < 7 ? 0 : token.length - 7)}';

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final muted = _xs(t, color: _muted(t));
    final alert = _xs(t, color: t.product.brutalOrange);
    final busy = state.pending || state.revokingId != null;
    // `space-y-2`
    return Column(
      key: const ValueKey('external-agent-token'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        RaftCssText(
          tr(
            'Generate a token for this agent, then use it with Raft CLI login or pass it as the credential to the Raft SDK.',
          ),
          style: muted,
        ),
        if (state.token.isNotEmpty) ...[
          // `<label className="block text-xs font-bold">`
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftCssText(
                tr('Agent token'),
                style: _xs(t, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Container(
                key: const ValueKey('external-token-value'),
                padding: const EdgeInsets.all(8),
                decoration: RaftCssBoxDecoration(
                  color: t.colors['layer-panel'],
                  border: Border.all(color: t.colors['line-muted']!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: RaftCssText(
                  maskToken(state.token),
                  style: _xs(t, mono: true, color: t.strong),
                ),
              ),
            ],
          ),
          RaftCssText(
            tr(
              'Copy this token to your secret store now. It cannot be retrieved after you leave this panel. Each generation creates a separate credential; existing tokens stay active.',
            ),
            style: muted,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _smOutline(
              context,
              state.copied ? 'Copied' : 'Copy Token',
              actions.onCopy,
              key: const ValueKey('external-token-copy'),
            ),
          ),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: _smOutline(
              context,
              state.pending ? 'Generating Token…' : 'Generate Login Token',
              busy ? null : actions.onGenerate,
              key: const ValueKey('external-token-generate'),
            ),
          ),
        if (state.error)
          RaftCssText(
            key: const ValueKey('external-token-error'),
            tr(
              'The agent exists, but no usable token was received. A token may have been created if the response was lost. Check existing credentials before generating another.',
            ),
            style: alert,
          ),
        // `min-w-0 space-y-2 border-t border-line-muted pt-2`
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.colors['line-muted']!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  RaftCssText(
                    tr('Existing tokens'),
                    style: _xs(t, weight: FontWeight.w700),
                  ),
                  _smOutline(
                    context,
                    'Refresh Tokens',
                    state.loading || busy ? null : actions.onRefresh,
                    key: const ValueKey('external-token-refresh'),
                  ),
                ],
              ),
              if (state.loading)
                Semantics(
                  liveRegion: true,
                  child: RaftCssText(tr('Loading tokens…'), style: _xs(t)),
                ),
              if (state.listError)
                RaftCssText(
                  tr(
                    'Could not load tokens. Refresh to check their current status.',
                  ),
                  style: alert,
                ),
              if (!state.loading && !state.listError) ...[
                if (state.credentials.isEmpty)
                  RaftCssText(
                    tr('No tokens have been issued for this agent.'),
                    style: _xs(t),
                  ),
                for (final c in state.credentials)
                  _credential(context, t, c, busy),
              ],
              if (state.revokeError)
                RaftCssText(
                  tr(
                    'Revocation was not confirmed. Refresh to check the token before trying again.',
                  ),
                  style: alert,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _credential(
    BuildContext context,
    RaftTokens t,
    RaftExternalCredential c,
    bool busy,
  ) {
    String tr(String s) => raftText(context, s);
    final text = _xs(t);
    // `space-y-1 rounded-md border border-line-muted p-2 text-xs
    // theme-brutal:rounded-none theme-brutal:border-black/20`
    return Container(
      key: ValueKey('external-credential-${c.id}'),
      padding: const EdgeInsets.all(8),
      decoration: RaftCssBoxDecoration(
        border: Border.all(color: t.colors['line-muted']!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          RaftCssText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${tr(c.label)} ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: c.masked,
                  style: TextStyle(
                    fontFamily: t.monoFont,
                    fontFamilyFallback: t.fontFallback,
                  ),
                ),
              ],
            ),
            style: text,
          ),
          RaftCssText(c.created, style: text),
          RaftCssText(tr(c.revoked ? 'Revoked' : 'Valid'), style: text),
          if (!c.revoked)
            if (state.confirmId == c.id) ...[
              RaftCssText(
                tr(
                  'Apps using this token will lose access. Other tokens will stay active.',
                ),
                style: text,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smOutline(
                    context,
                    'Confirm Revocation',
                    busy ? null : () => actions.onConfirmRevoke(c.id),
                    key: const ValueKey('external-token-confirm-revoke'),
                  ),
                  _smOutline(
                    context,
                    'Keep Token',
                    state.revokingId != null ? null : actions.onCancelRevoke,
                    key: const ValueKey('external-token-cancel-revoke'),
                  ),
                ],
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: _smOutline(
                  context,
                  'Revoke Token',
                  busy ? null : () => actions.onRevoke(c.id),
                  key: ValueKey('external-token-revoke-${c.id}'),
                ),
              ),
        ],
      ),
    );
  }
}

/// The "External setup" section of the agent profile.
class RaftExternalSetupSection extends StatelessWidget {
  const RaftExternalSetupSection({
    super.key,
    required this.setupState,
    required this.tab,
    required this.onTab,
    required this.steps,
    required this.otherInstruction,
    required this.onCopy,
    this.lastUsed,
    this.statusError,
    this.tokenManager,
    this.copiedTarget,
    this.hosted,
  });

  /// A cloud agent: its provisioning status replaces the token manager and
  /// the setup steps (Web `hostedRuntime ? <HostedRuntimeStatus/> : ...`).
  final Widget? hosted;

  /// `waiting_for_login`, `credential_minted` or `connected` (null while the
  /// status read is in flight).
  final String? setupState;

  /// `Last used {time}` already formatted.
  final String? lastUsed;
  final String? statusError;

  /// The token manager (only for who may issue credentials).
  final Widget? tokenManager;
  final RaftExternalSetupTab tab;
  final ValueChanged<RaftExternalSetupTab> onTab;

  /// Steps of the Hermes / Claude Code tab; null for Other Agents.
  final List<RaftExternalSetupStep>? steps;

  /// The Other Agents instruction text.
  final String otherInstruction;
  final String? copiedTarget;

  /// Copies [text]; [target] names the button that shows `Copied`.
  final void Function(String text, String target) onCopy;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final stepList = steps;
    // `border-t ... px-5 py-4`, eyebrow `mb-2`.
    return RaftPanelSection(
      key: const ValueKey('external-setup'),
      gap: 8,
      children: [
        // `<SectionEyebrow as="div" className="mb-2">`; RaftCssText snaps the
        // glyph baseline like Blink so the 16px line box lands on whole pixels.
        RaftCssPixelSnap(
          child: RaftScaled.lineBox(
            context,
            height: 16,
            child: RaftCssText(
              tr('External setup'),
              style: RaftSectionEyebrow.style(t),
            ),
          ),
        ),
        // `space-y-3 border theme-brutal:border-2 border-line-muted
        // theme-brutal:border-black bg-info-soft theme-brutal:bg-brutal-cyan/15
        // p-3 shadow-raft-sm theme-brutal:shadow-brutal-sm`
        // Blink snaps the box to whole pixels (the profile above it ends on a
        // half pixel: the 22.5px name line).
        RaftCssPixelSnap(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: RaftCssBoxDecoration(
              color: t.colors['info-soft'],
              border: Border.all(color: t.colors['line-muted']!, width: 1),
              boxShadow: t.themeShadows.sm.outer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // `inline-flex border ... px-2 py-0.5 text-xs font-bold`
                    Container(
                      key: const ValueKey('external-setup-state'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: RaftCssBoxDecoration(
                        color: t.colors['layer-panel'],
                        border: Border.all(
                          color: t.colors['line-muted']!,
                          width: 1,
                        ),
                      ),
                      child: RaftCssText(
                        tr(switch (setupState) {
                          'connected' => 'Connected',
                          'credential_minted' => 'Credential minted',
                          _ => 'Waiting for login',
                        }),
                        style: _xs(t, weight: FontWeight.w700, color: t.strong),
                      ),
                    ),
                    if (lastUsed != null)
                      RaftCssText(
                        lastUsed!,
                        style: _xs(t, mono: true, color: _muted(t)),
                      ),
                  ],
                ),
                if (hosted != null)
                  hosted!
                else ...[
                  ?tokenManager,
                  RaftSegmentedControl<RaftExternalSetupTab>(
                    legacyStyle: RaftSegmentedStyle.recipe,
                    value: tab,
                    label: tr('External agent setup path'),
                    items: const [
                      RaftSegmentedOption(
                        value: RaftExternalSetupTab.hermes,
                        label: 'Hermes',
                      ),
                      RaftSegmentedOption(
                        value: RaftExternalSetupTab.claudeCode,
                        label: 'Claude Code',
                      ),
                      RaftSegmentedOption(
                        value: RaftExternalSetupTab.otherAgents,
                        label: 'Other Agents',
                      ),
                    ],
                    onChanged: onTab,
                  ),
                  if (stepList != null)
                    _steps(context, t, stepList)
                  else
                    _other(context, t),
                ],
                if ((hosted == null &&
                        tab == RaftExternalSetupTab.otherAgents) ||
                    statusError != null)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hosted == null &&
                          tab == RaftExternalSetupTab.otherAgents)
                        _smOutline(
                          context,
                          copiedTarget == 'setup' ? 'Copied' : 'Copy Setup',
                          () => onCopy(otherInstruction, 'setup'),
                          key: const ValueKey('external-setup-copy'),
                        ),
                      if (statusError != null)
                        RaftCssText(
                          raftText(context, statusError!),
                          style: _xs(
                            t,
                            weight: FontWeight.w700,
                            color: t.colors['warning-strong'],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _steps(
    BuildContext context,
    RaftTokens t,
    List<RaftExternalSetupStep> list,
  ) {
    String tr(String s) => raftText(context, s);
    final tabName = switch (tab) {
      RaftExternalSetupTab.hermes => 'hermes',
      RaftExternalSetupTab.claudeCode => 'claude-code',
      RaftExternalSetupTab.otherAgents => 'other-agents',
    };
    final note = _xs(t, color: _muted(t));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        RaftCssText(
          tr('Run these steps in the terminal.'),
          style: _xs(t, weight: FontWeight.w700, color: _muted(t)),
        ),
        // `<ol className="space-y-4">`
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            for (final (i, step) in list.indexed)
              Column(
                key: ValueKey('external-step-${i + 1}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RaftCssText(
                        raftFormat(context, 'Step {step}', {'step': i + 1}),
                        style: _xs(
                          t,
                          weight: FontWeight.w700,
                          color: _muted(t),
                        ),
                      ),
                      _smOutline(
                        context,
                        copiedTarget == '$tabName-step-${i + 1}'
                            ? 'Copied'
                            : 'Copy Step',
                        () => onCopy(step.command, '$tabName-step-${i + 1}'),
                        key: ValueKey('external-step-copy-${i + 1}'),
                      ),
                    ],
                  ),
                  RaftCssText(
                    step.title,
                    style: TextStyle(
                      fontFamily: t.headingFont,
                      fontFamilyFallback: t.fontFallback,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                      color: t.strong,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                  // `break-all border border-line-muted
                  // theme-brutal:border-black/20 bg-layer-panel
                  // theme-brutal:bg-white/80 p-2 font-mono text-xs`
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: RaftCssBoxDecoration(
                      color: t.colors['layer-panel'],
                      border: Border.all(color: t.colors['line-muted']!),
                    ),
                    child: RaftCssText(
                      step.command,
                      style: _xs(t, mono: true, color: t.strong),
                    ),
                  ),
                  if (step.description.isNotEmpty)
                    RaftCssText(step.description, style: note),
                ],
              ),
          ],
        ),
        RaftCssText(
          tr('Keep RAFT_PROFILE set when running this agent.'),
          style: note,
        ),
        if (tab == RaftExternalSetupTab.claudeCode)
          RaftCssText(
            tr('Keep Claude Code running so it can receive Raft work.'),
            style: note,
          )
        else if (tab == RaftExternalSetupTab.hermes)
          RaftCssText(
            tr(
              'Restart or reload Hermes after setup so the saved profile is picked up.',
            ),
            style: note,
          ),
      ],
    );
  }

  Widget _other(BuildContext context, RaftTokens t) {
    // `space-y-2`; the command box has `theme-brutal:border-2 border-black`.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: RaftCssBoxDecoration(
            color: t.colors['layer-panel'],
            border: Border.all(color: t.colors['line-muted']!, width: 1),
          ),
          child: RaftCssText(
            otherInstruction,
            style: _xs(t, mono: true, color: t.strong),
          ),
        ),
        RaftCssText(
          raftText(
            context,
            'Use this flow for another agent runtime or custom harness.',
          ),
          style: _xs(t, color: _muted(t)),
        ),
      ],
    );
  }
}
