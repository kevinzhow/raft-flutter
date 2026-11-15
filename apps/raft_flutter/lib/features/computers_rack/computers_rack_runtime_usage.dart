// The Computers rack's runtime usage columns (Web v1.24 components/machine/
// rack/RackRuntimeUsage.tsx, rackRuntimeColumns.ts; features/computer/
// computersRackSort.ts rackRemaining; components/machine/bulkChangeModelPlan.ts
// allModelsUsageAccount / summarizeRuntimeUsage). One read per computer and
// provider for the whole list (so a usage heading can sort it), a cell per
// column that follows its own computer's reads, and the usage card on the cell.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/runtime_account_usage.dart';
import '../../data/workspace_controller.dart';
import '../computer_readiness_copy.dart' show rackReset, readinessDoLabel;
import '../runtime_usage_chip.dart';
import 'computers_rack_model.dart';

/// One computer's reads by provider; a provider missing from it is not
/// answered yet. A failed read is answered as missing (nothing to read).
typedef RackUsageResults = Map<String, RuntimeUsageRead>;

const _failedRead = RuntimeUsageRead('missing', null);

/// RACK_USAGE_WARN_PERCENT.
const rackUsageWarnPercent = 80;

// ------------------------------------------------------------ reads

/// useRackRuntimeUsages: the usage client's cached reads of each readable
/// computer, read again whenever a card fetches newer ones. A computer's
/// notifier changes only when its own results do.
class RackUsageReads {
  RackUsageReads(this.client);
  final RuntimeAccountUsageClient client;

  /// Bumped on any computer's change (the list sorts by them).
  final version = ValueNotifier<int>(0);
  final _notifiers = <String, ValueNotifier<RackUsageResults?>>{};
  final _twoLines = <String, bool>{};
  final _subjects = <String, String>{};
  String? _serverId, _key;
  void Function()? _unsubscribe;
  var _generation = 0;

  /// [targets]: the computers that are read, with their providers; any other
  /// computer has no results (null: nothing to read, "—").
  void sync(String? serverId, Map<String, List<String>> targets) {
    final key =
        '$serverId\n${[for (final e in targets.entries) '${e.key}\u0000${e.value.join(',')}'].join('\n')}';
    if (key == _key) return;
    final fresh = _key == null;
    _key = key;
    _serverId = serverId;
    _unsubscribe?.call();
    _unsubscribe = null;
    final generation = ++_generation;
    // A computer's results stay while only another's target changes.
    final subjects = {
      for (final e in targets.entries)
        e.key: '$serverId\u0000${e.value.join(',')}',
    };
    RackUsageResults? initial(String id) =>
        serverId != null && targets.containsKey(id)
        ? <String, RuntimeUsageRead>{}
        : null;
    void settle() {
      for (final e in [..._notifiers.entries]) {
        if (_subjects[e.key] != subjects[e.key]) e.value.value = initial(e.key);
      }
      _subjects
        ..clear()
        ..addAll(subjects);
      _load(generation, targets);
    }

    for (final id in targets.keys) {
      _notifiers.putIfAbsent(id, () => ValueNotifier(initial(id)));
    }
    if (fresh) {
      _subjects.addAll(subjects);
      for (final e in _notifiers.entries) {
        if (!targets.containsKey(e.key)) e.value.value = null;
      }
      _load(generation, targets);
    } else {
      // A notifier already drawn changes outside the build that found it.
      // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of the build that found the new targets; it schedules nothing itself.
      scheduleMicrotask(() {
        if (generation == _generation) settle();
      });
    }
  }

