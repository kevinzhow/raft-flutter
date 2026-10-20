// The pure side of the agent "Edit runtime config" modal when the server's
// `runtime_form_v2_web` flag is off (Web `RuntimeConfigFields` legacy fields +
// AgentDetailPanel draft state, utils/runtimeConfigForm.ts,
// hooks/useRuntimeModels.ts, utils/reasoningEffortOptions.ts): hydrate the
// draft from the agent, the machine model source states, reasoning
// reconciliation, change / validity gates and the runtimeConfig payload.
//
// Built-in Pi, Pi and Kimi Code carry provider machinery (connections, API
// keys, gateways, schema forms) of their own; those runtimes stay on the
// protocol-v2 form (see [legacyRuntimeEditorSupports]).
import '../data/runtime_config.dart';
import '../data/runtime_error.dart' show runtimeModelLookupReasons;
import 'agent_runtime_catalog.dart';

/// Runtimes whose settings the legacy editor can present and save.
bool legacyRuntimeEditorSupports(String runtime) =>
    !const {'builtin', 'pi', 'kimi-sdk', 'external'}.contains(runtime);

// One definition of the supported-runtime sets: data/runtime_config.dart.
bool supportsRuntimeApiUrl(String runtime) => runtimeSupportsApiUrl(runtime);
bool supportsRuntimeCommand(String runtime) => runtimeSupportsCommand(runtime);
bool supportsRuntimeFastMode(String runtime) =>
    runtimeSupportsFastMode(runtime);
bool supportsRuntimeReasoning(String runtime) =>
    runtimeSupportsReasoning(runtime);

/// `supportsRuntimeCustomModelName`.
bool supportsRuntimeCustomModelName(String runtime) => const {
  'builtin',
  'claude',
  'codex',
  'cursor',
  'copilot',
  'pi',
}.contains(runtime);

/// Antigravity owns model selection internally (`runtimeIgnoresModel`).
bool runtimeIgnoresModel(String runtime) => runtime == 'antigravity';

/// `getDefaultModel`.
String defaultRuntimeModel(String runtime) =>
    runtimeModelCatalog[runtime]?.firstOrNull?.id ?? 'sonnet';

/// `getModelLabel`: the catalog label, else the raw id.
String runtimeModelLabel(String runtime, String model) =>
    runtimeModelCatalog[runtime]
        ?.where((m) => m.id == model)
        .firstOrNull
        ?.label ??
    model;

const customModelSelectValue = '__custom__';

// ------------------------------------------------------------ model sources

/// `RuntimeModelSourceState`.
sealed class RuntimeModelSource {
  const RuntimeModelSource();
}

class RuntimeModelIdle extends RuntimeModelSource {
  const RuntimeModelIdle();
}

class RuntimeModelLoading extends RuntimeModelSource {
  const RuntimeModelLoading([this.previous]);

  /// A declared static catalog stays visible while the Computer confirms it.
  final List<RuntimeModelInfo>? previous;
}

class RuntimeModelLive extends RuntimeModelSource {
  const RuntimeModelLive(this.models, [this.defaultModel]);
  final List<RuntimeModelInfo> models;
  final String? defaultModel;
}

/// `missing_config` / `no_models` / `unsupported`.
class RuntimeModelNonLive extends RuntimeModelSource {
  const RuntimeModelNonLive(this.kind, [this.recovery]);
  final String kind;
  final String? recovery;
}

class RuntimeModelError extends RuntimeModelSource {
  const RuntimeModelError({this.retryable = true, this.code, this.reason});
  final bool retryable;
  final String? code;

  /// How the daemon's lookup ended, beside `runtime_not_found`. Absent on old
  /// daemons and unknown values: that is "unconfirmed", never "not installed".
  final String? reason;
}

const _detectionErrorCodes = {
  'runtime_not_found',
  'runtime_not_authenticated',
  'detect_timeout',
  'protocol_unsupported',
  'detect_failed',
  'computer_offline',
};

RuntimeModelInfo _parseModel(Map<dynamic, dynamic> m) => RuntimeModelInfo(
  id: '${m['id']}',
  label: '${m['label'] ?? m['id']}',
  supportedReasoningEfforts: m['supportedReasoningEfforts'] is List
      ? [for (final e in m['supportedReasoningEfforts'] as List) '$e']
      : null,
  defaultReasoningEffort: m['defaultReasoningEffort'] as String?,
  verified: m['verified'] as String?,
);

