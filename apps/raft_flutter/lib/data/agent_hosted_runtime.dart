// Cloud agents (Web "hosted runtime", raft-agent-provider.v1): the wire views
// and the pure rules the screens share. Web sources: shared
// agentRuntimeProvider.ts (views), components/agent/HostedRuntimeStatus.tsx
// `describeHostedRuntime`, components/agent/HostedModelChoice.tsx and
// components/agent/hostedRuntimeUsage.ts. Nothing here reads the network or
// the clock; the callers pass them in.
import 'package:intl/intl.dart';

/// Feature flag of the hosted runtime (`ANTIPROTON_HOSTED_RUNTIME_FEATURE_FLAG_KEY`).
const antiprotonHostedRuntimeFlag = 'antiproton_hosted_runtime';

/// Feature flag of the move-to-cloud migration target
/// (`AGENT_MIGRATION_HOSTED_FEATURE_FLAG_KEY`).
const agentMigrationHostedFlag = 'agent_migration_hosted_v0';

/// The only provider kind today (`AGENT_RUNTIME_PROVIDER_KINDS`).
const hostedRuntimeProviderKind = 'antiproton';

/// Where the provider's availability probe lives.
String hostedRuntimeProviderPath(String kind) =>
    '/agent-runtime-providers/${Uri.encodeComponent(kind)}';

/// `hostedRuntimeModelsPath`.
String hostedRuntimeModelsListPath(String kind) =>
    '${hostedRuntimeProviderPath(kind)}/models';

String hostedRuntimeRetryPath(String agentId) =>
    '/agents/${Uri.encodeComponent(agentId)}/hosted-runtime/retry';

String hostedRuntimeUsagePath(String agentId) =>
    '/agents/${Uri.encodeComponent(agentId)}/hosted-runtime/usage';

/// What a status chip looks like for a provisioning state: the fixed
/// presence light and the tone of the soft badge.
enum HostedStateTone { primary, success, warning, muted }

enum HostedStatePresence { busy, online, error, offline }

/// `describeHostedRuntime` + `STATE_CHIP`: the English label (also the l10n
/// key), whether the provider is still working and whether Retry applies.
typedef HostedRuntimeDescription = ({
  String label,
  bool inProgress,
  bool canRetry,
  HostedStateTone tone,
  HostedStatePresence presence,
});

/// `AgentHostedRuntimeSummary` as far as the screens read it. A state this
/// client does not know yields no summary: the agent then shows the ordinary
/// external setup instead of a panel it cannot describe.
class HostedRuntimeSummary {
  const HostedRuntimeSummary({
    required this.provider,
    required this.state,
    required this.syncPending,
    required this.pushRegistered,
    required this.pushError,
    required this.lastErrorCode,
    required this.lastErrorMessage,
    required this.retryNeedsModel,
  });

  static const states = {
    'provisioning',
    'active',
    'failed',
    'deleting',
    'deleted',
  };

  final String provider, state;
  final bool syncPending, retryNeedsModel;

  /// `push` is null (no registration to report) or `{registered, error}`.
  final bool? pushRegistered;
  final String? pushError;

  /// `lastError` is null, or `{code, message}`.
  final String? lastErrorCode, lastErrorMessage;

  bool get hasLastError => lastErrorCode != null;

  static HostedRuntimeSummary? parse(Object? json) {
    if (json is! Map) return null;
    final state = json['state'];
    if (state is! String || !states.contains(state)) return null;
    final push = json['push'];
    final error = json['lastError'];
    String? text(Object? value) => value is String ? value : null;
    return HostedRuntimeSummary(
      provider: text(json['provider']) ?? hostedRuntimeProviderKind,
      state: state,
      syncPending: json['syncPending'] == true,
      pushRegistered: push is Map ? push['registered'] == true : null,
      pushError: push is Map ? text(push['error']) : null,
      lastErrorCode: error is Map ? text(error['code']) ?? '' : null,
      lastErrorMessage: error is Map ? text(error['message']) : null,
      retryNeedsModel: json['retryNeedsModel'] == true,
    );
  }