  void _load(int generation, Map<String, List<String>> targets) {
    final serverId = _serverId;
    if (serverId == null) return;
    void load() {
      for (final e in targets.entries) {
        for (final provider in e.value) {
          void answer(RuntimeUsageRead result) {
            if (generation != _generation) return;
            final notifier = _notifiers[e.key];
            final own = notifier?.value;
            if (notifier == null || own == null) return;
            if (identical(own[provider], result)) return;
            // A failed read again keeps what an earlier read answered.
            if (identical(result, _failedRead) && own[provider] != null) return;
            if (!identical(result, _failedRead)) {
              _twoLines['${e.key}\u0000$provider'] =
                  result.snapshot != null &&
                  _tightestHasModelLine(result.snapshot!);
            }
            notifier.value = {...own, provider: result};
            version.value++;
          }

          client
              .read(serverId, e.key, provider)
              .then(answer, onError: (_) => answer(_failedRead));
        }
      }
    }

    load();
    _unsubscribe = client.subscribe(load);
  }

  /// The computer's cell notifier (null value: not read).
  ValueNotifier<RackUsageResults?> of(String machineId) =>
      _notifiers.putIfAbsent(machineId, () => ValueNotifier(null));

  RackUsageResults? results(String machineId) => _notifiers[machineId]?.value;

  /// How many lines this provider's last answer drew here (the pending
  /// placeholder's shape the next time).
  bool pendingTwoLines(String machineId, String provider) =>
      _twoLines['$machineId\u0000$provider'] ?? false;

  void dispose() {
    _generation++;
    _unsubscribe?.call();
    version.dispose();
    for (final n in _notifiers.values) {
      n.dispose();
    }
  }
}

/// The providers of a computer's runtimes, in the providers' order.
List<String> machineUsageProviders(RackMachine m) {
  final wanted = {
    for (final r in rackMachineRuntimes(m)) usageProviderForRuntime(r),
  };
  return [
    for (final p in rackUsageProviders)
      if (wanted.contains(p)) p,
  ];
}

// ------------------------------------------------------------ the cell's facts

/// One account's share as every usage summary counts it (BulkRuntimeUsageSummary).
class RackSummary {
  const RackSummary.used(this.plan, this.percent)
    : kind = 'used',
      resetsAt = null;
  const RackSummary.limit(this.plan, this.resetsAt)
    : kind = 'limit',
      percent = 0;
  const RackSummary.attention(this.plan)
    : kind = 'attention',
      percent = 0,
      resetsAt = null;
  final String kind;
  final String? plan, resetsAt;
  final int percent;
}

class RackModelLine {
  const RackModelLine(this.name, this.used, this.usedUp, this.resetsAt);
  final String name;
  final int used;
  final bool usedUp;
  final String? resetsAt;
}

enum RackCellKind { absent, pending, unavailable, value }

class RackCell {
  const RackCell(
    this.kind, {
    this.provider = '',
    this.runtimeId = '',
    this.used = 0,
    this.warn = false,
    this.usedUp = false,
    this.stale = false,
    this.summary,
    this.attention,
    this.model,
  });
  final RackCellKind kind;
  final String provider, runtimeId;
  final int used;
  final bool warn, usedUp, stale;
  final RackSummary? summary, attention;
  final RackModelLine? model;
}

const claudeOAuthAppsWindowLabel = 'Current week (OAuth apps)';

List<Map> _windows(Map account) => [
  for (final w in (account['windows'] as List? ?? const []))
    if (w is Map) w,
];

bool _modelScoped(Map w) {
  final scope = w['scope'];
  return scope is Map &&
      (scope['kind'] == 'model' || scope['kind'] == 'models');
}

double? _tightness(Map w) {
  if (w['status'] == 'limit_reached') return 2;
  final ratio = w['usedRatio'];
  return w['status'] == 'ok' && ratio is num ? ratio.toDouble() : null;
}

List<Map>? _roomiestGroup(List<Map> windows) {
  final groups = <String, List<Map>>{};
  for (final w in windows) {
    final scope = w['scope'];
    if (scope is! Map || scope['kind'] != 'models') return null;
    (groups['${scope['name']}'.toLowerCase()] ??= []).add(w);
  }
  if (groups.length < 2) return null;
  List<Map>? best;
  double? bestTightness;
  for (final group in groups.values) {
    final readings = [for (final w in group) ?_tightness(w)];
    if (readings.isEmpty) continue;
    final tightness = readings.reduce((a, b) => a > b ? a : b);
    if (bestTightness == null || tightness < bestTightness) {
      best = group;
      bestTightness = tightness;
    }
  }
  return best;
}

