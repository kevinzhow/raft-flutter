import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/closed_dm_reopen.dart';
import '../data/workspace_controller.dart';
import 'sidebar_projection.dart';
import 'sidebar_reorder.dart';

/// Where the lifted row sits in the live projection: a section and the slot
/// among that section's other rows ([shown] never holds the lifted row).
class SidebarDropTarget {
  const SidebarDropTarget(this.group, this.shown, this.index);
  final SidebarGroup group;
  final List<SidebarEntry> shown;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is SidebarDropTarget &&
      other.group.id == group.id &&
      other.index == index;

  @override
  int get hashCode => Object.hash(group.id, index);
}

/// The item drag in flight (Sidebar.tsx `sidebarDndActiveId`,
/// `sidebarDndProjection`): the section the row was lifted from and the slot
/// it holds now. Sections list their rows through [project], so the row moves
/// as the pointer does and the section it left closes up.
class SidebarDrag {
  SidebarDrag._();
  static final source = _Signal<String?>(null);
  static final target = _Signal<SidebarDropTarget?>(null);
  static SidebarEntry? entry;
  static bool get active => source.value != null;
  static Listenable get changes => Listenable.merge([source, target]);

  /// [base] as [group] lists it with the lifted row moved to its slot.
  static List<SidebarEntry> project(
    SidebarGroup group,
    List<SidebarEntry> base,
  ) {
    final lifted = entry, to = target.value;
    if (lifted == null || to == null) return base;
    final rest = [
      for (final e in base)
        if (e.key != lifted.key) e,
    ];
    if (group.id != to.group.id) {
      return rest.length == base.length ? base : rest;
    }
    return [...rest]..insert(to.index.clamp(0, rest.length), lifted);
  }
}

/// A process-wide value listenable. It is not a [ChangeNotifier]: it lives as
/// long as the sidebar can be dragged and has nothing to dispose.
class _Signal<T> implements ValueListenable<T> {
  _Signal(this._value);
  T _value;
  final _listeners = <VoidCallback>{};

  @override
  T get value => _value;
  set value(T next) {
    if (_value == next) return;
    _value = next;
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

/// One lifted row, as it was listed when it was lifted ([shown] are the rows
/// of [group] then): its owner, section and entry.
class SidebarDragSession {
  SidebarDragSession({
    required this.w,
    required this.group,
    required this.entry,
    required this.shown,
  });
  final WorkspaceController w;
  final SidebarGroup group;
  final SidebarEntry entry;
  final List<SidebarEntry> shown;
  Timer? _scroll;
  Offset? _at;

  void start() {
    SidebarDrag.entry = entry;
    SidebarDrag.target.value = null;
    SidebarDrag.source.value = group.id;
  }

  void move(Offset at) {
    _at = at;
    SidebarDrag.target.value = _resolve(at);
    _autoscroll(at);
  }

  /// Persists where the row was dropped through the optimistic
  /// [WorkspaceController.updateSidebarOrder].
  void finish() {
    final to = SidebarDrag.target.value;
    cancel();
    if (to == null) return;
    final updates = to.group.id == group.id
        ? sidebarReorderUpdates(
            group: group,
            shown: shown,
            preferences: w.sidebarOrder,
            from: shown.indexWhere((e) => e.key == entry.key),
            to: to.index,
          )
        : sidebarCrossMoveUpdates(
            entry: entry,
            dest: to.group,
            shown: to.shown,
            index: to.index,
            preferences: w.sidebarOrder,
          );
    if (updates != null) unawaited(w.updateSidebarOrder(updates));
  }

  void cancel() {
    _scroll?.cancel();
    _scroll = null;
    SidebarDrag.target.value = null;
    SidebarDrag.source.value = null;
    SidebarDrag.entry = null;
  }

  /// The slot under the pointer. Over the lifted row itself, over a section
  /// that cannot take it, or over no row at all, the row stays where it is
  /// (Sidebar.tsx `resolveSidebarDndRetainedContainer`).
  SidebarDropTarget? _resolve(Offset at) {
    _SidebarDropZoneState? row, empty;
    for (final zone in _zones) {
      final box = zone.context.findRenderObject();
      if (box is RenderBox &&
          box.attached &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).contains(at)) {
        if (zone.widget.entryKey == null) {
          empty = zone;
        } else {
          row = zone;
        }
      }
    }
    final zone = (row ?? empty)?.widget;
    final current = SidebarDrag.target.value;
    if (zone == null ||
        zone.entryKey == entry.key ||
        !sidebarDropAllowed(entry, zone.group, w.sidebarOrder)) {
      return current;
    }
    final rest = [
      for (final e in zone.shown)
        if (e.key != entry.key) e,
    ];
    if (zone.entryKey == null) {
      return SidebarDropTarget(zone.group, rest, rest.length);
    }
    final box = row!.context.findRenderObject()! as RenderBox;
    final center = box.localToGlobal(box.size.center(Offset.zero)).dy;
    final over = rest.indexWhere((e) => e.key == zone.entryKey);
    return over < 0
        ? current
        : SidebarDropTarget(zone.group, rest, over + (at.dy >= center ? 1 : 0));
  }

  static const _edge = 56.0, _step = 14.0;

  /// A pointer held near the top or bottom of the list scrolls it, as the
  /// list's own drag did.
  void _autoscroll(Offset at) {
    ScrollPosition? position;
    Rect? view;
    for (final zone in _zones) {
      final scrollable = Scrollable.maybeOf(zone.context);
      final box = scrollable?.context.findRenderObject();
      if (scrollable != null && box is RenderBox && box.hasSize) {
        position = scrollable.position;
        view = box.localToGlobal(Offset.zero) & box.size;
        break;
      }
    }
    final pos = position;
    final direction = view == null
        ? 0
        : at.dy < view.top + _edge
        ? -1
        : at.dy > view.bottom - _edge
        ? 1
        : 0;
    if (pos == null || direction == 0) {
      _scroll?.cancel();
      _scroll = null;
      return;
    }
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Runs only while a lifted row is held within the list's edge band and is cancelled when it leaves, drops or is cancelled.
    _scroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final to = (pos.pixels + direction * _step).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (to != pos.pixels) pos.jumpTo(to);
      final last = _at;
      if (last != null) SidebarDrag.target.value = _resolve(last);
    });
  }
}

