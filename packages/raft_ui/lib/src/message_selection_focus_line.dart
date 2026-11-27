import 'package:flutter/widgets.dart';

TextSelectionToolbarAnchors? raftMessageSelectionFocusLine(
  SelectionContainerDelegate selection,
  RenderBox overlay,
) {
  final geometry = selection.value;
  final focus = geometry.endSelectionPoint;
  if (focus == null || !geometry.hasSelection) return null;
  final middle = focus.localPosition.dy - focus.lineHeight / 2;
  Rect? line;
  for (final rect in geometry.selectionRects) {
    if (rect.isEmpty || middle < rect.top || middle > rect.bottom) continue;
    line = line == null ? rect : line.expandToInclude(rect);
  }
  if (line == null) return null;
  final global = MatrixUtils.transformRect(
    selection.getTransformTo(null),
    line,
  );
  return TextSelectionToolbarAnchors(
    primaryAnchor: overlay.globalToLocal(global.topCenter),
    secondaryAnchor: overlay.globalToLocal(global.bottomCenter),
  );
}
