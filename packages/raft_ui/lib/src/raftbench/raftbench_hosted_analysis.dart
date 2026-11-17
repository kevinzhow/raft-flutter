// RaftBench "Patterns and improvements" (Web raftbench/HostedAnalysis.tsx):
// enable / disable, the finding index, progress and coverage, the findings,
// the service agent, agent access, and the sources and start date.
import 'package:flutter/material.dart';

import '../../raft_ui.dart';

import 'raftbench_finding_index.dart';
import 'raftbench_findings.dart';
import 'raftbench_parts.dart';
import 'raftbench_reader_access.dart';

class RaftbenchHostedAnalysis extends StatelessWidget {
  const RaftbenchHostedAnalysis({
    super.key,
    required this.controller,
    required this.allowed,
    required this.onOpenAgent,
    required this.onOpenEvidence,
  });
  final RaftbenchHostedPanel controller;
  final bool allowed;

  /// Open the agent's profile (Web `nav.toAgent`).
  final void Function(String agentId) onOpenAgent;

  /// Open a cited message in the thread panel (Web `EvidenceChip`).
  final RaftbenchOpenEvidence onOpenEvidence;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => _Analysis(
      controller: controller,
      allowed: allowed,
      onOpenAgent: onOpenAgent,
      onOpenEvidence: onOpenEvidence,
    ),
  );
}

