import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'sidebar_drop.dart';
export 'sidebar_drop.dart' show reopenOpenedDm, sidebarShownEntries;
import 'sidebar_projection.dart';

/// Sidebar.tsx `isSidebarDndContainerManual`: rows of a group can be dragged
/// into a new order only while the group sorts manually (an absent or unknown
/// mode is manual, as [projectSidebar] treats it).
bool sidebarGroupReorderable(
  SidebarGroup group,
  Map<String, dynamic> preferences,
) {
  final mode = group.custom
      ? [
          for (final s in (preferences['customSections'] as List? ?? []))
            if (s is Map && '${s['id']}' == group.id) s['sortMode'],
        ].firstOrNull
      : switch (group.id) {
          'system:pinned' => preferences['pinnedSortMode'],
          'system:joint' => preferences['jointChannelSortMode'],
          'system:channels' => preferences['channelSortMode'],
          'system:dms' => preferences['dmSortMode'],
          _ => 'az',
        };
  return mode != 'az' && mode != 'recent';
}

/// The `updateSidebarOrder` payload (Sidebar.tsx `handleSidebarDragEnd`) for
/// moving the shown row at [from] to [to] inside [group]. Both are indexes
/// into [shown] as [SliverReorderableList.onReorderItem] reports them (the
/// row already removed). [shown] may be a filtered subset of the group's
/// entries: hidden rows keep their slots. Null when nothing moves or the group
/// is not reorderable.
Map<String, dynamic>? sidebarReorderUpdates({
  required SidebarGroup group,
  required List<SidebarEntry> shown,
  required Map<String, dynamic> preferences,
  required int from,
  required int to,
}) {
  if (from == to ||
      from < 0 ||
      to < 0 ||
      from >= shown.length ||
      to >= shown.length ||
      !sidebarGroupReorderable(group, preferences)) {
    return null;
  }
  final moved = [...shown];
  moved.insert(to, moved.removeAt(from));
  // Sidebar.tsx `replaceSidebarSubsetOrder` on the group's own rows.
  final shownKeys = {for (final e in shown) e.key};
  var next = 0;
  final entries = [
    for (final e in group.entries)
      shownKeys.contains(e.key) ? moved[next++] : e,
  ];
  if (group.id == 'system:pinned') {
    return {'pinned': _ordered(_rows(preferences['pinned']), entries)};
  }
  if (group.custom) {
    final all = _rows(preferences['sectionPlacements']);
    final own = [
      for (final p in all)
        if ('${p['sectionId']}' == group.id) p,
    ]..sort((a, b) => _position(a).compareTo(_position(b)));
    return {
      'sectionPlacements': [
        for (final p in all)
          if ('${p['sectionId']}' != group.id) p,
        for (final (i, p) in _ordered(own, entries).indexed)
          {...p, 'position': i},
      ],
    };
  }
  final key = group.id == 'system:dms' ? 'dmOrder' : 'channelOrder';
  return {
    key: replaceSidebarSubsetOrder(
      [...(preferences[key] as List? ?? const []).whereType<String>()],
      [for (final e in group.entries) ?e.channel?.id],
      [for (final e in entries) ?e.channel?.id],
    ),
  };
}

/// Sidebar.tsx `replaceSidebarSubsetOrder`: the slots [previous] ids hold in
/// [order] take [next] in sequence; the rest of [next] is appended.
List<String> replaceSidebarSubsetOrder(
  List<String> order,
  List<String> previous,
  List<String> next,
) {
  final subset = previous.toSet();
  var index = 0;
  final result = [
    for (final id in order)
      subset.contains(id) && index < next.length ? next[index++] : id,
  ];
  return [...result, ...next.skip(index)];
}

List<Map<String, dynamic>> _rows(Object? value) => [
  for (final r in (value as List? ?? const []))
    if (r is Map) Map<String, dynamic>.from(r),
];

num _position(Map<String, dynamic> p) => (p['position'] as num?) ?? 0;

/// [refs] (pinned refs or placements) in the order of the [entries] they
/// project to; refs no entry resolves (a deleted channel) keep their order
/// after them.
List<Map<String, dynamic>> _ordered(
  List<Map<String, dynamic>> refs,
  List<SidebarEntry> entries,
) {
  final rest = [...refs];
  return [
    for (final e in entries)
      if (rest.indexWhere((r) => _resolves(r, e)) case final i when i >= 0)
        rest.removeAt(i),
    ...rest,
  ];
}

