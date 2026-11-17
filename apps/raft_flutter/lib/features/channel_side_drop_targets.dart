// The places a dragged section can land (Web v1.24 `sideSectionDrag.tsx`
// `sideDropTargets` and `targetAt`), computed from the boxes the side area
// shows: before each section of each visible column and at its bottom, and a
// new column at each visible column's left edge and right of the last. Pure
// geometry: no widgets, so the rules are easy to read and test.
//
// Left out against Web: the column making room for the place (a gap opening
// with the neighbours giving it height) and the glide of the other sections on
// the drop; the place is drawn over the column instead.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'channel_side_layout.dart';

/// The pointer is on a new column's edge within this many px (Web `EDGE_ZONE`).
const channelSideEdgeZone = 24.0;

/// A new column's strip on its edge is this wide (Web `EDGE_STRIP`).
const channelSideEdgeStrip = 24.0;

/// One visible column as the area shows it: its layout [index], its [rect] and
/// the [boxes] of its shown sections, in the area's coordinates.
typedef ChannelSideColumnBox = ({
  int index,
  Rect rect,
  List<({ChannelSideSection section, Rect rect})> boxes,
});

/// How a place reads to a screen reader (Web `description`).
enum ChannelSidePlace { above, bottom, newLeft, newRight }

class ChannelSideDropTarget {
  const ChannelSideDropTarget({
    required this.drop,
    required this.place,
    required this.sections,
    required this.line,
    required this.area,
    this.above,
    this.edge,
    this.zone,
    this.fits = true,
  });

  final ChannelSideDrop drop;
  final ChannelSidePlace place;

  /// The section it lands above ([ChannelSidePlace.above]).
  final ChannelSideSection? above;

  /// The sections the place is by (the column it is the bottom of or beside),
  /// without the one being moved.
  final List<ChannelSideSection> sections;

  /// What the pointer is matched against: a column's edge (vertical, 2px) or a
  /// place in a column (horizontal).
  final Rect line;

  /// A new column's edge the pointer must be near.
  final double? edge;

  /// Anywhere in it is this place too: the chat, for the new column left of
  /// the first.
  final Rect? zone;

  /// Where the section will stand: the dashed area.
  final Rect area;

  /// False: the place is refused (a new column the window can't hold).
  final bool fits;

  bool get newColumn => drop is ChannelSideDropNewColumn;
  bool get vertical => newColumn;
}

