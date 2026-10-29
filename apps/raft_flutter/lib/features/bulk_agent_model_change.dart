// Web v1.21.12 machine/bulkChangeModelPlan.ts and the dialog's apply step.
// No UI or transport ownership: planning and execution are independently testable.
import 'agent_runtime_draft.dart';
import 'agent_runtime_catalog.dart';

const bulkModelFlag = 'bulk_change_model_web_v0';

class BulkModelTarget {
  const BulkModelTarget(this.runtime, this.model, this.reasoning);
  final String runtime, model;
  final String? reasoning;
  bool matches(Map agent) =>
      agent['runtime'] == runtime &&
      agent['model'] == model &&
      agent['reasoningEffort'] == reasoning;
}

enum BulkUnfinishedPhase { saveFailed, restartPending }

class BulkModelAgent {
  const BulkModelAgent(
    this.value, {
    required this.running,
    this.targetRuntimeAllowed,
    this.phase,
  });
  final Map<String, dynamic> value;
  final bool running;
  final bool? targetRuntimeAllowed;
  final BulkUnfinishedPhase? phase;
  String get id => value['id'] as String;
  String get runtime => value['runtime'] as String? ?? '';
}

enum BulkModelAction { change, restartOnly, skip }

enum BulkModelSkip { customSettings, runtimeUnavailable, noChange }

class BulkModelRow {
  const BulkModelRow(
    this.agent,
    this.action, {
    this.restarts = false,
    this.skip,
  });
  final BulkModelAgent agent;
  final BulkModelAction action;
  final bool restarts;
  final BulkModelSkip? skip;
}

bool bulkSelectableRuntime(String runtime) =>
    !const {'builtin', 'pi', 'kimi-sdk'}.contains(runtime) &&
    !runtimeIgnoresModel(runtime);

bool bulkAgentRebuildable(BulkModelAgent agent) {
  if (agent.value['external'] == true ||
      !bulkSelectableRuntime(agent.runtime)) {
    return false;
  }
  final config = agent.value['runtimeConfig'];
  if (config == null) return true;
  if (config is! Map || config['runtime'] != agent.runtime) return false;
  final model = config['model'], provider = config['provider'];
  if (model is! Map || model['kind'] != 'preset') return false;
  if (provider != null && (provider is! Map || provider['kind'] != 'default')) {
    return false;
  }
  return config['command'] is! String ||
      (config['command'] as String).trim().isEmpty;
}

List<BulkModelRow> planBulkModelChange(
  List<BulkModelAgent> agents,
  BulkModelTarget target,
) => [
  for (final agent in agents)
    if (agent.phase == BulkUnfinishedPhase.restartPending &&
        target.matches(agent.value))
      BulkModelRow(agent, BulkModelAction.restartOnly, restarts: true)
    else if (!bulkAgentRebuildable(agent))
      BulkModelRow(
        agent,
        BulkModelAction.skip,
        skip: BulkModelSkip.customSettings,
      )
    else if (agent.runtime != target.runtime &&
        agent.targetRuntimeAllowed == false)
      BulkModelRow(
        agent,
        BulkModelAction.skip,
        skip: BulkModelSkip.runtimeUnavailable,
      )
    else if (target.matches(agent.value))
      BulkModelRow(agent, BulkModelAction.skip, skip: BulkModelSkip.noChange)
    else
      BulkModelRow(agent, BulkModelAction.change, restarts: agent.running),
];

Map<String, dynamic> buildBulkAgentUpdate(
  BulkModelAgent agent,
  BulkModelTarget target,
) {
  final config = agent.value['runtimeConfig'];
  final mode = config is Map ? config['mode'] : null;
  final env = config is Map
      ? config['envVars'] ?? agent.value['envVars']
      : agent.value['envVars'];
  final draft = RuntimeDraft(
    runtime: target.runtime,
    model: target.model,
    reasoning: target.reasoning,
    fastMode:
        agent.runtime == target.runtime &&
        mode is Map &&
        mode['kind'] == 'fast',
    envVars: [
      if (env is Map)
        for (final entry in env.entries)
          MapEntry('${entry.key}', '${entry.value}'),
    ],
  );
  return {
    'runtime': target.runtime,
    'model': target.model,
    'reasoningEffort': target.reasoning,
    'runtimeConfig': draft.buildRuntimeConfig(),
  };
}

