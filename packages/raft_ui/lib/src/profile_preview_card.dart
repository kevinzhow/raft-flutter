import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'hover_card.dart';
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'panel_layout.dart';
import 'recipe_surface.dart';
import 'theme.dart';
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
  });

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
    Color muted(double brutal) =>
        raftPanelInk(t, brutal, t.colors['foreground-muted']!);
    final strong = t.brutal ? Colors.black : t.colors['foreground-strong']!;
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
    Widget line(String text, TextStyle style, {bool tooltip = false}) {
      final label = Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
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

    final rule = t.brutal ? Colors.black : t.colors['line-muted']!;
    final factStyle = mono(11, 11 * 1.25, muted(.7));
    final factLabel = mono(
      11,
      11 * 1.25,
      raftPanelInk(t, .45, t.colors['foreground-placeholder']!),
    );
    final header = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: facts == null ? 0 : 2),
            child: avatar,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: line(name, sans(14, 20, strong, FontWeight.w700)),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 6),
                      RaftStatusDot(
                        activity: status!.activity,
                        external: status!.external,
                        size: RaftStatusDotSize.sm,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: line(status!.text, mono(12, 16, muted(.6))),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) line(subtitle!, mono(12, 16, muted(.6))),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: line(
                      note,
                      sans(
                        12,
                        16,
                        raftPanelInk(t, .5, t.colors['foreground-hint']!),
                      ),
                    ),
                  ),
                if (facts != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: t.brutal
                              ? Colors.black.withValues(alpha: .2)
                              : t.colors['line-muted']!,
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
                                  right: 8,
                                  top: i == 0 ? 0 : 4,
                                ),
                                child: Text(fact.label, style: factLabel),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                                child: line(
                                  fact.capitalize && fact.value.isNotEmpty
                                      ? fact.value[0].toUpperCase() +
                                            fact.value.substring(1)
                                      : fact.value,
                                  factStyle,
                                  tooltip: true,
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
    final section = BorderSide(color: rule, width: 2);
    return Column(
      key: const ValueKey('profile-preview-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (description != null && description!.isNotEmpty)
          Container(
            key: const ValueKey('profile-preview-description'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(top: section)),
            child: line(
              description!.replaceAll('\n', ' '),
              sans(12, 16, muted(.7)),
              tooltip: true,
            ),
          ),
        if (activity.isNotEmpty)
          Container(
            key: const ValueKey('profile-preview-activity'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(top: section)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActivityHeading(onPressed: onOpenActivity),
                const SizedBox(height: 6),
                for (final (i, row) in activity.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: Row(
                      key: const ValueKey('profile-preview-activity-row'),
                      children: [
                        Text(
                          row.time,
                          style: mono(
                            10,
                            15,
                            raftPanelInk(
                              t,
                              .4,
                              t.colors['foreground-placeholder']!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        RaftStatusDot(
                          activity: row.activity,
                          size: RaftStatusDotSize.sm,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: line(
                            row.text,
                            sans(12, 16, muted(.7)),
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
/// the agent's activity, otherwise a static uppercase divider.
class _ActivityHeading extends StatelessWidget {
  const _ActivityHeading({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(context, 'Recent activity');
    TextStyle style(bool hovered) {
      final color = hovered
          ? (t.brutal ? Colors.black : t.colors['foreground-strong']!)
          : raftPanelInk(t, .5, t.colors['foreground-muted']!);
      return raftCssText.merge(
        RaftTypography.body(
          t,
          size: 10,
          line: 15,
          weight: FontWeight.w700,
          color: color,
        ).copyWith(
          letterSpacing: .25,
          decoration: hovered ? TextDecoration.underline : null,
          decorationColor: color,
        ),
      );
    }

    if (onPressed == null) {
      return Text(label.toUpperCase(), style: style(false));
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
            Text(label, style: s),
            const SizedBox(width: 2),
            RaftIcon(RaftGlyph.chevronRight, size: 10, color: s.color),
          ],
        );
      },
    );
  }
}
