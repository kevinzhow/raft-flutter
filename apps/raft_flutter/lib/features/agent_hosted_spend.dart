// Web components/settings/HostedRuntimeSpendCard.tsx: the server's cloud
// agent spend on the Plan page, as the provider reports it
// (`GET /billing/hosted-runtime-usage`): today against the daily limit, the
// last 30 UTC days and spend by agent. Read once when the page opens. Hidden
// when the server has no cloud runtime or the viewer is not an owner or admin
// (4xx but 400 and 429); a warning when the provider does not answer.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/workspace_controller.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'private_route_guard.dart' show workspaceAuthority;

const hostedSpendPath = '/billing/hosted-runtime-usage';

enum _Load { loading, hidden, error, ready }

class AgentHostedSpendCard extends StatefulWidget {
  const AgentHostedSpendCard({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  State<AgentHostedSpendCard> createState() => _AgentHostedSpendCardState();
}

class _AgentHostedSpendCardState extends State<AgentHostedSpendCard> {
  WorkspaceController get w => widget.controller;
  _Load _load = _Load.loading;
  Map<String, dynamic> _spend = const {};
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _read() async {
    final authority = workspaceAuthority(w);
    try {
      final data = await w.client.get(hostedSpendPath);
      if (_disposed || authority != workspaceAuthority(w)) return;
      setState(() {
        if (data is Map) {
          _spend = Map<String, dynamic>.from(data);
          _load = _Load.ready;
        } else {
          _load = _Load.error;
        }
      });
    } on RaftApiException catch (e) {
      if (_disposed || e.staleScope) return;
      final s = e.status;
      setState(
        () => _load = s != null && s < 500 && s != 429 && s != 400
            ? _Load.hidden
            : _Load.error,
      );
    } catch (_) {
      if (!_disposed) setState(() => _load = _Load.error);
    }
  }

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};
  static List<Map<String, dynamic>> _rows(Object? v) => [
    if (v is List)
      for (final r in v)
        if (r is Map) Map<String, dynamic>.from(r),
  ];
  static num _num(Object? v) => v is num && v.isFinite ? v : 0;

  @override
  Widget build(BuildContext context) {
    if (_load == _Load.hidden) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String tr(String s) => raftText(context, s);
    String usd(num v) => hostedUsd(
      v,
      locale,
      under: (amount) =>
          raftFormat(context, 'under {amount}', {'amount': amount}),
    );
    String utcDay(String iso) {
      final at = DateTime.tryParse(iso);
      return at == null ? iso : DateFormat.MMMd(locale).format(at.toUtc());
    }

    final value = RaftTypography.inherited(
      t,
      size: 14,
      line: 20,
      color: text.strong,
    );
    final mono = RaftPanelText.mono(t);
    final hint = RaftPanelText.caption(t);

    final Widget body;
    switch (_load) {
      case _Load.loading || _Load.hidden:
        body = Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: tr('Loading cloud agent spend'),
            child: const RaftSpinner(),
          ),
        );
      case _Load.error:
        body = RaftBanner(
          key: const ValueKey('hosted-runtime-spend-error'),
          size: RaftBannerRecipeSize.sm,
          description: tr('Failed to load cloud agent spend'),
        );
      case _Load.ready:
        final today = _map(_spend['today']);
        final periods = _rows(_spend['periods']);
        final agents = _rows(_spend['agents']);
        final resetsAt = agentTimeFormatter(
          context,
          w,
        ).shortDateTime(today['resetsAt']);
        final unpriced = periods.any(
          (p) => p['unpriced'] is List && (p['unpriced'] as List).isNotEmpty,
        );
        final limit = today['limitUsd'];
        body = RaftGapColumn(
          gap: 12,
          children: [
            if (today['refusing'] == true)
              RaftBanner(
                key: const ValueKey('hosted-runtime-spend-refusing'),
                size: RaftBannerRecipeSize.sm,
                description: raftFormat(
                  context,
                  today['platformLimitReached'] == true
                      ? "The platform's daily limit has been reached. Cloud agents' model calls are refused until {time}."
                      : "This server has reached its daily limit. Cloud agents' model calls are refused until {time}.",
                  {'time': resetsAt},
                ),
              ),
            RaftInfoRow(
              label: tr('Today (UTC)'),
              child: RaftGapColumn(
                gap: 0,
                children: [
                  RaftCssText(
                    key: const ValueKey('hosted-runtime-spend-today'),
                    limit is num
                        ? raftFormat(
                            context,
                            '{spent} of the {limit} daily limit',
                            {
                              'spent': usd(_num(today['spentUsd'])),
                              'limit': usd(limit),
                            },
                          )
                        : raftFormat(context, '{spent}, no daily limit', {
                            'spent': usd(_num(today['spentUsd'])),
                          }),
                    style: value,
                  ),
                  RaftCssText(
                    raftFormat(context, 'Resets {time}', {'time': resetsAt}),
                    style: hint,
                  ),
                ],
              ),
            ),
            RaftInfoRow(
              label: tr('Last 30 days'),
              child: RaftGapColumn(
                gap: 4,
                children: [
                  RaftCssText(
                    key: const ValueKey('hosted-runtime-spend-total'),
                    usd(_num(_spend['totalUsd'])),
                    style: mono,
                  ),
                  if (periods.isEmpty)
                    RaftCssText(tr('No spend in the last 30 days'), style: hint)
                  else
                    RaftGapColumn(
                      key: const ValueKey('hosted-runtime-spend-days'),
                      gap: 2,
                      children: [
                        for (final p in periods)
                          RaftGapRow(
                            gap: 12,
                            baseline: true,
                            shrinkWrap: true,
                            children: [
                              RaftCssText(
                                utcDay('${p['start']}'),
                                style: hint.copyWith(fontFamily: t.monoFont),
                              ),
                              RaftCssText(
                                usd(_num(p['totalUsd'])),
                                style: hint.copyWith(
                                  fontFamily: t.monoFont,
                                  color: text.strong,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (agents.isNotEmpty)
              RaftInfoRow(
                label: tr('By agent'),
                child: RaftGapColumn(
                  key: const ValueKey('hosted-runtime-spend-agents'),
                  gap: 2,
                  children: [
                    for (final a in agents)
                      RaftGapRow(
                        gap: 8,
                        children: [
                          Expanded(
                            child: RaftCssText(
                              a['name'] is String
                                  ? a['name'] as String
                                  : tr('Deleted agents'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: hint.copyWith(color: text.strong),
                            ),
                          ),
                          RaftCssText(
                            usd(_num(a['totalUsd'])),
                            style: hint.copyWith(fontFamily: t.monoFont),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (unpriced)
              RaftCssText(
                tr('Some usage has no price and is not included.'),
                style: hint,
              ),
            RaftCssText(
              tr(
                _spend['estimated'] == true
                    ? 'Estimated, in USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.'
                    : 'In USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.',
              ),
              style: hint,
            ),
          ],
        );
    }
    return Column(
      key: const ValueKey('hosted-runtime-spend'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Cloud agent spend',
          glyph: RaftGlyph.activity,
        ),
        RaftSettingsCard(child: body),
      ],
    );
  }
}
