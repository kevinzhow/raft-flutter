// The announcement page body: ReactMarkdown + remark-gfm exactly as the Web
// AnnouncementModal renders it inside raft-ui's AnnouncementDialogText.
//
// Presentation only; the dialog around it is announcement_modal.dart.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_autolink.dart';
import 'raft_underline.dart';
import 'dialog_card.dart';
import 'panel_layout.dart'
    show RaftCssText, raftCssBaseline, raftTextMetricsCache;
import 'recipe_surface.dart';
import 'recipes/inline_code.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// A CSS block box for [RaftAnnouncementMarkdown]: its vertical margins
/// collapse with adjacent siblings (and through padding-less parents).
@immutable
class RaftCssBlock {
  const RaftCssBlock({
    required this.child,
    this.marginTop = 0,
    this.marginBottom = 0,
  });
  final Widget child;
  final double marginTop, marginBottom;
}

/// The announcement page body: ReactMarkdown + remark-gfm with the
/// AnnouncementModal `components` overrides (`a` underlined, `code` the
/// plain raft-ui InlineCode) inside AnnouncementDialogText, under Tailwind
/// preflight:
///
/// * `[&_p+p]:mt-3`; `ul`/`ol` `pl-5 list-disc|list-decimal`, no margins;
/// * `h1` `text-xl`, `h2` `text-lg`, `h3` `text-base`, all `font-bold`
///   (h4-h6 inherit); no heading margins, no uppercase;
/// * `pre` scrolls horizontally.
///
/// Vertical margins collapse like CSS (siblings and through parents without
/// padding); the scroll container's padding stops them at the edges.
class RaftAnnouncementMarkdown extends StatefulWidget {
  const RaftAnnouncementMarkdown(this.data, {super.key, this.onLink});

  final String data;
  final ValueChanged<String>? onLink;

  @override
  State<RaftAnnouncementMarkdown> createState() =>
      _RaftAnnouncementMarkdownState();
}

class _RaftAnnouncementMarkdownState extends State<RaftAnnouncementMarkdown> {
  /// The link recognizers of the tree last built; this state owns them.
  var _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers(List<TapGestureRecognizer> recognizers) {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers(_recognizers);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The previous tree is replaced by this build.
    _disposeRecognizers(_recognizers);
    _recognizers = [];
    final data = widget.data, onLink = widget.onLink;
    final nodes = raftFlattenNestedLinks(
      md.Document(
        inlineSyntaxes: [RaftBareUrlSyntax()],
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parse(data),
    );
    final builder = _MarkdownBlocks(context, onLink, _recognizers);
    return _layoutBlocks(builder.blocks(nodes), outer: true);
  }
}

/// Lays [blocks] out as a column with collapsed sibling margins. With
/// [outer] the first top and last bottom margins are kept inside (a padded
/// container); otherwise the caller collapses them outwards.
Widget _layoutBlocks(List<RaftCssBlock> blocks, {required bool outer}) {
  final children = <Widget>[];
  for (var i = 0; i < blocks.length; i++) {
    final gap = i == 0
        ? (outer ? blocks[i].marginTop : 0.0)
        : math.max(blocks[i - 1].marginBottom, blocks[i].marginTop);
    if (gap > 0) children.add(SizedBox(height: gap));
    children.add(blocks[i].child);
  }
  if (outer && blocks.isNotEmpty && blocks.last.marginBottom > 0) {
    children.add(SizedBox(height: blocks.last.marginBottom));
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

/// A padding-less container (ul, li, blockquote): its children's outer
/// margins collapse with its own.
RaftCssBlock _container(
  List<RaftCssBlock> children, {
  double marginTop = 0,
  double marginBottom = 0,
  Widget Function(Widget child)? wrap,
}) {
  final top = children.isEmpty ? 0.0 : children.first.marginTop;
  final bottom = children.isEmpty ? 0.0 : children.last.marginBottom;
  final column = _layoutBlocks(children, outer: false);
  return RaftCssBlock(
    child: wrap == null ? column : wrap(column),
    marginTop: math.max(marginTop, top),
    marginBottom: math.max(marginBottom, bottom),
  );
}

const _blockTags = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'pre',
  'blockquote',
  'hr',
  'table',
};

class _MarkdownBlocks {
  _MarkdownBlocks(this.context, this.onLink, this.recognizers)
    : t = RaftTokens.of(context),
      base = DefaultTextStyle.of(context).style;
  final BuildContext context;
  final ValueChanged<String>? onLink;

  /// Collects the recognizers created for links (owned by the caller).
  final List<TapGestureRecognizer> recognizers;
  final RaftTokens t;
  final TextStyle base;

  List<RaftCssBlock> blocks(List<md.Node> nodes) {
    final out = <RaftCssBlock>[];
    final inline = <md.Node>[];
    // `[&_p+p]:mt-3` follows the previous sibling ELEMENT, text between does
    // not count.
    var previousTag = '';
    void flushInline() {
      if (inline.isEmpty) return;
      final spans = _inlineSpans(List.of(inline), base);
      inline.clear();
      if (spans.isEmpty) return;
      out.add(RaftCssBlock(child: _text(spans, base)));
    }

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is md.Element && _blockTags.contains(node.tag)) {
        flushInline();
        final block = _block(node, afterParagraph: previousTag == 'p');
        previousTag = node.tag;
        if (block != null) out.add(block);
      } else {
        if (node is md.Element) previousTag = node.tag;
        inline.add(node);
      }
    }
    flushInline();
    return out;
  }

