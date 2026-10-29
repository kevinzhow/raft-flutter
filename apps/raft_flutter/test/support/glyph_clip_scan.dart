// Render-tree scan for text whose glyph ink can be cut by an enclosing clip.
//
// A CSS line box is often shorter than the glyph box of its font (Elegant
// `leading-none` = 14px at 14px, PingFang SC / Noto CJK taller still). The
// glyphs paint outside the box; any clip at the box edge (ClipRect,
// ClipRRect, ClipPath, a Material or Container with `clipBehavior`) shaves
// descenders and ideograph tops. This walks every RenderParagraph and
// reports ancestors whose clip rectangle lies inside the "ink envelope"
// [baseline - 0.80em, baseline + 0.22em] of the paragraph's first/last line
// while the paragraph box itself lies inside the clip.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ink above the baseline: CJK ideographs reach ~.88em, Latin ascenders and
/// accented capitals ~.78em. Below: Latin descenders ~.22em.
const glyphInkAbove = .80, glyphInkBelow = .22;

class GlyphClipFinding {
  GlyphClipFinding({
    required this.text,
    required this.fontSize,
    required this.clip,
    required this.cutTop,
    required this.cutBottom,
    required this.chain,
  });
  final String text, clip, chain;
  final double fontSize, cutTop, cutBottom;
  Map<String, Object?> toJson() => {
    'text': text,
    'fontSize': fontSize,
    'clip': clip,
    'cutTop': double.parse(cutTop.toStringAsFixed(2)),
    'cutBottom': double.parse(cutBottom.toStringAsFixed(2)),
    'chain': chain,
  };
}

TextStyle? _firstStyle(InlineSpan span, TextStyle inherited) {
  final own = inherited.merge(span.style);
  if (span is TextSpan) {
    if (span.text != null && span.text!.trim().isNotEmpty) return own;
    for (final child in span.children ?? const <InlineSpan>[]) {
      final s = _firstStyle(child, own);
      if (s != null) return s;
    }
  }
  return null;
}

Rect? _clipBounds(RenderObject o) {
  if (o is RenderClipRect) {
    if (o.clipBehavior == Clip.none) return null;
    return o.clipper?.getClip(o.size) ?? Offset.zero & o.size;
  }
  if (o is RenderClipRRect) {
    if (o.clipBehavior == Clip.none) return null;
    return (o.clipper?.getClip(o.size) ??
            o.borderRadius
                .resolve(TextDirection.ltr)
                .toRRect(Offset.zero & o.size))
        .outerRect;
  }
  if (o is RenderClipOval) {
    if (o.clipBehavior == Clip.none) return null;
    return o.clipper?.getClip(o.size) ?? Offset.zero & o.size;
  }
  if (o is RenderClipPath) {
    if (o.clipBehavior == Clip.none) return null;
    return o.clipper?.getClip(o.size).getBounds() ?? Offset.zero & o.size;
  }
  if (o is RenderPhysicalModel) {
    if (o.clipBehavior == Clip.none) return null;
    return Offset.zero & o.size;
  }
  if (o is RenderPhysicalShape) {
    if (o.clipBehavior == Clip.none) return null;
    return o.clipper?.getClip(o.size).getBounds() ?? Offset.zero & o.size;
  }
  return null;
}

String _creator(RenderObject o) {
  final creator = o.debugCreator;
  if (creator is DebugCreator) {
    final names = <String>[];
    creator.element.visitAncestorElements((e) {
      names.add(e.widget.runtimeType.toString());
      return names.length < 7;
    });
    return '${creator.element.widget.runtimeType} < ${names.join(' < ')}';
  }
  return o.runtimeType.toString();
}

List<GlyphClipFinding> scanGlyphClips(WidgetTester t) {
  final findings = <GlyphClipFinding>[];
  final seen = <String>{};
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.attached && o.hasSize) {
      _check(o, findings, seen);
    }
    o.visitChildren(visit);
  }

  visit(t.binding.renderViews.first);
  return findings;
}

void _check(RenderParagraph p, List<GlyphClipFinding> out, Set<String> seen) {
  final text = p.text.toPlainText();
  if (text.trim().isEmpty || p.size.isEmpty) return;
  final style = _firstStyle(p.text, const TextStyle());
  final size = style?.fontSize;
  if (size == null || size <= 0) return;
  // ignore: invalid_use_of_protected_member
  final baseline = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final lineHeight = p.getFullHeightForCaret(const TextPosition(offset: 0));
  // Rendered box of the paragraph in global coordinates.
  final topLeft = p.localToGlobal(Offset.zero);
  final box = topLeft & p.size;
  final scale = p.getTransformTo(null).getMaxScaleOnAxis();
  final em = size * scale;
  final firstBaseline = box.top + baseline * scale;
  final lastBaseline = box.bottom - (lineHeight - baseline) * scale;
  final inkTop = firstBaseline - glyphInkAbove * em;
  final inkBottom = lastBaseline + glyphInkBelow * em;
  for (RenderObject? a = p.parent; a != null; a = a.parent) {
    final local = a is RenderBox || a is RenderObjectWithChildMixin
        ? _clipBounds(a)
        : null;
    if (local == null || a is! RenderBox) continue;
    final clip = MatrixUtils.transformRect(a.getTransformTo(null), local);
    if (!clip.isFinite) continue;
    // Only clips that currently show the whole paragraph box: a partly
    // scrolled-out or truncated paragraph is not this problem.
    if (box.top < clip.top - .01 || box.bottom > clip.bottom + .01) continue;
    if (box.right < clip.left || box.left > clip.right) continue;
    final cutTop = (clip.top - inkTop).clamp(0.0, double.infinity);
    final cutBottom = (inkBottom - clip.bottom).clamp(0.0, double.infinity);
    if (cutTop < .5 && cutBottom < .5) continue;
    final key = '${a.runtimeType}|${_creator(a)}|$text';
    if (!seen.add(key)) continue;
    out.add(
      GlyphClipFinding(
        text: text.length > 40 ? text.substring(0, 40) : text,
        fontSize: size,
        clip: a.runtimeType.toString(),
        cutTop: cutTop / scale,
        cutBottom: cutBottom / scale,
        chain: _creator(a),
      ),
    );
  }
}
