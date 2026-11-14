import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'markdown_scrollbar.dart';
import 'tooltip.dart' show RaftTooltip;

// Formulas in Markdown (Web 1.24 task #775, components/markdown/InlineMath,
// DisplayMath, mathFormula.ts): rendered as KaTeX does with `throwOnError:
// false`, `trust: false` (flutter_math has no \href, \url or HTML
// extensions at all).

/// KaTeX's `.katex { font-size: 1.21em }`.
const raftMathFontScale = 1.21;

/// KaTeX's `errorColor` for a formula it cannot parse.
// ds-allow: KaTeX 0.19 default errorColor (#cc0000), the Web's error text.
const raftMathErrorColor = Color(0xFFCC0000);

MathOptions _options(
  BuildContext context,
  TextStyle style, {
  required bool display,
}) {
  final size = style.fontSize ?? 14;
  return MathOptions(
    style: display ? MathStyle.display : MathStyle.text,
    // The reader's text size applies to the formula as to the text around it.
    fontSize: MediaQuery.textScalerOf(context).scale(size) * raftMathFontScale,
    color: style.color ?? DefaultTextStyle.of(context).style.color!,
  );
}

Widget _error(String source, TextStyle style) => Text(
  source,
  style: style.copyWith(color: raftMathErrorColor),
  textScaler: TextScaler.noScaling,
);

/// An inline formula (`$…$`, or `$$…$$` within a line), on the baseline of
/// the text around it. Its source is its tooltip (Web `title`) and label.
class RaftInlineMath extends StatelessWidget {
  const RaftInlineMath({super.key, required this.source, required this.style});
  final String source;

  /// The surrounding text's style (size and colour).
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final options = _options(context, style, display: false);
    return RaftTooltip(
      message: source,
      excludeFromSemantics: true,
      child: Semantics(
        label: source,
        excludeSemantics: true,
        child: Math.tex(
          source,
          options: options,
          mathStyle: MathStyle.text,
          onErrorFallback: (_) => _error(
            source,
            style.copyWith(fontSize: options.fontSize / raftMathFontScale),
          ),
        ),
      ),
    );
  }
}

/// The span an inline formula takes in a paragraph.
InlineSpan raftInlineMathSpan(String source, TextStyle style) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: RaftInlineMath(source: source, style: style),
);

/// A block formula (`$$` on its own lines): centred, 1em above and below
/// (KaTeX `.katex-display`); a formula wider than the text scrolls sideways,
/// as a wide Markdown table does.
class RaftDisplayMath extends StatefulWidget {
  const RaftDisplayMath({super.key, required this.source, required this.style});
  final String source;
  final TextStyle style;

  @override
  State<RaftDisplayMath> createState() => _RaftDisplayMathState();
}

class _RaftDisplayMathState extends State<RaftDisplayMath> {
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _options(context, widget.style, display: true);
    final em = options.fontSize / raftMathFontScale;
    final formula = Math.tex(
      widget.source,
      options: options,
      mathStyle: MathStyle.display,
      onErrorFallback: (_) =>
          _error(widget.source, widget.style.copyWith(fontSize: em)),
    );
    return Semantics(
      key: const ValueKey('raft-math-display'),
      label: widget.source,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => buildMarkdownScrollbar(
          context,
          controller,
          SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(vertical: em),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 0,
              ),
              child: Center(widthFactor: 1, child: formula),
            ),
          ),
          null,
        ),
      ),
    );
  }
}