/// allModelsUsageAccount: the account as every summary counts it.
({Map account, bool modelLine}) allModelsAccount(Map account) {
  final all = _windows(account);
  final counted = [
    for (final w in all)
      if (w['label'] != claudeOAuthAppsWindowLabel) w,
  ];
  final allModels = [
    for (final w in counted)
      if (!_modelScoped(w)) w,
  ];
  final roomiest = allModels.isEmpty ? _roomiestGroup(counted) : null;
  final modelLine =
      roomiest != null || (allModels.isNotEmpty && counted.any(_modelScoped));
  final kept = roomiest ?? (allModels.isNotEmpty ? allModels : counted);
  if (kept.length == all.length) {
    return (account: account, modelLine: modelLine);
  }
  final limitOnlyLeftOut =
      account['health'] == 'rate_limited' &&
      !kept.any((w) => w['status'] == 'limit_reached') &&
      all.any((w) => !kept.contains(w) && w['status'] == 'limit_reached');
  return (
    account: {
      ...account,
      if (limitOnlyLeftOut) 'health': 'ok',
      'windows': kept,
    },
    modelLine: modelLine,
  );
}

/// usableAgainAt: the latest reset, null when any does not say.
String? _usableAgainAt(List<String?> resets) {
  String? latest;
  DateTime? latestAt;
  for (final r in resets) {
    final at = r == null ? null : DateTime.tryParse(r);
    if (r == null || at == null) return null;
    if (latestAt == null || at.isAfter(latestAt)) {
      latest = r;
      latestAt = at;
    }
  }
  return latest;
}

int _percent(num ratio) => (ratio * 100).round();

/// summarizeRuntimeUsage for one account.
RackSummary? _summarize(Map reported) {
  final account = allModelsAccount(reported).account;
  final plan = account['planLabel'] as String?;
  final windows = _windows(account);
  final limited = [
    for (final w in windows)
      if (w['status'] == 'limit_reached') w,
  ];
  if (limited.isNotEmpty) {
    return RackSummary.limit(
      plan,
      _usableAgainAt([for (final w in limited) w['resetsAt'] as String?]),
    );
  }
  if (account['health'] != 'ok') return RackSummary.attention(plan);
  final ratios = [
    for (final w in windows)
      if (w['status'] == 'ok' && w['usedRatio'] is num)
        (w['usedRatio'] as num).toDouble(),
  ];
  if (ratios.isEmpty) return null;
  return RackSummary.used(
    plan,
    _percent(ratios.reduce((a, b) => a > b ? a : b)),
  );
}

int? _usedOf(RackSummary? s) => switch (s?.kind) {
  'used' => s!.percent,
  'limit' => 100,
  _ => null,
};

({
  ({int used, RackSummary summary, Map account})? tightest,
  RackSummary? attention,
})
_readAccounts(Map snapshot) {
  ({int used, RackSummary summary, Map account})? tightest;
  RackSummary? attention;
  for (final a in (snapshot['accounts'] as List? ?? const [])) {
    if (a is! Map) continue;
    final summary = _summarize(a);
    if (summary?.kind == 'attention') attention ??= summary;
    final used = _usedOf(summary);
    if (summary == null || used == null) continue;
    if (tightest == null ||
        used > tightest.used ||
        (used == tightest.used && summary.kind == 'limit')) {
      tightest = (used: used, summary: summary, account: a);
    }
  }
  return (tightest: tightest, attention: attention);
}

bool _tightestHasModelLine(Map snapshot) {
  final t = _readAccounts(snapshot).tightest;
  return t != null && _modelLineOf(t.account, const []) != null;
}

String _modelLineName(Map scope) {
  if (scope['kind'] == 'account') return '';
  final name = '${scope['name'] ?? ''}';
  if (scope['kind'] != 'models') return name;
  final cut = name.replaceFirst(
    RegExp(r'\s+models$', caseSensitive: false),
    '',
  );
  return cut.isEmpty ? name : cut;
}

