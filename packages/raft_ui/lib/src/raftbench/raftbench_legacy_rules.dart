// The collapsed "Legacy phrase and repetition rules" section (Web RaftBenchPage
// `raftbench-legacy-rules`): manual phrase matching over the latest messages
// of the chosen scope, a review queue with evidence and nearby context.
import 'package:flutter/material.dart';

import '../../raft_ui.dart';

import 'raftbench_parts.dart';

String _label(RaftbenchSignal kind) => switch (kind) {
  RaftbenchSignal.frustration => 'Human frustration',
  RaftbenchSignal.negative => 'Negative sentiment',
  RaftbenchSignal.repetition => 'Repeated agent messages',
};
String _rule(RaftbenchSignal kind) => switch (kind) {
  RaftbenchSignal.frustration => 'Explicit English/Chinese frustration phrase. Quotations, negation and sarcasm can be misread; inspect the context.',
  RaftbenchSignal.negative => 'Negative wording in a human message. This is a review cue, not proof of failure.',
  RaftbenchSignal.repetition => 'Identical text after case/whitespace normalization, at least 16 characters, from the same agent in the same channel within 15 minutes. Legitimate reminders can match.',
};
String _reviewLabel(RaftbenchReview status) => switch (status) {
  RaftbenchReview.needsReview => 'Needs review',
  RaftbenchReview.confirmed => 'Confirmed',
  RaftbenchReview.dismissed => 'Dismissed',
};

class RaftbenchLegacyRules extends StatelessWidget {
  const RaftbenchLegacyRules({
    super.key,
    required this.controller,
    required this.channelName,
    required this.onOpenMessage,
  });
  final RaftbenchRulesPanel controller;

  /// The scope shown in the coverage line (the workspace overview or a channel).
  final String channelName;
  final void Function(String channelId, String messageId) onOpenMessage;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _Rules(
      controller: controller,
      channelName: channelName,
      onOpenMessage: onOpenMessage,
    ),
  );
}