  RaftCssBlock? _block(md.Element e, {required bool afterParagraph}) {
    final children = e.children ?? const <md.Node>[];
    switch (e.tag) {
      case 'p':
        return RaftCssBlock(
          child: _text(_inlineSpans(children, base), base),
          marginTop: afterParagraph ? 12 : 0,
        );
      case 'h1' || 'h2' || 'h3':
        final style = raftCssTextStyle(
          family: t.bodyFont,
          step: switch (e.tag) {
            'h1' => RaftTextSteps.xl,
            'h2' => RaftTextSteps.lg,
            _ => RaftTextSteps.base,
          },
          weight: FontWeight.w700,
          color: base.color,
        ).copyWith(fontFamilyFallback: base.fontFamilyFallback);
        return RaftCssBlock(child: _text(_inlineSpans(children, style), style));
      case 'h4' || 'h5' || 'h6':
        return RaftCssBlock(child: _text(_inlineSpans(children, base), base));
      case 'ul' || 'ol':
        return _list(e);
      case 'blockquote':
        return _container(blocks(children));
      case 'pre':
        return RaftCssBlock(child: _codeBlock(e.textContent));
      case 'hr':
        return RaftCssBlock(child: Container(height: 1, color: base.color));
      case 'table':
        return RaftCssBlock(child: _table(e));
      default:
        return RaftCssBlock(child: _text(_inlineSpans(children, base), base));
    }
  }

