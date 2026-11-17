// The run and findings block of the "Patterns and improvements" panel (Web
// HostedAnalysis.tsx): window, status, failure or partial reasons, the
// findings (flat and paged, or grouped by kind) with their evidence chips and
// the Agree / Inaccurate votes.
import 'package:flutter/material.dart';

import '../../raft_ui.dart';

import 'raftbench_parts.dart';

const _statusText = {
  'stale':
      'A source message changed or was deleted. The old result is hidden; the service will analyze refreshed material.',
  'queued': 'Waiting for the analysis agent…',
  'running': 'Reading channel messages…',
  'ready': 'Analysis complete',
  'partial': 'Partial analysis — coverage is incomplete',
  'failed': 'Analysis did not finish',
};
const _kindText = {
  'repeated_clarification': 'Repeated clarification',
  'repeated_attempt': 'Repeated attempts',
  'unsupported_completion': 'Completion claim needs verification',
  'successful_practice': 'Practice worth reusing',
};

/// The label of a pattern kind, as an English catalog key.
String raftbenchKindLabel(String kind) => _kindText[kind] ?? 'Unknown';

/// Splits an evidence target (Web `parseEvidenceTarget`): `#channel` cites a
/// top-level message, `#channel:shortId` a reply in that message's thread.
({String channelName, String? threadShortId}) raftbenchParseEvidenceTarget(
  String target,
) {
  final parts = target.replaceFirst(RegExp(r'^#'), '').split(':');
  final short = parts.length > 1 ? parts[1] : '';
  return (
    channelName: parts.first,
    threadShortId: short.isEmpty ? null : short,
  );
}

/// Which option an evidence target names: Web matches the channel name
/// (without `#` and without a `:shortId`) against the option labels.
RaftbenchOption? raftbenchEvidenceSource(
  List<RaftbenchOption> options,
  RaftbenchEvidenceRef ref,
) {
  final name = raftbenchParseEvidenceTarget(ref.target).channelName;
  for (final option in options) {
    if (option.label.replaceFirst(RegExp(r'^#'), '') == name) return option;
  }
  return null;
}

