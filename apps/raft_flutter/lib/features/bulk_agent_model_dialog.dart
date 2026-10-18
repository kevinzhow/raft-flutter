// Web v1.21.12 BulkChangeModelDialog: choose -> review -> applying.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/runtime_account_usage.dart';
import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart';
import 'agent_runtime_catalog.dart';
import 'agent_runtime_draft.dart';
import 'bulk_agent_model_change.dart';
import 'management_support.dart';
import 'resource_cards.dart' show resourceRelativeTime;
import 'runtime_usage_chip.dart';

Future<BulkModelReceipt?> showBulkAgentModelDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required Map<String, dynamic> machine,
  required List<String> agentIds,
  required bool Function() authorized,
  ValueChanged<String>? onOpenAgent,
  BulkModelReceipt? retry,
  DateTime Function()? now,
}) async {
  final identity = pageIdentity(controller);
  var revoked = false;
  bool current() =>
      !revoked && identity == pageIdentity(controller) && authorized();
  if (!context.mounted || !current()) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = raftFormRoute<BulkModelReceipt>(
    context,
    guardUnsaved: false,
    dialogMaxWidth: 672,
    builder: (_) => RaftModalBackdrop(
      child: BulkAgentModelDialog(
        controller: controller,
        machine: machine,
        agentIds: agentIds,
        current: current,
        retry: retry,
        now: now,
        onClose: ([receipt]) => navigator.pop(receipt),
        onOpenAgent: onOpenAgent == null
            ? null
            : (id) {
                navigator.pop();
                onOpenAgent(id);
              },
      ),
    ),
  );
  void changed() {
    if (!current()) {
      revoked = true;
      if (route.isActive) route.navigator?.removeRoute(route);
    }
  }

  controller.addListener(changed);
  try {
    final receipt = await navigator.push(route);
    return current() ? receipt : null;
  } finally {
    controller.removeListener(changed);
  }
}

enum _Step { choose, review, applying }