  HostedRuntimeDescription describe() => switch (state) {
    'provisioning' => (
      label: 'Setting up',
      inProgress: true,
      canRetry: hasLastError,
      tone: HostedStateTone.primary,
      presence: HostedStatePresence.busy,
    ),
    'active' when syncPending => (
      label: 'Syncing changes',
      inProgress: true,
      canRetry: hasLastError,
      tone: HostedStateTone.primary,
      presence: HostedStatePresence.busy,
    ),
    'active' => (
      label: 'Running',
      inProgress: false,
      canRetry: hasLastError,
      tone: HostedStateTone.success,
      presence: HostedStatePresence.online,
    ),
    'failed' => (
      label: 'Setup failed',
      inProgress: false,
      canRetry: true,
      tone: HostedStateTone.warning,
      presence: HostedStatePresence.error,
    ),
    'deleting' => (
      label: 'Removing',
      inProgress: true,
      canRetry: false,
      tone: HostedStateTone.primary,
      presence: HostedStatePresence.busy,
    ),
    _ => (
      label: 'Removed',
      inProgress: false,
      canRetry: false,
      tone: HostedStateTone.muted,
      presence: HostedStatePresence.offline,
    ),
  };
}

/// One model a provider offers.
typedef HostedModelOption = ({String id, String label});

/// `HostedRuntimeModelsView` (`GET /agent-runtime-providers/:kind/models`):
/// what a new cloud agent may start on.
class HostedModelsList {
  const HostedModelsList({
    required this.models,
    required this.defaultModel,
    required this.defaultLabel,
    required this.locked,
    required this.picker,
  });

  final List<HostedModelOption> models;
  final String? defaultModel, defaultLabel;

  /// An administrator decides the model: a create or retry must not name one.
  final bool locked;

  /// `antiproton_model_picker`; absent from older servers means true.
  final bool picker;

  static HostedModelsList? parse(Object? json) {
    if (json is! Map) return null;
    final models = <HostedModelOption>[];
    final list = json['models'];
    if (list is List) {
      for (final m in list) {
        if (m is Map && m['id'] is String) {
          models.add((
            id: m['id'] as String,
            label: '${m['label'] ?? m['id']}',
          ));
        }
      }
    }
    String? text(String key) =>
        json[key] is String ? json[key] as String : null;
    return HostedModelsList(
      models: models,
      defaultModel: text('default'),
      defaultLabel: text('defaultLabel'),
      locked: json['locked'] == true,
      picker: json['picker'] != false,
    );
  }

  /// `label` of an offered id, else the id itself.
  String labelOf(String id) {
    for (final m in models) {
      if (m.id == id) return m.label;
    }
    return id;
  }
}

/// `hostedModelPickerShown`: absent or true shows the picker.
bool hostedModelPickerShown(HostedModelsList? view) => view?.picker != false;

/// The model a cloud agent starts on: the pick, or null (the provider's
/// default). Nothing is named while the list is unknown, an administrator
/// decides, or the server does not offer a picker.
String? hostedModelToSend(HostedModelsList? view, String? pick) =>
    view == null || view.locked || !hostedModelPickerShown(view) ? null : pick;

// ------------------------------------------------------------------- usage

/// One `HostedRuntimeUsageRow`.
class HostedUsageRow {
  const HostedUsageRow({
    required this.at,
    required this.resource,
    required this.dimensions,
    required this.quantity,
    required this.hasCost,
    required this.cost,
  });

  final String at, resource;
  final Map<String, String> dimensions;
  final num quantity;

  /// `cost` is present (a number or an explicit null = not priced).
  final bool hasCost;
  final num? cost;