String bulkModelLabel(
  String runtime,
  String model, {
  bool withRuntime = false,
}) {
  final label = runtimeModelLabel(runtime, model);
  return withRuntime ? '${runtimeName(runtime)} · $label' : label;
}

String runtimeName(String runtime) =>
    runtimeInfos.where((info) => info.id == runtime).firstOrNull?.name ??
    runtime;

/// Memory-only, owned by the account/server/role page snapshot. Absolute
/// deadlines prevent success banners or highlights replaying on a revisit.
class BulkModelReceipt {
  BulkModelReceipt({
    required this.target,
    required this.total,
    required List<String> changed,
    required List<String> skipped,
    required Map<String, BulkUnfinishedPhase> unfinished,
    required DateTime now,
  }) : changed = List.unmodifiable(changed),
       skipped = List.unmodifiable(skipped),
       unfinished = Map.unmodifiable(unfinished),
       bannerUntil = now.add(const Duration(seconds: 5)),
       highlightUntil = now.add(const Duration(seconds: 3));
  final BulkModelTarget target;
  final int total;
  final List<String> changed, skipped;
  final Map<String, BulkUnfinishedPhase> unfinished;
  final DateTime bannerUntil, highlightUntil;
  bool get success => unfinished.isEmpty;
  bool visibleAt(DateTime now) => !success || now.isBefore(bannerUntil);
  Set<String> highlightsAt(DateTime now) =>
      now.isBefore(highlightUntil) ? changed.toSet() : const {};
}

typedef BulkModelRequest = Future<dynamic> Function(
  String method,
  String path, {
  dynamic data,
});

/// Each PATCH uses the same server contract as the single-agent editor. A
/// failed PATCH may already have saved: only a fresh GET can classify it.
class BulkModelExecutor {
  const BulkModelExecutor({
    required this.request,
    required this.current,
    required this.acceptAgent,
  });
  final BulkModelRequest request;
  final bool Function() current;
  final void Function(Map<String, dynamic>) acceptAgent;

  Future<BulkModelReceipt?> apply(
    List<BulkModelRow> plan,
    BulkModelTarget target, {
    required DateTime Function() now,
    required void Function(String id, String state) stateChanged,
  }) async {
    final applying = [
      for (final row in plan)
        if (row.action != BulkModelAction.skip) row,
    ];
    if (!current() || applying.isEmpty) return null;
    final unfinished = <String, BulkUnfinishedPhase>{};
    final changed = <String>{};
    await Future.wait([
      for (final row in applying)
        (() async {
          if (!current()) return;
          final id = row.agent.id;
          stateChanged(id, 'saving');
          try {
            if (row.action == BulkModelAction.restartOnly) {
              await request(
                'POST',
                '/agents/$id/reset',
                data: {'mode': 'restart'},
              );
            } else {
              final value = await request(
                'PATCH',
                '/agents/$id',
                data: {
                  ...buildBulkAgentUpdate(row.agent, target),
                  if (row.restarts) 'restartMode': 'restart',
                },
              );
              if (current() && value is Map && value['id'] == id) {
                acceptAgent(Map<String, dynamic>.from(value));
              }
            }
            if (!current()) return;
            changed.add(id);
            stateChanged(id, 'saved');
          } catch (_) {
            if (!current()) return;
            var phase = row.action == BulkModelAction.restartOnly
                ? BulkUnfinishedPhase.restartPending
                : BulkUnfinishedPhase.saveFailed;
            try {
              final fresh = await request('GET', '/agents/$id');
              if (!current()) return;
              if (fresh is Map && fresh['id'] == id) {
                acceptAgent(Map<String, dynamic>.from(fresh));
                phase = target.matches(fresh)
                    ? BulkUnfinishedPhase.restartPending
                    : BulkUnfinishedPhase.saveFailed;
              }
            } catch (_) {
              // An unreadable fresh state preserves restart-only knowledge.
            }
            if (!current()) return;
            unfinished[id] = phase;
            stateChanged(id, 'failed');
          }
        })(),
    ]);
    if (!current()) return null;
    return BulkModelReceipt(
      target: target,
      total: applying.length,
      changed: [
        for (final row in applying)
          if (changed.contains(row.agent.id)) row.agent.id,
      ],
      skipped: [
        for (final row in plan)
          if (row.action == BulkModelAction.skip) row.agent.id,
      ],
      unfinished: {
        for (final row in applying) row.agent.id: ?unfinished[row.agent.id],
      },
      now: now(),
    );
  }
}