class BulkAgentModelDialog extends StatefulWidget {
  const BulkAgentModelDialog({
    super.key,
    required this.controller,
    required this.machine,
    required this.agentIds,
    required this.current,
    required this.onClose,
    this.onOpenAgent,
    this.retry,
    this.now,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> machine;
  final List<String> agentIds;
  final bool Function() current;
  final void Function([BulkModelReceipt? receipt]) onClose;
  final ValueChanged<String>? onOpenAgent;
  final BulkModelReceipt? retry;
  final DateTime Function()? now;
  @override
  State<BulkAgentModelDialog> createState() => _BulkAgentModelDialogState();
}

class _BulkAgentModelDialogState extends State<BulkAgentModelDialog> {
  WorkspaceController get w => widget.controller;
  DateTime _now() => widget.now?.call() ?? DateTime.now();
  bool get current => mounted && widget.current();
  List<Map<String, dynamic>> get agents => [
    for (final id in widget.agentIds)
      if (w.services.entityDirectory.agent(id) case final row?)
        if (row['machineId'] == widget.machine['id'] &&
            row['deletedAt'] == null)
          row,
  ];
  late final runtimes = [
    for (final value in widget.machine['runtimes'] as List? ?? const [])
      if (value is String && bulkSelectableRuntime(value)) value,
  ];
  late String runtime = _initialRuntime();
  late String modelChoice = widget.retry?.target.model ?? '';
  late String? reasoningChoice = widget.retry?.target.reasoning;
  _Step step = _Step.choose;
  RuntimeModelSource source = const RuntimeModelIdle();
  var sourceTicket = 0;
  bool checking = false;
  final allowed = <String, bool>{};
  final applyStates = <String, String>{};
  final usage = <String, Map<String, dynamic>?>{};
  BulkModelTarget? reviewedTarget;
  List<BulkModelRow>? applyingPlan;

  String _initialRuntime() {
    final retry = widget.retry?.target.runtime;
    if (retry != null && runtimes.contains(retry)) return retry;
    final counts = <String, int>{};
    for (final row in agents) {
      final id = row['runtime'];
      if (id is String && runtimes.contains(id)) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    String? best;
    for (final id in counts.keys) {
      if (best == null || counts[id]! > counts[best]!) best = id;
    }
    return best ?? runtimes.firstOrNull ?? '';
  }

  @override
  void initState() {
    super.initState();
    w.services.entityDirectory.addListener(_changed);
    _loadModels();
    if (canViewRuntimeUsage(w, widget.machine)) {
      for (final id in runtimes) {
        if (runtimeUsageProvider(id) case final provider?) {
          unawaited(() async {
            try {
              final result = await runtimeUsageClient(w)
                  .read(w.server!.id, widget.machine['id'] as String, provider);
              if (current) setState(() => usage[id] = result.snapshot);
            } catch (_) {
              // Optional usage never prevents a model change.
            }
          }());
        }
      }
    }
  }

  @override
  void dispose() {
    w.services.entityDirectory.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (current) setState(() {});
  }

  void _loadModels() {
    if (runtime.isEmpty) return;
    final ticket = ++sourceTicket, selectedRuntime = runtime;
    final identity = pageIdentity(w);
    final key = 'bulk-model:${widget.machine['id']}:$runtime:models';
    final cached = readPageSnapshot(w, key);
    final at = cached?['at'];
    if (cached?['source'] is RuntimeModelLive &&
        at is DateTime &&
        _now().difference(at).inSeconds < 60) {
      source = cached!['source'] as RuntimeModelLive;
      return;
    }
    source = runtimeModelLoadingFor(runtime);
    final Future<RuntimeModelSource> pending;
    if (cached?['pending'] case final Future<RuntimeModelSource> existing) {
      pending = existing;
    } else {
      late final Future<RuntimeModelSource> request;
      request = (() async {
        RuntimeModelSource next;
        try {
          next = parseRuntimeModelSourcePayload(
            await Future.sync(
              () => w.query(
                '/servers/${w.server!.id}/machines/${widget.machine['id']}/runtime-models/$selectedRuntime',
              ),
            ),
          );
        } catch (_) {
          next = const RuntimeModelError();
        }
        if (identity == pageIdentity(w) &&
            identical(readPageSnapshot(w, key)?['pending'], request)) {
          writePageSnapshot(w, key, identity, {
            if (next is RuntimeModelLive) 'source': next,
            if (next is RuntimeModelLive) 'at': _now(),
          });
        }
        return next;
      })();
      writePageSnapshot(w, key, identity, {'pending': request});
      pending = request;
    }
    unawaited(
      pending.then((next) {
        if (current && ticket == sourceTicket) setState(() => source = next);
      }),
    );
  }

  List<RuntimeModelInfo> get models =>
      projectRuntimeModels(runtime, source).models;
  String get model {
    if (models.any((m) => m.id == modelChoice)) return modelChoice;
    final preferred = source is RuntimeModelLive
        ? (source as RuntimeModelLive).defaultModel ??
              defaultRuntimeModel(runtime)
        : defaultRuntimeModel(runtime);
    return models.where((m) => m.id == preferred).firstOrNull?.id ??
        models.firstOrNull?.id ??
        '';
  }

  BulkModelTarget get target =>
      reviewedTarget ??
      BulkModelTarget(
        runtime,
        model,
        supportsRuntimeReasoning(runtime)
            ? reconcileReasoningEffort(runtime, model, reasoningChoice, models)
            : null,
      );
  List<BulkModelRow> get plan =>
      applyingPlan ??
      planBulkModelChange([
        for (final row in agents)
          BulkModelAgent(
            row,
            running: agentRowAmbientDisplay(row).activity != 'offline',
            targetRuntimeAllowed: allowed[row['id']],
            phase: widget.retry?.unfinished[row['id']],
          ),
      ], target);

  Future<void> _review() async {
    if (!current || checking) return;
    setState(() => checking = true);
    final chosenTarget = target;
    final selectedRuntime = runtime;
    final checks = await Future.wait([
      for (final row in agents)
        if (row['runtime'] != selectedRuntime)
          (() async {
            try {
              final value = await w.query(
                '/agents/${row['id']}/runtime-options',
              );
              final options = value is Map ? value['options'] : null;
              return (
                row['id'] as String,
                options is List &&
                    options.any(
                      (o) =>
                          o is Map &&
                          o['runtimeId'] == selectedRuntime &&
                          o['canSelectInThisContext'] == true,
                    ),
              );
            } catch (_) {
              return (row['id'] as String, false);
            }
          })(),
    ]);
    if (!current || selectedRuntime != runtime) return;
    setState(() {
      checking = false;
      reviewedTarget = chosenTarget;
      allowed
        ..clear()
        ..addEntries([for (final item in checks) MapEntry(item.$1, item.$2)]);
      step = _Step.review;
    });
  }

  Future<void> _apply() async {
    if (!current || step != _Step.review) return;
    final rows = plan, selectedTarget = target;
    setState(() {
      applyingPlan = rows;
      step = _Step.applying;
    });
    final executor = BulkModelExecutor(
      request: (method, path, {data}) =>
          method == 'GET' ? w.query(path) : w.command(method, path, data: data),
      current: () => current,
      acceptAgent: w.services.entityDirectory.agentUpdateReceiver(),
    );
    final receipt = await executor.apply(
      rows,
      selectedTarget,
      now: _now,
      stateChanged: (id, state) {
        if (current) setState(() => applyStates[id] = state);
      },
    );
    if (current && receipt != null) widget.onClose(receipt);
  }

  String? _usage(String id) {
    final accounts = usage[id]?['accounts'];
    if (accounts is! List || accounts.isEmpty || accounts.first is! Map) {
      return null;
    }
    final account = accounts.first as Map;
    final plan =
        account['planLabel'] as String? ?? raftText(context, 'Account');
    final windows = (account['windows'] as List? ?? const []).whereType<Map>();
    final limited = windows
        .where((w) => w['status'] == 'limit_reached')
        .firstOrNull;
    if (limited != null) {
      final reset = resourceRelativeTime(
        limited['resetsAt'] as String?,
        now: _now(),
        chinese: Localizations.localeOf(context).languageCode == 'zh',
      );
      return reset.isEmpty
          ? raftFormat(context, '{plan} · limit reached', {'plan': plan})
          : raftFormat(context, '{plan} · limit reached, resets {reset}', {
              'plan': plan,
              'reset': reset,
            });
    }
    if (account['health'] != 'ok') {
      return raftFormat(context, '{plan} · needs attention', {'plan': plan});
    }
    final ratios = [
      for (final w in windows)
        if (w['status'] == 'ok' && w['usedRatio'] is num) w['usedRatio'] as num,
    ];
    if (ratios.isEmpty) return null;
    final peak = ratios.reduce((a, b) => a > b ? a : b);
    return raftFormat(context, '{plan} · {percent}% used', {
      'plan': plan,
      'percent': (peak * 100).round(),
    });
  }

  Widget _choose() {
    final reasoning = reasoningOptionsForModel(runtime, model, models);
    Widget field(String label, Widget input) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftCssText(label),
        const SizedBox(height: RaftSpace.x1_5),
        input,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (runtimes.isEmpty)
          const RaftAgentFieldNote(
            'No runtime on this computer can be changed in bulk.',
          )
        else ...[
          field(
            'Runtime',
            RaftAgentSelect<String>(
              key: const ValueKey('bulk-model-runtime'),
              value: runtime,
              semanticLabel: raftText(context, 'Runtime'),
              options: [
                for (final id in runtimes)
                  RaftAgentSelectOption(
                    id,
                    [runtimeName(id), ?_usage(id)].join(' · '),
                  ),
              ],
              onChanged: checking
                  ? null
                  : (id) => setState(() {
                      runtime = id;
                      modelChoice = '';
                      allowed.clear();
                      _loadModels();
                    }),
            ),
          ),
          const SizedBox(height: RaftSpace.x1_5),
          RaftAgentFieldNote(
            raftFormat(
              context,
              'Uses the {runtime} account signed in on this computer.',
              {'runtime': runtimeName(runtime)},
            ),
          ),
          const SizedBox(height: RaftSpace.x4),
          field(
            'Model',
            RaftAgentSelect<String>(
              key: const ValueKey('bulk-model-model'),
              value: model,
              semanticLabel: raftText(context, 'Model'),
              placeholder: 'Loading models…',
              options: [
                for (final m in models) RaftAgentSelectOption(m.id, m.label),
              ],
              onChanged: checking
                  ? null
                  : (id) => setState(() => modelChoice = id),
            ),
          ),
          if (supportsRuntimeReasoning(runtime) && model.isNotEmpty) ...[
            const SizedBox(height: RaftSpace.x4),
            field(
              'Reasoning',
              RaftAgentSelect<String>(
                key: const ValueKey('bulk-model-reasoning'),
                value: target.reasoning ?? '__default__',
                semanticLabel: raftText(context, 'Reasoning'),
                options: [
                  RaftAgentSelectOption(
                    '__default__',
                    raftText(context, 'Default'),
                  ),
                  for (final (id, label) in reasoning)
                    RaftAgentSelectOption(id, raftText(context, label)),
                ],
                onChanged: checking
                    ? null
                    : (id) => setState(
                        () => reasoningChoice = id == '__default__' ? null : id,
                      ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _row(BulkModelRow row, {bool applying = false}) {
    final agent = row.agent.value, selectedTarget = target;
    final from = bulkModelLabel(
      row.agent.runtime,
      '${agent['model'] ?? ''}',
      withRuntime: row.agent.runtime != runtime,
    );
    final to = bulkModelLabel(
      runtime,
      selectedTarget.model,
      withRuntime: row.agent.runtime != runtime,
    );
    final reason = switch (row.skip) {
      BulkModelSkip.customSettings => 'Custom settings',
      BulkModelSkip.runtimeUnavailable => 'Not available',
      BulkModelSkip.noChange => 'No change',
      null => null,
    };
    return Padding(
      key: ValueKey('bulk-model-row-${row.agent.id}'),
      padding: const EdgeInsets.symmetric(vertical: RaftSpace.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RaftAvatarSlot(
                name: agentRowName(agent),
                avatarUrl: agent['avatarUrl'] as String?,
                slot: RaftAvatarSlotContext.compactList,
              ),
              const SizedBox(width: RaftSpace.x2),
              Expanded(child: RaftCssText(agentRowName(agent))),
            ],
          ),
          const SizedBox(height: RaftSpace.x1_5),
          if (applying)
            RaftCssText(switch (applyStates[row.agent.id]) {
              'saved' => 'Saved',
              'failed' => "Didn't finish",
              _ => 'Saving…',
            }, key: ValueKey('bulk-model-apply-${row.agent.id}'))
          else ...[
            RaftCssText(
              row.action == BulkModelAction.restartOnly ? to : '$from → $to',
            ),
            if (reason != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: RaftSpace.x2,
                children: [
                  RaftCssText(reason),
                  if (row.skip != BulkModelSkip.noChange &&
                      widget.onOpenAgent != null)
                    RaftAgentDialogButton(
                      label: raftText(context, 'Edit'),
                      size: RaftButtonRecipeSize.sm,
                      onPressed: () => widget.onOpenAgent!(row.agent.id),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = plan;
    final count = rows.where((r) => r.action != BulkModelAction.skip).length;
    final restarts = rows.where((r) => r.restarts).length;
    final busy = step == _Step.applying;
    String plural(String one, String many, int value) =>
        raftFormat(context, value == 1 ? one : many, {'count': value});
    return PopScope(
      canPop: !busy,
      child: RaftAgentDialogCard(
        key: const ValueKey('bulk-change-model-dialog'),
        bare: true,
        plainCard: true,
        maxWidth: 672,
        title: busy
            ? plural(
                'Changing {count} agent…',
                'Changing {count} agents…',
                count,
              )
            : plural(
                'Change model for {count} agent',
                'Change model for {count} agents',
                agents.length,
              ),
        onClose: busy ? null : () => widget.onClose(),
        footer: busy
            ? null
            : RaftAgentDialogFooter(
                children: [
                  if (step == _Step.review)
                    RaftAgentDialogButton(
                      label: raftText(context, 'Back'),
                      size: RaftButtonRecipeSize.sm,
                      onPressed: () => setState(() {
                        reviewedTarget = null;
                        step = _Step.choose;
                      }),
                    ),
                  RaftAgentDialogButton(
                    label: raftText(context, 'Cancel'),
                    size: RaftButtonRecipeSize.sm,
                    onPressed: checking ? null : () => widget.onClose(),
                  ),
                  RaftAgentDialogButton(
                    key: ValueKey(
                      step == _Step.choose
                          ? 'bulk-model-next'
                          : 'bulk-model-apply',
                    ),
                    label: step == _Step.choose
                        ? raftText(context, 'Next')
                        : plural(
                            'Change {count} agent',
                            'Change {count} agents',
                            count,
                          ),
                    primary: true,
                    busy: checking,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: step == _Step.choose
                        ? checking || runtime.isEmpty || model.isEmpty
                              ? null
                              : _review
                        : count == 0
                        ? null
                        : _apply,
                  ),
                ],
              ),
        children: [
          if (!busy) ...[
            RaftCssText(
              '${raftText(context, 'Choose model')} → ${raftText(context, 'Review')}',
            ),
            const SizedBox(height: RaftSpace.x4),
          ],
          if (step == _Step.choose)
            _choose()
          else ...[
            for (final row in rows)
              if (!busy || row.action != BulkModelAction.skip)
                _row(row, applying: busy),
            if (!busy && restarts > 0)
              RaftAgentFieldNote(
                plural(
                  '{count} running agent will restart.',
                  '{count} running agents will restart.',
                  restarts,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
