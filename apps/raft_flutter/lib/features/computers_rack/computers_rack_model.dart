// The Computers overview's rules, pure (Web v1.24 features/computer/
// computersRackFilter.ts, computersRackSort.ts, computersRackToolbarModel.ts,
// components/layout/sidebarMachineOrder.ts, components/machine/rack/
// rackRuntimeColumns.ts, utils/computerUpgradeIndicator.ts): the toolbar, the
// list, the counts and the attention summary read the same answers.
//
// A machine is the server's row as the entity directory keeps it
// (`Map<String, dynamic>`, GET /servers/:id/machines).
import '../computer_detail_view.dart' show computerDiskLow;

typedef RackMachine = Map<String, dynamic>;

// ------------------------------------------------------------ order

/// sidebarMachineOrder.ts isMyComputer: one the viewer attached
/// (`computerAttachedByCurrentUser`) or one Raft records them as the owner of
/// (`ownerUserId`; null is a Public Computer).
bool isMyComputer(RackMachine m, String? userId) =>
    m['computerAttachedByCurrentUser'] == true ||
    (userId != null && userId.isNotEmpty && m['ownerUserId'] == userId);

/// sidebarMachineTier without a local device (the app is never Raft
/// Desktop's This device): 1 the viewer's own, 2 the rest.
int rackMachineTier(RackMachine m, String? userId) =>
    isMyComputer(m, userId) ? 1 : 2;

/// useOrderedMachines: the viewer's own computers, then the rest, each in
/// the server's order.
List<RackMachine> orderRackMachines(
  Iterable<RackMachine> machines,
  String? userId,
) => [
  ...machines.where((m) => isMyComputer(m, userId)),
  ...machines.where((m) => !isMyComputer(m, userId)),
];

// ------------------------------------------------------------ runtimes

/// shared runtimeAccountUsage.ts RUNTIME_ACCOUNT_USAGE_PROVIDERS.
const rackUsageProviders = ['claude', 'codex', 'kimi', 'grok', 'antigravity'];

/// computersRackFilter.ts RACK_PROVIDER_NAMES.
const rackProviderNames = <String, String>{
  'claude': 'Claude Code',
  'codex': 'Codex',
  'kimi': 'Kimi',
  'grok': 'Grok',
  'antigravity': 'Antigravity',
};

/// shared runtimeCatalog.ts RUNTIMES, in catalog order (id, display name).
const rackRuntimeCatalog = <(String, String)>[
  ('claude', 'Claude Code'),
  ('codex', 'Codex CLI'),
  ('grok', 'Grok Build'),
  ('builtin', 'Built-in Pi'),
  ('antigravity', 'Antigravity CLI'),
  ('kimi-sdk', 'Kimi Code'),
  ('kimi', 'Kimi CLI'),
  ('copilot', 'Copilot CLI'),
  ('cursor', 'Cursor CLI'),
  ('gemini', 'Gemini CLI'),
  ('opencode', 'OpenCode'),
  ('pi', 'Pi'),
  ('qwen', 'Qwen Code'),
  ('qoder', 'Qoder'),
  ('codebuddy', 'CodeBuddy Code'),
];

/// shared getRuntimeDisplayName.
String rackRuntimeDisplayName(String id) {
  for (final (runtime, name) in rackRuntimeCatalog) {
    if (runtime == id) return name;
  }
  return id;
}

int _catalogIndex(String id) {
  for (var i = 0; i < rackRuntimeCatalog.length; i++) {
    if (rackRuntimeCatalog[i].$1 == id) return i;
  }
  return 1 << 30;
}

/// utils/runtimeCatalogOrder.ts compareRuntimeCatalogOrder.
int compareRuntimeCatalogOrder(String a, String b) {
  final d = _catalogIndex(a) - _catalogIndex(b);
  return d != 0 ? d : a.compareTo(b);
}

/// utils/runtimeUsageProvider.ts: the account usage provider a runtime
/// reports through; Kimi Code and Kimi CLI share Kimi's account.
String? usageProviderForRuntime(String id) => switch (id) {
  'claude' || 'codex' || 'grok' || 'antigravity' => id,
  'kimi' || 'kimi-sdk' => 'kimi',
  _ => null,
};

List<String> rackMachineRuntimes(RackMachine m) => [
  for (final r in (m['runtimes'] is List ? m['runtimes'] as List : const []))
    if (r is String) r,
];

