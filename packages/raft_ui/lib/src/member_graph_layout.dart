// The member graph's data model, link derivation, force layout and zoom
// transform: a line-for-line port of the pure parts of Web
// `components/settings/MemberGraphSection.tsx` (buildMemberLinks,
// computeMemberNetworkLayout, d3-zoom's wheel / pan / pinch maths). Pure Dart
// (no widgets) so the layout is testable and can run off the UI thread.
import 'dart:math' as math;
import 'dart:typed_data';

const double raftGraphViewBoxWidth = 920;
const double raftGraphViewBoxHeight = 560;
const double raftGraphPadding = 58;
const double raftGraphMaxZoom = 4;
const double raftGraphNodeSize = 36;
const double _centerX = raftGraphViewBoxWidth / 2;
const double _centerY = raftGraphViewBoxHeight / 2;

/// `GraphHuman` / `GraphAgent` of `GET /servers/:id/member-graph`.
class RaftGraphMember {
  const RaftGraphMember({
    required this.agent,
    required this.id,
    required this.name,
    this.displayName,
    this.avatarUrl,
    this.gravatarHash = '',
    this.channelIds = const [],
  });

  factory RaftGraphMember.fromJson(Map<String, dynamic> json) =>
      RaftGraphMember(
        agent: json['type'] == 'agent',
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        gravatarHash: json['gravatarHash'] is String
            ? json['gravatarHash'] as String
            : '',
        channelIds: [
          for (final c in (json['channelIds'] as List? ?? const [])) '$c',
        ],
      );

  final bool agent;
  final String id, name;
  final String? displayName, avatarUrl;
  final String gravatarHash;
  final List<String> channelIds;

  /// `member.displayName || member.name`.
  String get label =>
      displayName != null && displayName!.isNotEmpty ? displayName! : name;

  /// `${type}:${id}`.
  String get key => '${agent ? 'agent' : 'human'}:$id';
}

/// `GraphChannel`.
class RaftGraphChannel {
  const RaftGraphChannel({
    required this.id,
    required this.name,
    required this.humanCount,
    required this.agentCount,
    required this.memberCount,
  });

  factory RaftGraphChannel.fromJson(Map<String, dynamic> json) =>
      RaftGraphChannel(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        humanCount: (json['humanCount'] as num?)?.toInt() ?? 0,
        agentCount: (json['agentCount'] as num?)?.toInt() ?? 0,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      );

  final String id, name;
  final int humanCount, agentCount, memberCount;
}

/// `MemberLink`: two members that share at least one channel.
class RaftGraphLink {
  RaftGraphLink(this.source, this.target);
  final String source, target;
  final channelIds = <String>[];
  final channelNames = <String>[];
  int get weight => channelIds.length;
}

class RaftGraphPoint {
  const RaftGraphPoint(this.x, this.y);
  final double x, y;
}

/// JavaScript `a.localeCompare(b)` under the default ICU root collation, as far
/// as member names need it: punctuation < digits < letters, letters compared
/// without case or accents first, then lowercase before uppercase.
int raftLocaleCompare(String a, String b) {
  int primary(int unit) {
    if (unit >= 0x30 && unit <= 0x39) return 0x1000 + unit;
    final lower = _foldAccent(String.fromCharCode(unit).toLowerCase());
    final code = lower.codeUnitAt(0);
    if (code >= 0x61 && code <= 0x7a) return 0x2000 + code;
    if (code < 0x80) return code; // whitespace and punctuation sort first
    return 0x10000 + code;
  }

  final ka = a.runes.toList(), kb = b.runes.toList();
  final n = math.min(ka.length, kb.length);
  for (var i = 0; i < n; i++) {
    final d = primary(ka[i]) - primary(kb[i]);
    if (d != 0) return d.sign;
  }
  if (ka.length != kb.length) return (ka.length - kb.length).sign;
  // Tertiary: lowercase before uppercase.
  for (var i = 0; i < n; i++) {
    if (ka[i] == kb[i]) continue;
    final la =
        String.fromCharCode(ka[i]) == String.fromCharCode(ka[i]).toLowerCase();
    final lb =
        String.fromCharCode(kb[i]) == String.fromCharCode(kb[i]).toLowerCase();
    if (la != lb) return la ? -1 : 1;
    return ka[i].compareTo(kb[i]).sign;
  }
  return 0;
}

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
};
String _foldAccent(String c) => _accents[c] ?? c;