  static HostedUsageRow? parse(Object? json) {
    if (json is! Map) return null;
    final quantity = json['quantity'];
    if (quantity is! num || !quantity.isFinite) return null;
    final dims = json['dimensions'];
    return HostedUsageRow(
      at: json['at'] is String ? json['at'] as String : '',
      resource: json['resource'] is String ? json['resource'] as String : '',
      dimensions: dims is Map
          ? {
              for (final e in dims.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
      quantity: quantity,
      hasCost: json.containsKey('cost'),
      cost: json['cost'] is num ? json['cost'] as num : null,
    );
  }
}

/// One UTC day of cost.
typedef HostedUsageDay = ({String day, num usd, bool priced, bool hasUnpriced});

class HostedUsageSummary {
  const HostedUsageSummary({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cacheRead,
    required this.cacheWrite,
    required this.totalTokens,
    required this.toolTotal,
    required this.toolSucceeded,
    required this.toolFailed,
    required this.topModels,
    required this.costDays,
    required this.costTotal,
    required this.costPriced,
    required this.costHasUnpriced,
  });

  final num input, output, reasoning, cacheRead, cacheWrite, totalTokens;
  final num toolTotal, toolSucceeded, toolFailed;

  /// Models by total tokens, largest first.
  final List<({String model, num tokens})> topModels;

  /// USD by UTC day, newest first; empty when no row carries a cost.
  final List<HostedUsageDay> costDays;
  final num costTotal;

  /// False when every row with a cost is unpriced: the total is "unpriced".
  final bool costPriced, costHasUnpriced;

  bool get hasCost => costDays.isNotEmpty;
  bool get hasUsage => totalTokens > 0 || toolTotal > 0;
}

const _tokenKinds = {
  'input': 'input',
  'output': 'output',
  'reasoning': 'reasoning',
  'cache_read': 'cacheRead',
  'cache_write_5m': 'cacheWrite',
  'cache_write_1h': 'cacheWrite',
};

/// `hostedRuntimeUsageWindow`: the last [days] UTC days including today, so
/// `1d` buckets are whole days.
({String from, String to}) hostedUsageWindow(DateTime now, {int days = 7}) {
  final utc = now.toUtc();
  final startOfToday = DateTime.utc(utc.year, utc.month, utc.day);
  return (
    from: startOfToday.subtract(Duration(days: days - 1)).toIso8601String(),
    to: utc.toIso8601String(),
  );
}

/// `summarizeHostedRuntimeUsage`.
HostedUsageSummary summarizeHostedUsage(
  Iterable<HostedUsageRow> rows, {
  int topModelCount = 3,
}) {
  final tokens = <String, num>{
    'input': 0,
    'output': 0,
    'reasoning': 0,
    'cacheRead': 0,
    'cacheWrite': 0,
  };
  num totalTokens = 0, toolTotal = 0, toolSucceeded = 0, toolFailed = 0;
  final byModel = <String, num>{};
  final byDay = <String, ({num usd, bool priced, bool hasUnpriced})>{};
  for (final row in rows) {
    final quantity = row.quantity;
    final at = DateTime.tryParse(row.at);
    final costKnown =
        row.hasCost &&
        at != null &&
        (row.cost == null ? quantity > 0 : row.cost!.isFinite);
    if (costKnown) {
      final day = at.toUtc().toIso8601String().substring(0, 10);
      final entry = byDay[day] ?? (usd: 0, priced: false, hasUnpriced: false);
      byDay[day] = row.cost == null
          ? (usd: entry.usd, priced: entry.priced, hasUnpriced: true)
          : (
              usd: entry.usd + row.cost!,
              priced: true,
              hasUnpriced: entry.hasUnpriced,
            );
    }
    if (row.resource == 'model.tokens') {
      totalTokens += quantity;
      final kind = _tokenKinds[row.dimensions['kind'] ?? ''];
      if (kind != null) tokens[kind] = tokens[kind]! + quantity;
      final model = row.dimensions['model'];
      if (model != null && model.isNotEmpty) {
        byModel[model] = (byModel[model] ?? 0) + quantity;
      }
    } else if (row.resource == 'tool.call') {
      toolTotal += quantity;
      final outcome = row.dimensions['outcome'];
      if (outcome == 'succeeded') toolSucceeded += quantity;
      if (outcome == 'failed') toolFailed += quantity;
    }
  }
  final top =
      [
        for (final e in byModel.entries)
          if (e.value > 0) (model: e.key, tokens: e.value),
      ]..sort((a, b) {
        final by = b.tokens.compareTo(a.tokens);
        return by != 0 ? by : a.model.compareTo(b.model);
      });
  final days = [
    for (final e in byDay.entries)
      (
        day: e.key,
        usd: e.value.usd,
        priced: e.value.priced,
        hasUnpriced: e.value.hasUnpriced,
      ),
  ]..sort((a, b) => b.day.compareTo(a.day));
  return HostedUsageSummary(
    input: tokens['input']!,
    output: tokens['output']!,
    reasoning: tokens['reasoning']!,
    cacheRead: tokens['cacheRead']!,
    cacheWrite: tokens['cacheWrite']!,
    totalTokens: totalTokens,
    toolTotal: toolTotal,
    toolSucceeded: toolSucceeded,
    toolFailed: toolFailed,
    topModels: top.take(topModelCount).toList(),
    costDays: days,
    costTotal: days.fold<num>(0, (sum, d) => sum + d.usd),
    costPriced: days.any((d) => d.priced),
    costHasUnpriced: days.any((d) => d.hasUnpriced),
  );
}

/// `formatUsdAmount`: dollars with cents in the viewer's locale. A positive
/// amount under one cent reads "under $0.01", never "$0.00"; the caller
/// supplies the localized "under {amount}" text.
String hostedUsd(
  num usd,
  String locale, {
  required String Function(String amount) under,
}) {
  final money = NumberFormat.simpleCurrency(
    locale: locale.toLowerCase().startsWith('zh') ? 'zh_CN' : 'en_US',
    name: 'USD',
    decimalDigits: 2,
  );
  return usd > 0 && usd < 0.01 ? under(money.format(0.01)) : money.format(usd);
}