RackModelLine? _modelLineOf(Map account, List<String> groups) {
  if (!allModelsAccount(account).modelLine) return null;
  final scoped = [
    for (final w in _windows(account))
      if (w['label'] != claudeOAuthAppsWindowLabel && _modelScoped(w)) w,
  ];
  bool inGroup(Map w) {
    final scope = w['scope'];
    return scope is Map &&
        scope['kind'] == 'models' &&
        groups.any((g) => g.toLowerCase() == '${scope['name']}'.toLowerCase());
  }

  final agents = [
    for (final w in scoped)
      if (inGroup(w)) w,
  ];
  RackModelLine? tightest;
  for (final w in agents.isNotEmpty ? agents : scoped) {
    if (w['scope'] is! Map || w['status'] == 'parse_unavailable') continue;
    final usedUp = w['status'] == 'limit_reached';
    if (!usedUp && w['usedRatio'] is! num) continue;
    final line = RackModelLine(
      _modelLineName(w['scope'] as Map),
      usedUp ? 100 : _percent(w['usedRatio'] as num),
      usedUp,
      w['resetsAt'] as String?,
    );
    if (tightest == null ||
        line.used > tightest.used ||
        (line.used == tightest.used && usedUp && !tightest.usedUp)) {
      tightest = line;
    }
  }
  return tightest;
}

/// rackAgentModelGroups: the model groups these agents' models count against.
List<String> rackAgentModelGroups(Iterable<Map> agents) {
  final groups = <String>{};
  for (final a in agents) {
    if (a['runtime'] != 'antigravity') continue;
    final id = '${a['model'] ?? ''}'.trim().toLowerCase();
    if (id.startsWith('gemini')) {
      groups.add('Gemini Models');
    } else if (RegExp(r'(?:^|/)(?:claude|gpt)(?![a-z])').hasMatch(id)) {
      groups.add('Claude and GPT models');
    }
  }
  return groups.toList()..sort();
}

/// The computer's runtime for a provider (the usage card's subject).
String? rackProviderRuntime(RackMachine m, String provider) {
  final own = rackMachineRuntimes(m)..sort(compareRuntimeCatalogOrder);
  for (final r in own) {
    if (usageProviderForRuntime(r) == provider) return r;
  }
  return null;
}

/// rackRuntimeCell. [results] null: the viewer may not see that usage.
RackCell rackRuntimeCell(
  RackMachine m,
  String provider,
  RackUsageResults? results, [
  List<String> modelGroups = const [],
]) {
  final runtimeId = rackProviderRuntime(m, provider);
  if (runtimeId == null) return const RackCell(RackCellKind.absent);
  final result = results?[provider];
  if (results != null && result == null) {
    return RackCell(
      RackCellKind.pending,
      provider: provider,
      runtimeId: runtimeId,
    );
  }
  if (result?.unsupported ?? false) return const RackCell(RackCellKind.absent);
  final snapshot = result?.snapshot;
  RackCell unavailable([RackSummary? attention]) => RackCell(
    RackCellKind.unavailable,
    provider: provider,
    runtimeId: runtimeId,
    attention: attention,
  );
  if (result == null || snapshot == null) return unavailable();
  final (:tightest, :attention) = _readAccounts(snapshot);
  if (tightest == null) return unavailable(attention);
  return RackCell(
    RackCellKind.value,
    provider: provider,
    runtimeId: runtimeId,
    used: tightest.used,
    warn: tightest.used >= rackUsageWarnPercent,
    usedUp: tightest.summary.kind == 'limit',
    stale: result.state == 'stale',
    summary: tightest.summary,
    attention: attention,
    model: _modelLineOf(tightest.account, modelGroups),
  );
}

