// Web AgentStatusBadge (v1.24.0, features/agent/AgentStatusBadge.tsx): the
// agent profile's status chip with the quiet actions beside it. A soft Badge
// holds the presence light and the words; Retry and Change model are text
// links; delivery / wake counts are a mono hint after them. Presentation only:
// the app decides which words, light and links apply and owns every action.
import 'package:flutter/material.dart';

import 'design_primitives.dart'
    show RaftTextLink, RaftTextLinkVariant, RaftTouchTarget;
import 'interaction.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/badge.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'recipes/badge.g.dart'
    show RaftBadgeRecipeAppearance, RaftBadgeRecipeVariant;
import 'theme.dart';
import 'tokens/tokens.dart';
import 'tooltip.dart';

/// The chip's wash (raft-ui `Badge` variants, Web `PRESENCE_CHIP_VARIANT`).
enum RaftAgentStatusTone { success, busy, warning, muted, information }

/// The presence light in the chip (`StatusDot`).
enum RaftAgentStatusLight { online, busy, error, offline, external }

class RaftAgentStatusRow extends StatelessWidget {
  const RaftAgentStatusRow({
    super.key,
    required this.text,
    required this.tone,
    required this.light,
    this.tooltip,
    this.wrap = false,
    this.onOpenChip,
    this.onRetry,
    this.retrying = false,
    this.onChangeModel,
    this.detail,
    this.linkLabel,
    this.onLink,
    this.body,
  });

  /// A readiness chip's own link (Web `agent-readiness-link`, a TextLink to
  /// the verification portal): [linkLabel] opens through [onLink].
  final String? linkLabel;
  final VoidCallback? onLink;

  /// The readiness sentence under the chip row (Web `agent-readiness-detail`,
  /// callout, muted). Null draws nothing.
  final String? body;

  /// The chip's words, already localized. Also its tooltip unless [tooltip].
  final String text;
  final String? tooltip;
  final RaftAgentStatusTone tone;
  final RaftAgentStatusLight light;

  /// A sentence (revoked Computer access): the chip wraps instead of cutting.
  final bool wrap;

  /// The chip is a button (Computer offline / update required open that
  /// Computer, where the steps are).
  final VoidCallback? onOpenChip;

  /// Retry (the menu's Restart): says "Restarting…" and is disabled while it
  /// runs ([retrying]). Null hides it.
  final VoidCallback? onRetry;
  final bool retrying;

  /// Change model: opens the agent's model setting. Null hides it.
  final VoidCallback? onChangeModel;

  /// The mono hint after the links (delivery / wake counts).
  final String? detail;

  static RaftBadgeRecipeVariant _variant(RaftAgentStatusTone tone) =>
      switch (tone) {
        RaftAgentStatusTone.success => RaftBadgeRecipeVariant.success,
        // The Working chip has its own wash (`fill`), the variant only names
        // the family.
        RaftAgentStatusTone.busy => RaftBadgeRecipeVariant.accent,
        RaftAgentStatusTone.warning => RaftBadgeRecipeVariant.warning,
        RaftAgentStatusTone.muted => RaftBadgeRecipeVariant.muted,
        RaftAgentStatusTone.information => RaftBadgeRecipeVariant.information,
      };

  Widget _dot() => switch (light) {
    RaftAgentStatusLight.online => const RaftStatusDot(
      activity: RaftActivityTone.online,
    ),
    RaftAgentStatusLight.busy => const RaftStatusDot(
      activity: RaftActivityTone.working,
    ),
    RaftAgentStatusLight.error => const RaftStatusDot(
      activity: RaftActivityTone.error,
    ),
    RaftAgentStatusLight.offline => const RaftStatusDot(
      activity: RaftActivityTone.offline,
    ),
    RaftAgentStatusLight.external => const RaftStatusDot(external: true),
  };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final touch = RaftInteraction.of(context).touch;
    Widget chip = RaftBadge(
      key: const ValueKey('agent-status-chip'),
      label: text,
      appearance: RaftBadgeRecipeAppearance.soft,
      variant: _variant(tone),
      fill: tone == RaftAgentStatusTone.busy
          ? t.ui['presence-busy-soft']
          : null,
      leading: _dot(),
      wrap: wrap,
      onPressed: onOpenChip,
      semanticLabel: null,
    );
    chip = RaftTooltip(message: tooltip ?? text, child: chip);
    if (onOpenChip != null && touch) chip = RaftTouchTarget(child: chip);

    Widget link(Key key, String label, VoidCallback? onPressed) {
      final button = RaftTextLink(
        key: key,
        label: raftText(context, label),
        onPressed: onPressed,
        // Web: the DS TextLink, quiet beside the chip.
        variant: RaftTextLinkVariant.muted,
      );
      return touch ? RaftTouchTarget(child: button) : button;
    }

    final links = <Widget>[
      if (linkLabel != null && onLink != null)
        // `whitespace-nowrap`: one line; in a window too narrow for it the
        // link shrinks to fit instead of overflowing.
        LayoutBuilder(
          builder: (context, box) => ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: link(
                const ValueKey('agent-readiness-link'),
                linkLabel!,
                onLink,
              ),
            ),
          ),
        ),
      if (onChangeModel != null)
        link(
          const ValueKey('agent-status-change-model'),
          'Change model',
          onChangeModel,
        ),
      if (onRetry != null)
        link(
          const ValueKey('agent-status-retry'),
          retrying ? 'Restarting…' : 'Retry',
          retrying ? null : onRetry,
        ),
    ];
    final hint = detail == null
        ? null
        : RaftTooltip(
            message: detail!,
            child: RaftCssText(
              detail!,
              key: const ValueKey('agent-status-detail'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t
                  .scale(
                    RaftTypeScale.monoMeta,
                    mono: true,
                    color: t.ui.foregroundHint,
                  )
                  .copyWith(fontWeight: FontWeight.w400),
            ),
          );
    // A panel mid-transition can hand the row no width at all: draw nothing
    // rather than a chip that cannot fit its light.
    final sentence = body;
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 24) return const SizedBox.shrink();
        final row = _layout(chip, links, hint);
        if (sentence == null) return row;
        // `flex flex-col gap-1`: the chip row, then the sentence.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            row,
            RaftCssText(
              sentence,
              key: const ValueKey('agent-readiness-detail'),
              style: t.scale(
                RaftTypeScale.callout,
                color: t.ui.foregroundMuted,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _layout(Widget chip, List<Widget> links, Widget? hint) {
    if (wrap) {
      return Wrap(
        key: const ValueKey('agent-status-row'),
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: double.maxFinite),
            child: chip,
          ),
          ...links,
          ?hint,
        ],
      );
    }
    return Row(
      key: const ValueKey('agent-status-row'),
      children: [
        Flexible(child: chip),
        for (final l in links) ...[const SizedBox(width: 6), l],
        if (hint != null) ...[const SizedBox(width: 6), Flexible(child: hint)],
      ],
    );
  }
}
