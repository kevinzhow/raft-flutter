// Web components/agent/HostedRuntimeStatus.tsx: what the profile's External
// setup shows for a cloud agent instead of the manual setup steps. The
// provisioning state as a status chip (setting up / running / syncing /
// setup failed / removing / removed), "Runs in the cloud" and "Free for a
// limited time", the provider's last error, and Retry. After the provider
// refused the picked model (`retryNeedsModel`) a retry names the model again
// (never silently the default). While the provider is still working the
// panel re-reads the agent's external status every 5 seconds
// (`HOSTED_RUNTIME_POLL_MS`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_hosted_runtime.dart';
import '../data/workspace_controller.dart';
import 'agent_hosted_model_choice.dart';
import 'agent_hosted_provider.dart';
import 'private_route_guard.dart' show workspaceAuthority;

const hostedRuntimePollInterval = Duration(seconds: 5);

class AgentHostedRuntimeStatus extends StatefulWidget {
  const AgentHostedRuntimeStatus({
    super.key,
    required this.controller,
    required this.agentId,
    required this.summary,
    required this.onStatus,
  });

  final WorkspaceController controller;
  final String agentId;
  final HostedRuntimeSummary summary;

  /// A fresher `GET /agents/:id/external-status` (a poll, or the read after a
  /// retry): the profile adopts it.
  final void Function(Map<String, dynamic> status) onStatus;

  @override
  State<AgentHostedRuntimeStatus> createState() =>
      _AgentHostedRuntimeStatusState();
}

class _AgentHostedRuntimeStatusState extends State<AgentHostedRuntimeStatus> {
  WorkspaceController get w => widget.controller;
  late final HostedModelsLoader models = HostedModelsLoader(
    w,
    kind: widget.summary.provider,
  );
  RaftForegroundPeriodic? _poll;
  bool _retrying = false, _polling = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next Retry starts or the agent changes (the panel is keyed by agent).
  bool _retryError = false;
  String? _modelPick;

  HostedRuntimeDescription get view => widget.summary.describe();
  bool get needsModel => view.canRetry && widget.summary.retryNeedsModel;

  @override
  void initState() {
    super.initState();
    _syncPoll();
    models.ensure(needsModel);
  }

  @override
  void didUpdateWidget(AgentHostedRuntimeStatus old) {
    super.didUpdateWidget(old);
    _syncPoll();
    models.ensure(needsModel);
  }

  @override
  void dispose() {
    _poll?.dispose();
    models.dispose();
    super.dispose();
  }

  void _syncPoll() {
    if (view.inProgress) {
      _poll ??= RaftForegroundPeriodic(
        hostedRuntimePollInterval,
        () => unawaited(_refresh()),
      );
    } else {
      _poll?.dispose();
      _poll = null;
    }
  }

  Future<Map<String, dynamic>?> _read() async {
    final authority = workspaceAuthority(w);
    final id = widget.agentId;
    final status = await w.client.get(
      '/agents/${Uri.encodeComponent(id)}/external-status',
    );
    if (!mounted ||
        authority != workspaceAuthority(w) ||
        id != widget.agentId) {
      return null;
    }
    return status is Map ? Map<String, dynamic>.from(status) : null;
  }

  Future<void> _refresh() async {
    if (_polling) return;
    _polling = true;
    try {
      final status = await _read();
      if (status != null && mounted) widget.onStatus(status);
    } catch (_) {
      // The next tick tries again; a failed poll shows nothing.
    } finally {
      _polling = false;
    }
  }

  /// `HostedModelsList` once the retry's list is in.
  String? get _pickedModel {
    final view = models.view;
    return view != null && view.locked ? null : _modelPick;
  }

  String _pickedLabel(BuildContext context) {
    final picked = _pickedModel;
    final list = models.view;
    return picked == null
        ? hostedDefaultChoiceLabel(context, list)
        : list?.labelOf(picked) ?? picked;
  }