RuntimeModelSource _fromSet(List models, String? defaultModel) => models.isEmpty
    ? const RuntimeModelNonLive('no_models')
    : RuntimeModelLive([
        for (final m in models.whereType<Map>()) _parseModel(m),
      ], defaultModel);

/// `parseRuntimeModelSourcePayload`: the typed outcome payload and the old
/// `{models, default}` one.
RuntimeModelSource parseRuntimeModelSourcePayload(Object? payload) {
  if (payload is! Map) return const RuntimeModelError();
  final kind = payload['kind'];
  if (kind == 'live') {
    final value = payload['value'];
    if (value is! Map || value['models'] is! List) {
      return const RuntimeModelError();
    }
    return _fromSet(
      value['models'] as List,
      value['default'] is String ? value['default'] as String : null,
    );
  }
  if (kind == 'missing_config' || kind == 'no_models') {
    return RuntimeModelNonLive(
      kind as String,
      payload['recovery'] is String ? payload['recovery'] as String : null,
    );
  }
  if (kind == 'unsupported') return const RuntimeModelNonLive('unsupported');
  if (kind == 'error') {
    return RuntimeModelError(
      retryable: payload['retryable'] != false,
      code: _detectionErrorCodes.contains(payload['code'])
          ? payload['code'] as String
          : null,
      reason: runtimeModelLookupReasons.contains(payload['reason'])
          ? payload['reason'] as String
          : null,
    );
  }
  if (payload['models'] is List) {
    return _fromSet(
      payload['models'] as List,
      payload['default'] is String ? payload['default'] as String : null,
    );
  }
  return const RuntimeModelError();
}

/// `runtimeModelFallbackOptions`: a known model stays editable without
/// claiming it can launch.
List<RuntimeModelInfo> runtimeModelFallbackOptions(
  String runtime,
  RuntimeModelSource source,
) {
  if (runtime == 'builtin' ||
      runtime == 'pi' ||
      source is RuntimeModelLive ||
      source is RuntimeModelLoading ||
      source is RuntimeModelIdle) {
    return const [];
  }
  return [
    for (final m in runtimeModelCatalog[runtime] ?? const <RuntimeModelInfo>[])
      RuntimeModelInfo(
        id: m.id,
        label: m.label,
        supportedReasoningEfforts: m.supportedReasoningEfforts,
        defaultReasoningEffort: m.defaultReasoningEffort,
        verified: 'suggestion_only',
      ),
  ];
}

