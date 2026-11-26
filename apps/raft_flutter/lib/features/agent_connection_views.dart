// The parts of Web's GitHub connection card (components/agent/
// AgentConnections.tsx, GithubConnectionDetails.tsx, GithubRevokeHint.tsx,
// GithubConnectAccountDialog.tsx) that only draw: the state chip, the access
// line, the reconnect detail, the actions menu, the revoke hint and the access
// choice of the connect dialog. The section owns every decision.
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_connections.dart';
import 'resource_cards.dart' show resourceRelativeTime;

enum AgentConnectionState { connected, notConnected, needsReconnect }

/// `ConnectionStateChip`: Connected / Not connected / Needs reconnecting.
class AgentConnectionStateChip extends StatelessWidget {
  const AgentConnectionStateChip({super.key, required this.state});
  final AgentConnectionState state;

  @override
  Widget build(BuildContext context) => RaftBadge(
    key: ValueKey('agent-connection-github-state-${state.name}'),
    label: raftText(context, switch (state) {
      AgentConnectionState.needsReconnect => 'Needs reconnecting',
      AgentConnectionState.connected => 'Connected',
      AgentConnectionState.notConnected => 'Not connected',
    }),
    appearance: RaftBadgeRecipeAppearance.soft,
    variant: switch (state) {
      AgentConnectionState.needsReconnect => RaftBadgeRecipeVariant.warning,
      AgentConnectionState.connected => RaftBadgeRecipeVariant.success,
      AgentConnectionState.notConnected => RaftBadgeRecipeVariant.muted,
    },
    leading: RaftStatus(
      presence: switch (state) {
        AgentConnectionState.needsReconnect => RaftPresence.error,
        AgentConnectionState.connected => RaftPresence.online,
        AgentConnectionState.notConnected => RaftPresence.offline,
      },
    ),
  );
}

/// The words for what a connection can do ("Can use public repos only").
String? agentConnectionAccessSummary(BuildContext context, GithubAccess a) =>
    switch (a.access) {
      'private' => raftText(context, 'Can use public and private repos'),
      'public' => raftText(context, 'Can use public repos only'),
      _ => null,
    };

/// `AccessLine`: what the connection can do, in words; the raw GitHub scopes
/// only in its tooltip. Nothing when not recorded or when it is short.
class AgentConnectionAccessLine extends StatelessWidget {
  const AgentConnectionAccessLine({super.key, required this.access});
  final GithubAccess access;

  @override
  Widget build(BuildContext context) {
    final text = access.short.isNotEmpty
        ? null
        : agentConnectionAccessSummary(context, access);
    if (text == null) return const SizedBox.shrink();
    final line = RaftCssText(
      key: ValueKey('agent-connection-github-access-${access.access}'),
      text,
      style: RaftPanelText.caption(RaftTokens.of(context)),
    );
    final granted = access.granted;
    if (granted == null || granted.isEmpty) return line;
    return RaftTooltip(
      message: raftFormat(context, 'GitHub scopes: {scopes}', {
        'scopes': granted.join(', '),
      }),
      child: line,
    );
  }
}

/// `HealthDetail`: why a connection needs reconnecting. The sentence, the
/// provider's reason (muted) and when it last checked (hint).
class AgentConnectionHealthDetail extends StatelessWidget {
  const AgentConnectionHealthDetail({
    super.key,
    required this.style,
    required this.message,
    this.reason,
    this.checkedAt,
  });
  final TextStyle style;
  final String message;
  final String? reason, checkedAt;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final checked = resourceRelativeTime(
      checkedAt,
      locale: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftCssText(message, style: style),
        if (reason != null)
          RaftCssText(
            key: const ValueKey('agent-connection-github-health-reason'),
            reason,
            style: style.copyWith(color: t.colors['foreground-muted']),
          ),
        if (checked.isNotEmpty)
          RaftCssText(
            key: const ValueKey('agent-connection-github-health-checked'),
            raftFormat(context, 'Last checked {time}', {'time': checked}),
            style: style.copyWith(color: t.colors['foreground-hint']),
          ),
      ],
    );
  }
}

/// `ConnectionActionsMenu`: the ⋯ of a connected card.
class AgentConnectionActionsMenu extends StatelessWidget {
  const AgentConnectionActionsMenu({
    super.key,
    required this.agentName,
    required this.canDisconnect,
    required this.removing,
    required this.onConnectNew,
    required this.onDetach,
    required this.onDisconnect,
  });
  final String agentName;
  final bool canDisconnect, removing;