/// `[...data.humans, ...data.agents]` sorted by display name.
List<RaftGraphMember> raftSortedGraphMembers(
  List<RaftGraphMember> humans,
  List<RaftGraphMember> agents,
) => _stableSort([
  ...humans,
  ...agents,
], (a, b) => raftLocaleCompare(a.label, b.label));

/// Channels by member count (largest first), then name.
List<RaftGraphChannel> raftSortedGraphChannels(
  List<RaftGraphChannel> channels,
) => _stableSort(
  channels,
  (a, b) => b.memberCount != a.memberCount
      ? b.memberCount - a.memberCount
      : raftLocaleCompare(a.name, b.name),
);

/// JavaScript's sort is stable; Dart's is not guaranteed to be.
List<T> _stableSort<T>(List<T> input, int Function(T a, T b) compare) {
  final indexed = [for (var i = 0; i < input.length; i++) (i, input[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// `buildMemberLinks`: channel co-membership, preferring focused channels
/// (everything except `all` and rooms over 36 members) so the default shape is
/// not a complete graph.
List<RaftGraphLink> raftBuildMemberLinks(
  List<RaftGraphMember> members,
  List<RaftGraphChannel> channels,
) {
  final membersByChannel = <String, List<String>>{};
  for (final member in members) {
    for (final channelId in member.channelIds) {
      (membersByChannel[channelId] ??= []).add(member.key);
    }
  }

  List<RaftGraphLink> linksFor(List<RaftGraphChannel> candidates) {
    final links = <String, RaftGraphLink>{};
    for (final channel in candidates) {
      final keys =
          (membersByChannel[channel.id] ?? const <String>[]).toSet().toList()
            ..sort();
      for (var i = 0; i < keys.length; i++) {
        for (var j = i + 1; j < keys.length; j++) {
          final source = keys[i], target = keys[j];
          final link = links.putIfAbsent(
            '$source--$target',
            () => RaftGraphLink(source, target),
          );
          link.channelIds.add(channel.id);
          link.channelNames.add(channel.name);
        }
      }
    }
    return links.values.toList();
  }

  final focused = linksFor([
    for (final c in channels)
      if (c.name != 'all' && c.memberCount <= 36) c,
  ]);
  return focused.isNotEmpty
      ? focused
      : linksFor([
          for (final c in channels)
            if (c.name != 'all') c,
        ]);
}

/// `buildMemberLinkDegrees`: distinct neighbours per member.
Map<String, int> raftMemberLinkDegrees(List<RaftGraphLink> links) {
  final neighbors = <String, Set<String>>{};
  for (final link in links) {
    (neighbors[link.source] ??= {}).add(link.target);
    (neighbors[link.target] ??= {}).add(link.source);
  }
  return {for (final e in neighbors.entries) e.key: e.value.length};
}

class _Component {
  _Component(this.keys, this.cx, this.cy, this.radiusX, this.radiusY);
  final List<String> keys;
  final double cx, cy, radiusX, radiusY;
}

double _clamp(double value, double min, double max) =>
    math.max(min, math.min(max, value));

double _seededAngle(String input) {
  var hash = 0;
  for (final unit in input.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFFFFFF;
  }
  return hash / 0xffffffff * math.pi * 2;
}

RaftGraphPoint _initialPoint(String key, int index, int total) {
  final angle =
      index / math.max(total, 1) * math.pi * 2 +
      _seededAngle(key) * 0.08 -
      math.pi / 2;
  return RaftGraphPoint(
    _centerX + math.cos(angle) * 326,
    _centerY + math.sin(angle) * 198,
  );
}

RaftGraphPoint _componentInitialPoint(
  String key,
  int index,
  int total,
  _Component c,
) {
  if (total <= 1) return RaftGraphPoint(c.cx, c.cy);
  final angle =
      index / total * math.pi * 2 + _seededAngle(key) * 0.1 - math.pi / 2;
  final scale = total <= 3 ? 0.46 : 0.78;
  return RaftGraphPoint(
    c.cx + math.cos(angle) * c.radiusX * scale,
    c.cy + math.sin(angle) * c.radiusY * scale,
  );
}

List<List<String>> _connectedComponents(
  List<String> nodeKeys,
  Map<String, Set<String>> neighbors,
) {
  final visited = <String>{};
  final components = <List<String>>[];
  for (final key in nodeKeys) {
    if (visited.contains(key)) continue;
    final stack = [key];
    final component = <String>[];
    visited.add(key);
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      component.add(current);
      for (final next in neighbors[current] ?? const <String>{}) {
        if (visited.contains(next)) continue;
        visited.add(next);
        stack.add(next);
      }
    }
    component.sort();
    components.add(component);
  }
  return _stableSort(
    components,
    (a, b) => b.length != a.length
        ? b.length - a.length
        : raftLocaleCompare(a.first, b.first),
  );
}

List<_Component> _assignComponentLayouts(
  List<List<String>> components,
  bool dense,
) {
  if (components.length <= 1) {
    return [
      _Component(
        components.isEmpty ? <String>[] : components[0],
        _centerX,
        _centerY,
        326,
        198,
      ),
    ];
  }
  final largest = components[0].length;
  final second = components[1].length;
  final useGrid = largest <= 1 || second >= math.max(4, largest * 0.45);
  const usableWidth = raftGraphViewBoxWidth - raftGraphPadding * 2;
  const usableHeight = raftGraphViewBoxHeight - raftGraphPadding * 2;

  if (useGrid) {
    final columns = math.sqrt(components.length * 1.45).ceil();
    final rows = (components.length / columns).ceil();
    final cellWidth = usableWidth / columns;
    final cellHeight = usableHeight / rows;
    return [
      for (final (index, keys) in components.indexed)
        () {
          final column = index % columns;
          final row = index ~/ columns;
          final sizeScale = _clamp(math.sqrt(keys.length) / 3, 0.42, 1);
          return _Component(
            keys,
            raftGraphPadding + cellWidth * (column + 0.5),
            raftGraphPadding + cellHeight * (row + 0.5),
            math.max(28, math.min(cellWidth * 0.34 * sizeScale, 150)),
            math.max(24, math.min(cellHeight * 0.34 * sizeScale, 104)),
          );
        }(),
    ];
  }

  final rail = components.sublist(1);
  final railColumns = rail.length > 7 ? 2 : 1;
  final railRows = (rail.length / railColumns).ceil();
  final railWidth = dense ? 296.0 : 260.0;
  final mainWidth = raftGraphViewBoxWidth - railWidth - raftGraphPadding * 2;
  final railCellWidth = railWidth / railColumns;
  final railCellHeight = usableHeight / math.max(railRows, 1);
  final layouts = <_Component>[
    _Component(
      components[0],
      raftGraphPadding + mainWidth * 0.5,
      _centerY,
      math.min(mainWidth * 0.38, dense ? 250 : 282),
      dense ? 190 : 206,
    ),
  ];
  for (final (railIndex, keys) in rail.indexed) {
    final column = railIndex % railColumns;
    final row = railIndex ~/ railColumns;
    final sizeScale = _clamp(math.sqrt(keys.length) / 2.2, 0.44, 1);
    layouts.add(
      _Component(
        keys,
        raftGraphViewBoxWidth -
            raftGraphPadding -
            railWidth +
            railCellWidth * (column + 0.5),
        raftGraphPadding + railCellHeight * (row + 0.5),
        math.max(18, math.min(railCellWidth * 0.28 * sizeScale, 56)),
        math.max(14, math.min(railCellHeight * 0.24 * sizeScale, 40)),
      ),
    );
  }
  return layouts;
}

/// Result of [raftComputeMemberNetworkLayout].
class RaftGraphLayout {
  const RaftGraphLayout(this.positions, this.degrees);

  /// Member key -> position in the 920 x 560 view box.
  final Map<String, RaftGraphPoint> positions;

  /// Member key -> distinct linked members.
  final Map<String, int> degrees;
}

/// `computeMemberNetworkLayout`: components laid out on a grid or a main
/// area plus a rail, then 128 (150 when dense) rounds of repulsion, link
/// springs and gravity with a linearly cooling `alpha`.
RaftGraphLayout raftComputeMemberNetworkLayout(
  List<RaftGraphMember> members,
  List<RaftGraphLink> links,
  bool dense,
) {
  final positions = <String, RaftGraphPoint>{};
  final degrees = <String, int>{};
  final nodeKeys = [for (final m in members) m.key];
  final neighbors = <String, Set<String>>{};
  for (final (index, member) in members.indexed) {
    positions[member.key] = _initialPoint(member.key, index, members.length);
    neighbors[member.key] = {};
  }
  for (final link in links) {
    neighbors[link.source]?.add(link.target);
    neighbors[link.target]?.add(link.source);
  }
  for (final member in members) {
    degrees[member.key] = neighbors[member.key]?.length ?? 0;
  }
  if (nodeKeys.length <= 1) return RaftGraphLayout(positions, degrees);

  final layouts = _assignComponentLayouts(
    _connectedComponents(nodeKeys, neighbors),
    dense,
  );
  final n = nodeKeys.length;
  final indexOf = {for (var i = 0; i < n; i++) nodeKeys[i]: i};
  final px = Float64List(n), py = Float64List(n);
  final component = List<int>.filled(n, 0);
  final gx = Float64List(n), gy = Float64List(n);
  for (final (ci, c) in layouts.indexed) {
    for (final (index, key) in c.keys.indexed) {
      final i = indexOf[key]!;
      component[i] = ci;
      gx[i] = c.cx;
      gy[i] = c.cy;
      final p = _componentInitialPoint(key, index, c.keys.length, c);
      px[i] = p.x;
      py[i] = p.y;
    }
  }
  final deg = Int32List(n);
  for (var i = 0; i < n; i++) {
    deg[i] = degrees[nodeKeys[i]] ?? 0;
  }
  final linkSource = [for (final l in links) indexOf[l.source] ?? -1];
  final linkTarget = [for (final l in links) indexOf[l.target] ?? -1];

  const area = raftGraphViewBoxWidth * raftGraphViewBoxHeight;
  final repulsion = math.min(8200, math.max(2800, area / math.max(n, 1) / 1.9));
  final iterations = dense ? 150 : 128;
  final multi = layouts.length > 1;
  final dx = Float64List(n), dy = Float64List(n);

  for (var step = 0; step < iterations; step++) {
    final alpha = 1 - step / iterations;
    dx.fillRange(0, n, 0);
    dy.fillRange(0, n, 0);
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (multi && component[i] != component[j]) continue;
        final ddx = px[i] - px[j];
        final ddy = py[i] - py[j];
        final distanceSq = math.max(100.0, ddx * ddx + ddy * ddy);
        final force = repulsion / distanceSq * alpha;
        final distance = math.sqrt(distanceSq);
        final fx = ddx / distance * force;
        final fy = ddy / distance * force;
        dx[i] += fx;
        dy[i] += fy;
        dx[j] -= fx;
        dy[j] -= fy;
      }
    }
    for (var k = 0; k < links.length; k++) {
      final s = linkSource[k], t = linkTarget[k];
      if (s < 0 || t < 0) continue;
      final ddx = px[t] - px[s];
      final ddy = py[t] - py[s];
      final distance = math.max(1.0, math.sqrt(ddx * ddx + ddy * ddy));
      final desired = dense ? 112.0 : 210.0;
      final force =
          (distance - desired) *
          (0.018 + math.min(links[k].weight, 4) * 0.004) *
          alpha;
      final fx = ddx / distance * force;
      final fy = ddy / distance * force;
      dx[s] += fx;
      dy[s] += fy;
      dx[t] -= fx;
      dy[t] -= fy;
    }
    for (var i = 0; i < n; i++) {
      final gravity = deg[i] == 0 ? 0.04 : 0.014;
      dx[i] += (gx[i] - px[i]) * gravity * alpha;
      dy[i] += (gy[i] - py[i]) * gravity * alpha;
      px[i] = _clamp(
        px[i] + dx[i],
        raftGraphPadding,
        raftGraphViewBoxWidth - raftGraphPadding,
      );
      py[i] = _clamp(
        py[i] + dy[i],
        raftGraphPadding,
        raftGraphViewBoxHeight - raftGraphPadding,
      );
    }
  }
  for (var i = 0; i < n; i++) {
    positions[nodeKeys[i]] = RaftGraphPoint(px[i], py[i]);
  }
  return RaftGraphLayout(positions, degrees);
}

/// `dense`: a large graph draws curved, fainter edges and side labels.
bool raftGraphDense(int memberCount, int linkCount) =>
    memberCount > 34 || linkCount > 120;

/// d3-zoom's `ZoomTransform` (`k`, `x`, `y`) with the pieces the graph uses.
class RaftGraphZoom {
  const RaftGraphZoom([this.k = 1, this.x = 0, this.y = 0]);
  final double k, x, y;
  static const identity = RaftGraphZoom();

  double invertX(double px) => (px - x) / k;
  double invertY(double py) => (py - y) / k;
  RaftGraphZoom translate(double tx, double ty) =>
      RaftGraphZoom(k, x + k * tx, y + k * ty);
  RaftGraphZoom scale(double factor) => RaftGraphZoom(k * factor, x, y);

  /// d3-zoom `constrain` with `extent = [[0, 0], [w, h]]` and
  /// `translateExtent = [[0, 0], [w, h]]`.
  RaftGraphZoom constrain(double w, double h) {
    final dx0 = invertX(0) - 0, dx1 = invertX(w) - w;
    final dy0 = invertY(0) - 0, dy1 = invertY(h) - h;
    double pick(double d0, double d1) => d1 > d0
        ? (d0 + d1) / 2
        : (math.min(0.0, d0) != 0 ? math.min(0.0, d0) : math.max(0.0, d1));
    return translate(pick(dx0, dx1), pick(dy0, dy1));
  }

  /// A wheel step about [px], [py]: `k * 2^delta`, clamped to 1..4, keeping
  /// the point under the pointer fixed.
  RaftGraphZoom zoomAt(double px, double py, double delta, double w, double h) {
    final next = _clamp(k * math.pow(2, delta), 1, raftGraphMaxZoom);
    return _about(px, py, next, w, h);
  }

  /// Zoom to scale [next] keeping content point under ([px], [py]) in place.
  RaftGraphZoom _about(double px, double py, double next, double w, double h) {
    final p0x = invertX(px), p0y = invertY(py);
    return RaftGraphZoom(
      next,
      px - p0x * next,
      py - p0y * next,
    ).constrain(w, h);
  }

  /// [zoomAt] with an explicit target scale (double click: `k * 2`, shift
  /// `k / 2`; pinch).
  RaftGraphZoom zoomTo(
    double px,
    double py,
    double target,
    double w,
    double h,
  ) => _about(px, py, _clamp(target, 1, raftGraphMaxZoom), w, h);

  /// Pan by a pointer movement.
  RaftGraphZoom pan(double dx, double dy, double w, double h) =>
      RaftGraphZoom(k, x + dx, y + dy).constrain(w, h);

  /// d3-zoom `wheelDelta` for a wheel event.
  static double wheelDelta(double deltaY, {bool ctrl = false, int mode = 0}) =>
      -deltaY * (mode == 1 ? 0.05 : (mode != 0 ? 1 : 0.002)) * (ctrl ? 10 : 1);

  @override
  bool operator ==(Object other) =>
      other is RaftGraphZoom && other.k == k && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(k, x, y);
}

/// The SVG view box of a zoom transform (`viewBox` memo of the Web canvas).
({double x, double y, double width, double height}) raftGraphViewBox(
  RaftGraphZoom z,
  double width,
  double height,
) {
  if (width <= 0 || height <= 0) {
    return (
      x: 0,
      y: 0,
      width: raftGraphViewBoxWidth,
      height: raftGraphViewBoxHeight,
    );
  }
  final w = raftGraphViewBoxWidth / z.k;
  final h = raftGraphViewBoxHeight / z.k;
  return (
    x: _clamp(
      -z.x / z.k / width * raftGraphViewBoxWidth,
      0,
      raftGraphViewBoxWidth - w,
    ),
    y: _clamp(
      -z.y / z.k / height * raftGraphViewBoxHeight,
      0,
      raftGraphViewBoxHeight - h,
    ),
    width: w,
    height: h,
  );
}

/// `shortLabel`.
String raftGraphShortLabel(String label, [int max = 18]) {
  final runes = label.codeUnits;
  return runes.length > max ? '${label.substring(0, max - 1)}…' : label;
}