/// rackRuntimeColumns.ts: one usage column per provider any of [machines]
/// has (catalog order, at most one per provider), and every runtime that
/// reports no usage in Other.
class RackRuntimeColumns {
  const RackRuntimeColumns(this.usage, this.other);

  /// Providers, each with the runtime that names its column.
  final List<({String provider, String runtimeId})> usage;
  final List<String> other;
}

RackRuntimeColumns rackRuntimeColumns(Iterable<RackMachine> machines) {
  final present = {for (final m in machines) ...rackMachineRuntimes(m)}.toList()
    ..sort(compareRuntimeCatalogOrder);
  final usage = <({String provider, String runtimeId})>[];
  final other = <String>[];
  for (final id in present) {
    final provider = usageProviderForRuntime(id);
    if (provider == null) {
      other.add(id);
    } else if (!usage.any((c) => c.provider == provider)) {
      usage.add((provider: provider, runtimeId: id));
    }
  }
  return RackRuntimeColumns(usage, other);
}

/// rackOtherRuntimes: the machine's runtimes in Other, in the columns' order.
List<String> rackOtherRuntimes(RackMachine m, List<String> other) {
  final own = rackMachineRuntimes(m);
  return [
    for (final id in other)
      if (own.contains(id)) id,
  ];
}

// ------------------------------------------------------------ filters

enum RackStatusFilter { all, online, offline, attention }

enum RackGroupBy { none, prefix, provider }

/// The Runtime filter's items: the usage providers these computers have,
/// then `other` when any runtime has none.
List<String> runtimeFilterOptions(RackRuntimeColumns columns) => [
  for (final c in columns.usage) c.provider,
  if (columns.other.isNotEmpty) 'other',
];

/// The chosen runtimes the computers still have.
List<String> effectiveRuntimeFilter(
  List<String> chosen,
  List<String> options,
) => [
  for (final r in chosen)
    if (options.contains(r)) r,
];

/// utils/computerUpgradeIndicator.ts serverNeedsAttention: the server's
/// verdict (#68), or null from an older server.
bool? serverNeedsAttention(RackMachine m) {
  final attention = m['attention'];
  if (attention is! Map) return null;
  final count = attention['count'];
  return count is num && count > 0;
}

/// computersRackFilter.ts rackNeedsAttention.
bool rackNeedsAttention(RackMachine m) {
  final server = serverNeedsAttention(m);
  if (server != null) return server;
  if (m['isComputer'] == true &&
      (m['computerUpgradeAvailable'] == true || m['status'] == 'offline')) {
    return true;
  }
  if (m['status'] != 'online') return m['isComputer'] == true;
  return computerDiskLow(m) != null;
}

String? _ownerName(RackMachine m) {
  final owner = m['ownerUserId'] != null ? m['owner'] : null;
  if (owner is! Map) return null;
  final display = owner['displayName'];
  return display is String && display.isNotEmpty
      ? display
      : owner['name'] as String?;
}

/// computersRackFilter.ts rackSearchMatch: the trimmed, case-folded search
/// is part of the name, the host name or the owner's name; null when empty.
({bool name, bool hostname, bool owner})? rackSearchMatch(
  RackMachine m,
  String search,
) {
  final query = search.trim().toLowerCase();
  if (query.isEmpty) return null;
  bool holds(Object? part) =>
      part is String && part.toLowerCase().contains(query);
  final owner = m['owner'];
  return (
    name: holds(m['name']),
    hostname: holds(m['hostname']),
    owner: holds(_ownerName(m)) || (owner is Map && holds(owner['name'])),
  );
}

Set<String> _machineRuntimeFilters(RackMachine m) => {
  for (final id in rackMachineRuntimes(m))
    usageProviderForRuntime(id) ?? 'other',
};

List<RackMachine> filterRackMachines(
  List<RackMachine> machines, {
  required String query,
  required RackStatusFilter status,
  required List<String> runtimes,
}) {
  if (query.trim().isEmpty &&
      status == RackStatusFilter.all &&
      runtimes.isEmpty) {
    return machines;
  }
  return [
    for (final m in machines)
      if (_keeps(m, query, status, runtimes)) m,
  ];
}

bool _keeps(
  RackMachine m,
  String query,
  RackStatusFilter status,
  List<String> runtimes,
) {
  final match = rackSearchMatch(m, query);
  if (match != null && !(match.name || match.hostname || match.owner)) {
    return false;
  }
  final online = m['status'] == 'online';
  switch (status) {
    case RackStatusFilter.online when !online:
    case RackStatusFilter.offline when online:
      return false;
    case RackStatusFilter.attention when !rackNeedsAttention(m):
      return false;
    default:
  }
  if (runtimes.isNotEmpty) {
    final own = _machineRuntimeFilters(m);
    if (!runtimes.any(own.contains)) return false;
  }
  return true;
}