/// rackRemaining: what a provider's accounts on a computer have left, 0 to 1
/// (the tightest account, in each its tightest window); null: nothing to read.
double? rackRemaining(RuntimeUsageRead? result) {
  final snapshot = result?.snapshot;
  if (snapshot == null) return null;
  double? tightest;
  for (final reported in (snapshot['accounts'] as List? ?? const [])) {
    if (reported is! Map) continue;
    final account = allModelsAccount(reported).account;
    double? remaining;
    if (account['health'] == 'rate_limited') {
      remaining = 0;
    } else if (account['health'] == 'ok') {
      final used = [
        for (final w in _windows(account))
          if (w['status'] == 'ok' || w['status'] == 'limit_reached')
            if (w['usedRatio'] is num)
              (w['usedRatio'] as num).toDouble()
            else if (w['status'] == 'limit_reached')
              1.0,
      ];
      if (used.isNotEmpty) {
        final most = used.reduce((a, b) => a > b ? a : b);
        remaining = (1 - most).clamp(0, 1).toDouble();
      }
    }
    if (remaining != null && (tightest == null || remaining < tightest)) {
      tightest = remaining;
    }
  }
  return tightest;
}

/// rackLoginStep: "verify_account" / "sign_in" when the computer's machine
/// login of one of the provider's runtimes is blocked and holds agents.
String? rackLoginStep(RackMachine m, String provider) {
  final attention = m['attention'];
  final items = attention is Map ? attention['items'] : null;
  if (items is! List) return null;
  final runtimes = rackMachineRuntimes(m);
  for (final item in items) {
    if (item is! Map || item['code'] == null) continue;
    final count = item['agentCount'];
    if (count is! num || count == 0) continue;
    final resource = item['resource'];
    if (resource is! Map || resource['kind'] != 'login') continue;
    final key = '${resource['key']}';
    if (!key.startsWith('shared:')) continue;
    final runtimeId = key.substring('shared:'.length);
    if (!runtimes.contains(runtimeId) ||
        usageProviderForRuntime(runtimeId) != provider) {
      continue;
    }
    final action = item['action'];
    if (action == 'verify_account' || action == 'sign_in') {
      return action as String;
    }
  }
  return null;
}

// ------------------------------------------------------------ words

String _inWords(BuildContext context, ({String unit, int count}) reset) {
  final one = reset.count == 1;
  return raftFormat(
    context,
    switch (reset.unit) {
      'm' => one ? 'in {count} minute' : 'in {count} minutes',
      'h' => one ? 'in {count} hour' : 'in {count} hours',
      _ => one ? 'in {count} day' : 'in {count} days',
    },
    {'count': reset.count},
  );
}

int? _ms(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso)?.millisecondsSinceEpoch;

/// runtimeUsageText: "Max · 28% used", "Plus · Used up · back in 3 hours".
String? _summaryText(BuildContext context, RackSummary? s, int nowMs) {
  if (s == null) return null;
  final plan = s.plan ?? raftText(context, 'Runtime account');
  switch (s.kind) {
    case 'used':
      return raftFormat(context, '{plan} · {percent}% used', {
        'plan': plan,
        'percent': s.percent,
      });
    case 'attention':
      return raftFormat(context, '{plan} · needs attention', {'plan': plan});
    default:
      final reset = rackReset(_ms(s.resetsAt), nowMs);
      return reset == null
          ? raftFormat(context, '{plan} · Used up', {'plan': plan})
          : raftFormat(context, '{plan} · Used up · back {reset}', {
              'plan': plan,
              'reset': _inWords(context, reset),
            });
  }
}

String _modelValueText(BuildContext context, RackModelLine m, int nowMs) {
  if (!m.usedUp) {
    return raftFormat(context, '{percent}%', {'percent': m.used});
  }
  final reset = rackReset(_ms(m.resetsAt), nowMs);
  if (reset == null) return raftText(context, 'Used up');
  return raftFormat(
    context,
    switch (reset.unit) {
      'm' => '{count}m',
      'h' => '{count}h',
      _ => '{count}d',
    },
    {'count': reset.count},
  );
}