/// `canonicalizeCodexPresentation`: bundled order first for Codex.
List<RuntimeModelInfo> _canonicalCodex(
  String runtime,
  List<RuntimeModelInfo> models,
) {
  if (runtime != 'codex') return models;
  final order = [for (final m in runtimeModelCatalog['codex']!) m.id];
  int rank(String id) {
    final i = order.indexOf(id);
    return i == -1 ? 1 << 30 : i;
  }

  final indexed = [for (var i = 0; i < models.length; i++) (i, models[i])]
    ..sort((a, b) {
      final d = rank(a.$2.id) - rank(b.$2.id);
      return d != 0 ? d : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// `projectRuntimeModelSourcePresentation`.
({List<RuntimeModelInfo> models, bool loading, bool live}) projectRuntimeModels(
  String runtime,
  RuntimeModelSource source,
) {
  final value = switch (source) {
    RuntimeModelLive(:final models) => models,
    RuntimeModelLoading(:final previous) => previous,
    _ => null,
  };
  if (value == null) {
    return (
      models: runtimeModelFallbackOptions(runtime, source),
      loading: source is RuntimeModelLoading,
      live: false,
    );
  }
  return (
    models: _canonicalCodex(runtime, value),
    loading: source is RuntimeModelLoading,
    live: source is RuntimeModelLive,
  );
}

/// The state a (re)scan starts in: a static catalog stays visible.
RuntimeModelSource runtimeModelLoadingFor(String runtime) =>
    RuntimeModelLoading(staticRuntimeModelSources[runtime]);

/// `runtimeModelSelectionIsRunnable`: form eligibility only.
bool runtimeModelSelectionIsRunnable({
  required String runtime,
  required RuntimeModelSource source,
  required String model,
  required bool customMode,
  required bool customAllowed,
  String? persistedModel,
}) {
  if (runtimeIgnoresModel(runtime)) return true;
  final trimmed = model.trim();
  if (trimmed.isEmpty) return false;
  if (customMode) return customAllowed;
  if (source is RuntimeModelLive) {
    if (source.models.any((m) => m.id == trimmed)) return true;
    return customAllowed && persistedModel == trimmed;
  }
  return runtimeModelFallbackOptions(
    runtime,
    source,
  ).any((m) => m.id == trimmed);
}

// ---------------------------------------------------------------- reasoning

RuntimeModelInfo? _resolveModel(
  String runtime,
  String model,
  List<RuntimeModelInfo> live,
) {
  final found = live.where((m) => m.id == model).firstOrNull;
  if (found?.supportedReasoningEfforts?.isNotEmpty == true) return found;
  final stat = runtimeModelCatalog[runtime]
      ?.where((m) => m.id == model)
      .firstOrNull;
  return stat ?? found;
}

/// `reasoningEffortOptionsForModel`: (id, label) in ladder order.
List<(String, String)> reasoningOptionsForModel(
  String runtime,
  String model,
  List<RuntimeModelInfo> live,
) {
  final supported = _resolveModel(
    runtime,
    model,
    live,
  )?.supportedReasoningEfforts;
  return [
    for (final e in reasoningEfforts)
      if (supported != null && supported.isNotEmpty
          ? supported.contains(e.$1)
          : baseReasoningEfforts.contains(e.$1))
        e,
  ];
}

/// `reconcileReasoningEffort`.
String? reconcileReasoningEffort(
  String runtime,
  String model,
  String? current,
  List<RuntimeModelInfo> live,
) {
  final info = _resolveModel(runtime, model, live);
  final supported = info?.supportedReasoningEfforts;
  if (supported == null || supported.isEmpty) return current;
  if (current != null && supported.contains(current)) return current;
  final fallback = info?.defaultReasoningEffort;
  return fallback != null && supported.contains(fallback) ? fallback : null;
}

// -------------------------------------------------------------------- draft

/// The editor's drafted values (AgentDetailPanel `draft*` state).
class RuntimeDraft {
  RuntimeDraft({
    required this.runtime,
    required this.model,
    this.customModelMode = false,
    this.providerCustom = false,
    this.providerApiUrl = '',
    this.providerApiKey = '',
    this.fastMode = false,
    this.command = '',
    this.reasoning,
    List<MapEntry<String, String>>? envVars,
  }) : envVars = envVars ?? [];

  String runtime, model;
  bool customModelMode, providerCustom, fastMode;
  String providerApiUrl, providerApiKey, command;
  String? reasoning;
  List<MapEntry<String, String>> envVars;

  RuntimeDraft copy() => RuntimeDraft(
    runtime: runtime,
    model: model,
    customModelMode: customModelMode,
    providerCustom: providerCustom,
    providerApiUrl: providerApiUrl,
    providerApiKey: providerApiKey,
    fastMode: fastMode,
    command: command,
    reasoning: reasoning,
    envVars: [...envVars],
  );

  /// `hydrateRuntimeConfigForm(agent)` -> the draft seed: the shared
  /// [RuntimeConfig.fromAgent] (structured runtimeConfig, flat columns as the
  /// fallback) so the editor opens on exactly what the profile shows.
  factory RuntimeDraft.hydrate(Map<String, dynamic> agent) {
    final config = RuntimeConfig.fromAgent(agent);
    return RuntimeDraft(
      runtime: config.runtime,
      model: config.model,
      customModelMode: config.customModel,
      providerCustom: config.customProvider,
      providerApiUrl: config.providerApiUrl,
      providerApiKey: config.customProvider ? config.apiKey : '',
      fastMode: config.fastMode,
      command: config.commandText,
      reasoning: config.reasoningEffort,
      envVars: [
        for (final e in config.envVarMap.entries) MapEntry(e.key, e.value),
      ],
    );
  }

  /// `draftEnvVars`: trimmed non-empty keys, null when none.
  Map<String, String>? get envVarMap {
    final next = <String, String>{};
    for (final e in envVars) {
      final key = e.key.trim();
      if (key.isNotEmpty) next[key] = e.value;
    }
    return next.isEmpty ? null : next;
  }

  /// Web `runtimeConfigChanged` (the fields the legacy editor edits).
  bool changedFrom(RuntimeDraft base) =>
      runtime != base.runtime ||
      model != base.model ||
      customModelMode != base.customModelMode ||
      providerCustom != base.providerCustom ||
      providerApiUrl.trim() != base.providerApiUrl ||
      providerApiKey.trim() != base.providerApiKey ||
      fastMode != base.fastMode ||
      command.trim() != base.command ||
      (reasoning) != (base.reasoning) ||
      _envJson(envVarMap) != _envJson(base.envVarMap);

  static String _envJson(Map<String, String>? map) {
    if (map == null) return 'null';
    final keys = map.keys.toList();
    return keys.map((k) => '$k=${map[k]}').join('\u0000');
  }

  /// Whether the environment variables differ from [base]'s.
  static bool envChanged(RuntimeDraft a, RuntimeDraft base) =>
      _envJson(a.envVarMap) != _envJson(base.envVarMap);

  bool get apiUrlRequired => supportsRuntimeApiUrl(runtime) && providerCustom;
  static final _httpUrl = RegExp(r'^https?://', caseSensitive: false);
  bool get apiUrlInvalid => apiUrlRequired
      ? !_httpUrl.hasMatch(providerApiUrl.trim())
      : providerApiUrl.trim().isNotEmpty &&
            !_httpUrl.hasMatch(providerApiUrl.trim());
  bool get apiKeyInvalid => apiUrlRequired && providerApiKey.trim().isEmpty;
  bool get customModelInvalid => customModelMode && model.trim().isEmpty;

  /// `buildRuntimeConfig` for the runtimes the legacy editor covers.
  Map<String, dynamic> buildRuntimeConfig() {
    final customName = model.trim();
    return {
      'version': runtimeConfigVersion,
      'runtime': runtime,
      if (supportsRuntimeApiUrl(runtime))
        'provider': providerCustom
            ? {
                'kind': 'custom',
                'apiUrl': providerApiUrl.trim(),
                'apiKey': providerApiKey.trim(),
              }
            : {'kind': 'default'},
      'model': customModelMode
          ? {
              'kind': 'custom',
              'name': customName.isEmpty
                  ? defaultRuntimeModel(runtime)
                  : customName,
            }
          : {
              'kind': 'preset',
              'id': model.isEmpty ? defaultRuntimeModel(runtime) : model,
            },
      'mode': {
        'kind': fastMode && supportsRuntimeFastMode(runtime)
            ? 'fast'
            : 'default',
      },
      'reasoningEffort': supportsRuntimeReasoning(runtime) ? reasoning : null,
      'envVars': envVarMap,
      if (supportsRuntimeCommand(runtime) && command.trim().isNotEmpty)
        'command': command.trim(),
    };
  }
}

/// `isRuntimeConfigSaveDisabled`.
bool runtimeConfigSaveDisabled({
  required bool saving,
  required bool changed,
  required bool runtimeCanSelect,
  required bool providerApiUrlInvalid,
  required bool providerApiKeyInvalid,
  required bool customModelInvalid,
  required bool modelSourceInvalid,
}) =>
    saving ||
    !changed ||
    !runtimeCanSelect ||
    providerApiUrlInvalid ||
    providerApiKeyInvalid ||
    customModelInvalid ||
    modelSourceInvalid;

/// Web `runtimeAvailabilitySuffix` kind: `none`, `comingSoon`,
/// `updateComputer` or `notInstalled`.
String runtimeAvailabilityKind(String runtime, List<String> machineRuntimes) {
  final info = runtimeInfos.where((r) => r.id == runtime).firstOrNull;
  if (info == null) return 'none';
  if (!info.supported) return 'comingSoon';
  if (machineRuntimes.contains(info.id)) return 'none';
  return info.binary.isEmpty ? 'updateComputer' : 'notInstalled';
}

/// `getExistingAgentRuntimeOptions`: deprecated runtimes only for their own.
List<({String id, String name, String binary, bool supported, bool deprecated})>
existingAgentRuntimeOptions(String current) => [
  for (final r in runtimeInfos)
    if (!r.deprecated || r.id == current) r,
];