// ------------------------------------------------------------ groups

/// shared HOST_PROVIDER_LABELS.
const hostProviderLabels = <String, String>{
  'aws': 'AWS',
  'gcp': 'Google Cloud',
  'hetzner': 'Hetzner Cloud',
  'digitalocean': 'DigitalOcean',
  'vultr': 'Vultr',
  'linode': 'Akamai (Linode)',
  'scaleway': 'Scaleway',
  'alibaba': 'Alibaba Cloud',
  'upcloud': 'UpCloud',
  'exoscale': 'Exoscale',
  'openstack': 'OpenStack',
  'exe_dev': 'exe.dev',
  'sprites': 'Sprites',
  'fly': 'Fly.io',
};

typedef NamePrefix = ({String key, String title});

List<NamePrefix> _namePrefixes(String name) {
  final trimmed = name.trim();
  final words = RegExp(r'[^-_.]+').allMatches(trimmed).toList();
  return [
    for (var i = 0; i < words.length; i++)
      (
        key: [for (final w in words.take(i + 1)) w[0]!.toLowerCase()].join('-'),
        title: trimmed.substring(0, words[i].end),
      ),
  ];
}

int _codeUnitCompare(String a, String b) => a.compareTo(b);

/// computersRackFilter.ts rackNamePrefixGroups (#triage:#291): each name's
/// group in the order given, or null for Other. See the Web source for the
/// three rules; this is a line-by-line port.
List<NamePrefix?> rackNamePrefixGroups(List<String> names) {
  final prefixes = names.map(_namePrefixes).toList();
  final shorterThanAName = {
    for (final own in prefixes)
      for (final p in own.take(own.isEmpty ? 0 : own.length - 1)) p.key,
  };
  final wholeNames = <String, int>{};
  for (final own in prefixes) {
    if (own.isNotEmpty) {
      wholeNames.update(own.last.key, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final ownCandidates = [
    for (final own in prefixes)
      [
        for (var i = 0; i < own.length; i++)
          if (i < own.length - 1 ||
              shorterThanAName.contains(own[i].key) ||
              (wholeNames[own[i].key] ?? 0) > 1)
            own[i],
      ],
  ];
  final support = <String, int>{};
  for (final own in ownCandidates) {
    for (final p in own) {
      support.update(p.key, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final candidates = [
    for (final own in ownCandidates)
      [
        for (final p in own)
          if ((support[p.key] ?? 0) > 1) p.key,
      ].reversed.toList(),
  ];
  final assigned = <String?>[
    for (final own in candidates) own.isEmpty ? null : own.first,
  ];
  int depth(String key) => key.split('-').length;
  for (;;) {
    final groups = <String, List<int>>{};
    for (var i = 0; i < assigned.length; i++) {
      final key = assigned[i];
      if (key != null) (groups[key] ??= []).add(i);
    }
    final lones =
        [
          for (final e in groups.entries)
            if (e.value.length == 1) e.key,
        ]..sort((a, b) {
          final d = depth(b) - depth(a);
          return d != 0 ? d : _codeUnitCompare(a, b);
        });
    if (lones.isEmpty) break;
    final lone = lones.first;
    final under =
        [
          for (final e in groups.entries)
            if (e.key.startsWith('$lone-')) e,
        ]..sort((a, b) {
          final d = a.value.length - b.value.length;
          return d != 0 ? d : _codeUnitCompare(a.key, b.key);
        });
    if (under.isNotEmpty) {
      for (final index in under.first.value) {
        assigned[index] = lone;
      }
    } else {
      final index = groups[lone]!.first;
      final own = candidates[index];
      final next = own.indexOf(lone) + 1;
      assigned[index] = next < own.length ? own[next] : null;
    }
  }
  final spellings = <String, Map<String, int>>{};
  for (var i = 0; i < assigned.length; i++) {
    final key = assigned[i];
    if (key == null) continue;
    final title = prefixes[i].firstWhere((p) => p.key == key).title;
    (spellings[key] ??= {}).update(title, (n) => n + 1, ifAbsent: () => 1);
  }
  final titles = {
    for (final e in spellings.entries)
      e.key:
          (e.value.entries.toList()..sort((a, b) {
                final d = b.value - a.value;
                return d != 0 ? d : _codeUnitCompare(a.key, b.key);
              }))
              .first
              .key,
  };
  return [
    for (final key in assigned)
      key == null ? null : (key: key, title: titles[key]!),
  ];
}

/// One group of the overview. `fallback` groups (Personal computers, Other)
/// come last.
class RackGroup {
  const RackGroup(this.key, this.title, this.fallback, this.machines);
  final String key, title;
  final bool fallback;
  final List<RackMachine> machines;
}

/// Intl.Collator(locale, {numeric: true, sensitivity: "base"}) for the
/// names the rack compares: case- and accent-blind, digits by value.
int rackCollate(String a, String b) {
  final x = _collationKey(a), y = _collationKey(b);
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final (xa, xn) = x[i];
    final (ya, yn) = y[i];
    if (xn != null && yn != null) {
      final d = xn.compareTo(yn);
      if (d != 0) return d;
      continue;
    }
    final d = xa.compareTo(ya);
    if (d != 0) return d;
  }
  return x.length - y.length;
}

List<(String, BigInt?)> _collationKey(String s) => [
  for (final m in RegExp(r'\d+|\D').allMatches(s.toLowerCase()))
    RegExp(r'^\d+$').hasMatch(m[0]!)
        ? (m[0]!, BigInt.parse(m[0]!))
        : (_fold(m[0]!), null),
];

String _fold(String c) =>
    const {
      'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ñ': 'n', 'ç': 'c',
    }[c] ??
    c;

/// computersRackFilter.ts groupRackMachines: [machines] (already sorted) in
/// groups keeping that order inside each; groups by [rank] (a group's best
/// member, lower first), then A to Z; fallback groups last.
List<RackGroup> groupRackMachines(
  List<RackMachine> machines,
  RackGroupBy groupBy, {
  required String personalLabel,
  required String otherLabel,
  int? Function(RackMachine)? rank,
}) {
  if (groupBy == RackGroupBy.none) {
    return [RackGroup('all', '', false, machines)];
  }
  final prefixes = groupBy == RackGroupBy.prefix
      ? rackNamePrefixGroups([for (final m in machines) '${m['name'] ?? ''}'])
      : null;
  final groups = <String, (String, bool, List<RackMachine>, List<int?>)>{};
  for (var i = 0; i < machines.length; i++) {
    final m = machines[i];
    final String key, title;
    final bool fallback;
    if (groupBy == RackGroupBy.provider) {
      final provider = m['hostProvider'];
      final label = provider is String ? hostProviderLabels[provider] : null;
      (key, title, fallback) = label != null
          ? ('provider:$provider', label, false)
          : ('fallback:provider', personalLabel, true);
    } else {
      final prefix = prefixes![i];
      (key, title, fallback) = prefix != null
          ? ('prefix:${prefix.key}', prefix.title, false)
          : ('fallback:prefix', otherLabel, true);
    }
    final group = groups.putIfAbsent(key, () => (title, fallback, [], [null]));
    group.$3.add(m);
    final value = rank?.call(m);
    if (value != null && (group.$4[0] == null || value < group.$4[0]!)) {
      group.$4[0] = value;
    }
  }
  final sorted = groups.entries.toList()
    ..sort((a, b) {
      final (at, af, _, ab) = a.value;
      final (bt, bf, _, bb) = b.value;
      if (af != bf) return af ? 1 : -1;
      if (ab[0] != null || bb[0] != null) {
        if (ab[0] == null) return 1;
        if (bb[0] == null) return -1;
        if (ab[0] != bb[0]) return ab[0]!.compareTo(bb[0]!);
      }
      return rackCollate(at, bt);
    });
  return [
    for (final e in sorted)
      RackGroup(e.key, e.value.$1, e.value.$2, e.value.$3),
  ];
}

// ------------------------------------------------------------ sort

enum RackSortDirection { asc, desc }

/// `name`, `disk`, `memory` or `remaining:<provider>`.
class RackSort {
  const RackSort(this.key, this.direction);
  final String key;
  final RackSortDirection direction;
  @override
  bool operator ==(Object other) =>
      other is RackSort && other.key == key && other.direction == direction;
  @override
  int get hashCode => Object.hash(key, direction);
}

bool isRackSortKey(String key) =>
    key == 'name' ||
    key == 'disk' ||
    key == 'memory' ||
    rackUsageProviders.any((p) => key == 'remaining:$p');

String? parseRemainingSortKey(String key) {
  if (!key.startsWith('remaining:')) return null;
  final provider = key.substring('remaining:'.length);
  return rackUsageProviders.contains(provider) ? provider : null;
}

/// Numbers start high to low, the name A to Z.
RackSortDirection firstSortDirection(String key) =>
    key == 'name' ? RackSortDirection.asc : RackSortDirection.desc;

/// The stored sort if these computers still have its runtime; else null.
RackSort? effectiveRackSort(RackSort? sort, RackRuntimeColumns columns) {
  if (sort == null) return null;
  final provider = parseRemainingSortKey(sort.key);
  if (provider == null) return sort;
  return columns.usage.any((c) => c.provider == provider) ? sort : null;
}

/// targetComputerInfo.ts liveDiskStatus / liveMemoryStatus: online only.
Map? liveResourceStatus(RackMachine m, String field) {
  if (m['status'] != 'online') return null;
  final status = m[field];
  return status is Map ? status : null;
}

double? rackUsedRatio(Map? status) {
  if (status == null) return null;
  final available = status['availableBytes'], total = status['totalBytes'];
  if (available is! num || total is! num || total <= 0) return null;
  return 1 - available / total;
}

/// What a provider's accounts on a computer have left, 0 to 1 (the usage
/// columns' reads, WP-COMP2); null without a read.
typedef RackRemaining = double? Function(RackMachine m, String provider);

Object? rackSortValue(RackMachine m, String key, RackRemaining? remaining) {
  if (key == 'name') {
    final name = '${m['name'] ?? ''}'.trim();
    final host = '${m['hostname'] ?? ''}'.trim();
    return name.isNotEmpty ? name : (host.isNotEmpty ? host : null);
  }
  if (key == 'disk') return rackUsedRatio(liveResourceStatus(m, 'diskStatus'));
  if (key == 'memory') {
    return rackUsedRatio(liveResourceStatus(m, 'memoryStatus'));
  }
  final provider = parseRemainingSortKey(key);
  if (provider == null ||
      !rackMachineRuntimes(
        m,
      ).any((r) => usageProviderForRuntime(r) == provider)) {
    return null;
  }
  return remaining?.call(m, provider);
}

/// [machines] in [sort]'s order; no value is last both ways; ties keep the
/// list's own order.
List<RackMachine> sortRackMachines(
  List<RackMachine> machines,
  RackSort sort, {
  RackRemaining? remaining,
}) {
  final sign = sort.direction == RackSortDirection.asc ? 1 : -1;
  final keyed = [
    for (var i = 0; i < machines.length; i++)
      (i, machines[i], rackSortValue(machines[i], sort.key, remaining)),
  ];
  keyed.sort((a, b) {
    final (ai, _, av) = a;
    final (bi, _, bv) = b;
    int order;
    if (av == null || bv == null) {
      order = av == bv ? 0 : (av == null ? 1 : -1);
    } else if (av is String && bv is String) {
      order = sign * rackCollate(av, bv);
    } else {
      order = sign * (av as num).compareTo(bv as num);
    }
    return order != 0 ? order : ai - bi;
  });
  return [for (final (_, m, _) in keyed) m];
}

/// The Sort's choices in sections: Mine first (`default`) and Name; each
/// runtime's remaining; Disk and Memory.
List<List<String>> sortMenuSections(RackRuntimeColumns columns) => [
  const ['default', 'name'],
  if (columns.usage.isNotEmpty)
    [for (final c in columns.usage) 'remaining:${c.provider}'],
  const ['disk', 'memory'],
];

RackSort? chooseRackSortKey(String key) =>
    key == 'default' ? null : RackSort(key, firstSortDirection(key));

// ------------------------------------------------------------ counts

/// ComputersRackCounts' numbers: computers, online, agents and (when the
/// server summarizes) how many need attention.
({int computers, int online, int agents, int? attention}) rackCounts(
  List<RackMachine> machines,
  int Function(RackMachine) agentsOn,
) {
  var agents = 0;
  for (final m in machines) {
    agents += agentsOn(m);
  }
  final summarized = machines.any((m) => m['attention'] is Map);
  final attention = [
    for (final m in machines)
      if ((serverNeedsAttention(m) ?? false)) m,
  ].length;
  return (
    computers: machines.length,
    online: machines.where((m) => m['status'] == 'online').length,
    agents: agents,
    attention: summarized && attention > 0 ? attention : null,
  );
}
