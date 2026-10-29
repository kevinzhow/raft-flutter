import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../data/workspace_message_windows.dart' show ReadingAnchor;

/// A prepend preserves the center's distances; an interior insertion does not.
bool insertsBetweenRetainedRows(
  Iterable<String> before,
  Iterable<String> after,
) {
  final retained = before.toSet();
  var seen = false, inserted = false;
  for (final id in after) {
    if (retained.contains(id)) {
      if (inserted) return true;
      seen = true;
    } else if (seen) {
      inserted = true;
    }
  }
  return false;
}

bool _painted(RenderObject row) {
  RenderObject? node = row;
  while (node != null) {
    if (node is RenderSliver && node.geometry?.visible != true) return false;
    final parent = node.parent;
    if (parent != null && !parent.paintsChild(node)) return false;
    final data = node.parentData;
    if (parent is RenderSliverMultiBoxAdaptor &&
        data is SliverMultiBoxAdaptorParentData) {
      final offset = data.layoutOffset;
      final extent = parent.constraints.axis == Axis.vertical
          ? node.paintBounds.height
          : node.paintBounds.width;
      final scroll = parent.constraints.scrollOffset;
      if (offset == null ||
          offset + extent <= scroll ||
          offset >= scroll + parent.constraints.remainingPaintExtent) {
        return false;
      }
    }
    node = parent;
  }
  return true;
}

/// Captures a visible row by key and its distance below the timeline top.
ReadingAnchor? captureTimelineReadingAnchor(BuildContext context) {
  ReadingAnchor? best;
  var bestTop = double.infinity;
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('message-wrapper-')) {
      final row = element.renderObject;
      final Object? clip = row == null
          ? null
          : RenderAbstractViewport.maybeOf(row);
      if (row is RenderBox &&
          clip is RenderBox &&
          row.attached &&
          _painted(row) &&
          row.hasSize &&
          clip.hasSize) {
        final top =
            row.localToGlobal(Offset.zero).dy -
            clip.localToGlobal(Offset.zero).dy;
        if (top + row.size.height > 1 &&
            top < clip.size.height &&
            top < bestTop) {
          bestTop = top;
          best = ReadingAnchor(
            key.value.substring('message-wrapper-'.length),
            top,
          );
        }
      }
      return;
    }
    element.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return best;
}
