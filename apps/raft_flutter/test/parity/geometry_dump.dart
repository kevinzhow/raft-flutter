// Debug aid: with PARITY_GEOMETRY_DUMP=1 each capture also writes
// <caseId>.geometry.txt (global logical rects of text, decorated boxes and
// pictures inside the crop), to compare box-for-box with a React DOM dump.
import 'dart:io';

import 'package:flutter/rendering.dart';

bool get parityGeometryDumpEnabled =>
    Platform.environment['PARITY_GEOMETRY_DUMP'] == '1';

String parityGeometryDump(RenderObject root, Rect crop, RenderObject ancestor) {
  final lines = <String>[];
  void visit(RenderObject node, int depth) {
    if (node is RenderBox && node.hasSize) {
      final o = node.localToGlobal(Offset.zero, ancestor: ancestor);
      final r = o & node.size;
      if (r.overlaps(crop)) {
        String? detail;
        if (node is RenderParagraph) {
          final s = node.text.toPlainText();
          final st = node.text.style;
          detail =
              '"${s.length > 50 ? s.substring(0, 50) : s}" ${st?.fontSize}/${st?.height == null ? '-' : (st!.height! * (st.fontSize ?? 14)).toStringAsFixed(2)} w${st?.fontWeight?.value} ${st?.fontFamily}';
        } else if (node is RenderDecoratedBox &&
            node.decoration is BoxDecoration) {
          final d = node.decoration as BoxDecoration;
          detail = 'box color=${d.color} border=${d.border} radius=${d.borderRadius}';
        } else if (node is RenderEditable) {
          final st = node.text?.style;
          detail =
              'editable "${node.plainText.length > 40 ? node.plainText.substring(0, 40) : node.plainText}" ${st?.fontSize}/${st?.height} prefLine=${node.preferredLineHeight.toStringAsFixed(2)}';
        } else if (node is RenderPadding) {
          detail = 'pad ${node.padding}';
        }
        if (detail != null || depth < 0) {
          lines.add(
            '${' ' * (depth % 40)}${node.runtimeType} [${(r.left - crop.left).toStringAsFixed(1)},${(r.top - crop.top).toStringAsFixed(1)} ${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}] ${detail ?? ''}',
          );
        }
      }
    }
    node.visitChildren((c) => visit(c, depth + 1));
  }

  visit(root, 0);
  return lines.join('\n');
}
