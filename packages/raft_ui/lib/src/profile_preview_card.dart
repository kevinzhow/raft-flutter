import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'design_primitives.dart';
import 'flex_shrink_row.dart';
import 'hover_card.dart';
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart';

/// One `<dt>/<dd>` pair of the agent card facts grid.
@immutable
class RaftProfilePreviewFact {
  const RaftProfilePreviewFact(
    this.label,
    this.value, {
    this.capitalize = false,
  });
  final String label, value;

  /// `capitalize` (reasoning effort).
  final bool capitalize;
}

/// One MentionHoverActivityPreview row: clock, status dot, text.
@immutable
class RaftProfilePreviewActivity {
  const RaftProfilePreviewActivity({
    required this.time,
    required this.activity,
    required this.text,
  });
  final String time, text;
  final RaftActivityTone activity;
}

/// Agent presence line next to the name: StatusDot sm + mono activity text.
@immutable
class RaftProfilePreviewStatus {
  const RaftProfilePreviewStatus({
    required this.activity,
    required this.text,
    this.external = false,
  });
  final RaftActivityTone activity;
  final String text;
  final bool external;
}

/// Web ProfilePreviewCardContent.tsx (and ExternalIdentityPreviewCard's
/// body): the hover card shown for an agent or member avatar / @mention.
/// Presentation only; the adapter resolves identity, permissions and data.
class RaftProfilePreviewCard extends StatelessWidget {
  const RaftProfilePreviewCard({
    super.key,
    required this.avatar,
    required this.name,
    this.subtitle,
    this.status,
    this.facts,
    this.description,
    this.notes = const [],
    this.activity = const [],
    this.onOpenActivity,
    this.avatarTopInset,
  });

  /// `mt-0.5` on the avatar slot: 2 for a resolved profile (agent, member),
  /// 0 for the unavailable / external bodies. Null keeps the facts rule
  /// (agent cards with a facts grid).
  final double? avatarTopInset;

  /// AvatarSlot `mention-card` (48px).
  final Widget avatar;
  final String name;

  /// Mono line under the name: `@handle`, "Profile unavailable", or the
  /// external provider/kind.
  final String? subtitle;
  final RaftProfilePreviewStatus? status;

  /// Agent facts grid (Computer / Runtime / Model / Reasoning). Null hides
  /// the grid (members, channel-summary agents).
  final List<RaftProfilePreviewFact>? facts;
  final String? description;

  /// Plain `mt-1 text-xs` lines under the subtitle (external identity).
  final List<String> notes;