class RaftbenchFindings extends StatelessWidget {
  const RaftbenchFindings({
    super.key,
    required this.controller,
    required this.onOpenEvidence,
  });
  final RaftbenchHostedPanel controller;
  final RaftbenchOpenEvidence onOpenEvidence;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    final fmt = RaftbenchFormat(context);
    String tr(String s) => raftText(context, s);
    final c = controller, data = c.data!, run = c.run!;
    final report = run.report;
    final hint = ty.caption(color: ty.hint, weight: FontWeight.w400);
    final groups = c.groups;
    final progressive = data.progress != null;
    final emptyPoll =
        progressive && run.fetchedMessages == 0 && run.failureReason == null;
    final statusKey = c.noMaterial
        ? 'No material in this window'
        : _statusText[run.status] ?? 'Unknown';
    final reason = report?.reason;
    final showReason = reason != null && reason != run.failureReason;
    Widget live(Widget child) => Semantics(liveRegion: true, child: child);
    Widget at(double top, Widget child) => Padding(
      padding: EdgeInsets.only(top: top),
      child: child,
    );
    return Column(
      key: ValueKey('raftbench-run-${run.runId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!progressive)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                raftFormat(context, '{from} – {to}', {
                  'from': fmt.stamp(run.from),
                  'to': fmt.stamp(run.to),
                }),
                style: hint,
              ),
              Text(
                raftFormat(context, '{count} messages read', {
                  'count': fmt.number(run.fetchedMessages),
                }),
                style: hint,
              ),
            ],
          ),
        if (!c.busy &&
            !emptyPoll &&
            !(progressive && run.status == 'partial') &&
            (c.noMaterial || run.status != 'ready'))
          at(12, Text(tr(statusKey), style: ty.body(weight: FontWeight.w600))),
        if (run.failureReason != null)
          at(
            8,
            live(
              Text(run.failureReason!, style: ty.callout(color: ty.warning)),
            ),
          ),
        if (showReason && !emptyPoll)
          at(8, Text(reason, style: ty.callout(color: ty.warning))),
        if (report != null) ...[
          if (report.patterns.isEmpty && (groups == null || groups.isEmpty))
            at(
              16,
              Text(
                tr(
                  c.noMaterial
                      ? 'No messages were read in this window; nothing was analyzed. Try a channel with recent messages.'
                      : 'No findings in this view. Check History and data coverage; this does not mean there are no problems.',
                ),
                style: ty.callout(),
              ),
            ),
          if (c.feedbackError)
            at(
              12,
              live(
                Text(
                  tr('Feedback was not saved. Refresh and try again.'),
                  style: ty.body(color: ty.danger),
                ),
              ),
            ),
          if (c.groupsUnavailable)
            at(
              12,
              live(
                Text(
                  tr(
                    'Grouping by type is unavailable right now. Showing all findings by date; the total and pages below are complete.',
                  ),
                  style: hint,
                ),
              ),
            ),
          at(12, groups != null ? _groups(context, groups) : _flat(context)),
          at(
            12,
            Text(
              tr(
                'Based on the selected channels and the thread replies you can read. Task conversations and tool results are not read yet, and very long messages are cut short. Suggestions are for you to review — nothing changes automatically.',
              ),
              style: hint,
            ),
          ),
          if (groups == null) at(16, _pages(context, ty, fmt)),
        ],
      ],
    );
  }

  Widget _flat(BuildContext context) {
    final c = controller, run = c.run!, feedback = c.data!.findingFeedback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final (index, pattern) in run.report!.patterns.indexed)
          _Finding(
            key: ValueKey('raftbench-finding-${run.runId}-${c.page}-$index'),
            pattern: pattern,
            feedback: index < feedback.length ? feedback[index] : null,
            grouped: false,
            controller: c,
            onOpenEvidence: onOpenEvidence,
          ),
      ],
    );
  }

  Widget _groups(BuildContext context, Map<String, RaftbenchGroup> groups) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final c = controller;
    return Column(
      key: const ValueKey('raftbench-finding-groups'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        for (final kind in raftbenchPatternKinds)
          if (groups[kind] case final group? when group.patterns.isNotEmpty)
            Column(
              key: ValueKey('raftbench-group-$kind'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          tr(raftbenchKindLabel(kind)),
                          style: ty.body(weight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fmt.number(group.total),
                        style: ty.callout(color: ty.hint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    for (final (index, pattern) in group.patterns.indexed)
                      _Finding(
                        key: ValueKey('raftbench-finding-$kind-$index'),
                        pattern: pattern,
                        feedback: index < group.feedback.length
                            ? group.feedback[index]
                            : null,
                        grouped: true,
                        controller: c,
                        onOpenEvidence: onOpenEvidence,
                      ),
                  ],
                ),
                if (group.patterns.length < group.total)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RaftbenchButton(
                        raftFormat(context, 'Show {count} more', {
                          'count': fmt.number(
                            group.total - group.patterns.length,
                          ),
                        }),
                        variant: RaftButtonRecipeVariant.ghost,
                        onPressed: () => c.expandGroup(kind),
                      ),
                    ),
                  ),
              ],
            ),
      ],
    );
  }

  Widget _pages(BuildContext context, RaftbenchType ty, RaftbenchFormat fmt) {
    String tr(String s) => raftText(context, s);
    final c = controller, data = c.data!;
    return Semantics(
      container: true,
      label: tr('Analysis result pages'),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          RaftbenchButton(
            tr('Previous page'),
            onPressed:
                data.pagination.page <= 1 || data.pagination.page != c.page
                ? null
                : () => c.setPage(c.page - 1),
          ),
          Text(
            raftFormat(context, 'Page {page} of {total} · {count} findings', {
              'page': fmt.number(data.pagination.page),
              'total': fmt.number(data.pagination.pageCount),
              'count': data.pagination.total,
            }),
            style: ty.callout(),
          ),
          RaftbenchButton(
            tr('Next page'),
            onPressed:
                data.pagination.page >= data.pagination.pageCount ||
                    data.pagination.page != c.page
                ? null
                : () => c.setPage(c.page + 1),
          ),
        ],
      ),
    );
  }
}

