// Web components/agent/AgentHostedRuntimeUsage.tsx: the last seven days of a
// cloud agent as its provider reports them (`GET /agents/:id/hosted-runtime/
// usage?from&to&bucket=1d`): USD by UTC day when the provider prices it,
// tokens by kind summed across models, tool calls and the top models.
// Hidden when the agent is not hosted or the caller may not see it (4xx but
// 400 and 429); a warning when the provider does not answer.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show workspaceAuthority;
import 'resource_cards.dart' show resourceRelativeTime;

enum _Load { loading, hidden, error, ready }

class AgentHostedRuntimeUsage extends StatefulWidget {
  const AgentHostedRuntimeUsage({
    super.key,
    required this.controller,
    required this.agentId,
    this.now,
  });

  final WorkspaceController controller;
  final String agentId;

  /// The clock of the seven-day window (tests pin it).
  final DateTime Function()? now;

  @override
  State<AgentHostedRuntimeUsage> createState() =>
      _AgentHostedRuntimeUsageState();
}

class _AgentHostedRuntimeUsageState extends State<AgentHostedRuntimeUsage> {
  WorkspaceController get w => widget.controller;
  _Load _load = _Load.loading;
  HostedUsageSummary? _summary;
  bool _partial = false;
  String _asOf = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void didUpdateWidget(AgentHostedRuntimeUsage old) {
    super.didUpdateWidget(old);
    if (old.agentId != widget.agentId) {
      _generation++;
      _load = _Load.loading;
      _summary = null;
      unawaited(_read());
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _read() async {
    final run = _generation;
    final authority = workspaceAuthority(w);
    final window = hostedUsageWindow((widget.now ?? DateTime.now)());
    try {
      final data = await w.client.get(
        hostedRuntimeUsagePath(widget.agentId),
        query: {'from': window.from, 'to': window.to, 'bucket': '1d'},
      );
      if (!mounted ||
          run != _generation ||
          authority != workspaceAuthority(w)) {
        return;
      }
      final rows = data is Map && data['rows'] is List
          ? [for (final r in data['rows'] as List) ?HostedUsageRow.parse(r)]
          : const <HostedUsageRow>[];
      setState(() {
        _summary = summarizeHostedUsage(rows);
        _partial = data is Map && data['partial'] == true;
        _asOf = data is Map && data['asOf'] is String
            ? data['asOf'] as String
            : '';
        _load = _Load.ready;
      });
    } on RaftApiException catch (e) {
      if (!mounted || run != _generation || e.staleScope) return;
      final s = e.status;
      setState(
        () => _load = s != null && s < 500 && s != 429 && s != 400
            ? _Load.hidden
            : _Load.error,
      );
    } catch (_) {
      if (!mounted || run != _generation) return;
      setState(() => _load = _Load.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_load == _Load.hidden) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final summary = _summary;
    String tr(String s) => raftText(context, s);
    final hint = RaftPanelText.caption(t)
        .copyWith(color: t.colors['foreground-hint']);
    final value = RaftPanelText.profileValue(t);
    final mono = RaftPanelText.profileMono(t);
    String usd(num v) => hostedUsd(
      v,
      locale,
      under: (amount) =>
          raftFormat(context, 'under {amount}', {'amount': amount}),
    );
    final numbers = NumberFormat.decimalPattern(locale);
    String n(num v) => numbers.format(v);

    Widget grid(List<(String, String, {bool bold})> rows) => RaftGapColumn(
      gap: 2,
      children: [
        for (final (label, text, :bold) in rows)
          RaftGapRow(
            gap: 12,
            baseline: true,
            shrinkWrap: true,
            children: [
              RaftCssText(label, style: hint),
              RaftCssText(text, style: bold ? RaftPanelText.boldMono(t) : mono),
            ],
          ),
      ],
    );

    final Widget body;
    if (_load == _Load.loading || summary == null && _load == _Load.ready) {
      body = Align(
        alignment: Alignment.centerLeft,
        child: Semantics(label: tr('Loading...'), child: const RaftSpinner()),
      );
    } else if (_load == _Load.error) {
      body = RaftCssText(
        tr('Failed to load usage'),
        style: RaftPanelText.warningCaption(t),
      );
    } else if (!summary!.hasUsage) {
      body = RaftCssText(tr('No usage in the last 7 days'), style: value);
    } else {
      final cost = summary;
      body = RaftGapColumn(
        gap: 8,
        children: [
          if (cost.hasCost)
            RaftInfoRow(
              label: tr('Cost'),
              child: RaftGapColumn(
                key: const ValueKey('agent-hosted-runtime-cost'),
                gap: 4,
                children: [
                  grid([
                    for (final day in cost.costDays)
                      (
                        DateFormat.MMMd(locale).format(
                          DateTime.parse('${day.day}T00:00:00Z').toUtc(),
                        ),
                        day.priced ? usd(day.usd) : tr('Unpriced'),
                        bold: false,
                      ),
                    (
                      tr('Total'),
                      cost.costPriced ? usd(cost.costTotal) : tr('Unpriced'),
                      bold: true,
                    ),
                  ]),
                  if (cost.costHasUnpriced)
                    RaftCssText(
                      tr(
                        'Some usage, such as tool calls, has no price and is not included.',
                      ),
                      style: hint,
                    ),
                  RaftCssText(
                    tr(
                      'In USD by UTC day, as reported by the provider. For reference, not a bill.',
                    ),
                    style: hint,
                  ),
                ],
              ),
            ),
          RaftInfoRow(
            label: tr('Tokens'),
            child: grid([
              (tr('Input'), n(cost.input), bold: false),
              (tr('Output'), n(cost.output), bold: false),
              (tr('Reasoning tokens'), n(cost.reasoning), bold: false),
              (tr('Cache read'), n(cost.cacheRead), bold: false),
              (tr('Cache write'), n(cost.cacheWrite), bold: false),
              (tr('Total tokens'), n(cost.totalTokens), bold: false),
            ]),
          ),
          RaftInfoRow(
            label: tr('Tool calls'),
            child: RaftCssText(
              raftFormat(
                context,
                '{total} ({succeeded} succeeded, {failed} failed)',
                {
                  'total': n(cost.toolTotal),
                  'succeeded': n(cost.toolSucceeded),
                  'failed': n(cost.toolFailed),
                },
              ),
              style: value,
            ),
          ),
          if (cost.topModels.isNotEmpty)
            RaftInfoRow(
              label: tr('Top models'),
              child: RaftGapColumn(
                gap: 2,
                children: [
                  for (final m in cost.topModels)
                    RaftGapRow(
                      gap: 8,
                      children: [
                        Expanded(
                          child: RaftCssText(
                            m.model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mono,
                          ),
                        ),
                        RaftCssText(
                          n(m.tokens),
                          style: mono.copyWith(color: hint.color),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      );
    }
    return RaftPanelSection(
      key: const ValueKey('agent-hosted-runtime-usage'),
      gap: 8,
      children: [
        RaftSectionEyebrow(tr('Usage (last 7 days)')),
        body,
        if (_load == _Load.ready && _partial)
          RaftCssText(
            raftFormat(context, 'Partial data, as of {time}', {
              'time': _asOfText(context, locale),
            }),
            style: hint,
          ),
      ],
    );
  }

  String _asOfText(BuildContext context, String locale) {
    final relative = resourceRelativeTime(
      _asOf,
      now: (widget.now ?? DateTime.now)(),
      chinese: locale.toLowerCase().startsWith('zh'),
    );
    if (relative.isNotEmpty) return relative;
    final at = DateTime.tryParse(_asOf);
    return at == null
        ? _asOf
        : DateFormat.yMMMd(locale).add_jm().format(at.toLocal());
  }
}
