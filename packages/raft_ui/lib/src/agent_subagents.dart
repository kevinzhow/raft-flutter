// Web v1.24 components/agent/AgentActivityLog.tsx, the Subagents view of the
// Activity tab: the state chip, the Running / Ended list of subagent rows and
// the detail head with its description list. Presentation only: the host folds
// the activity into groups and owns the stop command.
import 'package:flutter/material.dart';

import 'icons.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/badge.dart' show RaftBadge;
import 'raft/button.dart' show RaftButton;
import 'raft/list_row.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'recipes/badge.g.dart'
    show RaftBadgeRecipeAppearance, RaftBadgeRecipeVariant;
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'space.dart';
import 'system_inset.dart' show raftScrollPadding;
import 'theme.dart';
import 'tokens/tokens.dart';

/// `SUBAGENT_STATE_CHIP`: the badge family and the light of a subagent state.
enum RaftSubagentChipTone { busy, success, warning, muted }

/// The light inside the chip: the presence lights, and the task Done colour.
enum RaftSubagentChipLight { busy, error, offline, done }

/// `SubagentStateChip`: a soft Badge with a presence light and its word, on the
/// soft tint of the light's family. A failure or a limit is the error light
/// (warning family), a stop or an end the offline one.
class RaftSubagentStateChip extends StatelessWidget {
  const RaftSubagentStateChip({
    super.key,
    required this.label,
    required this.tone,
    required this.light,
  });
  final String label;
  final RaftSubagentChipTone tone;
  final RaftSubagentChipLight light;

  @override
  Widget build(BuildContext context) => RaftBadge(
    label: label,
    appearance: RaftBadgeRecipeAppearance.soft,
    // The Working chip has its own wash (`fill`); the variant only names the
    // family (as the agent status chip does).
    fill: tone == RaftSubagentChipTone.busy
        ? RaftTokens.of(context).ui['presence-busy-soft']
        : null,
    variant: switch (tone) {
      RaftSubagentChipTone.busy => RaftBadgeRecipeVariant.accent,
      RaftSubagentChipTone.success => RaftBadgeRecipeVariant.success,
      RaftSubagentChipTone.warning => RaftBadgeRecipeVariant.warning,
      RaftSubagentChipTone.muted => RaftBadgeRecipeVariant.muted,
    },
    leading: switch (light) {
      RaftSubagentChipLight.busy => const RaftStatus(
        presence: RaftPresence.busy,
      ),
      RaftSubagentChipLight.error => const RaftStatus(
        presence: RaftPresence.error,
      ),
      RaftSubagentChipLight.offline => const RaftStatus(
        presence: RaftPresence.offline,
      ),
      RaftSubagentChipLight.done => const RaftStatus(
        variant: RaftStatusVariant.success,
      ),
    },
  );
}

/// One row of the list (`SubagentRow`).
class RaftSubagentRowData {
  const RaftSubagentRowData({
    required this.id,
    required this.title,
    required this.time,
    required this.facts,
    required this.chip,
  });

  /// The group's key; [RaftSubagentsList.onOpen] gets it back.
  final String id;
  final String title, time, facts;
  final Widget chip;
}

/// `SubagentsList`: Running then Ended, each a heading with its count over a
/// group of rows, and the "recent activity only" caption under them.
class RaftSubagentsList extends StatelessWidget {
  const RaftSubagentsList({
    super.key,
    required this.running,
    required this.ended,
    required this.runningLabel,
    required this.endedLabel,
    required this.footer,
    required this.onOpen,
  });
  final List<RaftSubagentRowData> running, ended;
  final String runningLabel, endedLabel, footer;
  final ValueChanged<String> onOpen;

