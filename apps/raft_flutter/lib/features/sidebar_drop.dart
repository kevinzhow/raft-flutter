import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/closed_dm_reopen.dart';
import '../data/workspace_controller.dart';
import 'sidebar_projection.dart';
import 'sidebar_reorder.dart';

/// Where a sidebar row dragged out of its section would land.
class SidebarDropHint {
  const SidebarDropHint(this.group, this.shown, this.entryKey, this.after);

  /// The destination section, the rows it shows, and the row the pointer is on
  /// (null: the section's empty hint). [after]: lands below that row.
  final SidebarGroup group;
  final List<SidebarEntry> shown;
  final String? entryKey;
  final bool after;

  /// Index among [shown] the row is inserted at.
  int get index {
    if (entryKey == null) return shown.length;
    final at = shown.indexWhere((e) => e.key == entryKey);
    return at < 0 ? shown.length : at + (after ? 1 : 0);
  }

  @override
  bool operator ==(Object other) =>
      other is SidebarDropHint &&
      other.group.id == group.id &&
      other.entryKey == entryKey &&
      other.after == after;

  @override
  int get hashCode => Object.hash(group.id, entryKey, after);
}

/// An item drag that left the pointer free to cross sections (Sidebar.tsx
/// `sidebarDndActiveId`): the section it started in, and the drop target the
/// pointer is over.
class SidebarDrag {
  SidebarDrag._();
  static final source = _Signal<String?>(null);
  static final hint = _Signal<SidebarDropHint?>(null);
  static bool get active => source.value != null;
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

/// One lifted row: its owner, section and entry.
class SidebarDragSession {
  SidebarDragSession({
    required this.w,
    required this.group,
    required this.entry,
  });
  final WorkspaceController w;
  final SidebarGroup group;
  final SidebarEntry entry;

  void start() => SidebarDrag.source.value = group.id;

  void move(Offset at) => SidebarDrag.hint.value = _target(at);

  /// Drops at [at]: true when the row went to another section (the persisting
  /// move is sent), false when it stays where the list put it.
  bool finish(Offset at) {
    final target = _target(at);
    SidebarDrag.hint.value = null;
    SidebarDrag.source.value = null;
    if (target == null) return false;
    final updates = sidebarCrossMoveUpdates(
      entry: entry,
      dest: target.group,
      shown: target.shown,
      index: target.index,
      preferences: w.sidebarOrder,
    );
    if (updates != null) unawaited(w.updateSidebarOrder(updates));
    return true;
  }

  void cancel() {
    SidebarDrag.hint.value = null;
    SidebarDrag.source.value = null;
  }

  SidebarDropHint? _target(Offset at) {
    _SidebarDropZoneState? row, empty;
    for (final zone in _zones) {
      final box = zone.context.findRenderObject();
      if (box is! RenderBox ||
          !box.attached ||
          !box.hasSize ||
          zone.widget.group.id == group.id ||
          !(box.localToGlobal(Offset.zero) & box.size).contains(at) ||
          !sidebarDropAllowed(entry, zone.widget.group, w.sidebarOrder)) {
        continue;
      }
      if (zone.widget.entryKey == null) {
        empty = zone;
      } else {
        row = zone;
      }
    }
    final zone = row ?? empty;
    if (zone == null) return null;
    final box = zone.context.findRenderObject()! as RenderBox;
    final center = box.localToGlobal(box.size.center(Offset.zero)).dy;
    return SidebarDropHint(
      zone.widget.group,
      zone.widget.shown,
      zone.widget.entryKey,
      at.dy >= center,
    );
  }
}

final _zones = <_SidebarDropZoneState>{};

/// A row (or the empty hint) of a section that a dragged row can land on.
/// While it is the target it shows the edge the row lands on.
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
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ValueListenableBuilder<SidebarDropHint?>(
      valueListenable: SidebarDrag.hint,
      child: widget.child,
      builder: (context, hint, child) {
        final on =
            hint != null &&
            hint.group.id == widget.group.id &&
            hint.entryKey == widget.entryKey;
        if (!on) return child!;
        final edge = Container(height: t.border, color: t.accent);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.entryKey == null)
              Positioned.fill(child: ColoredBox(color: t.accentSoft)),
            child!,
            if (widget.entryKey != null)
              Positioned(
                left: 0,
                right: 0,
                top: hint.after ? null : 0,
                bottom: hint.after ? 0 : null,
                child: IgnorePointer(child: edge),
              ),
          ],
        );
      },
    );
  }
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