  /// Null when the caller is not the agent's owner.
  final VoidCallback? onConnectNew;
  final VoidCallback onDetach, onDisconnect;

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, 'More actions');
    return RaftDropdownMenu(
      key: const ValueKey('agent-connection-github-menu'),
      label: label,
      tooltip: label,
      align: RaftDropdownAlign.end,
      width: 240,
      triggerBuilder: (context, focusNode, open) => RaftButton(
        glyph: RaftGlyph.ellipsisVertical,
        focusNode: focusNode,
        tooltip: label,
        semanticLabel: label,
        uiVariant: RaftButtonVariant.ghost,
        uiSize: RaftButtonSize.iconLg,
        onPressed: open,
      ),
      entries: [
        if (onConnectNew != null) ...[
          RaftMenuEntry(
            label: raftText(context, 'Connect new account'),
            glyph: RaftGlyph.plug,
            onPressed: onConnectNew,
          ),
          const RaftMenuEntry.separator(),
        ],
        RaftMenuEntry(
          label: raftFormat(context, 'Remove from {agent}', {
            'agent': agentName,
          }),
          glyph: RaftGlyph.unplug,
          onPressed: removing ? null : onDetach,
        ),
        if (canDisconnect)
          RaftMenuEntry(
            label: raftText(context, 'Disconnect for all agents'),
            glyph: RaftGlyph.unplug,
            onPressed: onDisconnect,
          ),
      ],
    );
  }
}

/// `GithubRevokeHint`: after a removal the provider could not finish, where
/// the authorization is revoked. Shown only on the server's word.
class AgentConnectionRevokeHint extends StatefulWidget {
  const AgentConnectionRevokeHint({
    super.key,
    required this.onOpen,
    required this.onClose,
  });
  final VoidCallback onOpen, onClose;

  @override
  State<AgentConnectionRevokeHint> createState() =>
      _AgentConnectionRevokeHintState();
}

class _AgentConnectionRevokeHintState extends State<AgentConnectionRevokeHint> {
  final tap = TapGestureRecognizer();

  @override
  void dispose() {
    tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    tap.onTap = widget.onOpen;
    final close = raftText(context, 'Dismiss');
    final link = raftText(context, 'your GitHub settings');
    final template = raftText(
      context,
      "An agent still holds a copy of this GitHub credential that can't be removed from here. To stop it working, revoke the app in {link}. That signs out every connection made with this GitHub account.",
    );
    final at = template.indexOf('{link}');
    return RaftBanner(
      key: const ValueKey('agent-connection-github-revoke-hint'),
      status: RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      glyph: RaftGlyph.triangleAlert,
      centerAction: true,
      descriptionBuilder: (style) => RaftCssText.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: at < 0 ? template : template.substring(0, at)),
            if (at >= 0) ...[
              TextSpan(
                text: link,
                recognizer: tap,
                mouseCursor: SystemMouseCursors.click,
                semanticsLabel:
                    '$link ${raftText(context, '(opens in a new tab)')}',
                style: style.apply(
                  fontWeightDelta: 2,
                  decoration: TextDecoration.underline,
                ),
              ),
              const TextSpan(text: '\u2009'),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: RaftIcon(RaftGlyph.arrowUpRight, size: 12),
              ),
              TextSpan(text: template.substring(at + '{link}'.length)),
            ],
          ],
        ),
      ),
      action: RaftButton(
        key: const ValueKey('agent-connection-github-revoke-close'),
        glyph: RaftGlyph.x,
        tooltip: close,
        semanticLabel: close,
        uiVariant: RaftButtonVariant.ghost,
        uiSize: RaftButtonSize.iconSm,
        onPressed: widget.onClose,
      ),
    );
  }
}

/// `AccessOption`: one repository-access choice of the connect dialog, named
/// by its title and described by its scope line.
class AgentConnectionAccessOption extends StatelessWidget {
  const AgentConnectionAccessOption({
    super.key,
    required this.value,
    required this.title,
    required this.description,
    required this.scope,
  });
  final String value, title, description, scope;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final body = RaftPanelText.caption(t);
    return RaftRadioGroupItem<String>(
      key: ValueKey('agent-connection-access-$value'),
      value: value,
      gap: 12,
      markInset: RaftAgentConnectionInsets.firstLine,
      crossAxisAlignment: CrossAxisAlignment.start,
      padding: RaftAgentConnectionInsets.accessRow,
      minHeight: 44,
      semanticLabel: '$title. $description $scope',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftCssText(title, style: RaftPanelText.bold(t)),
          Text.rich(
            TextSpan(
              style: body,
              children: [
                TextSpan(text: '$description '),
                TextSpan(
                  text: scope,
                  style: body.copyWith(fontFamily: t.monoFont),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