  Widget _heading(
    BuildContext context,
    String label,
    int count, {
    required bool busy,
  }) {
    final t = RaftTokens.of(context);
    return Padding(
      // `px-1 pb-1.5 pt-3`
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        spacing: 8,
        children: [
          RaftStatus(presence: busy ? RaftPresence.busy : RaftPresence.offline),
          RaftCssText(
            label,
            style: t.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w700,
              color: t.ui.foregroundMuted,
            ),
          ),
          RaftCssText(
            '$count',
            style: t.scale(
              RaftTypeScale.monoMeta,
              mono: true,
              color: t.ui.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(List<RaftSubagentRowData> rows) => RaftListRowGroup(
    children: [
      for (final row in rows)
        RaftListRow(
          key: ValueKey('subagent-row-${row.id}'),
          onPressed: () => onOpen(row.id),
          children: [
            const RaftListRowIcon(RaftGlyph.bot),
            RaftListRowBody(
              children: [
                RaftListRowTop(
                  children: [
                    RaftListRowTitle(row.title),
                    RaftListRowMeta(row.time),
                  ],
                ),
                RaftListRowBottom(
                  children: [RaftListRowDescription(row.facts), row.chip],
                ),
              ],
            ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ListView(
      key: const ValueKey('subagents-list'),
      padding: raftScrollPadding(
        context,
        const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      children: [
        if (running.isNotEmpty) ...[
          _heading(context, runningLabel, running.length, busy: true),
          _group(running),
        ],
        if (ended.isNotEmpty) ...[
          _heading(context, endedLabel, ended.length, busy: false),
          _group(ended),
        ],
        Padding(
          // `block px-1 pt-3`
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: RaftCssText(
            footer,
            style: t.scale(
              RaftTypeScale.caption,
              weight: FontWeight.w400,
              color: t.ui.foregroundMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// `SubagentDetail` head: the back button, the title (at most two lines), the
/// state chip and, for a running subagent the viewer may stop, Stop.
class RaftSubagentDetailHead extends StatelessWidget {
  const RaftSubagentDetailHead({
    super.key,
    required this.title,
    required this.chip,
    required this.backLabel,
    required this.onBack,
    this.stopLabel,
    this.onStop,
  });
  final String title, backLabel;
  final Widget chip;
  final VoidCallback onBack;
  final String? stopLabel;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.ui.lineSeam)),
      ),
      child: Padding(
        // `px-(--surface-inset) py-3 max-md:px-4`
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            RaftButton(
              key: const ValueKey('subagent-back'),
              glyph: RaftGlyph.arrowLeft,
              tooltip: backLabel,
              semanticLabel: backLabel,
              tone: RaftButtonRecipeVariant.ghost,
              size: RaftButtonRecipeSize.iconMd,
              onPressed: onBack,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Semantics(
                    header: true,
                    child: RaftCssText(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.scale(
                        RaftTypeScale.headline,
                        weight: FontWeight.w600,
                        color: t.ui.foreground,
                      ),
                    ),
                  ),
                  chip,
                ],
              ),
            ),
            if (stopLabel != null && onStop != null)
              RaftButton(
                key: const ValueKey('subagent-stop'),
                label: stopLabel!,
                tone: RaftButtonRecipeVariant.outline,
                size: RaftButtonRecipeSize.md,
                onPressed: onStop,
              ),
          ],
        ),
      ),
    );
  }
}

/// One term and its details of a [RaftDescriptionList]. [detailsChild]
/// replaces the [details] text (a spinner, a badge); [details] still names it
/// for assistive technology.
class RaftDescriptionEntry {
  const RaftDescriptionEntry(
    this.term,
    this.details, {
    this.detailsChild,
    this.termChild,
    this.key,
  });
  final String term, details;
  final Widget? detailsChild, termChild;
  final Key? key;
}

/// raft-ui `DescriptionList`: `horizontal` is a two-column grid, the terms
/// (footnote, medium, hint) at least 88px wide and at most 160px, 16px before
/// the details (callout, at least 32px tall), 2px between the rows; `inline`
/// wraps term-and-details pairs side by side, 24px apart across and 8px
/// between lines, 12px between a term and its details.
class RaftDescriptionList extends StatelessWidget {
  const RaftDescriptionList({
    super.key,
    required this.entries,
    this.inline = false,
    this.stacked = false,
    this.rowGap = 2,
  });
  final List<RaftDescriptionEntry> entries;
  final bool inline, stacked;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final term = t.scale(
      RaftTypeScale.footnote,
      weight: FontWeight.w500,
      color: t.ui.foregroundHint,
    );
    final details = t.scale(
      RaftTypeScale.callout,
      weight: FontWeight.w400,
      color: t.ui.foreground,
    );
    Widget detailsOf(RaftDescriptionEntry e) =>
        e.detailsChild ?? RaftCssText(e.details, style: details);
    if (inline) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 8,
        children: [
          for (final e in entries)
            ConstrainedBox(
              key: e.key,
              constraints: const BoxConstraints(maxWidth: 384),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  e.termChild ?? RaftCssText(e.term, style: term),
                  const SizedBox(width: 12),
                  Flexible(child: detailsOf(e)),
                ],
              ),
            ),
        ],
      );
    }
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: rowGap + RaftSpace.x2,
        children: [
          for (final entry in entries)
            Column(
              key: entry.key,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: rowGap,
              children: [
                entry.termChild ?? RaftCssText(entry.term, style: term),
                detailsOf(entry),
              ],
            ),
        ],
      );
    }
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        for (var i = 0; i < entries.length; i++)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 16, top: i == 0 ? 0 : rowGap),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 88,
                    maxWidth: 160,
                  ),
                  child:
                      entries[i].termChild ??
                      RaftCssText(entries[i].term, style: term),
                ),
              ),
              KeyedSubtree(
                key: entries[i].key,
                child: Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : rowGap),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: detailsOf(entries[i]),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The facts band under the detail head (`border-b border-line-seam px-… py-3`).
class RaftSubagentFacts extends StatelessWidget {
  const RaftSubagentFacts({super.key, required this.entries});
  final List<RaftDescriptionEntry> entries;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: RaftTokens.of(context).ui.lineSeam),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: RaftDescriptionList(entries: entries),
    ),
  );
}