String _modelLabel(BuildContext context, RackModelLine m, int nowMs) {
  final reset = rackReset(_ms(m.resetsAt), nowMs);
  final usage = m.usedUp
      ? (reset == null
            ? raftText(context, 'Used up')
            : raftFormat(context, 'Used up · back {when}', {
                'when': _inWords(context, reset),
              }))
      : raftFormat(context, '{percent}% used', {'percent': m.used});
  return raftFormat(context, '{model}: {usage}', {
    'model': m.name,
    'usage': usage,
  });
}

/// The cell as raft_ui draws it, with its words.
RaftRackUsage rackUsageCellData(
  BuildContext context,
  RackMachine m,
  RackCell cell,
  int nowMs, {
  bool pendingTwoLines = false,
}) {
  if (cell.kind == RackCellKind.absent) return const RaftRackUsage.absent();
  final runtime = rackRuntimeDisplayName(cell.runtimeId);
  String meter(String usage) => raftFormat(
    context,
    '{runtime} account: {usage}',
    {'runtime': runtime, 'usage': usage},
  );
  final step = rackLoginStep(m, cell.provider);
  if (step != null) {
    return RaftRackUsage(
      kind: RaftRackUsageKind.step,
      label: meter(readinessDoLabel(context, step)),
      text: raftText(context, step == 'sign_in' ? 'Sign in' : 'Verify'),
    );
  }
  if (cell.kind == RackCellKind.pending) {
    return RaftRackUsage(
      kind: RaftRackUsageKind.pending,
      label: meter(raftText(context, 'Loading…')),
      pendingTwoLines: pendingTwoLines,
    );
  }
  final attention = _summaryText(context, cell.attention, nowMs);
  if (cell.kind == RackCellKind.unavailable) {
    return RaftRackUsage(
      kind: RaftRackUsageKind.dash,
      attention: cell.attention != null,
      label: attention != null
          ? meter(attention)
          : raftFormat(context, '{runtime}: usage unavailable', {
              'runtime': runtime,
            }),
    );
  }
  final summary = cell.summary!;
  final reset = cell.usedUp && summary.kind == 'limit'
      ? rackReset(_ms(summary.resetsAt), nowMs)
      : null;
  final value = reset != null
      ? [
          summary.plan ?? raftText(context, 'Runtime account'),
          raftFormat(context, 'Used up · back {when}', {
            'when': _inWords(context, reset),
          }),
        ].join(' · ')
      : _summaryText(context, summary, nowMs);
  final model = cell.model;
  final usage = [
    value,
    if (model != null) _modelLabel(context, model, nowMs),
    attention,
  ].whereType<String>().join(' · ');
  final text = !cell.usedUp
      ? raftFormat(context, '{percent}% used', {'percent': cell.used})
      : reset == null
      ? raftText(context, 'Used up')
      : raftFormat(
          context,
          switch (reset.unit) {
            'm' => 'Back in {count}m',
            'h' => 'Back in {count}h',
            _ => 'Back in {count}d',
          },
          {'count': reset.count},
        );
  return RaftRackUsage(
    kind: RaftRackUsageKind.value,
    label: cell.stale
        ? raftFormat(context, '{runtime} account: {usage} · last known', {
            'runtime': runtime,
            'usage': usage,
          })
        : meter(usage),
    text: text,
    used: cell.used,
    warn: cell.warn,
    stale: cell.stale,
    attention: cell.attention != null,
    model: model == null
        ? null
        : RaftRackModelLine(
            name: model.name,
            text: _modelValueText(context, model, nowMs),
            used: model.used,
            label: _modelLabel(context, model, nowMs),
          ),
  );
}

// ------------------------------------------------------------ widgets

/// A provider's cell on a computer (list, phone) or its card line: follows
/// its own computer's reads, and opens the usage card when there is
/// something on it to read (a value, an account needing attention, a step).
class RackUsageCellView extends StatelessWidget {
  const RackUsageCellView({
    super.key,
    required this.controller,
    required this.reads,
    required this.machine,
    required this.provider,
    required this.modelGroups,
    this.line = false,
    this.emphasized = false,
  });
  final WorkspaceController controller;
  final RackUsageReads reads;
  final RackMachine machine;
  final String provider;
  final List<String> modelGroups;
  final bool line, emphasized;