/// Whether [ref] is what [projectSidebar] resolved into [entry]: a `channel`
/// ref is a channel or DM id, `human` a human DM peer, `agent` an agent row or
/// (without one) the agent DM of that peer.
bool _resolves(Map<String, dynamic> ref, SidebarEntry entry) {
  final id = '${ref['id']}', c = entry.channel;
  bool peer(bool agent) =>
      c != null &&
      c.type == 'dm' &&
      (c.string('peerType') == 'agent') == agent &&
      c.string('peerId') == id;
  return switch (ref['kind']) {
    'channel' => entry.agent == null && c?.id == id,
    'human' => peer(false),
    'agent' => entry.agent == null ? peer(true) : '${entry.agent!['id']}' == id,
    _ => false,
  };
}

/// sidebarSections.ts `SIDEBAR_SYSTEM_SECTION_IDS`.
const sidebarSystemSectionIds = [
  'system:pinned',
  'system:joint',
  'system:channels',
  'system:dms',
];

/// sidebarSections.ts `normalizeSidebarSectionOrder`: the stored
/// `sectionOrder`, then the system and custom sections it lacks; unknown and
/// repeated ids are dropped. [projectSidebar] lays the groups out in it.
List<String> sidebarSectionOrder(Map<String, dynamic> preferences) {
  final allowed = {
    ...sidebarSystemSectionIds,
    for (final s in _rows(preferences['customSections'])) '${s['id']}',
  };
  final seen = <String>{};
  return [
    for (final id in [
      ...(preferences['sectionOrder'] as List? ?? const []).whereType<String>(),
      ...allowed,
    ])
      if (allowed.contains(id) && seen.add(id)) id,
  ];
}

/// The `updateSidebarOrder` payload (Sidebar.tsx `handleSidebarDragEnd` with
/// `reorderSidebarSectionOrder`) for dropping section [fromId] on section
/// [toId]: [fromId] takes [toId]'s slot, so it lands before [toId] when moved
/// up and after it when moved down. Null when nothing moves.
Map<String, dynamic>? sidebarSectionReorderUpdates({
  required Map<String, dynamic> preferences,
  required String fromId,
  required String toId,
}) {
  final order = sidebarSectionOrder(preferences);
  final from = order.indexOf(fromId), to = order.indexOf(toId);
  if (from < 0 || to < 0 || from == to) return null;
  final next = [...order]..removeAt(from);
  next.insert(to, fromId);
  return {'sectionOrder': next};
}

/// The glyph the lifted card of [group]'s header carries.
RaftGlyph sidebarSectionGlyph(SidebarGroup group) => switch (group.id) {
  'system:pinned' => RaftGlyph.pin,
  'system:joint' => RaftGlyph.globe,
  'system:channels' => RaftGlyph.hash,
  'system:dms' => RaftGlyph.messageSquare,
  _ => RaftGlyph.folderClosed,
};

/// [header] of [group] as Sidebar.tsx `SortableSidebarSection` makes it: a
/// long press lifts the whole section and a drop on another section header
/// persists the new `sectionOrder` through the optimistic
/// [WorkspaceController.updateSidebarOrder]. [onHeldInPlace] (the header's
/// menu) opens when the press is released without the pointer travelling.
/// [count] is the number painted on the header; the Channels section can hide
/// rows that [SidebarGroup.entries] still contains.
Widget sidebarSectionDragHeader({
  required SidebarGroup group,
  required WorkspaceController w,
  required String label,
  required Widget header,
  int? count,
  ValueChanged<Offset>? onHeldInPlace,
}) => SidebarSectionDragHeader(
  key: ValueKey('sidebar-section-drag-${group.id}'),
  id: group.id,
  order: sidebarSectionOrder(w.sidebarOrder),
  label: label,
  count: count ?? group.entries.length,
  glyph: sidebarSectionGlyph(group),
  onHeldInPlace: onHeldInPlace,
  onMove: (from, to) {
    final updates = sidebarSectionReorderUpdates(
      preferences: w.sidebarOrder,
      fromId: from,
      toId: to,
    );
    if (updates != null) unawaited(w.updateSidebarOrder(updates));
  },
  child: header,
);

