// The current runtime configuration of an agent, as every read surface must
// see it. Port of Web `hydrateRuntimeConfigForm(agent)` (packages/web
// utils/runtimeConfigForm.ts) -> shared `hydrateRuntimeConfig` /
// `hydrateLegacyRuntimeConfigWithTrace` (packages/shared runtimeConfigLegacy.ts)
// plus the `runtimeConfig*` accessors and `supports*` predicates.
//
// The server stores the structured `runtimeConfig`
// ({version, runtime, provider?, model: {kind, id|name}, mode: {kind},
// reasoningEffort, envVars, command?}) and projects the older flat columns
// (`runtime`, `model`, `reasoningEffort`, `envVars`) next to it. Fast mode lives
// ONLY in `runtimeConfig.mode.kind`; there is no flat `fastMode` column, so
// reading `agent['fastMode']` can never show a saved Fast mode. Member /
// non-admin projections strip `runtimeConfig`; then the flat columns are all
// there is and the mode is `default`, exactly like Web.
import '../features/agent_runtime_catalog.dart';

/// `RUNTIME_CONFIG_VERSION`.
const _version = 1;

/// `CONTROLLED_RUNTIME_ENV_KEYS`: env keys the runtime config owns, hidden from
/// the user-editable env vars on read (`stripControlledRuntimeEnvVars`).
const _builtinControlledEnvKeys = <String>{
  'DEEPSEEK_API_KEY',
  'MINIMAX_API_KEY',
  'MINIMAX_CN_API_KEY',
  'ZAI_API_KEY',
  'ZAI_CODING_CN_API_KEY',
  'MOONSHOT_API_KEY',
  'KIMI_API_KEY',
  'QWEN_TOKEN_PLAN_API_KEY',
  'QWEN_TOKEN_PLAN_CN_API_KEY',
  'OPENROUTER_API_KEY',
  'OPENAI_API_KEY',
  'ANTHROPIC_API_KEY',
  'GEMINI_API_KEY',
  'XAI_API_KEY',
  'XIAOMI_API_KEY',
  'OPENAI_BASE_URL',
  'ANTHROPIC_BASE_URL',
  'ANTHROPIC_OAUTH_TOKEN',
};
const _controlledEnvKeys = <String, Set<String>>{
  'builtin': _builtinControlledEnvKeys,
  'claude': {
    'ANTHROPIC_BASE_URL',
    'ANTHROPIC_API_KEY',
    'ANTHROPIC_CUSTOM_MODEL_OPTION',
  },
  'pi': {'DEEPSEEK_API_KEY'},
};

// ------------------------------------------------------- supported runtimes

/// `supportsRuntimeFastMode` (`RUNTIME_FAST_MODE_RUNTIMES`).
bool runtimeSupportsFastMode(String runtime) =>
    fastModeRuntimes.contains(runtime);

/// `REASONING_EFFORT_RUNTIMES.has(runtime)`.
bool runtimeSupportsReasoning(String runtime) =>
    reasoningEffortRuntimes.contains(runtime);

/// `supportsRuntimeApiUrl`.
bool runtimeSupportsApiUrl(String runtime) => runtime == 'claude';

/// `supportsRuntimeCommand`.
bool runtimeSupportsCommand(String runtime) => runtime == 'claude';

// ------------------------------------------------------------------- config

class RuntimeConfig {
  const RuntimeConfig({
    required this.runtime,
    required this.model,
    this.customModel = false,
    this.fastMode = false,
    this.reasoningEffort,
    this.envVars,
    this.command,
    this.customProvider = false,
    this.apiUrl = '',
    this.apiKey = '',
  });

