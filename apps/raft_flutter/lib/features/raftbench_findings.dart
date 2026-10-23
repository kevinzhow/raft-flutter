// The run and findings block of the conversation-insights panel (Web
// HostedAnalysis.tsx): window, status, failure or partial reasons, accepted
// findings with evidence references that open the source message, paging.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raftbench_hosted_controller.dart';
import '../data/raftbench_models.dart';
import 'raftbench_parts.dart';

const _statusText = {
  'stale': 'A source message changed or was deleted. The old result is hidden; the service will analyze refreshed material.',
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
const _intentText = {
  'active': 'Actively pursued',
  'deliberately_paused': 'Deliberately paused',
  'unknown': 'Unknown',
};

/// Which option an evidence target names: Web matches the channel name
/// without its `#` against the target without its `#`, so a target carrying a
/// `:xxxxxxxx` disambiguator finds no source and stays unavailable.
RaftbenchOption? raftbenchEvidenceSource(
  List<RaftbenchOption> options,
  RaftbenchEvidenceRef ref,
) {
  if (ref.target.isEmpty) return null;
  final name = ref.target.substring(1);
  for (final option in options) {
    if (option.label.replaceFirst(RegExp(r'^#'), '') == name) return option;
  }
  return null;
}

class RaftbenchFindings extends StatelessWidget {
  const RaftbenchFindings({
    super.key,
    required this.controller,
    required this.onOpenMessage,
  });
  final RaftbenchHostedController controller;
  final void Function(String channelId, String messageId) onOpenMessage;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    final fmt = RaftbenchFormat(context);
    String tr(String s) => raftText(context, s);
    final c = controller, data = c.data!, run = c.run!;
    final report = run.report;
    final hint = ty.caption(color: ty.hint, weight: FontWeight.w400);
    final readCount = raftFormat(
      context,
      data.progress != null
          ? 'This batch: {count} messages read'
          : '{count} messages read',
      {'count': fmt.number(run.fetchedMessages)},
    );
    final statusKey = c.noMaterial
        ? 'No material in this window'
        : _statusText[run.status] ?? 'Unknown';
    final reason = report?.reason;
    final showReason = reason != null && reason != run.failureReason;
    Widget live(Widget child) => Semantics(liveRegion: true, child: child);
    return Column(
      key: ValueKey('raftbench-run-${run.runId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            Text(readCount, style: hint),
          ],
        ),
        if (!c.busy)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(tr(statusKey), style: ty.body(weight: FontWeight.w600)),
          ),
        if (run.failureReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: live(
              Text(run.failureReason!, style: ty.callout(color: ty.warning)),
            ),
          ),
        if (showReason)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              run.fetchedMessages == 0 && (data.progress?.readMessages ?? 0) > 0
                  ? tr(
                      'No new messages in this batch. Earlier accepted findings are kept.',
                    )
                  : reason,
              style: ty.callout(color: ty.warning),
            ),
          ),
        if (report != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(
                'Conversation evidence only. Tool outcomes and thread replies are not included. Suggestions need human review and never create or publish skills automatically.',
              ),
              style: hint,
            ),
          ),
          if (report.patterns.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                tr(
                  c.noMaterial
                      ? 'No messages were read in this window; nothing was analyzed. Try a channel with recent messages.'
                      : 'No supported pattern was returned in the material read. This does not mean all collaboration is healthy.',
                ),
                style: ty.callout(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final (index, pattern) in report.patterns.indexed)
                  _Finding(
                    key: ValueKey(
                      'raftbench-finding-${run.runId}-${c.page}-$index',
                    ),
                    pattern: pattern,
                    options: c.options,
                    onOpenMessage: onOpenMessage,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(
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
                        data.pagination.page <= 1 ||
                            data.pagination.page != c.page
                        ? null
                        : () => c.setPage(c.page - 1),
                  ),
                  Text(
                    raftFormat(
                      context,
                      'Page {page} of {total} · {count} findings',
                      {
                        'page': fmt.number(data.pagination.page),
                        'total': fmt.number(data.pagination.pageCount),
                        'count': data.pagination.total,
                      },
                    ),
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
            ),
          ),
        ],
      ],
    );
  }
}

class _Finding extends StatelessWidget {
  const _Finding({
    super.key,
    required this.pattern,
    required this.options,
    required this.onOpenMessage,
  });
  final RaftbenchPattern pattern;
  final List<RaftbenchOption> options;
  final void Function(String, String) onOpenMessage;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    String tr(String s) => raftText(context, s);
    final hint = ty.caption(color: ty.hint, weight: FontWeight.w400);
    final refs = [
      for (final ref in pattern.evidence) (ref, false),
      for (final ref in pattern.counterevidence) (ref, true),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: t.colors['line-hairline']!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(_kindText[pattern.kind] ?? 'Unknown'),
              style: ty.body(weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Text(pattern.explanation, style: ty.callout()),
          const SizedBox(height: 8),
          Text(
            tr(
              pattern.evidenceLevel == 'insufficient'
                  ? 'Evidence: insufficient to determine the outcome'
                  : 'Evidence: conversation only; actual task or tool outcome is unverified',
            ),
            style: hint,
          ),
          const SizedBox(height: 8),
          Text(
            raftFormat(context, 'Task intent: {intent}', {
              'intent': tr(_intentText[pattern.intent] ?? 'Unknown'),
            }),
            style: hint,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (ref, counter) in refs)
                () {
                  final source = raftbenchEvidenceSource(options, ref);
                  if (source == null) {
                    return Text(
                      tr('Source unavailable in this view'),
                      style: ty.caption(weight: FontWeight.w500),
                    );
                  }
                  return RaftbenchButton(
                    raftFormat(context, '{label} {target} · {message}', {
                      'label': tr(counter ? 'Counterevidence' : 'Evidence'),
                      'target': ref.target,
                      'message': ref.messageId.length > 8
                          ? ref.messageId.substring(0, 8)
                          : ref.messageId,
                    }),
                    small: true,
                    onPressed: () => onOpenMessage(source.value, ref.messageId),
                  );
                }(),
            ],
          ),
          if (pattern.counterevidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              raftFormat(context, '{count} counterexamples were considered', {
                'count': pattern.counterevidence.length,
              }),
              style: ty.caption(weight: FontWeight.w500),
            ),
          ],
          if (pattern.suggestion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.sidebar,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('Draft improvement or shared-skill proposal'),
                    style: ty.callout(weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(pattern.suggestion, style: ty.callout()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