class _Rules extends StatelessWidget {
  const _Rules({
    required this.controller,
    required this.channelName,
    required this.onOpenMessage,
  });
  final RaftbenchRulesPanel controller;
  final String channelName;
  final void Function(String, String) onOpenMessage;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    final c = controller;
    String tr(String s) => raftText(context, s);
    final snapshot = c.snapshot;
    final hint = ty.caption(color: ty.hint, weight: FontWeight.w400);
    return RaftbenchDetails(
      key: const ValueKey('raftbench-legacy-rules'),
      summaryStyle: ty.callout(weight: FontWeight.w600),
      summaryBox: BoxDecoration(
        border: Border.all(color: t.colors['line-hairline']!),
        borderRadius: BorderRadius.circular(10),
      ),
      summary: Text(tr('Legacy phrase and repetition rules')),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            RaftbenchCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(
                      'Manual phrase matching only, without AI interpretation. Positive and negative counts are wording matches; unscored does not mean neutral. The same messages and rules produce the same counts.',
                    ),
                    style: hint,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      RaftbenchButton(
                        tr(
                          c.loading
                              ? 'Reading selected scope…'
                              : snapshot != null
                              ? 'Refresh phrase scan'
                              : 'Scan phrases and repeats',
                        ),
                        small: true,
                        onPressed: c.canScan ? c.analyze : null,
                      ),
                      Text(
                        tr(
                          'Pilot results stay inside staging. Export is unavailable.',
                        ),
                        style: hint,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (c.failed)
              RaftbenchCard(
                color: t.colors['warning-soft'],
                transparentBorder: true,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    tr(
                      'Could not read the requested scope. Check your access and retry. Previous evidence has been cleared.',
                    ),
                    style: ty.callout(),
                  ),
                ),
              ),
            if (snapshot == null && !c.failed && !c.loading)
              RaftbenchCard(
                child: Text(
                  tr(
                    'Start a workspace overview, or choose a channel. Messages are read only when you start.',
                  ),
                  style: ty.callout(color: t.muted),
                ),
              ),
            if (snapshot != null) ..._results(context, t, ty, hint, snapshot),
            Text(
              raftFormat(
                context,
                'Rule version: {version}. Exact repetition and phrase rules only; semantic loops and indirect frustration may be missed.',
                {'version': raftbenchRuleVersion},
              ),
              style: hint,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
    RaftbenchOverviewSnapshot snapshot,
  ) {
    final c = controller;
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final evaluation = c.evaluation;
    final wide = raftBreakpointWidth(context) >= 1024;
    final warning = t.colors['warning-soft'];
    final options = c.options;
    String channelLabel(String id) =>
        options.where((o) => o.value == id).firstOrNull?.label ?? id;
    final unjoined = options.where((o) => o.unjoinedPublic).toList();
    final stats = [
      RaftbenchCard(
        color: warning,
        transparentBorder: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Review cues'), style: ty.caption(weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '${evaluation.findings.length}',
              key: const ValueKey('raftbench-cue-count'),
              style: ty.title(),
            ),
            const SizedBox(height: 4),
            Text(
              raftFormat(context, '{count} awaiting review', {
                'count': c.pendingCount,
              }),
              style: ty.caption(color: t.muted),
            ),
          ],
        ),
      ),
      RaftbenchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Messages observed'),
              style: ty.caption(color: t.muted, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('${snapshot.messages.length}', style: ty.title()),
          ],
        ),
      ),
      RaftbenchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Human wording'),
              style: ty.caption(color: t.muted, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              raftFormat(
                context,
                '{positive} positive · {negative} negative · {mixed} mixed · {unscored} unscored',
                {
                  'positive': evaluation.sentiment.positive,
                  'negative': evaluation.sentiment.negative,
                  'mixed': evaluation.sentiment.mixed,
                  'unscored': evaluation.sentiment.unscored,
                },
              ),
              style: ty.callout(),
            ),
          ],
        ),
      ),
    ];
    return [
      LayoutBuilder(
        builder: (context, box) {
          final columns = wide ? 3 : 2;
          final width = (box.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: width, child: stats[0]),
              SizedBox(width: width, child: stats[1]),
              SizedBox(width: wide ? width : box.maxWidth, child: stats[2]),
            ],
          );
        },
      ),
      RaftbenchCard(
        child: RaftbenchDetails(
          summaryStyle: ty.footnote(weight: FontWeight.w600),
          summary: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(tr('Coverage & limitations')),
          ),
          child: DefaultTextStyle.merge(
            style: ty.caption(color: t.muted, weight: FontWeight.w400),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    '$channelName · ${raftFormat(context, 'Snapshot of {count} messages · {time}', {'count': snapshot.messages.length, 'time': fmt.timeSeconds(snapshot.fetchedAt)})}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
                  ),
                  Text(
                    '${tr('Each scanned channel covers up to its latest 200 top-level messages. Older history and thread replies are not included.')}${snapshot.historyLimited ? ' ${tr('The server also applied a plan-based history limit.')}' : ' '}',
                  ),
                  Text(
                    raftFormat(
                      context,
                      '{read} of {requested} requested channels read · {visible} visible channels in this workspace',
                      {
                        'read': snapshot.channels.length,
                        'requested': snapshot.requestedChannels,
                        'visible': options.length,
                      },
                    ),
                  ),
                  Text(
                    raftFormat(
                      context,
                      'Public channels not joined: {available} available; {read} read in this snapshot. Scope includes accessible public/joint channels and joined private channels.',
                      {
                        'available': unjoined.length,
                        'read': snapshot.channels
                            .where(
                              (ch) =>
                                  unjoined.any((o) => o.value == ch.channelId),
                            )
                            .length,
                      },
                    ),
                  ),
                  if (c.channelId == raftbenchWorkspaceScope &&
                      options.length > raftbenchOverviewChannelLimit)
                    Text(
                      raftFormat(
                        context,
                        'Bounded overview: up to {limit} visible channels. {omitted} other channels are not scanned; choose one directly to inspect it.',
                        {
                          'limit': raftbenchOverviewChannelLimit,
                          'omitted':
                              options.length - raftbenchOverviewChannelLimit,
                        },
                      ),
                    ),
                  if (snapshot.unavailableChannelIds.isNotEmpty)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        raftFormat(
                          context,
                          '{count} channels could not be read and contribute no evidence or signal counts. This overview is partial.',
                          {'count': snapshot.unavailableChannelIds.length},
                        ),
                      ),
                    ),
                  Text(
                    tr(
                      'Tool execution outcomes are unavailable in channel history; tool failure loops are not assessed.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      RaftbenchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Semantics(
                  header: true,
                  child: Text(tr('Channel breakdown'), style: ty.headline()),
                ),
                RaftbenchButton(
                  tr('All scanned channels'),
                  small: true,
                  variant: RaftButtonRecipeVariant.ghost,
                  onPressed: c.clearDrill,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final channel in snapshot.channels)
                  RaftbenchButton(
                    '${channelLabel(channel.channelId)} · ${raftFormat(context, '{count} cues', {'count': evaluation.findings.where((f) => f.evidence.first.channelId == channel.channelId).length})}',
                    small: true,
                    variant: c.drillChannelId == channel.channelId
                        ? RaftButtonRecipeVariant.information
                        : RaftButtonRecipeVariant.outline,
                    onPressed: () => c.drillTo(channel.channelId),
                  ),
              ],
            ),
          ],
        ),
      ),
      _queueAndEvidence(context, t, ty, hint, wide, channelLabel),
    ];
  }

  Widget _queueAndEvidence(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
    bool twoColumns,
    String Function(String) channelLabel,
  ) {
    final c = controller;
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final findings = c.findings;
    final finding = c.finding, review = c.review;
    final queue = RaftbenchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Semantics(
            header: true,
            child: Text(tr('Review queue'), style: ty.headline()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in <RaftbenchSignal?>[
                null,
                ...RaftbenchSignal.values,
              ])
                RaftbenchButton(
                  tr(kind == null ? 'All signals' : _label(kind)),
                  small: true,
                  variant: c.filter == kind
                      ? RaftButtonRecipeVariant.information
                      : RaftButtonRecipeVariant.outline,
                  onPressed: () => c.setFilter(kind),
                ),
            ],
          ),
          RaftbenchDetails(
            summaryStyle: ty.footnote(weight: FontWeight.w600, color: t.muted),
            summary: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(tr('Detection settings')),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Minimum repeats (2–20)'),
                    style: ty.footnote(weight: FontWeight.w600, color: t.muted),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 96,
                    child: RaftTextInput(
                      key: ValueKey('raftbench-minimum-${c.minimum}'),
                      initialValue: '${c.minimum}',
                      keyboardType: TextInputType.number,
                      semanticLabel: tr('Minimum repeats (2–20)'),
                      onChanged: c.changeMinimum,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: t.colors['line-hairline']),
          Text(
            raftFormat(context, '{count} cues', {'count': findings.length}),
            style: hint,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: twoColumns ? 512 : 256),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final f in findings)
                    _FindingRow(
                      finding: f,
                      selected: finding?.id == f.id,
                      label: tr(_label(f.kind)),
                      detail:
                          '${channelLabel(f.evidence.first.channelId)} · ${f.evidence.first.senderName ?? f.evidence.first.senderId} · ${fmt.time(DateTime.tryParse(f.evidence.first.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0))} · ${tr(_reviewLabel(c.reviews[f.id]?.status ?? RaftbenchReview.needsReview))}',
                      onTap: () => c.chooseFinding(f.id),
                    ),
                ],
              ),
            ),
          ),
          if (findings.isEmpty)
            Text(
              tr(
                'No matching cues in this window. This does not establish that the agent succeeded.',
              ),
              style: ty.callout(color: t.muted),
            ),
        ],
      ),
    );
    final evidence = RaftbenchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr('Evidence and nearby context'),
              style: ty.headline(),
            ),
          ),
          if (finding != null && review != null)
            ..._evidence(context, t, ty, hint, finding, review, fmt)
          else
            Text(
              tr('Select a cue to inspect its original messages.'),
              style: ty.callout(color: t.muted),
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [queue, evidence],
          );
        }
        final width = (box.maxWidth - 16) / 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            SizedBox(width: width, child: queue),
            SizedBox(width: width, child: evidence),
          ],
        );
      },
    );
  }

  List<Widget> _evidence(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
    RaftbenchFinding finding,
    RaftbenchCueReview review,
    RaftbenchFormat fmt,
  ) {
    final c = controller;
    String tr(String s) => raftText(context, s);
    final ids = c.evidenceIds;
    final tone = switch (finding.kind) {
      RaftbenchSignal.frustration => t.colors['warning-soft']!,
      RaftbenchSignal.negative => t.colors['danger-soft']!,
      RaftbenchSignal.repetition => t.colors['info-soft']!,
    };
    final badge = switch (finding.kind) {
      RaftbenchSignal.frustration => RaftBadgeRecipeVariant.warning,
      RaftbenchSignal.negative => RaftBadgeRecipeVariant.danger,
      RaftbenchSignal.repetition => RaftBadgeRecipeVariant.information,
    };
    final line = Container(height: 1, color: t.colors['line-hairline']);
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: RaftBadge(
          label: tr(_label(finding.kind)),
          appearance: RaftBadgeRecipeAppearance.soft,
          variant: badge,
        ),
      ),
      Text(tr(_rule(finding.kind)), style: ty.callout(color: t.muted)),
      line,
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              for (final m in c.evidence)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ids.contains(m.id) ? tone : t.colors['fill-muted'],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            m.senderName ?? m.senderId,
                            style: ty.footnote(weight: FontWeight.w700),
                          ),
                          Text(() {
                            final at = DateTime.tryParse(m.createdAt);
                            return at == null
                                ? m.createdAt
                                : '${fmt.date(at)} ${fmt.time(at)}';
                          }(), style: ty.monoMeta()),
                          RaftBadge(
                            label: tr(
                              ids.contains(m.id) ? 'Matched' : 'Nearby context',
                            ),
                            appearance: RaftBadgeRecipeAppearance.outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(m.content, style: ty.callout(color: t.ink)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RaftbenchButton(
                          tr('Open original message'),
                          small: true,
                          variant: RaftButtonRecipeVariant.ghost,
                          onPressed: () => onOpenMessage(m.channelId, m.id),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      line,
      Text(
        tr('Reviewer note'),
        style: ty.footnote(weight: FontWeight.w600, color: t.muted),
      ),
      RaftTextarea(
        key: ValueKey('raftbench-note-${finding.id}'),
        initialValue: review.note,
        semanticLabel: tr('Reviewer note'),
        onChanged: c.setNote,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          RaftbenchButton(
            tr('Confirm signal'),
            small: true,
            onPressed: c.confirm,
          ),
          RaftbenchButton(
            tr('Mark as false positive'),
            small: true,
            variant: RaftButtonRecipeVariant.outline,
            onPressed: c.dismiss,
          ),
          RaftbenchButton(
            tr('Reopen'),
            small: true,
            variant: RaftButtonRecipeVariant.ghost,
            onPressed: c.reopen,
          ),
        ],
      ),
      Text(
        tr(
          'Review labels last until you refresh or leave this page; export to save them. No messages or labels are sent to another service.',
        ),
        style: hint,
      ),
    ];
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({
    required this.finding,
    required this.selected,
    required this.label,
    required this.detail,
    required this.onTap,
  });
  final RaftbenchFinding finding;
  final bool selected;
  final String label, detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    final tone = switch (finding.kind) {
      RaftbenchSignal.frustration => t.colors['warning']!,
      RaftbenchSignal.negative => t.colors['danger']!,
      RaftbenchSignal.repetition => t.colors['info']!,
    };
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('raftbench-finding-${finding.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? t.colors['info-soft'] : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: RaftStatusDot(color: tone, size: RaftStatusDotSize.sm),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label · ${finding.evidence.length}',
                        style: ty.callout(weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: ty.caption(color: t.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