class _Analysis extends StatelessWidget {
  const _Analysis({
    required this.controller,
    required this.allowed,
    required this.onOpenAgent,
    required this.onOpenEvidence,
  });
  final RaftbenchHostedPanel controller;
  final bool allowed;
  final void Function(String) onOpenAgent;
  final RaftbenchOpenEvidence onOpenEvidence;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    final c = controller, data = c.data, pad = RaftbenchCard.inset(context);
    String tr(String s) => raftText(context, s);
    final fmt = RaftbenchFormat(context);
    final run = c.run;
    final selected = c.selected;
    final invalid = c.invalidHistory;
    final hint = ty.caption(color: ty.hint, weight: FontWeight.w400);
    final toggleLabel = c.saving
        ? 'Saving…'
        : data?.enabled == true
        ? 'Disable and clear results'
        : 'Enable and start analysis';
    final toggleDisabled =
        !allowed ||
        data == null ||
        c.saving ||
        (!data.enabled && (selected.isEmpty || invalid));
    // Plain block flow: each block carries its own `mt-*` (nothing collapses
    // away at the top of the padded body).
    Widget at(double top, Widget child) => Padding(
      padding: EdgeInsets.only(top: top),
      child: child,
    );
    Widget live(Widget child) => Semantics(liveRegion: true, child: child);
    final index = data?.enabled == true && data?.kindCounts != null;
    final children = <Widget>[
      if (c.loading)
        at(12, live(Text(tr('Loading analysis settings…'), style: ty.body()))),
      if (c.loadError != null) at(12, _error(ty, c.loadError!, load: true)),
      if (c.saveError != null) at(12, _error(ty, c.saveError!, load: false)),
      if (data?.enabled == true && data?.triage != null)
        at(12, RaftbenchTriageLine(triage: data!.triage!)),
      if (index)
        Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 20),
          child: RaftbenchFindingIndex(controller: c),
        ),
      at(index ? 0 : 16, _coverageDetails(context, t, ty, hint, fmt)),
      if (run != null && !c.emptyScan)
        at(
          16,
          RaftbenchFindings(controller: c, onOpenEvidence: onOpenEvidence),
        ),
      if (data != null) at(16, _agentCard(context, t, ty, hint)),
      at(
        16,
        RaftbenchReaderAccess(
          controller: c.readers,
          enabled: data?.enabled == true,
        ),
      ),
      at(16, _settings(context, t, ty, hint)),
    ];
    return RaftbenchCard(
      padded: false,
      clip: true,
      color: t.canvas,
      child: Column(
        key: const ValueKey('raftbench-hosted-analysis'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: t.colors['line-hairline']!),
              ),
            ),
            padding: EdgeInsets.all(pad),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    tr('Patterns and improvements'),
                    style: ty.headline(),
                  ),
                ),
                RaftbenchButton(
                  tr(toggleLabel),
                  onPressed: toggleDisabled ? null : c.toggleAnalysis,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// `ErrorLine`: the failure with its diagnostic code, and for a 401 / 403 the
  /// reason to try something else.
  Widget _error(RaftbenchType ty, String code, {required bool load}) => Builder(
    builder: (context) {
      String tr(String s) => raftText(context, s);
      return Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              raftFormat(
                context,
                load
                    ? 'Analysis settings could not be loaded (code: {code}). Refresh the page to try again.'
                    : 'Analysis settings could not be saved (code: {code}). Try again.',
                {'code': code},
              ),
              style: ty.body(color: ty.danger),
            ),
            if (code == 'HTTP 401' || code == 'HTTP 403')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr(
                    code == 'HTTP 401'
                        ? 'Your sign-in may have expired. Refresh the page or sign in again.'
                        : 'Your account may not have access to RaftBench on this server.',
                  ),
                  style: ty.caption(color: ty.danger, weight: FontWeight.w400),
                ),
              ),
          ],
        ),
      );
    },
  );

  /// `<details>` "Reading progress and coverage": the cumulative read count,
  /// the source coverage, the model and cadence, provisioning, the busy bar and
  /// the skipped chunks.
  Widget _coverageDetails(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
    RaftbenchFormat fmt,
  ) {
    String tr(String s) => raftText(context, s);
    Widget live(Widget child) => Semantics(liveRegion: true, child: child);
    Widget at(double top, Widget child) => Padding(
      padding: EdgeInsets.only(top: top),
      child: child,
    );
    final c = controller, data = c.data, run = c.run;
    final coverage = data?.coverage;
    final progress = data?.progress;
    return RaftbenchDetails(
      key: const ValueKey('raftbench-coverage-details'),
      summaryStyle: ty.callout(weight: FontWeight.w600),
      summary: Text(tr('Reading progress and coverage')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data?.enabled == true &&
              progress != null &&
              progress.readMessages > 0)
            at(
              16,
              live(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coverage != null
                          ? raftFormat(
                              context,
                              'Read {count} of {total} messages so far',
                              {
                                'count': fmt.number(progress.readMessages),
                                'total': fmt.number(coverage.windowMessages),
                              },
                            )
                          : raftFormat(
                              context,
                              'Read {count} messages so far',
                              {'count': fmt.number(progress.readMessages)},
                            ),
                      style: ty.body(weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'New messages are read in the background. Findings so far stay visible.',
                      ),
                      style: hint,
                    ),
                  ],
                ),
              ),
            ),
          if (coverage != null) at(16, _coverage(context, t, ty, hint, fmt)),
          if (data?.enabled == true)
            at(
              8,
              Text(
                raftFormat(context, 'Current cloud agent model: {model}', {
                  'model':
                      c.modelAgentId == data!.agentId && c.modelLabel != null
                      ? c.modelLabel!
                      : tr('Unknown'),
                }),
                style: hint,
              ),
            ),
          if (data?.enabled == true)
            at(
              12,
              Text(
                raftFormat(
                  context,
                  '{sources} channels · history continues in background; checks for new messages every {count} minutes',
                  {
                    'count': data!.intervalMinutes,
                    'sources': data.channelIds.length,
                  },
                ),
                style: hint,
              ),
            ),
          if (data?.enabled == true && data?.provisioning?.state == 'failed')
            at(
              12,
              live(
                Text(
                  tr(
                    'The analysis agent could not start. An administrator needs to check the cloud agent service.',
                  ),
                  style: ty.body(color: ty.danger),
                ),
              ),
            ),
          if (c.busy && !c.emptyScan) at(16, _busy(context, t, ty, hint)),
          if (run != null && run.skippedRanges.isNotEmpty)
            at(
              12,
              RaftBanner(
                size: RaftBannerRecipeSize.sm,
                description: [
                  for (final range in run.skippedRanges)
                    raftFormat(
                      context,
                      'A chunk from {from} to {to} ({count} messages) was not analyzed after 3 failed attempts. Its outcome is unknown.',
                      {
                        'from': fmt.stamp(range.from),
                        'to': fmt.stamp(range.to),
                        'count': range.messages == null
                            ? tr('Unknown')
                            : fmt.number(range.messages!),
                      },
                    ),
                ].join('\n'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _box({required Widget child}) => Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: RaftTokens.of(context).colors['line-hairline']!,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    ),
  );

  Widget _agentCard(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
  ) {
    String tr(String s) => raftText(context, s);
    final c = controller, data = c.data!;
    return _box(
      child: RaftbenchDetails(
        open: data.agentId == null,
        summaryStyle: ty.body(weight: FontWeight.w600),
        summary: Text(tr('RaftBench service agent')),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      tr(
                        'This agent reads selected sources and submits dashboard results. It does not reply to DMs. Open its card to inspect it.',
                      ),
                      style: hint,
                    ),
                  ),
                  RaftbenchButton(
                    tr('Create service agent'),
                    onPressed: c.saving ? null : c.createServiceAgent,
                  ),
                ],
              ),
              if (c.serviceAgents.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final agent in c.serviceAgents) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.colors['line-hairline']!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => onOpenAgent(agent.agentId),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  agent.name,
                                  style: ty
                                      .callout(weight: FontWeight.w600)
                                      .copyWith(
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                            Text(
                              data.agentId == agent.agentId
                                  ? tr('Assigned to this analysis')
                                  : agent.ready
                                  ? tr('Ready to assign')
                                  : tr(
                                      'Setting up; assignment available when ready',
                                    ),
                              style: hint,
                            ),
                          ],
                        ),
                        if (data.agentId != agent.agentId)
                          RaftbenchButton(
                            tr('Assign agent'),
                            onPressed: !agent.ready || c.assignmentBlocked
                                ? null
                                : () => c.assignAgent(agent.agentId),
                          ),
                      ],
                    ),
                  ),
                  if (agent != c.serviceAgents.last) const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 8),
              Text(
                tr(
                  'Cloud is available now. Computer assignment will appear when its runner supports this read-only agent profile.',
                ),
                style: hint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settings(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
  ) {
    String tr(String s) => raftText(context, s);
    final c = controller, data = c.data;
    final wide = raftBreakpointWidth(context) >= 640;
    final today = c.now().toUtc().toIso8601String().substring(0, 10);
    return RaftbenchDetails(
      open: data?.enabled != true,
      summaryStyle: ty.callout(weight: FontWeight.w600),
      summary: Text(tr('Sources and historical range')),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: IgnorePointer(
          ignoring: c.saving,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Channels to analyze (up to 50)'),
                style: ty.callout(weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'I authorize this read-only agent to analyze these channels on staging. Findings accumulate within this analysis range on staging; disabling or changing the range clears them. No export.',
                ),
                style: hint,
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Runs as a cloud agent using its configured model and budget. Each batch reads at most 2,000 messages / 64,000 source characters; unfinished history continues in the background. These are batch limits, not a limit on the analysis range. Per-batch model tokens and cost are not yet available.',
                ),
                style: hint,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 176),
                child: _ChannelGrid(
                  controller: c,
                  columns: wide ? 2 : 1,
                  ty: ty,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('Analyze messages since (UTC)'),
                style: ty.callout(weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: wide ? 168 : double.infinity,
                  child: RaftbenchDateField(
                    value: c.dateValue,
                    max: today,
                    semanticLabel: tr('Analyze messages since (UTC)'),
                    enabled: !c.saving,
                    onChanged: c.setHistoryDate,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final days in raftbenchHistoryDays)
                    RaftbenchButton(
                      raftFormat(context, 'Past {days} days', {'days': days}),
                      onPressed: c.saving
                          ? null
                          : () => c.chooseHistoryDays(days),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Choose how far back the first scan starts. Messages are processed in batches; a batch budget is not a total data limit. Changing the range restarts analysis and clears its current results.',
                ),
                style: hint,
              ),
              if (data?.enabled == true && c.changed) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RaftbenchButton(
                    tr('Apply changes and restart'),
                    onPressed:
                        c.selected.isEmpty || c.invalidHistory || c.saving
                        ? null
                        : c.applySettings,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverage(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
    RaftbenchFormat fmt,
  ) {
    String tr(String s) => raftText(context, s);
    final c = controller, data = c.data!, coverage = data.coverage!;
    return _box(
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              raftFormat(
                context,
                'Selected channels: {total} messages total; {count} in the analysis range.',
                {
                  'total': fmt.number(coverage.totalMessages),
                  'count': fmt.number(coverage.windowMessages),
                },
              ),
              style: ty.callout(),
            ),
            const SizedBox(height: 4),
            Text(
              coverage.latestAt != null
                  ? raftFormat(context, 'Newest source message: {time}', {
                      'time': fmt.stamp(coverage.latestAt!),
                    })
                  : tr('No messages in the selected channels'),
              style: hint,
            ),
            const SizedBox(height: 4),
            Text(
              raftFormat(context, '{from} – {to}', {
                'from': fmt.stamp(coverage.from),
                'to': fmt.stamp(coverage.to),
              }),
              style: hint,
            ),
            if (c.emptyRange) ...[
              const SizedBox(height: 12),
              Text(
                tr(
                  'Messages exist, but they are outside this range. Choose an earlier start date to analyze them.',
                ),
                style: ty.callout(),
              ),
              if (data.enabled && c.availableHistory != null) ...[
                const SizedBox(height: 8),
                Text(
                  raftFormat(
                    context,
                    'The selected channels contain {count} messages across all history. Start with the newest message\'s UTC date to see a smaller slice. Restarting replaces current findings and may still require multiple model calls.',
                    {'count': fmt.number(coverage.totalMessages)},
                  ),
                  style: hint,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RaftbenchButton(
                    raftFormat(
                      context,
                      'Analyze the newest source day from {date}',
                      {'date': c.availableHistory},
                    ),
                    onPressed: c.saving || c.changed
                        ? null
                        : c.analyzeAvailableHistory,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _busy(
    BuildContext context,
    RaftTokens t,
    RaftbenchType ty,
    TextStyle hint,
  ) {
    String tr(String s) => raftText(context, s);
    final c = controller, data = c.data!, run = c.run;
    final state = data.provisioning?.state;
    final headline = state == 'failed'
        ? 'The analysis agent could not start. An administrator needs to check the cloud agent service.'
        : state != 'active'
        ? 'Starting your analysis agent…'
        : run == null || run.status == 'queued'
        ? 'Waiting for the analysis agent…'
        : run.stopReason == 'more_pages'
        ? (run.sourceKind == 'thread'
              ? 'Reading thread replies…'
              : 'Reading channel messages…')
        : 'Analyzing the messages read…';
    final count = run?.fetchedMessages ?? 0;
    final batch = data.progress != null;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(headline), style: ty.callout(weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Semantics(
            label: tr('Analysis progress'),
            value: raftFormat(
              context,
              batch ? '{count} new messages read' : '{count} messages read',
              {'count': RaftbenchFormat(context).number(count)},
            ),
            child: RaftbenchBar(
              height: 8,
              track: t.sidebar,
              fill: ty.brand,
              fraction: 1 / 3,
              pulse: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            raftFormat(
              context,
              batch
                  ? 'Reading new messages. Findings so far stay visible.'
                  : '{count} messages read. The total is not known yet; this bar does not show a percentage.',
              {'count': RaftbenchFormat(context).number(count)},
            ),
            style: hint,
          ),
        ],
      ),
    );
  }
}

/// The channel checkboxes: `grid grid-cols-1 gap-2 sm:grid-cols-2`, scrolling
/// past `max-h-44`.
class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
    required this.controller,
    required this.columns,
    required this.ty,
  });
  final RaftbenchHostedPanel controller;
  final int columns;
  final RaftbenchType ty;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selected;
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, box) {
          final width = (box.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in controller.options)
                SizedBox(
                  width: width,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.toggleChannel(option.value),
                    child: Row(
                      children: [
                        RaftCheckbox(
                          value: selected.contains(option.value),
                          onChanged: (_) =>
                              controller.toggleChannel(option.value),
                          semanticLabel: option.label,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ty.callout(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
