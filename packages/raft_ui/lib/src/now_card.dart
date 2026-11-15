import 'package:flutter/material.dart';

import 'card.dart';
import 'design_primitives.dart'
    show RaftControl, RaftControlKind, RaftTouchTarget;
import 'interaction.dart';
import 'icons.dart';
import 'list_items.dart' show RaftSectionEyebrow;
import 'otter_indicator.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Web `AgentNowCard`: what the agent is doing now (Ottie, then a headline or
/// the profile's status chip, the step it is on and who the turn answers) and,
/// on the profile, the last few turns one line each. The adapter owns every
/// word and the turn rows; this lays them out.
///
/// With [onOpenEyebrow] the heading is a button with a chevron (the profile's
/// "Recent activity" that opens the Activity tab).
class RaftNowCard extends StatelessWidget {
  const RaftNowCard({
    super.key,
    required this.otter,
    required this.lead,
    this.eyebrow,
    this.onOpenEyebrow,
    this.step,
    this.focus,
    this.rows = const [],
  });

  /// Ottie's pose.
  final RaftOtterStatus otter;

  /// The first line: a bold headline, or the status chip row.
  final Widget lead;

  /// The heading above Ottie.
  final String? eyebrow;
  final VoidCallback? onOpenEyebrow;

  /// The step it is on, then the turn it answers; one line each, cut at the end.
  final String? step, focus;

  /// The recent turns, one line each, under a hairline.
  final List<Widget> rows;

  static Widget _target(BuildContext context, Widget child) =>
      RaftInteraction.of(context).touch ? RaftTouchTarget(child: child) : child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    return RaftCard(
      key: const ValueKey('agent-now-card'),
      // ds-allow: Web CardContent `p-4`
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // ds-allow: Web CardContent `gap-3`
        spacing: 12,
        children: [
          if (eyebrow != null)
            Align(
              alignment: Alignment.centerLeft,
              child: onOpenEyebrow == null
                  ? RaftCssText(eyebrow!, style: RaftSectionEyebrow.style(t))
                  : _target(
                      context,
                      // ds-allow: Web SectionEyebrow rendered as a button: a text-link press target with the hover underline; RaftButton has no eyebrow variant.
                      RaftControl(
                        key: const ValueKey('agent-now-open-activity'),
                        kind: RaftControlKind.textLink,
                        visualHeight: 20,
                        // The Web heading keeps its own box; a finger still
                        // gets the native target through RaftTouchTarget.
                        minimumTargetSize: 0,
                        onPressed: onOpenEyebrow,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          // ds-allow: Web `gap-0.5`
                          spacing: 2,
                          children: [
                            Flexible(
                              child: RaftCssText(
                                eyebrow!,
                                style: RaftSectionEyebrow.style(t),
                              ),
                            ),
                            RaftIcon(
                              RaftGlyph.chevronRight,
                              size: 14,
                              color: ui.foregroundHint,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            // ds-allow: Web `gap-3`
            spacing: 12,
            children: [
              RaftOtterIndicator(status: otter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // ds-allow: Web `gap-1`
                  spacing: 4,
                  children: [
                    lead,
                    if (step != null)
                      RaftCssText(
                        step!,
                        key: const ValueKey('agent-now-step'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.scale(
                          RaftTypeScale.callout,
                          color: ui.foreground,
                        ),
                      ),
                    if (focus != null)
                      RaftCssText(
                        focus!,
                        key: const ValueKey('agent-now-focus'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.scale(
                          RaftTypeScale.callout,
                          color: ui.foregroundMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: ui.lineHairline)),
              ),
              // ds-allow: Web `pt-3`
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // ds-allow: Web `stack-y-1.5`
                spacing: 6,
                children: rows,
              ),
            ),
        ],
      ),
    );
  }
}

/// One recent turn of the profile's Now card (`RecentTurnRow`): the time, who
/// woke it, what it did, and the badges that need a look.
class RaftNowTurnRow extends StatelessWidget {
  const RaftNowTurnRow({
    super.key,
    required this.time,
    required this.actions,
    this.trigger,
    this.badges = const [],
  });
  final String time, actions;
  final String? trigger;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final callout = t.scale(RaftTypeScale.callout, color: ui.foreground);
    return LayoutBuilder(
      builder: (context, box) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        // ds-allow: Web `gap-2`
        spacing: 8,
        // A row that does not fit reflows onto a second line instead of
        // clipping (the Web row clips its tail).
        // ds-allow: Web `gap-2`
        runSpacing: 2,
        children: [
          RaftCssText(
            time,
            maxLines: 1,
            softWrap: false,
            style: t.scale(
              RaftTypeScale.monoMeta,
              mono: true,
              color: ui.foregroundHint,
            ),
          ),
          if (trigger != null)
            ConstrainedBox(
              // Web `max-w-[45%]`.
              constraints: BoxConstraints(maxWidth: box.maxWidth * .45),
              child: RaftCssText(
                trigger!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: callout,
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth),
            child: RaftCssText(
              actions,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: callout.copyWith(color: ui.foregroundMuted),
            ),
          ),
          ...badges,
        ],
      ),
    );
  }
}
