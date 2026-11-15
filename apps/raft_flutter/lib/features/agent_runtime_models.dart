// The pure model side of the agent runtime surfaces (Web
// hooks/useRuntimeModels.ts, utils/reasoningEffortOptions.ts): what a
// Computer reports for `GET /servers/:id/machines/:mid/runtime-models/:runtime`
// (the live list, the models it marked unavailable, how fresh the answer is),
// the projection a picker shows, and the reasoning-effort rules. The runtime
// editor itself is the server-described form (runtime_form_dialog.dart); this
// file serves the bulk model change and the profile's model label.
import '../data/runtime_error.dart' show runtimeModelLookupReasons;
import 'agent_runtime_catalog.dart';

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
  const RuntimeModelLive(
    this.models, [
    this.defaultModel,
    this.unavailable = const [],
    this.catalog,
  ]);
  final List<RuntimeModelInfo> models;
  final String? defaultModel;

  /// `RuntimeModelSet.unavailable`: models the runtime listed but marked not
  /// usable now. Never part of [models]: they are shown disabled.
  final List<RuntimeModelUnavailable> unavailable;

  /// `RuntimeModelSet.catalog`: proof the list came from the Built-in
  /// runtime's own versioned catalog. Null when absent or malformed.
  final RuntimeModelCatalogCapability? catalog;
}

/// `RuntimeModelUnavailable`: a model the Computer's runtime listed as
/// disabled; [reason] is the runtime's own untrusted text (plain text, may be
/// empty).
class RuntimeModelUnavailable {
  const RuntimeModelUnavailable({
    required this.id,
    required this.label,
    required this.reason,
  });
  final String id, label, reason;
}

/// `RuntimeModelCatalogCapability` (protocol 1, Built-in only).
class RuntimeModelCatalogCapability {
  const RuntimeModelCatalogCapability({
    required this.runtimeVersion,
    this.customModelProviderIds = const [],
  });
  final String runtimeVersion;

  /// The preset providers for which this Computer runs a typed model id
  /// outside the catalog; absent on older Computers means none.
  final List<String> customModelProviderIds;
}

/// How the server answered (`RuntimeModelFreshness`): the Computer's answer
/// (`ok`), its last list because it did not answer in time (`stale`, received
/// at [fetchedAt]), or nothing in time (`unavailable`). An older server sends
/// none: ok.
class RuntimeModelFreshness {
  const RuntimeModelFreshness._(this.state, [this.fetchedAt]);
  static const ok = RuntimeModelFreshness._('ok');
  static const unavailable = RuntimeModelFreshness._('unavailable');
  final String state;
  final String? fetchedAt;
  bool get isOk => state == 'ok';
}

/// `parseRuntimeModelFreshness`: the additive `freshness` object beside the
/// model source in the same response body.
RuntimeModelFreshness parseRuntimeModelFreshness(Object? payload) {
  final freshness = payload is Map ? payload['freshness'] : null;
  if (freshness is! Map) return RuntimeModelFreshness.ok;
  final state = freshness['state'], fetchedAt = freshness['fetchedAt'];
  if (state == 'stale') {
    return RuntimeModelFreshness._(
      'stale',
      fetchedAt is String ? fetchedAt : null,
    );
  }
  if (state == 'unavailable') return RuntimeModelFreshness.unavailable;
  return RuntimeModelFreshness.ok;
}

/// One answer of the model-list read: the source and how fresh it is
/// (`RuntimeModelLoad`).
typedef RuntimeModelLoad = ({
  RuntimeModelSource source,
  RuntimeModelFreshness freshness,
});

/// `parseRuntimeModelSourcePayload` + `parseRuntimeModelFreshness` of one
/// response body.
RuntimeModelLoad parseRuntimeModelLoad(Object? payload) => (
  source: parseRuntimeModelSourcePayload(payload),
  freshness: parseRuntimeModelFreshness(payload),
);

/// Only a fresh live list is worth sharing between readers
/// (`sharedRuntimeModelSource`): a stale or unavailable answer asks again.
bool runtimeModelLoadReusable(RuntimeModelLoad load) =>
    load.source is RuntimeModelLive && load.freshness.isOk;

