// The "What deserves attention" block of the panel (Web HostedAnalysis.tsx
// `findingIndex` section): the evidence period, how far the analysis has read,
// per-stream progress and retries, and the pattern kind filter with counts.
import 'package:flutter/material.dart';

import '../../raft_ui.dart';

import 'raftbench_findings.dart';
import 'raftbench_parts.dart';

/// `TriageLine`: "off" and "no_key" both mean nothing is being labeled, so
/// they read as not enabled rather than as progress.
class RaftbenchTriageLine extends StatelessWidget {
  const RaftbenchTriageLine({super.key, required this.triage});
  final RaftbenchTriage triage;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    final values = {
      'triaged': triage.triagedMessages,
      'labeled': triage.labeledMessages,
      'usage': triage.usage,
    };
    final (text, color) = switch (triage.state) {
      'off' || 'no_key' => ('Message labeling is not enabled.', ty.hint),
      'budget_exhausted' => (
        "Today's labeling budget is used up; it continues tomorrow. {triaged} labeled so far, {labeled} flagged.",
        ty.warning,
      ),
      'running' => (
        "Labeling messages: {triaged} labeled, {labeled} flagged · {usage}% of today's budget used",
        ty.hint,
      ),
      _ => (
        "Message labeling is up to date: {triaged} labeled, {labeled} flagged · {usage}% of today's budget used",
        ty.hint,
      ),
    };
    return Text(
      raftFormat(context, text, values),
      key: ValueKey('raftbench-triage-${triage.state}'),
      style: ty.caption(color: color, weight: FontWeight.w400),
    );
  }
}

class RaftbenchFindingIndex extends StatelessWidget {
  const RaftbenchFindingIndex({super.key, required this.controller});
  final RaftbenchHostedPanel controller;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final c = controller, data = c.data!, counts = data.kindCounts!;
    final hint = ty.caption(color: ty.hint, weight: FontWeight.w400);
    final channel = data.progress?.streamRead['channel'];
    final thread = data.progress?.streamRead['thread'];
    Widget at(double bottom, Widget child) => Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: child,
    );
    final scanned = data.progress?.scannedThroughAt;
    return Semantics(
      container: true,
      label: tr('What deserves attention'),
      child: Column(
        key: const ValueKey('raftbench-finding-index'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          at(
            12,
            Align(
              alignment: Alignment.centerLeft,
              child: RaftSegmentedControl<String>(
                label: tr('Evidence period'),
                value: c.period,
                onChanged: c.choosePeriod,
                items: [
                  for (final value in const ['recent', 'history'])
                    RaftSegmentedOption(
                      value: value,
                      label: tr(value == 'recent' ? 'Last 30 days' : 'History'),
                      itemKey: ValueKey('raftbench-period-$value'),
                    ),
                ],
              ),
            ),
          ),
          at(
            12,
            Text(
              raftFormat(context, 'Analyzed through {scanned}', {
                'scanned': scanned != null ? fmt.stamp(scanned) : tr('Unknown'),
              }),
              style: hint,
            ),
          ),
          if (channel != null && thread != null)
            at(
              12,
              Text(
                raftFormat(
                  context,
                  'Channel messages read: {channel} · Thread replies read: {thread}',
                  {
                    'channel': fmt.number(channel),
                    'thread': fmt.number(thread),
                  },
                ),
                key: const ValueKey('raftbench-stream-read'),
                style: hint,
              ),
            ),
          // Kept per stream even while the other stream runs, so a reply
          // failure stays visible after reading moves on to channels.
          for (final (stream, failures) in [
            for (final stream in const ['channel', 'thread'])
              (stream, c.run?.unreadFailures[stream] ?? 0),
          ])
            if (failures > 0)
              at(
                12,
                Text(
                  _retry(context, stream, failures),
                  key: ValueKey('raftbench-stream-retry-$stream'),
                  style: ty.caption(color: ty.warning, weight: FontWeight.w400),
                ),
              ),
          Semantics(
            header: true,
            child: Text(tr('What deserves attention'), style: ty.headline()),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftSegmentedControl<String>(
              label: tr('What deserves attention'),
              value: c.kind ?? 'all',
              onChanged: (value) => c.filterKind(value == 'all' ? null : value),
              items: [
                RaftSegmentedOption(
                  value: 'all',
                  label: tr('All patterns'),
                  itemKey: const ValueKey('raftbench-kind-all'),
                ),
                for (final kind in raftbenchPatternKinds)
                  RaftSegmentedOption(
                    value: kind,
                    label: tr(raftbenchKindLabel(kind)),
                    count: fmt.number(counts[kind] ?? 0),
                    itemKey: ValueKey('raftbench-kind-$kind'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The ICU plural of the retry lines, one catalog key per arm.
  static String _retry(BuildContext context, String stream, int count) {
    final key = switch ((stream == 'thread', count == 1)) {
      (true, true) =>
        'Thread replies failed to load 1 time; unread history is kept for retry.',
      (true, false) =>
        'Thread replies failed to load {count} times; unread history is kept for retry.',
      (false, true) =>
        'Channel messages failed to load 1 time; unread history is kept for retry.',
      (false, false) =>
        'Channel messages failed to load {count} times; unread history is kept for retry.',
    };
    return raftFormat(context, key, {'count': count});
  }
}