/// A section header that is both the drag handle (`LongPressDraggable`
/// carrying [id]) and the drop target of the other sections in [order].
class SidebarSectionDragHeader extends StatefulWidget {
  const SidebarSectionDragHeader({
    super.key,
    required this.id,
    required this.order,
    required this.label,
    required this.onMove,
    required this.child,
    this.count,
    this.glyph = RaftGlyph.folderClosed,
    this.onHeldInPlace,
  });

  final String id, label;
  final List<String> order;
  final int? count;
  final RaftGlyph glyph;

  /// Section `from` was dropped on this header (`to`).
  final void Function(String from, String to) onMove;
  final ValueChanged<Offset>? onHeldInPlace;
  final Widget child;

  @override
  State<SidebarSectionDragHeader> createState() => _SectionDragHeaderState();
}

class _SectionDragHeaderState extends State<SidebarSectionDragHeader> {
  bool dragging = false;

  void setDragging(bool value) {
    if (mounted && dragging != value) setState(() => dragging = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), id = widget.id;
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<String>(
        onWillAcceptWithDetails: (d) =>
            d.data != id && widget.order.contains(d.data),
        onAcceptWithDetails: (d) => widget.onMove(d.data, id),
        builder: (context, candidates, _) {
          final incoming = candidates.whereType<String>().firstOrNull;
          // The dropped section takes this slot: it lands below this header
          // when it comes from above, above it when it comes from below.
          final below =
              incoming != null &&
              widget.order.indexOf(incoming) < widget.order.indexOf(id);
          final edge = BorderSide(color: t.accent, width: t.border);
          return _SectionDraggable(
            data: id,
            onHeldInPlace: widget.onHeldInPlace == null
                ? null
                : (at) => widget.onHeldInPlace?.call(at),
            onDragStarted: () => setDragging(true),
            onDragEnd: (_) => setDragging(false),
            feedback: _SectionDragCard(
              width: constraints.maxWidth,
              label: widget.label,
              count: widget.count,
              glyph: widget.glyph,
            ),
            child: DecoratedBox(
              key: ValueKey('sidebar-section-drop-$id'),
              decoration: BoxDecoration(
                color: incoming == null ? null : t.accentSoft,
                border: incoming == null
                    ? null
                    : below
                    ? Border(bottom: edge)
                    : Border(top: edge),
              ),
              child: Opacity(opacity: dragging ? .4 : 1, child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

/// The lifted section: a card with the section's glyph, name and count that
/// follows the pointer.
class _SectionDragCard extends StatelessWidget {
  const _SectionDragCard({
    required this.width,
    required this.label,
    required this.count,
    required this.glyph,
  });

  final double width;
  final String label;
  final int? count;
  final RaftGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSidebarSectionRecipe(t, RaftDensityScope.of(context));
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.popover,
          borderRadius: BorderRadius.circular(t.radius),
          border: Border.all(color: t.line),
          boxShadow: t.shadows,
        ),
        child: Padding(
          padding: recipe.inset,
          child: DefaultTextStyle(
            style: recipe.title.copyWith(color: recipe.foreground),
            child: Row(
              children: [
                RaftIcon(
                  glyph,
                  size: RaftSidebarSectionMetrics.actionGlyph,
                  color: recipe.foreground,
                ),
                const SizedBox(width: RaftSidebarSectionMetrics.inlineGap),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: RaftSidebarSectionMetrics.inlineGap),
                  Text('$count', style: recipe.count),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [LongPressDraggable] through the rows' hold recognizer: a long press lifts
/// the section or row, a release without travel is [onHeldInPlace] instead.
/// The recognizer is made once per draggable state, so [onHeldInPlace] and
/// [sessionOf] must answer from the current widget, not the first one.
class _SectionDraggable extends LongPressDraggable<String> {
  const _SectionDraggable({
    required super.data,
    required super.feedback,
    required super.child,
    super.onDragStarted,
    super.onDragEnd,
    this.onHeldInPlace,
    this.sessionOf,
  });

  final ValueChanged<Offset>? onHeldInPlace;
  final SidebarDragSession? Function()? sessionOf;

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) =>
      _HoldRecognizer(
          debugOwner: this,
          onHeldInPlace: onHeldInPlace,
          sessionOf: sessionOf,
        )
        ..onStart = (position) {
          final drag = onStart(position);
          if (drag != null) unawaited(HapticFeedback.selectionClick());
          return drag;
        };
}

/// The index of the row keyed [key] (a sidebar row's own key) in [entries].
int? sidebarEntryIndex(List<SidebarEntry> entries, Key key) {
  if (key is! ValueKey<String>) return null;
  final index = entries.indexWhere(
    (entry) => 'sidebar-drag-${entry.key}' == key.value,
  );
  return index < 0 ? null : index;
}

/// Row [index] of [entries] built by [row]. A long press lifts it and it can
/// be dropped on any section that takes it ([SidebarDragSession]); the
/// section listing it follows the pointer through [SidebarDrag.project].
Widget sidebarListRow(
  List<SidebarEntry> entries,
  int index,
  RaftNavItem Function(SidebarEntry entry, bool reorderable) row, {
  required SidebarGroup group,
  required WorkspaceController w,
}) {
  final entry = entries[index], item = row(entry, true);
  return SidebarDragRow(
    key: ValueKey('sidebar-drag-${entry.key}'),
    session: SidebarDragSession(
      w: w,
      group: group,
      entry: entry,
      shown: entries,
    ),
    onHeldInPlace: item.onContextMenu,
    feedback: item,
    child: SidebarDropZone(
      group: group,
      shown: entries,
      entryKey: entry.key,
      child: item,
    ),
  );
}

/// A sidebar row that a long press lifts: it follows the pointer as a card
/// (the [feedback]) while its section moves it to the slot under the pointer.
class SidebarDragRow extends StatefulWidget {
  const SidebarDragRow({
    super.key,
    required this.session,
    required this.onHeldInPlace,
    required this.feedback,
    required this.child,
  });
  final SidebarDragSession session;
  final ValueChanged<Offset>? onHeldInPlace;
  final Widget feedback, child;

  @override
  State<SidebarDragRow> createState() => _SidebarDragRowState();
}

class _SidebarDragRowState extends State<SidebarDragRow> {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _SectionDraggable(
      data: widget.session.entry.key,
      sessionOf: () => widget.session,
      onHeldInPlace: widget.onHeldInPlace == null
          ? null
          : (at) => widget.onHeldInPlace?.call(at),
      feedback: SizedBox(
        width: constraints.maxWidth,
        child: raftSidebarReorderProxy(
          widget.feedback,
          0,
          const AlwaysStoppedAnimation(1),
        ),
      ),
      child: widget.child,
    ),
  );
}

/// The rows of a section listed by [shown].
Widget sidebarRowsSliver(
  List<SidebarEntry> shown, {
  required RaftNavItem Function(SidebarEntry entry, bool reorderable) row,
  required SidebarGroup group,
  required WorkspaceController w,
}) => SliverList.builder(
  itemCount: shown.length,
  itemBuilder: (context, index) =>
      sidebarListRow(shown, index, row, group: group, w: w),
  findChildIndexCallback: (key) => sidebarEntryIndex(shown, key),
);

/// A custom section: its header, its rows and the hint of an empty one. Like
/// the system sections it lists the live projection of an item drag; it is
/// shown even when empty, so it can take a drop.
Widget sidebarCustomGroupSliver({
  required SidebarGroup group,
  required WorkspaceController w,
  required Widget header,
  required bool expanded,
  required String emptyLabel,
  required RaftNavItem Function(SidebarEntry entry, bool reorderable) row,
}) => ListenableBuilder(
  key: ValueKey('sidebar-group-${group.id}'),
  listenable: SidebarDrag.changes,
  builder: (context, _) {
    final shown = SidebarDrag.project(group, group.entries);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (expanded) sidebarRowsSliver(shown, row: row, group: group, w: w),
        if (expanded && shown.isEmpty)
          SliverToBoxAdapter(
            child: SidebarDropZone(
              group: group,
              shown: shown,
              child: RaftSidebarSectionEmptyHint(emptyLabel),
            ),
          ),
      ],
    );
  },
);

/// [header] wrapped as a draggable section when [group] is present. A header
/// with no group stays as the shell built it.
Widget sidebarDragSectionHeader({
  required SidebarGroup? group,
  required WorkspaceController w,
  required String label,
  required Widget header,
  required Future<void> Function(Offset at, SidebarGroup group) onOpenMenu,
}) {
  if (group == null) return header;
  return sidebarSectionDragHeader(
    group: group,
    w: w,
    label: label,
    header: header,
    onHeldInPlace: (at) => onOpenMenu(at, group),
  );
}

/// A system group in the scrolling sidebar. The shell still chooses the kind,
/// copy, disclosure and row; this owner attaches the section and row drags.
Widget sidebarSystemGroupSliver({
  required SidebarGroup group,
  required List<SidebarEntry> entries,
  required WorkspaceController w,
  required String label,
  required RaftChatSidebarGroupKind kind,
  required bool expanded,
  required bool hideEmpty,
  required bool loading,
  required String emptyLabel,
  required ValueChanged<bool> onExpandedChanged,
  required Widget? attention,
  required List<RaftSidebarSectionAction> actions,
  required ValueChanged<Offset> onOpenMenu,
  required RaftNavItem Function(SidebarEntry entry, bool reorderable) row,
}) {
  return ListenableBuilder(
    key: ValueKey('sidebar-group-${group.id}'),
    listenable: SidebarDrag.changes,
    builder: (context, _) {
      final shown = SidebarDrag.project(group, entries);
      return RaftChatSidebarGroup.sliver(
        headerKey: ValueKey('sidebar-section-${group.id}'),
        disclosureKey: ValueKey('sidebar-disclosure-${group.id}'),
        kind: kind,
        label: label,
        count: shown.length,
        expanded: expanded,
        hideEmpty: hideEmpty,
        dragActive: SidebarDrag.active,
        dragSource: SidebarDrag.source.value == group.id,
        loading: loading,
        emptyLabel: emptyLabel,
        onExpandedChanged: onExpandedChanged,
        attention: attention,
        actions: actions,
        onContextMenu: onOpenMenu,
        contextMenuOnLongPress: false,
        wrapHeader: (header) => sidebarSectionDragHeader(
          group: group,
          w: w,
          label: label,
          header: header,
          count: shown.length,
          onHeldInPlace: onOpenMenu,
        ),
        wrapEmpty: (empty) =>
            SidebarDropZone(group: group, shown: shown, child: empty),
        itemBuilder: (context, index) =>
            sidebarListRow(shown, index, row, group: group, w: w),
        findChildIndexCallback: (key) => sidebarEntryIndex(shown, key),
      );
    },
  );
}

class _HoldRecognizer extends DelayedMultiDragGestureRecognizer {
  _HoldRecognizer({super.debugOwner, this.onHeldInPlace, this.sessionOf});
  final ValueChanged<Offset>? onHeldInPlace;
  final SidebarDragSession? Function()? sessionOf;

  /// The drag, observed for how far the pointer travels.
  @override
  GestureMultiDragStartCallback? get onStart {
    final start = super.onStart;
    if (start == null) return null;
    return (position) {
      final drag = start(position);
      return drag == null
          ? null
          : _HeldDrag(drag, position, onHeldInPlace, sessionOf?.call());
    };
  }
}

class _HeldDrag implements Drag {
  _HeldDrag(this.drag, this.origin, this.onHeldInPlace, this.session)
    : last = origin;
  final Drag drag;
  final Offset origin;
  final ValueChanged<Offset>? onHeldInPlace;
  final SidebarDragSession? session;
  Offset last;
  double travel = 0;
  bool lifted = false;

  @override
  void update(DragUpdateDetails details) {
    last = details.globalPosition;
    travel = math.max(travel, (last - origin).distance);
    // The projection starts only once the row really moves.
    if (travel >= kTouchSlop && !lifted && session != null) {
      lifted = true;
      session!.start();
    }
    if (lifted) session!.move(last);
    drag.update(details);
  }

  @override
  void end(DragEndDetails details) {
    // A short release is the menu, not a drop. Cancelling keeps the list and
    // the section target from committing a move the pointer barely started.
    if (travel < kTouchSlop) {
      drag.cancel();
      onHeldInPlace?.call(origin);
      return;
    }
    // A row is dropped where the projection holds it, not on a drag target.
    if (lifted) {
      session!.finish();
      drag.cancel();
      return;
    }
    drag.end(details);
  }

  @override
  void cancel() {
    if (lifted) session!.cancel();
    drag.cancel();
  }
}