final _zones = <_SidebarDropZoneState>{};

/// A row (or the empty hint) of a section that a dragged row can land on. The
/// lifted row itself shows faded where the projection holds it
/// (`opacity: isDragging ? 0.12 : 1`).
class SidebarDropZone extends StatefulWidget {
  const SidebarDropZone({
    super.key,
    required this.group,
    required this.shown,
    required this.child,
    this.entryKey,
  });
  final SidebarGroup group;
  final List<SidebarEntry> shown;
  final String? entryKey;
  final Widget child;

  @override
  State<SidebarDropZone> createState() => _SidebarDropZoneState();
}

class _SidebarDropZoneState extends State<SidebarDropZone> {
  @override
  void initState() {
    super.initState();
    _zones.add(this);
  }

  @override
  void dispose() {
    _zones.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.entryKey == null
      ? widget.child
      : ValueListenableBuilder<String?>(
          valueListenable: SidebarDrag.source,
          child: widget.child,
          builder: (context, source, child) =>
              source != null && SidebarDrag.entry?.key == widget.entryKey
              ? Opacity(opacity: .12, child: child)
              : child!,
        );
}

/// Sidebar.tsx `getSidebarDndHomeContainer`: the section an entry belongs to
/// when it is neither pinned nor placed (null for an agent with no DM yet).
String? sidebarHomeGroupId(SidebarEntry entry) {
  final c = entry.channel;
  if (c == null) return null;
  if (c.type == 'dm') return 'system:dms';
  return c.type == 'joint' ? 'system:joint' : 'system:channels';
}

/// Sidebar.tsx `isValidSidebarDndDestination`: only a manually sorted section
/// takes a drop; Pinned and custom sections take any row, the others only
/// their own.
bool sidebarDropAllowed(
  SidebarEntry entry,
  SidebarGroup dest,
  Map<String, dynamic> preferences,
) =>
    sidebarGroupReorderable(dest, preferences) &&
    (dest.id == 'system:pinned' ||
        dest.custom ||
        sidebarHomeGroupId(entry) == dest.id);

({String kind, String id}) _pinRef(SidebarEntry e) {
  if (e.agent != null) return (kind: 'agent', id: '${e.agent!['id']}');
  final c = e.channel!;
  if (c.type != 'dm') return (kind: 'channel', id: c.id);
  return (
    kind: c.string('peerType') == 'agent' ? 'agent' : 'human',
    id: c.string('peerId'),
  );
}

({String kind, String id}) _placement(SidebarEntry e) => e.agent != null
    ? (kind: 'agent', id: '${e.agent!['id']}')
    : (kind: 'channel', id: e.channel!.id);

List<Map<String, dynamic>> _maps(Object? value) => [
  for (final r in (value as List? ?? const []))
    if (r is Map) Map<String, dynamic>.from(r),
];

/// The `updateSidebarOrder` payload (Sidebar.tsx `handleSidebarDragEnd`) for
/// [entry] dropped into [dest] at [index] among the [shown] rows: Pinned
/// takes it as a pin and drops its placement, a custom section as a
/// placement and drops its pin, a home section reorders its own list and
/// drops both. Null when the entry cannot go there.
Map<String, dynamic>? sidebarCrossMoveUpdates({
  required SidebarEntry entry,
  required SidebarGroup dest,
  required List<SidebarEntry> shown,
  required int index,
  required Map<String, dynamic> preferences,
}) {
  if (!sidebarDropAllowed(entry, dest, preferences) ||
      (entry.agent == null && entry.channel == null)) {
    return null;
  }
  final item = _placement(entry), pin = _pinRef(entry);
  final pinned = _maps(preferences['pinned']);
  final placements = _maps(preferences['sectionPlacements']);
  final pinnedWithout = [
    for (final p in pinned)
      if (!(p['kind'] == pin.kind && p['id'] == pin.id)) p,
  ];
  final placementsWithout = [
    for (final p in placements)
      if (!(p['kind'] == item.kind && p['id'] == item.id)) p,
  ];
  final at = index.clamp(0, shown.length);
  final next = [...shown]..insert(at, entry);
  if (dest.id == 'system:pinned') {
    final refs = [
      for (final e in next)
        pinned.firstWhere(
          (p) => p['kind'] == _pinRef(e).kind && p['id'] == _pinRef(e).id,
          orElse: () => {'kind': _pinRef(e).kind, 'id': _pinRef(e).id},
        ),
    ];
    final seen = <String>{};
    return {
      'pinned': [
        for (final r in refs)
          if (seen.add('${r['kind']}:${r['id']}')) r,
      ],
      if (placementsWithout.length != placements.length)
        'sectionPlacements': placementsWithout,
    };
  }
  if (dest.custom) {
    final own =
        [
          for (final p in placementsWithout)
            if (p['sectionId'] == dest.id) p,
        ]..sort(
          (a, b) => ((a['position'] as num?) ?? 0).compareTo(
            (b['position'] as num?) ?? 0,
          ),
        );
    final position = at.clamp(0, own.length);
    own.insert(position, {
      'kind': item.kind,
      'id': item.id,
      'sectionId': dest.id,
      'position': position,
    });
    return {
      'sectionPlacements': [
        for (final p in placementsWithout)
          if (p['sectionId'] != dest.id) p,
        for (final (i, p) in own.indexed) {...p, 'position': i},
      ],
      if (pinnedWithout.length != pinned.length) 'pinned': pinnedWithout,
    };
  }
  final active = entry.channel?.id;
  if (active == null) return null;
  final key = dest.id == 'system:dms' ? 'dmOrder' : 'channelOrder';
  return {
    key: replaceSidebarSubsetOrder(
      [...(preferences[key] as List? ?? const []).whereType<String>()],
      {for (final e in shown) ?e.channel?.id, active}.toList(),
      [for (final e in next) ?e.channel?.id],
    ),
    if (pinnedWithout.length != pinned.length) 'pinned': pinnedWithout,
    if (placementsWithout.length != placements.length)
      'sectionPlacements': placementsWithout,
  };
}

/// Sidebar.tsx `filterSidebarChannelsByMembership`: with "joined channels
/// only" on, the Channels section lists the channels the member has joined.
List<SidebarEntry> sidebarShownEntries(SidebarGroup group, bool joinedOnly) =>
    joinedOnly && group.id == 'system:channels'
    ? [
        for (final e in group.entries)
          if (e.channel?.joined ?? true) e,
      ]
    : group.entries;

/// Feeds the open conversation to [tracker] and, for a closed DM that was just
/// opened, writes the shorter `hiddenDmIds`.
void reopenOpenedDm(WorkspaceController w, ClosedDmReopen tracker) {
  final open = w.section == 'chat' ? w.channel : null;
  final next = tracker.sync(
    open != null && open.type == 'dm' ? open.id : null,
    [
      for (final e in (w.sidebarOrder['hiddenDmIds'] as List? ?? const []))
        '$e',
    ],
  );
  if (next == null) return;
  // The write notifies the controller; keep it out of the listener call.
  // ignore: raft_lints/avoid_unreviewed_idle_work -- One microtask per opened closed DM, not a loop: it only moves the write out of the controller's notification.
  scheduleMicrotask(() => w.updateSidebarOrder({'hiddenDmIds': next}));
}