  @override
  Widget build(BuildContext context) {
    final id = '${machine['id']}';
    return ValueListenableBuilder<RackUsageResults?>(
      valueListenable: reads.of(id),
      builder: (context, results, _) {
        final cell = rackRuntimeCell(machine, provider, results, modelGroups);
        if (cell.kind == RackCellKind.absent) return const SizedBox.shrink();
        final nowMs = reads.client.now().millisecondsSinceEpoch;
        final data = rackUsageCellData(
          context,
          machine,
          cell,
          nowMs,
          pendingTwoLines: reads.pendingTwoLines(id, provider),
        );
        final widget = RaftRackUsageCell(
          usage: data,
          line: line,
          emphasized: emphasized,
          name: rackRuntimeShortName(cell.runtimeId),
        );
        final serverId = controller.server?.id;
        final step = rackLoginStep(machine, provider);
        final opens =
            serverId != null &&
            cell.kind != RackCellKind.pending &&
            (cell.kind == RackCellKind.value ||
                (cell.kind == RackCellKind.unavailable &&
                    cell.attention != null) ||
                step != null);
        final key = ValueKey('rack-usage-$id-$provider');
        if (opens) {
          final versions = machine['runtimeVersions'];
          return RuntimeUsageChip(
            key: key,
            controller: controller,
            serverId: serverId,
            machineId: id,
            runtimeId: cell.runtimeId,
            runtimeVersion: versions is Map
                ? versions[cell.runtimeId] as String?
                : null,
            label: data.label,
            client: reads.client,
            chip: (_) => widget,
          );
        }
        if (cell.kind == RackCellKind.pending) {
          return KeyedSubtree(key: key, child: widget);
        }
        return RaftTooltip(key: key, message: data.label, child: widget);
      },
    );
  }
}

/// rackRuntimeShortName: the catalog name's first word (Claude, Codex, Kimi).
String rackRuntimeShortName(String runtimeId) =>
    rackRuntimeDisplayName(runtimeId).split(' ').first;

/// What a computer's row adds for the runtime columns.
class RackRuntimeParts {
  const RackRuntimeParts(this.usageCells, this.usageLines, this.otherCell);
  final List<Widget> usageCells, usageLines;
  final Widget? otherCell;
}

RackRuntimeParts rackRuntimeParts({
  required WorkspaceController controller,
  required RackUsageReads reads,
  required RackMachine machine,
  required RackRuntimeColumns columns,
  required List<Map<String, dynamic>> agents,
  required String? leadProvider,
}) {
  final groups = rackAgentModelGroups(agents);
  Widget cell(String provider, {bool line = false, bool emphasized = false}) =>
      RackUsageCellView(
        controller: controller,
        reads: reads,
        machine: machine,
        provider: provider,
        modelGroups: groups,
        line: line,
        emphasized: emphasized,
      );
  final own = rackRuntimeColumns([machine]);
  final other = rackOtherRuntimes(machine, columns.other);
  return RackRuntimeParts(
    [for (final c in columns.usage) cell(c.provider)],
    [
      for (final c in own.usage)
        cell(c.provider, line: true, emphasized: c.provider == leadProvider),
    ],
    columns.other.isEmpty
        ? null
        : RaftRackOtherCell(
            count: other.length,
            names: other.map(rackRuntimeDisplayName).join(', '),
          ),
  );
}

/// The list header's usage headings, in column order.
List<RaftRackUsageHeading> rackUsageHeadings(RackRuntimeColumns columns) => [
  for (final c in columns.usage)
    RaftRackUsageHeading(
      key: 'remaining:${c.provider}',
      shortName: rackRuntimeShortName(c.runtimeId),
      fullName: rackRuntimeDisplayName(c.runtimeId),
    ),
];
