import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter paints Text that has no Material/DefaultTextStyle ancestor with the
/// MaterialApp "fallback style" (large red monospace type with a yellow double
/// underline, `debugLabel: 'fallback style; consider putting your text in a
/// Material'`). A page that shows it renders outside the app's page frame.
bool _isFallback(TextStyle? style) {
  if (style == null) return false;
  if ((style.debugLabel ?? '').contains('fallback style')) return true;
  return (style.decoration?.contains(TextDecoration.underline) ?? false) &&
      style.decorationStyle == TextDecorationStyle.double &&
      style.decorationColor == const Color(0xFFFFFF00);
}

/// Every painted paragraph (text) under the current tree whose style is
/// Flutter's missing-Material fallback: a human-readable list, empty when the
/// frame is clean.
List<String> fallbackStyleParagraphs() {
  final found = <String>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      var bad = false;
      node.text.visitChildren((span) {
        if (span is TextSpan && _isFallback(span.style)) bad = true;
        return true;
      });
      if (bad || _isFallback(node.text.style)) {
        found.add('"${node.text.toPlainText()}"');
      }
    }
    node.visitChildren(visit);
  }

  for (final view in RendererBinding.instance.renderViews) {
    visit(view);
  }
  return found;
}

/// Fails with the offending text when the current frame paints any fallback
/// styled text.
void expectNoFallbackTextStyle([String? state]) {
  expect(
    fallbackStyleParagraphs(),
    isEmpty,
    reason:
        '${state ?? 'frame'} paints text outside a Material/page frame '
        '(yellow double underline)',
  );
}