  RaftCssBlock _list(md.Element e) {
    final ordered = e.tag == 'ol';
    var number = int.tryParse(e.attributes['start'] ?? '') ?? 1;
    final items = <RaftCssBlock>[];
    final markerStyle = base.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    for (final li in (e.children ?? const <md.Node>[])) {
      if (li is! md.Element || li.tag != 'li') continue;
      // Outside ::marker: "1. " ends where the item content starts (the
      // list's `pl-5`); a disc is Blink's painted symbol.
      final marker = ordered ? '${number++}. ' : '\u2022 ';
      final painter = TextPainter(
        text: TextSpan(text: marker, style: markerStyle),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final markerWidth = painter.width;
      painter.dispose();
      final content = blocks(li.children ?? const <md.Node>[]);
      items.add(
        _container(
          content.isEmpty
              ? [RaftCssBlock(child: Text('', style: base))]
              : content,
          wrap: (column) => Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(padding: const EdgeInsets.only(left: 20), child: column),
              if (ordered)
                Positioned(
                  left: 20 - markerWidth,
                  top: 0,
                  child: ExcludeSemantics(
                    child: RaftCssText(
                      marker,
                      style: markerStyle,
                      softWrap: false,
                    ),
                  ),
                )
              else
                _disc(markerStyle),
            ],
          ),
        ),
      );
    }
    return _container(items);
  }

  /// Blink `ListMarker` symbol geometry (integer font ascent A): a circle
  /// `(A*2/3 + 1) / 2` wide, `3 * (A - A*2/3) / 2` below the marker's text
  /// top, its box ending 11px before the item content (measured).
  Widget _disc(TextStyle style) {
    final scaled = style.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14),
    );
    final ascent = raftCssContentMetrics(scaled).$1.round();
    final twoThirds = ascent * 2 ~/ 3;
    final size = ((twoThirds + 1) ~/ 2).toDouble();
    final top =
        raftCssBaseline(scaled) - ascent + (3 * (ascent - twoThirds) ~/ 2);
    return Positioned(
      left: 20 - size - 11,
      top: top,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(List<InlineSpan> spans, TextStyle style) {
    final text = RaftCssText.rich(
      TextSpan(children: spans),
      style: style,
      underline: _hasUnderline(spans),
    );
    // Elegant InlineCode is `inline-flex` (an atomic box that can grow its
    // line); brutal code is an inline box that never does.
    final atomic = !t.brutal && _hasWidgetSpan(spans);
    return atomic ? _CssAtomicLines(style: style, child: text) : text;
  }

  static bool _hasUnderline(List<InlineSpan> spans) => spans.any(
    (s) =>
        s is RaftUnderlineSpan ||
        (s is TextSpan && s.children != null && _hasUnderline(s.children!)),
  );

  static bool _hasWidgetSpan(List<InlineSpan> spans) => spans.any(
    (s) =>
        s is WidgetSpan ||
        (s is TextSpan && s.children != null && _hasWidgetSpan(s.children!)),
  );

  /// Inline content with CSS white-space collapsing (soft breaks are spaces).
  List<InlineSpan> _inlineSpans(List<md.Node> nodes, TextStyle style) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        spans.add(TextSpan(text: node.text.replaceAll(RegExp(r'\s+'), ' ')));
      } else if (node is md.Element) {
        final children = node.children ?? const <md.Node>[];
        switch (node.tag) {
          case 'strong':
            spans.add(
              TextSpan(
                style: const TextStyle(fontWeight: FontWeight.w700),
                children: _inlineSpans(children, style),
              ),
            );
          case 'em':
            spans.add(
              TextSpan(
                style: const TextStyle(fontStyle: FontStyle.italic),
                children: _inlineSpans(children, style),
              ),
            );
          case 'del':
            spans.add(
              TextSpan(
                style: const TextStyle(decoration: TextDecoration.lineThrough),
                children: _inlineSpans(children, style),
              ),
            );
          case 'br':
            spans.add(const TextSpan(text: '\n'));
          case 'code':
            final text = node.textContent.replaceAll(RegExp(r'\s+'), ' ');
            spans.add(_inlineCode(text, style));
          case 'a':
            final href = node.attributes['href'] ?? '';
            final link = onLink;
            final recognizer = link == null || href.isEmpty
                ? null
                : (TapGestureRecognizer()..onTap = () => link(href));
            if (recognizer != null) recognizers.add(recognizer);
            spans.add(
              RaftUnderlineSpan(
                mouseCursor: link == null ? null : SystemMouseCursors.click,
                children: [
                  for (final span in _inlineSpans(children, style))
                    _linked(span, recognizer),
                ],
              ),
            );
          case 'img' || 'input':
            break;
          default:
            spans.addAll(_inlineSpans(children, style));
        }
      }
    }
    return spans;
  }

  /// A span's recognizer only covers its own text, never its children's, so
  /// a link's recognizer goes on every text leaf of its content.
  InlineSpan _linked(InlineSpan span, TapGestureRecognizer? recognizer) {
    if (recognizer == null || span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      style: span.style,
      recognizer: span.text == null ? null : recognizer,
      mouseCursor: SystemMouseCursors.click,
      children: [
        for (final child in span.children ?? const <InlineSpan>[])
          _linked(child, recognizer),
      ],
    );
  }

  /// The plain raft-ui InlineCode (the Web `code` component adds no classes).
  ///
  /// Brutal is an inline box (content area + padding + border) that never
  /// grows its line; elegant is `inline-flex`, an atomic box whose line box is
  /// its own line height.
  InlineSpan _inlineCode(String text, TextStyle parent) {
    final tokens = RaftRecipeTokens(t);
    final root = RaftInlineCodeRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: tokens,
    ).root;
    final style = root
        .textStyle(tokens)
        .copyWith(
          leadingDistribution: TextLeadingDistribution.even,
          fontFamilyFallback: parent.fontFamilyFallback,
        );
    final size = style.fontSize ?? 14;
    final elegant = !t.brutal;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: RaftRecipeBox(
        style: root,
        tokens: tokens,
        applyText: false,
        // Blink: the content area is the rounded ascent + descent; the
        // elegant `inline-flex` line box is the recipe line height with
        // the floored half-leading above the rounded ascent.
        child: Builder(
          builder: (context) {
            final scaled = style.copyWith(
              fontSize: MediaQuery.textScalerOf(context).scale(size),
            );
            final (ascent, descent) = raftCssContentMetrics(scaled);
            final box = elegant
                ? scaled.fontSize! * (scaled.height ?? 1)
                : ascent + descent;
            return SizedBox(
              height: box,
              child: Baseline(
                baseline: elegant
                    ? ascent + ((box - (ascent + descent)) / 2).floorToDouble()
                    : ascent,
                baselineType: TextBaseline.alphabetic,
                child: Text(
                  text,
                  style: style.copyWith(height: kTextHeightNone),
                  softWrap: false,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// A fenced block: ReactMarkdown hands `<pre><code>` to the same
  /// InlineCode component, inside `pre max-w-full overflow-x-auto`.
  Widget _codeBlock(String code) {
    final tokens = RaftRecipeTokens(t);
    final root = RaftInlineCodeRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: tokens,
    ).root;
    final style = root
        .textStyle(tokens)
        .copyWith(
          leadingDistribution: TextLeadingDistribution.even,
          fontFamilyFallback: base.fontFamilyFallback,
        );
    final trimmed = code.endsWith('\n')
        ? code.substring(0, code.length - 1)
        : code;
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: RaftRecipeBox(
          style: root,
          tokens: tokens,
          applyText: false,
          child: Text(trimmed, style: style, softWrap: false),
        ),
      ),
    );
  }

  Widget _table(md.Element table) {
    final rows = <List<md.Element>>[];
    void collect(md.Element e) {
      for (final child in e.children ?? const <md.Node>[]) {
        if (child is! md.Element) continue;
        if (child.tag == 'tr') {
          rows.add([
            for (final cell in child.children ?? const <md.Node>[])
              if (cell is md.Element) cell,
          ]);
        } else {
          collect(child);
        }
      }
    }

    collect(table);
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.map((r) => r.length).reduce(math.max);
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (var i = 0; i < columns; i++)
                i < row.length
                    ? _text(
                        _inlineSpans(
                          row[i].children ?? const <md.Node>[],
                          base,
                        ),
                        row[i].tag == 'th'
                            ? base.copyWith(fontWeight: FontWeight.w700)
                            : base,
                      )
                    : const SizedBox.shrink(),
            ],
          ),
      ],
    );
  }
}