  /// Web `hydrateRuntimeConfigForm(agent)`: the structured `runtimeConfig`
  /// when the agent carries a version-1 one, completed from the flat columns;
  /// the flat columns alone otherwise.
  factory RuntimeConfig.fromAgent(Map<dynamic, dynamic> agent) {
    final raw = agent['runtimeConfig'];
    final stored = raw is Map && _isVersion(raw['version'])
        ? Map<dynamic, dynamic>.from(raw)
        : null;
    final runtime =
        _nonEmpty(stored?['runtime']) ??
        _nonEmpty(agent['runtime']) ??
        'claude';
    final fallbackModel = _nonEmpty(agent['model']) ?? _defaultModel(runtime);
    final legacyEnv = _normalizeEnv(agent['envVars']);
    final storedEnv = _normalizeEnv(stored?['envVars']);
    final isClaude = runtime == 'claude';
    final claudeEnv = isClaude ? legacyEnv : null;
    final String? legacyApiUrl = claudeEnv == null
        ? null
        : claudeEnv['ANTHROPIC_BASE_URL'];
    final String? legacyApiKey = claudeEnv == null
        ? null
        : claudeEnv['ANTHROPIC_API_KEY'];
    final String? legacyCustomModel = claudeEnv == null
        ? null
        : claudeEnv['ANTHROPIC_CUSTOM_MODEL_OPTION'];

    // `parseProviderConfig` (only the Claude custom arm is read by the app;
    // Built-in Pi / Pi providers belong to the protocol-v2 form).
    ({String url, String key})? custom;
    if (stored != null) {
      if (isClaude) {
        final provider = stored['provider'];
        if (provider is Map && provider['kind'] == 'custom') {
          final url = provider['apiUrl'], key = provider['apiKey'];
          if (url is String &&
              url.trim().isNotEmpty &&
              key is String &&
              key.trim().isNotEmpty) {
            custom = (url: url.trim(), key: key.trim());
          } else if (_has(legacyApiUrl) && _has(legacyApiKey)) {
            custom = (url: legacyApiUrl!.trim(), key: legacyApiKey!.trim());
          }
        }
      }
    } else if (isClaude && _has(legacyApiUrl) && _has(legacyApiKey)) {
      // Agents created before structured RuntimeConfig kept Claude provider
      // credentials in envVars.
      custom = (url: legacyApiUrl!, key: legacyApiKey!);
    }

    // `parseModelConfig` / `modelConfigFromLegacy`.
    ({bool custom, String value}) legacyModel() =>
        (custom: !_isPresetModel(runtime, fallbackModel), value: fallbackModel);
    var model = legacyModel();
    if (stored != null) {
      final cfg = stored['model'];
      if (cfg is Map) {
        final name = cfg['name'], id = cfg['id'];
        if (cfg['kind'] == 'custom' &&
            name is String &&
            name.trim().isNotEmpty) {
          model = (custom: true, value: name.trim());
        } else if (custom != null && isClaude && _has(legacyCustomModel)) {
          model = (custom: true, value: legacyCustomModel!.trim());
        } else if (cfg['kind'] == 'preset' &&
            id is String &&
            id.trim().isNotEmpty) {
          model = (custom: false, value: id.trim());
        }
      }
    }

    // `parseModeConfig`: only a stored config carries a mode.
    final modeCfg = stored?['mode'];
    final fast = modeCfg is Map && modeCfg['kind'] == 'fast';

    // `parseCommandConfig`: Claude-only, stored only.
    final commandRaw = stored?['command'];
    final command =
        stored != null &&
            isClaude &&
            commandRaw is String &&
            commandRaw.trim().isNotEmpty
        ? commandRaw.trim()
        : null;

    final reasoning = stored?['reasoningEffort'] ?? agent['reasoningEffort'];
    return RuntimeConfig(
      runtime: runtime,
      model: model.value,
      customModel: model.custom,
      fastMode: fast,
      reasoningEffort: reasoning is String ? reasoning : null,
      envVars: _stripControlled(
        runtime,
        stored != null ? storedEnv : legacyEnv,
      ),
      command: command,
      customProvider: custom != null,
      apiUrl: custom?.url ?? '',
      apiKey: custom?.key ?? '',
    );
  }

  final String runtime;

  /// `runtimeConfigModelValue`: the preset id or the custom name.
  final String model;

  /// `config.model.kind === "custom"`.
  final bool customModel;

  /// `runtimeConfigFastMode`: `config.mode.kind === "fast"`.
  final bool fastMode;
  final String? reasoningEffort;

  /// User env vars with the runtime-controlled keys removed; null when none.
  final Map<String, String>? envVars;

  /// `config.command` (Claude only), already trimmed.
  final String? command;

  /// `runtimeConfigProviderMode(config) == "custom"` (Claude only).
  final bool customProvider;
  final String apiUrl, apiKey;

  /// `supportsRuntimeFastMode(runtime)`: show the Mode row.
  bool get supportsFastMode => runtimeSupportsFastMode(runtime);

  /// `REASONING_EFFORT_RUNTIMES.has(runtime)`: show the Reasoning row.
  bool get supportsReasoning => runtimeSupportsReasoning(runtime);

  /// `runtimeConfigApiUrl`.
  String get providerApiUrl => customProvider ? apiUrl : '';

  /// `runtimeConfigCommand`.
  String get commandText => command?.trim() ?? '';

  /// Non-null user env vars (the profile / editor lists).
  Map<String, String> get envVarMap => envVars ?? const {};
}

// ------------------------------------------------------------------ helpers

bool _isVersion(Object? v) => v is num && v == _version;

String? _nonEmpty(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

bool _has(String? v) => v != null && v.trim().isNotEmpty;

String _defaultModel(String runtime) =>
    runtimeModelCatalog[runtime]?.firstOrNull?.id ?? 'sonnet';

bool _isPresetModel(String runtime, String model) =>
    (runtimeModelCatalog[runtime] ?? const []).any((m) => m.id == model);

/// `normalizeEnvVars`: string-valued entries only, null when none.
Map<String, String>? _normalizeEnv(Object? value) {
  if (value is! Map) return null;
  final out = <String, String>{};
  for (final e in value.entries) {
    final k = e.key, v = e.value;
    if (k is String && v is String) out[k] = v;
  }
  return out.isEmpty ? null : out;
}

/// `stripControlledRuntimeEnvVars`.
Map<String, String>? _stripControlled(
  String runtime,
  Map<String, String>? env,
) {
  if (env == null) return null;
  final controlled = _controlledEnvKeys[runtime] ?? const <String>{};
  final out = {
    for (final e in env.entries)
      if (!controlled.contains(e.key)) e.key: e.value,
  };
  return out.isEmpty ? null : out;
}