/// Every place [section] can land. [chat] is the conversation's box (a drop on
/// it is a new column left of the first); [head] the card head's height;
/// [fits] says whether the row can hold the layout a new column would make.
/// Places where the section already is are left out; a new column the layout
/// can't have (a fifth) or the window can't hold is [fits] false.
List<ChannelSideDropTarget> channelSideDropTargets({
  required ChannelSideLayout layout,
  required ChannelSideSection section,
  required List<ChannelSideColumnBox> columns,
  required Rect? chat,
  required double head,
  required bool Function(ChannelSideLayout moved) fits,
}) {
  final cols = [...columns]..sort((a, b) => a.rect.left.compareTo(b.rect.left));
  if (cols.isEmpty) return const [];
  final ownAt = cols.indexWhere(
    (c) => c.boxes.any((b) => b.section == section),
  );
  final alone = ownAt >= 0 && cols[ownAt].boxes.length == 1;
  final rowLeft = chat?.left ?? cols.first.rect.left;
  final rowRight = cols.last.rect.right;
  final targets = <ChannelSideDropTarget>[];

  void keep(ChannelSideDropTarget target) {
    final moved = layout.move(section, target.drop);
    if (identical(moved, layout)) {
      // Where it already is: no place. A new column the layout refuses (a
      // fifth) is a place that says no.
      if (target.newColumn) {
        targets.add(_refused(target));
      }
      return;
    }
    targets.add(!target.newColumn || fits(moved) ? target : _refused(target));
  }

  List<ChannelSideSection> others(ChannelSideColumnBox c) => [
    for (final b in c.boxes)
      if (b.section != section) b.section,
  ];

  // A new column at the left edge of the column at [position]; past the last
  // one, at the row's last edge.
  void newColumn(int position) {
    if (alone && (position == ownAt || position == ownAt + 1)) return;
    final column = position < cols.length ? cols[position] : null;
    final beside = column ?? cols.last;
    final edge = column != null ? column.rect.left : beside.rect.right;
    final rect = beside.rect;
    keep(
      ChannelSideDropTarget(
        drop: ChannelSideDropNewColumn(
          column != null ? column.index : beside.index + 1,
        ),
        place: column != null
            ? ChannelSidePlace.newLeft
            : ChannelSidePlace.newRight,
        sections: others(beside),
        edge: edge,
        line: Rect.fromLTWH(edge - 1, rect.top, 2, rect.height),
        area: Rect.fromLTWH(
          (edge - channelSideEdgeStrip / 2).clamp(
            rowLeft,
            math.max(rowLeft, rowRight - channelSideEdgeStrip),
          ),
          rect.top,
          channelSideEdgeStrip,
          rect.height,
        ),
      ),
    );
  }

  for (var position = 0; position < cols.length; position++) {
    final column = cols[position];
    final rect = column.rect;
    // The place's band straddles its seam, a head high, inside the column.
    Rect band(double seam) => Rect.fromLTWH(
      rect.left,
      (seam - head / 2).clamp(rect.top, math.max(rect.top, rect.bottom - head)),
      rect.width,
      math.min(head, rect.height),
    );
    newColumn(position);
    for (final box in column.boxes) {
      final seam = box.rect.top;
      keep(
        ChannelSideDropTarget(
          drop: ChannelSideDropInto(column.index, box.section),
          place: ChannelSidePlace.above,
          above: box.section,
          sections: others(column),
          line: Rect.fromLTWH(rect.left, seam - 1, rect.width, 2),
          area: band(seam),
        ),
      );
    }
    if (column.boxes.isNotEmpty) {
      final seam = column.boxes.last.rect.bottom;
      keep(
        ChannelSideDropTarget(
          drop: ChannelSideDropInto(column.index, null),
          place: ChannelSidePlace.bottom,
          sections: others(column),
          line: Rect.fromLTWH(rect.left, seam - 1, rect.width, 2),
          area: band(seam),
        ),
      );
    }
  }
  newColumn(cols.length);

  // The conversation doesn't move: dropped anywhere on it, a section makes a
  // new column left of the first.
  if (chat != null) {
    final at = cols.first.index;
    final i = targets.indexWhere(
      (t) =>
          t.drop is ChannelSideDropNewColumn &&
          (t.drop as ChannelSideDropNewColumn).at == at,
    );
    if (i >= 0) targets[i] = _withZone(targets[i], chat);
  }
  return targets;
}

ChannelSideDropTarget _refused(ChannelSideDropTarget t) =>
    ChannelSideDropTarget(
      drop: t.drop,
      place: t.place,
      sections: t.sections,
      line: t.line,
      area: t.area,
      edge: t.edge,
      zone: t.zone,
      fits: false,
    );

ChannelSideDropTarget _withZone(ChannelSideDropTarget t, Rect zone) =>
    ChannelSideDropTarget(
      drop: t.drop,
      place: t.place,
      sections: t.sections,
      line: t.line,
      area: t.area,
      edge: t.edge,
      zone: zone,
      fits: t.fits,
    );

/// The place under the pointer: a column's edge zone first, else the chat, else
/// the nearest place in the column it is over.
ChannelSideDropTarget? channelSideTargetAt(
  List<ChannelSideDropTarget> targets,
  Offset p,
) {
  final edges =
      targets
          .where(
            (t) =>
                t.vertical &&
                (p.dx - (t.edge ?? t.line.left)).abs() <= channelSideEdgeZone &&
                p.dy >= t.line.top &&
                p.dy <= t.line.bottom,
          )
          .toList()
        ..sort(
          (a, b) => (p.dx - a.edge!).abs().compareTo((p.dx - b.edge!).abs()),
        );
  if (edges.isNotEmpty) return edges.first;
  for (final t in targets) {
    if (t.zone != null && t.zone!.contains(p)) return t;
  }
  final inColumn = targets
      .where((t) => !t.vertical && p.dx >= t.line.left && p.dx <= t.line.right)
      .toList();
  if (inColumn.isEmpty) return null;
  inColumn.sort(
    (a, b) => (p.dy - a.line.top).abs().compareTo((p.dy - b.line.top).abs()),
  );
  return inColumn.first;
}