/// Blink content-area metrics of [style]: rounded ascent and descent.
(double, double) raftCssContentMetrics(TextStyle style) =>
    _cssContent.putIfAbsent(style, () {
      final probe = TextPainter(
        text: TextSpan(
          text: 'Hg',
          style: style.copyWith(height: kTextHeightNone),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Line metrics, not the painter height (rounded to whole pixels).
      final m = probe.computeLineMetrics().first;
      probe.dispose();
      return (m.ascent.roundToDouble(), m.descent.roundToDouble());
    });

final _cssContent = raftTextMetricsCache<TextStyle, (double, double)>();

/// Line boxes grown by atomic inline boxes. Flutter grows a line from its
/// fractional strut descent, Blink from `line-height - css baseline`; each
/// grown line is re-measured with Blink's descent and the box takes the sum
/// (the [RaftCssText] inside sizes to whole strut lines only).
class _CssAtomicLines extends SingleChildRenderObjectWidget {
  const _CssAtomicLines({required this.style, super.child});
  final TextStyle style;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCssAtomicLines(_metrics(context));
  @override
  void updateRenderObject(BuildContext context, _RenderCssAtomicLines r) =>
      r.metrics = _metrics(context);

  (double, double) _metrics(BuildContext context) {
    final scaled = style.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14),
    );
    final line = (scaled.fontSize ?? 14) * (scaled.height ?? 1.2);
    final probe = TextPainter(
      text: TextSpan(text: 'Hg', style: scaled),
      textDirection: TextDirection.ltr,
    )..layout();
    final flutterBelow =
        line - probe.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    probe.dispose();
    return (line, (line - raftCssBaseline(scaled)) - flutterBelow);
  }
}

class _RenderCssAtomicLines extends RenderProxyBox {
  _RenderCssAtomicLines(this._metrics);

  /// (line height, Blink descent - Flutter descent).
  (double, double) _metrics;
  set metrics((double, double) v) {
    if (v == _metrics) return;
    _metrics = v;
    markNeedsLayout();
  }

  RenderParagraph? _paragraph(RenderObject? node) {
    while (node != null && node is! RenderParagraph) {
      node = node is RenderObjectWithChildMixin<RenderBox> ? node.child : null;
    }
    return node as RenderParagraph?;
  }

  @override
  void performLayout() {
    final c = child!;
    c.layout(constraints, parentUsesSize: true);
    var height = c.size.height;
    final p = _paragraph(c);
    if (p != null) {
      final length = p.text.toPlainText(includeSemanticsLabels: false).length;
      final boxes = length == 0
          ? const <TextBox>[]
          : p.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: length),
              boxHeightStyle: ui.BoxHeightStyle.max,
            );
      final lines = <double, double>{};
      for (final b in boxes) {
        lines[b.top] = math.max(lines[b.top] ?? 0, b.bottom - b.top);
      }
      if (lines.isNotEmpty) {
        final (line, descentDelta) = _metrics;
        height = 0;
        for (final h in lines.values) {
          height += h > line + .01 ? math.max(line, h - descentDelta) : line;
        }
      }
    }
    size = constraints.constrain(Size(c.size.width, height));
  }
}