  /// Recent activity rows; empty hides the section.
  final List<RaftProfilePreviewActivity> activity;
  final VoidCallback? onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = t.colors['foreground-muted']!;
    final strong = t.colors['foreground-strong']!;
    TextStyle sans(double size, double line, Color color, [FontWeight? w]) =>
        raftCssText.merge(
          RaftTypography.body(
            t,
            size: size,
            line: line,
            color: color,
            weight: w ?? FontWeight.w400,
          ),
        );
    TextStyle mono(double size, double line, Color color) => raftCssText.merge(
      RaftTypography.mono(t, size: size, line: line, color: color),
    );
    Widget line(
      String text,
      TextStyle style, {
      bool tooltip = false,
      int maxLines = 1,
    }) {
      final label = Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        softWrap: maxLines > 1,
        style: style,
      );
      return tooltip
          ? RaftTooltip(
              message: text,
              onlyWhenTruncated: true,
              excludeFromSemantics: true,
              child: label,
            )
          : label;
    }

    // Raft look: ProfilePreviewCardContent's type styles (`text-headline`,
    // `text-callout`, `text-mono-meta`, `text-caption`, `text-footnote`) follow
    // the desktop / touch scale; the frozen looks keep their authored sizes.
    final raft = t.isRaftLook;
    final hint = t.colors['foreground-hint']!;
    final nameStyle = raft
        ? t.scale(RaftTypeScale.headline, color: t.colors['foreground'])
        : sans(14, 20, strong, FontWeight.w700);
    final monoMeta = raft
        ? t.scale(RaftTypeScale.monoMeta, mono: true, color: muted)
        : mono(12, 16, muted);
    final statusStyle = raft
        ? t.scale(RaftTypeScale.callout, color: hint)
        : mono(12, 16, muted);
    final bodyStyle = raft
        ? t.scale(RaftTypeScale.callout, color: muted)
        : sans(12, 16, muted);
    final rule = raft ? t.colors['line-hairline']! : t.colors['line-muted']!;
    final ruleWidth = raft ? 1.0 : 2.0;
    final factStyle = raft ? monoMeta : mono(11, 11 * 1.25, muted);
    final factLabel = raft
        ? t.scale(RaftTypeScale.caption, color: hint)
        : mono(11, 11 * 1.25, t.colors['foreground-placeholder']!);
    final factMinHeight = raft
        ? (factLabel.height! * factLabel.fontSize!)
        : 11 * 1.25;
    // Raft look: raft-ui `px-4 pt-4 pb-3 last:pb-4` (16 under the avatar row
    // when nothing follows, 12 above a description or activity section).
    final last =
        (description == null || description!.isEmpty) && activity.isEmpty;
    final header = Padding(
      padding: t.isRaftLook
          ? EdgeInsets.fromLTRB(16, 16, 16, last ? 16 : 12)
          : const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: avatarTopInset ?? (facts == null ? 0 : 2),
            ),
            child: avatar,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // `flex items-center gap-1.5`: the truncating name and status
                // text shrink in proportion to their width; the dot is fixed.
                if (status == null)
                  line(name, nameStyle)
                else
                  RaftFlexShrinkRow(
                    gap: 6,
                    truncating: true,
                    fixed: const {1},
                    children: [
                      line(name, nameStyle),
                      RaftStatusDot(
                        activity: status!.activity,
                        external: status!.external,
                        size: RaftStatusDotSize.sm,
                      ),
                      line(status!.text, statusStyle),
                    ],
                  ),
                if (subtitle != null) line(subtitle!, monoMeta),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: line(
                      note,
                      sans(12, 16, t.colors['foreground-hint']!),
                    ),
                  ),
                if (facts != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: raft ? rule : t.colors['line-muted']!,
                        ),
                      ),
                    ),
                    child: Table(
                      key: const ValueKey('profile-preview-facts'),
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: FlexColumnWidth(),
                      },
                      children: [
                        for (final (i, fact) in facts!.indexed)
                          TableRow(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  // `gap-x-3` (frozen: 8).
                                  right: raft ? 12 : 8,
                                  top: i == 0 ? 0 : 4,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: factMinHeight,
                                  ),
                                  child: Text(fact.label, style: factLabel),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: factMinHeight,
                                  ),
                                  child: line(
                                    fact.capitalize && fact.value.isNotEmpty
                                        ? fact.value[0].toUpperCase() +
                                              fact.value.substring(1)
                                        : fact.value,
                                    factStyle,
                                    tooltip: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final section = BorderSide(color: rule, width: ruleWidth);
    return Column(
      key: const ValueKey('profile-preview-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (description != null && description!.isNotEmpty)
          Container(
            key: const ValueKey('profile-preview-description'),
            // Raft look `line-clamp-2 px-4 py-3 last:pb-4 text-callout`.
            padding: raft
                ? EdgeInsets.fromLTRB(16, 12, 16, activity.isEmpty ? 16 : 12)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(top: section)),
            child: line(
              description!.replaceAll('\n', ' '),
              bodyStyle,
              tooltip: true,
              maxLines: raft ? 2 : 1,
            ),
          ),
        if (activity.isNotEmpty)
          Container(
            key: const ValueKey('profile-preview-activity'),
            // Raft look `px-4 py-3 last:pb-4`, heading `mb-2`, rows `stack-y-1.5`.
            padding: raft
                ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(top: section)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActivityHeading(onPressed: onOpenActivity),
                SizedBox(height: raft ? 8 : 6),
                for (final (i, row) in activity.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: Row(
                      key: const ValueKey('profile-preview-activity-row'),
                      children: [
                        Text(
                          row.time,
                          style: raft
                              ? monoMeta.copyWith(color: hint)
                              : mono(
                                  10,
                                  15,
                                  t.colors['foreground-placeholder']!,
                                ),
                        ),
                        SizedBox(width: raft ? 8 : 6),
                        RaftStatusDot(
                          activity: row.activity,
                          size: RaftStatusDotSize.sm,
                        ),
                        SizedBox(width: raft ? 8 : 6),
                        Expanded(
                          child: line(
                            row.text,
                            raft ? monoMeta : sans(12, 16, muted),
                            tooltip: true,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Recent Activity" heading: a Title Case link when the surface can open
/// the agent's activity, otherwise a static divider.
class _ActivityHeading extends StatelessWidget {
  const _ActivityHeading({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(context, 'Recent activity');
    TextStyle style(bool hovered) {
      final color = hovered
          ? (t.colors['foreground-strong']!)
          : t.isRaftLook
          ? t.colors['foreground-hint']!
          : t.colors['foreground-muted']!;
      if (t.isRaftLook) {
        // `text-footnote font-bold text-foreground-hint`.
        return t.scale(
          RaftTypeScale.footnote,
          weight: FontWeight.w700,
          color: hovered ? t.colors['foreground-strong']! : color,
        );
      }
      return raftCssText.merge(
        RaftTypography.body(
          t,
          size: 10,
          line: 15,
          weight: FontWeight.w700,
          color: color,
        ),
      );
    }

    if (onPressed == null) {
      return Text(label, style: style(false));
    }
    return RaftInteractive(
      key: const ValueKey('profile-preview-open-activity'),
      semanticLabel: label,
      onPressed: () {
        RaftHoverCard.dismiss(context);
        onPressed!();
      },
      builder: (context, state) {
        final s = style(state.hovered || state.focusVisible);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftUnderlinedText(
              label,
              style: s,
              underline: state.hovered || state.focusVisible,
            ),
            const SizedBox(width: 2),
            RaftIcon(
              RaftGlyph.chevronRight,
              size: t.isRaftLook ? 14 : 10,
              color: s.color,
            ),
          ],
        );
      },
    );
  }
}