const _unavailableMaxEntries = 50;
const _unavailableMaxText = 200;

String _boundedRuntimeText(String value) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > _unavailableMaxText
      ? '${text.substring(0, _unavailableMaxText - 1)}…'
      : text;
}

/// `sanitizeRuntimeModelUnavailable`: well-formed entries only, whitespace
/// collapsed, text capped at 200 characters, ids de-duplicated, at most 50
/// entries. Plain text only (nothing is interpreted).
List<RuntimeModelUnavailable> sanitizeRuntimeModelUnavailable(Object? value) {
  if (value is! List) return const [];
  final entries = <RuntimeModelUnavailable>[];
  final seen = <String>{};
  for (final candidate in value) {
    if (entries.length >= _unavailableMaxEntries) break;
    if (candidate is! Map) continue;
    final id = candidate['id'], label = candidate['label'];
    final reason = candidate['reason'];
    if (id is! String ||
        id.trim().isEmpty ||
        id.length > _unavailableMaxText ||
        !seen.add(id)) {
      continue;
    }
    entries.add(
      RuntimeModelUnavailable(
        id: id,
        label: label is String && label.trim().isNotEmpty
            ? _boundedRuntimeText(label)
            : id,
        reason: reason is String ? _boundedRuntimeText(reason) : '',
      ),
    );
  }
  return entries;
}

/// `parseBuiltInCatalogCapability`: null unless well formed.
RuntimeModelCatalogCapability? _parseCatalogCapability(Object? value) {
  if (value is! Map ||
      value['protocolVersion'] != 1 ||
      value['runtime'] != 'builtin') {
    return null;
  }
  final version = value['runtimeVersion'];
  if (version is! String || version.trim().isEmpty) return null;
  final providers = value['customModelProviderIds'];
  return RuntimeModelCatalogCapability(
    runtimeVersion: version,
    customModelProviderIds: providers is List
        ? [
            for (final p in providers)
              if (p is String) p,
          ]
        : const [],
  );
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

RuntimeModelSource _fromSet(
  List models,
  String? defaultModel, {
  Object? unavailable,
  Object? catalog,
}) => models.isEmpty
    ? const RuntimeModelNonLive('no_models')
    : RuntimeModelLive(
        [for (final m in models.whereType<Map>()) _parseModel(m)],
        defaultModel,
        sanitizeRuntimeModelUnavailable(unavailable),
        _parseCatalogCapability(catalog),
      );

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
      unavailable: value['unavailable'],
      catalog: value['catalog'],
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
      catalog: payload['catalog'],
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

/// `reasoningEffortOptionsForModel`: (id, label) in ladder order. A model
/// that declares its efforts offers those the runtime accepts (`off` and
/// `minimal` are Pi levels only); one that declares none offers the runtime's
/// default set, or none where the Computer lists the levels per model
/// (Antigravity, CodeBuddy Code).
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
  final declared = supported != null && supported.isNotEmpty;
  final offered = declared
      ? supported
      : runtimeOffersUndeclaredReasoningEfforts(runtime)
      ? defaultReasoningEffortsForRuntime(runtime)
      : const <String>[];
  return [
    for (final e in reasoningEfforts)
      if (offered.contains(e.$1) &&
          (!declared || isReasoningEffortOfferedOnRuntime(runtime, e.$1)))
        e,
  ];
}

/// `reconcileReasoningEffort`: the value when the model does not gate
/// reasoning or it is still valid; else the model's declared default effort,
/// else null ("Default"). A model that declares none on a runtime that offers
/// none for it resets to null.
String? reconcileReasoningEffort(
  String runtime,
  String model,
  String? current,
  List<RuntimeModelInfo> live,
) {
  final info = _resolveModel(runtime, model, live);
  final supported = info?.supportedReasoningEfforts;
  if (supported == null || supported.isEmpty) {
    return runtimeOffersUndeclaredReasoningEfforts(runtime) ? current : null;
  }
  if (current != null && supported.contains(current)) return current;
  final fallback = info?.defaultReasoningEffort;
  return fallback != null && supported.contains(fallback) ? fallback : null;
}