class _Finding extends StatelessWidget {
  const _Finding({
    super.key,
    required this.pattern,
    required this.feedback,
    required this.grouped,
    required this.controller,
    required this.onOpenEvidence,
  });
  final RaftbenchPattern pattern;
  final RaftbenchFeedback? feedback;

  /// Inside a kind group the kind heading is the group's.
  final bool grouped;
  final RaftbenchHostedPanel controller;
  final RaftbenchOpenEvidence onOpenEvidence;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final hint = ty.caption(color: ty.hint, weight: FontWeight.w400);
    final c = controller;
    final at = feedback?.evidenceAt;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: t.colors['line-hairline']!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!grouped)
            Semantics(
              header: true,
              child: Text(
                tr(raftbenchKindLabel(pattern.kind)),
                style: ty.body(weight: FontWeight.w600),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: grouped ? 0 : 4),
            child: Text(
              raftFormat(context, 'Latest evidence: {time}', {
                'time': at != null ? fmt.stamp(at) : tr('Unknown'),
              }),
              style: hint,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(pattern.explanation, style: ty.callout()),
          ),
          if (pattern.evidenceLevel == 'insufficient')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr('Evidence: insufficient to determine the outcome'),
                style: hint,
              ),
            ),
          for (final counter in const [false, true])
            if ((counter ? pattern.counterevidence : pattern.evidence)
                case final refs when refs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tr(counter ? 'Counterevidence' : 'Evidence'),
                      style: hint,
                    ),
                    for (final ref in refs)
                      _EvidenceChip(
                        key: ValueKey(
                          'raftbench-evidence-$counter-${ref.target}-${ref.messageId}',
                        ),
                        ref: ref,
                        channelId: raftbenchEvidenceSource(
                          c.options,
                          ref,
                        )?.value,
                        onOpen: onOpenEvidence,
                      ),
                  ],
                ),
              ),
          if (pattern.suggestion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.sidebar,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('Suggestion'),
                      style: ty.callout(weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(pattern.suggestion, style: ty.callout()),
                  ],
                ),
              ),
            ),
          if (feedback case final f?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final vote in const ['agree', 'inaccurate'])
                    RaftbenchButton(
                      tr(vote == 'agree' ? 'Agree' : 'Inaccurate'),
                      variant: RaftButtonRecipeVariant.ghost,
                      toggled: f.value == vote,
                      onPressed: c.feedbackSaving != null
                          ? null
                          : () => c.reviewFinding(f, vote),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A cited message (Web `EvidenceChip`): a link chip that opens the message in
/// the thread panel, or a static muted chip with a tooltip when the source is
/// not among the readable channels or no longer resolves.
class _EvidenceChip extends StatefulWidget {
  const _EvidenceChip({
    super.key,
    required this.ref,
    required this.channelId,
    required this.onOpen,
  });
  final RaftbenchEvidenceRef ref;
  final String? channelId;
  final RaftbenchOpenEvidence onOpen;

  @override
  State<_EvidenceChip> createState() => _EvidenceChipState();
}

class _EvidenceChipState extends State<_EvidenceChip> {
  bool unavailable = false;

  Future<void> _open() async {
    final channel = widget.channelId;
    if (channel == null) return;
    final ok = await widget.onOpen(
      channel,
      widget.ref.target,
      widget.ref.messageId,
    );
    if (!ok && mounted) setState(() => unavailable = true);
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.ref;
    final short = ref.messageId.length > 8
        ? ref.messageId.substring(0, 8)
        : ref.messageId;
    final label = '${ref.target} $short';
    if (widget.channelId == null || unavailable) {
      return RaftTooltip(
        message: raftText(context, 'Source unavailable in this view'),
        child: RaftReferenceChip(
          label: label,
          appearance: const RaftReferenceAppearance(
            RaftReferenceKind.attachmentComment,
          ),
        ),
      );
    }
    return Semantics(
      link: true,
      label: label,
      onTap: _open,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _open,
            child: RaftReferenceChip(
              label: label,
              appearance: const RaftReferenceAppearance(
                RaftReferenceKind.thread,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