  Future<void> _retry() async {
    if (_retrying) return;
    final authority = workspaceAuthority(w);
    final withModel = needsModel;
    final pick = _pickedModel;
    setState(() {
      _retrying = true;
      _retryError = false;
    });
    try {
      await w.command(
        'POST',
        hostedRuntimeRetryPath(widget.agentId),
        data: withModel ? {'model': pick} : null,
      );
      final status = await _read();
      if (status != null && mounted) widget.onStatus(status);
    } on RaftApiException catch (e) {
      if (mounted && !e.staleScope && authority == workspaceAuthority(w)) {
        setState(() => _retryError = true);
      }
    } catch (_) {
      if (mounted && authority == workspaceAuthority(w)) {
        setState(() => _retryError = true);
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final summary = widget.summary;
    final describe = view;
    String tr(String s) => raftText(context, s);
    final warning = RaftPanelText.warningCaption(t);
    final hint = RaftPanelText.caption(t)
        .copyWith(color: t.colors['foreground-hint']);
    return RaftGapColumn(
      key: ValueKey('agent-hosted-runtime-status-${summary.state}'),
      gap: 8,
      children: [
        RaftFlowRow(
          gapX: 8,
          gapY: 4,
          children: [
            RaftBadge(
              key: const ValueKey('hosted-runtime-state'),
              label: tr(describe.label),
              appearance: RaftBadgeRecipeAppearance.soft,
              variant: switch (describe.tone) {
                HostedStateTone.primary => RaftBadgeRecipeVariant.primary,
                HostedStateTone.success => RaftBadgeRecipeVariant.success,
                HostedStateTone.warning => RaftBadgeRecipeVariant.warning,
                HostedStateTone.muted => RaftBadgeRecipeVariant.muted,
              },
              leading: RaftStatusDot(
                activity: switch (describe.presence) {
                  HostedStatePresence.busy => RaftActivityTone.working,
                  HostedStatePresence.online => RaftActivityTone.online,
                  HostedStatePresence.error => RaftActivityTone.error,
                  HostedStatePresence.offline => RaftActivityTone.offline,
                },
              ),
            ),
            // The provider's name is not shown to people: a cloud agent
            // "runs in the cloud".
            RaftBadge(
              key: const ValueKey('hosted-runtime-location'),
              label: tr('Runs in the cloud'),
              appearance: RaftBadgeRecipeAppearance.soft,
              variant: RaftBadgeRecipeVariant.information,
              leading: const RaftIcon(RaftGlyph.cloud, size: 14),
            ),
            RaftCssText(
              key: const ValueKey('hosted-runtime-free'),
              tr('Free for a limited time'),
              style: hint,
            ),
          ],
        ),
        if (summary.state == 'active' && summary.pushRegistered == false)
          RaftCssText(
            [
              tr('Message delivery to this cloud agent is not registered yet.'),
              if (summary.pushError != null && summary.pushError!.isNotEmpty)
                summary.pushError!,
            ].join(' '),
            style: warning,
          ),
        if (summary.hasLastError)
          RaftCssText(
            key: const ValueKey('agent-hosted-runtime-error'),
            raftFormat(context, 'Last error ({code}): {message}', {
              'code': summary.lastErrorCode,
              'message': (summary.lastErrorMessage ?? '').isEmpty
                  ? summary.lastErrorCode
                  : summary.lastErrorMessage,
            }),
            style: warning,
          ),
        if (needsModel)
          RaftGapColumn(
            key: const ValueKey('agent-hosted-runtime-retry-model'),
            gap: 6,
            children: [
              RaftCssText(
                tr(
                  'The provider refused the model this agent was set to start on. Choose a model, then retry.',
                ),
                style: RaftPanelText.caption(t),
              ),
              HostedModelChoice(
                loader: models,
                value: _pickedModel,
                onChanged: (id) => setState(() => _modelPick = id),
              ),
            ],
          ),
        if (describe.canRetry)
          ListenableBuilder(
            listenable: models,
            builder: (context, _) => RaftFlowRow(
              children: [
                RaftRecipeButton(
                  key: const ValueKey('agent-hosted-runtime-retry'),
                  label: needsModel
                      ? raftFormat(context, 'Retry with {model}', {
                          'model': _pickedLabel(context),
                        })
                      : tr('Retry'),
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  onPressed:
                      _retrying ||
                          (needsModel &&
                              models.status == HostedModelsStatus.loading)
                      ? null
                      : () => unawaited(_retry()),
                  disabled:
                      _retrying ||
                      (needsModel &&
                          models.status == HostedModelsStatus.loading),
                ),
                if (_retryError)
                  RaftCssText(tr('Retry failed.'), style: warning),
              ],
            ),
          ),
      ],
    );
  }
}
