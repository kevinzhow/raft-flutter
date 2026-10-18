// Web account-level announcement popup (packages/web/src/components/
// AnnouncementModal.tsx): `Modal layer={1} closeOnBackdrop` holding a raft-ui
// `Card className="w-full max-w-xl flex flex-col"` with a title bar, one
// Markdown page at a time and a Back / Next-OK footer.
//
// Presentation and the modal's own keyboard contract only; loading, the
// read-complete write and when it is shown belong to the app.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_autolink.dart';
import 'raft_underline.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'panel_layout.dart'
    show RaftCssText, raftCssBaseline, raftTextMetricsCache;
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'recipes/inline_code.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// One page of an announcement (`AnnouncementPage { title?, body }`).
@immutable
class RaftAnnouncementPage {
  const RaftAnnouncementPage({this.title, required this.body});
  final String? title;

  /// Markdown (GFM).
  final String body;
}

/// Copy of the Web `common.announcement.*` messages (en / zh-cn).
@immutable
class RaftAnnouncementLabels {
  const RaftAnnouncementLabels({
    required this.dismiss,
    required this.back,
    required this.next,
    required this.ok,
  });

  /// `common.announcement.*` in the [context] locale.
  factory RaftAnnouncementLabels.of(BuildContext context) =>
      Localizations.maybeLocaleOf(context)?.languageCode == 'zh'
      ? const RaftAnnouncementLabels(
          dismiss: '关闭',
          back: '上一步',
          next: '下一步',
          ok: '确定',
        )
      : const RaftAnnouncementLabels(
          dismiss: 'Dismiss',
          back: 'Back',
          next: 'Next',
          ok: 'OK',
        );

  final String dismiss, back, next, ok;
}

/// The whole Web modal: backdrop + centred card, page navigation and the
/// keyboard contract.
///
/// * Next / Back walk the pages; on the last page the primary button reads
///   OK and calls [onConfirm] (explicit read-complete).
/// * ✕, Escape and a press on the backdrop call [onClose] (local close).
/// * Enter advances / confirms wherever focus is in the modal (Web: a
///   capture-phase window listener, so a focused Back button does not
///   swallow it).
/// * The primary button takes focus when the modal opens.
///
/// Page index starts at 0; key the widget by announcement id so a new
/// announcement starts on its first page.
class RaftAnnouncementModal extends StatefulWidget {
  const RaftAnnouncementModal({
    super.key,
    required this.title,
    required this.pages,
    required this.onClose,
    required this.onConfirm,
    this.labels,
    this.onLink,
    this.initialPage = 0,
  });

  final String title;
  final List<RaftAnnouncementPage> pages;
  final VoidCallback onClose, onConfirm;
  final RaftAnnouncementLabels? labels;
  final ValueChanged<String>? onLink;
  final int initialPage;

  @override
  State<RaftAnnouncementModal> createState() => _RaftAnnouncementModalState();
}

class _RaftAnnouncementModalState extends State<RaftAnnouncementModal> {
  late int page = widget.initialPage.clamp(0, _last);
  final primary = FocusNode(debugLabel: 'announcement-primary');

  /// Web focuses OK/Next on open (`:focus-visible`); the ring stays while
  /// that button keeps focus, including after it is clicked.
  bool ring = true;

  int get _last => math.max(0, widget.pages.length - 1);

  @override
  void initState() {
    super.initState();
    primary.addListener(_primaryFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) primary.requestFocus();
    });
  }

  bool _hadFocus = false;
  void _primaryFocus() {
    if (_hadFocus && !primary.hasFocus && ring) setState(() => ring = false);
    _hadFocus = primary.hasFocus;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    primary.removeListener(_primaryFocus);
    primary.dispose();
    super.dispose();
  }

  /// Sees every key from inside the modal before the app's activation
  /// shortcuts, so a focused Back button does not swallow Enter.
  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      next();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void next() {
    if (page >= _last) {
      widget.onConfirm();
    } else {
      setState(() => page = math.min(page + 1, _last));
    }
  }

  void back() => setState(() => page = math.max(page - 1, 0));

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return const SizedBox.shrink();
    final current = widget.pages[page.clamp(0, _last)];
    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _key,
      child: RaftModalBackdrop(
        onBackdrop: widget.onClose,
        child: RaftAnnouncementCard(
          title: widget.title,
          page: current,
          pageIndex: page,
          pageCount: widget.pages.length,
          labels: widget.labels ?? RaftAnnouncementLabels.of(context),
          onClose: widget.onClose,
          onBack: back,
          onNext: next,
          primaryFocusNode: primary,
          primaryFocusRing: ring,
          maxBodyHeight: MediaQuery.sizeOf(context).height * .6,
          onLink: widget.onLink,
        ),
      ),
    );
  }
}

/// The modal's card: `Card w-full max-w-xl` with header, body and footer.
class RaftAnnouncementCard extends StatelessWidget {
  const RaftAnnouncementCard({
    super.key,
    required this.title,
    required this.page,
    required this.pageIndex,
    required this.pageCount,
    required this.labels,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.maxBodyHeight,
    this.primaryFocusNode,
    this.primaryFocusRing = false,
    this.onLink,
  });

  /// The primary action was focused by the modal on open and still is.
  final bool primaryFocusRing;

  final String title;
  final RaftAnnouncementPage page;
  final int pageIndex, pageCount;
  final RaftAnnouncementLabels labels;
  final VoidCallback onClose, onBack, onNext;

  /// `max-h-[60vh]` of the page body.
  final double maxBodyHeight;
  final FocusNode? primaryFocusNode;
  final ValueChanged<String>? onLink;

  /// `max-w-xl` (36rem).
  static const maxWidth = 576.0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final root = RaftCardRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: tokens,
    ).root.withCssUsedBorderWidths();
    final borderInsets = root.borderWidth;
    final radius = root.borderRadius?.resolve(TextDirection.ltr);
    final last = pageIndex >= pageCount - 1;
    // `text-foreground-strong theme-brutal:text-black`.
    final ink = t.brutal ? Colors.black : t.strong;
    final rule = BorderSide(
      color: t.brutal ? Colors.black : t.colors['line-muted']!,
      width: t.brutal ? 2 : 1,
    );
    final header = Container(
      key: const ValueKey('announcement-header'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: t.brutal ? t.product.softSignal : t.colors['primary-soft'],
        border: Border(bottom: rule),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: RaftCssText(
                title.toUpperCase(),
                key: const ValueKey('announcement-title'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(t, ink),
              ),
            ),
          ),
          RaftCloseButton(onPressed: onClose, tooltip: labels.dismiss),
        ],
      ),
    );
    final bodyStyle = raftCssTextStyle(
      family: t.bodyFont,
      step: (14, 22.75), // text-sm leading-relaxed
      color: ink,
    ).copyWith(fontFamilyFallback: t.fontFallback);
    final pageTitle = page.title;
    final body = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxBodyHeight),
      child: SingleChildScrollView(
        key: const ValueKey('announcement-page-body'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: DefaultTextStyle(
          style: bodyStyle,
          child: RaftAnnouncementMarkdown(
            page.body,
            leading: pageTitle == null || pageTitle.isEmpty
                ? null
                : RaftCssBlock(
                    marginBottom: 12,
                    child: Builder(
                      builder: (context) {
                        final style = raftCssTextStyle(
                          family: t.bodyFont,
                          step: RaftTextSteps.base,
                          weight: FontWeight.w700,
                          color: ink,
                        ).copyWith(fontFamilyFallback: t.fontFallback);
                        return RaftCssText(
                          pageTitle.toUpperCase(),
                          style: style,
                        );
                      },
                    ),
                  ),
            onLink: onLink,
          ),
        ),
      ),
    );
    final footer = Container(
      key: const ValueKey('announcement-footer'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: t.brutal ? Colors.white : t.panel,
        border: Border(top: rule),
      ),
      child: Row(
        children: [
          if (pageCount > 1)
            RaftCssText(
              '${pageIndex + 1} / $pageCount',
              key: const ValueKey('announcement-page-indicator'),
              style: raftCssTextStyle(
                family: t.monoFont,
                step: RaftTextSteps.xs,
                color: t.brutal ? Colors.black.withValues(alpha: .6) : t.muted,
              ),
            ),
          const Spacer(),
          if (pageCount > 1 && pageIndex > 0) ...[
            RaftRecipeButton(
              key: const ValueKey('announcement-back'),
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.md,
              glyph: RaftGlyph.chevronLeft,
              label: labels.back,
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
          ],
          RaftRecipeButton(
            key: ValueKey(last ? 'announcement-ok' : 'announcement-next'),
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.md,
            fontWeight: FontWeight.w700,
            focusNode: primaryFocusNode,
            focusRing: primaryFocusRing,
            glyph: last ? null : RaftGlyph.chevronRight,
            glyphTrailing: true,
            label: last ? labels.ok : labels.next,
            onPressed: onNext,
          ),
        ],
      ),
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: ConstrainedBox(
        key: const ValueKey('announcement-modal'),
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: _CssPaintSnap(
          child: RaftRecipeBox(
            style: root,
            tokens: tokens,
            width: double.infinity,
            padding: EdgeInsets.zero,
            applyText: false,
            // `overflow-hidden`: children are clipped to the padding box.
            child: ClipRRect(
              borderRadius: radius == null
                  ? BorderRadius.zero
                  : BorderRadius.only(
                      topLeft: _inner(radius.topLeft, borderInsets),
                      topRight: _inner(radius.topRight, borderInsets),
                      bottomLeft: _inner(radius.bottomLeft, borderInsets),
                      bottomRight: _inner(radius.bottomRight, borderInsets),
                    ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, body, footer],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static TextStyle _titleStyle(RaftTokens t, Color ink) => raftCssTextStyle(
    family: t.bodyFont,
    step: RaftTextSteps.lg,
    weight: FontWeight.w700,
    color: ink,
  ).copyWith(fontFamilyFallback: t.fontFallback);

  static Radius _inner(Radius r, EdgeInsets border) => Radius.elliptical(
    math.max(0, r.x - border.left),
    math.max(0, r.y - border.top),
  );
}

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
/// AnnouncementModal `components` overrides, under Tailwind preflight:
///
/// * `p` `mb-2 last:mb-0`; `ul`/`ol` `mb-2 pl-5 list-disc|list-decimal`;
///   `li` `mb-0.5`;
/// * `h1`/`h2` `text-base font-bold uppercase mt-3 mb-2`, `h3` `text-sm`
///   (h4–h6 inherit, no margins);
/// * `a` `underline font-medium`, `code` InlineCode
///   `rounded-sm bg-layer-inset px-1 text-[0.85em] theme-brutal:bg-white`.
///
/// Vertical margins collapse like CSS (siblings and through parents without
/// padding); the scroll container's padding stops them at the edges.
class RaftAnnouncementMarkdown extends StatelessWidget {
  const RaftAnnouncementMarkdown(
    this.data, {
    super.key,
    this.leading,
    this.onLink,
  });

  final String data;

  /// A block before the Markdown in the same parent (the page title).
  final RaftCssBlock? leading;
  final ValueChanged<String>? onLink;

  @override
  Widget build(BuildContext context) {
    final nodes = raftFlattenNestedLinks(
      md.Document(
        inlineSyntaxes: [RaftBareUrlSyntax()],
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parse(data),
    );
    final builder = _MarkdownBlocks(context, onLink);
    final blocks = [?leading, ...builder.blocks(nodes)];
    return _layoutBlocks(blocks, outer: true);
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
  _MarkdownBlocks(this.context, this.onLink)
    : t = RaftTokens.of(context),
      base = DefaultTextStyle.of(context).style;
  final BuildContext context;
  final ValueChanged<String>? onLink;
  final RaftTokens t;
  final TextStyle base;

  List<RaftCssBlock> blocks(List<md.Node> nodes) {
    final out = <RaftCssBlock>[];
    final inline = <md.Node>[];
    void flushInline() {
      if (inline.isEmpty) return;
      final spans = _inlineSpans(List.of(inline), base, upper: false);
      inline.clear();
      if (spans.isEmpty) return;
      out.add(RaftCssBlock(child: _text(spans, base)));
    }

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is md.Element && _blockTags.contains(node.tag)) {
        flushInline();
        final lastChild = i == nodes.length - 1;
        final block = _block(node, lastChild: lastChild);
        if (block != null) out.add(block);
      } else {
        inline.add(node);
      }
    }
    flushInline();
    return out;
  }

  RaftCssBlock? _block(md.Element e, {required bool lastChild}) {
    final children = e.children ?? const <md.Node>[];
    switch (e.tag) {
      case 'p':
        return RaftCssBlock(
          child: _text(_inlineSpans(children, base, upper: false), base),
          marginBottom: lastChild ? 0 : 8,
        );
      case 'h1' || 'h2' || 'h3':
        final style = raftCssTextStyle(
          family: t.bodyFont,
          step: e.tag == 'h3' ? RaftTextSteps.sm : RaftTextSteps.base,
          weight: FontWeight.w700,
          color: base.color,
        ).copyWith(fontFamilyFallback: base.fontFamilyFallback);
        return RaftCssBlock(
          child: _text(_inlineSpans(children, style, upper: true), style),
          marginTop: 12,
          marginBottom: 8,
        );
      case 'h4' || 'h5' || 'h6':
        return RaftCssBlock(
          child: _text(_inlineSpans(children, base, upper: false), base),
        );
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
        return RaftCssBlock(
          child: _text(_inlineSpans(children, base, upper: false), base),
        );
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
          marginBottom: 2,
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
    return _container(items, marginBottom: 8);
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
  List<InlineSpan> _inlineSpans(
    List<md.Node> nodes,
    TextStyle style, {
    required bool upper,
  }) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        var text = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (upper) text = text.toUpperCase();
        spans.add(TextSpan(text: text));
      } else if (node is md.Element) {
        final children = node.children ?? const <md.Node>[];
        switch (node.tag) {
          case 'strong':
            spans.add(
              TextSpan(
                style: const TextStyle(fontWeight: FontWeight.w700),
                children: _inlineSpans(children, style, upper: upper),
              ),
            );
          case 'em':
            spans.add(
              TextSpan(
                style: const TextStyle(fontStyle: FontStyle.italic),
                children: _inlineSpans(children, style, upper: upper),
              ),
            );
          case 'del':
            spans.add(
              TextSpan(
                style: const TextStyle(decoration: TextDecoration.lineThrough),
                children: _inlineSpans(children, style, upper: upper),
              ),
            );
          case 'br':
            spans.add(const TextSpan(text: '\n'));
          case 'code':
            final text = node.textContent.replaceAll(RegExp(r'\s+'), ' ');
            spans.add(_inlineCode(upper ? text.toUpperCase() : text, style));
          case 'a':
            final href = node.attributes['href'] ?? '';
            final link = onLink;
            spans.add(
              RaftUnderlineSpan(
                style: const TextStyle(fontWeight: FontWeight.w500),
                recognizer: link == null || href.isEmpty
                    ? null
                    : (TapGestureRecognizer()..onTap = () => link(href)),
                mouseCursor: link == null ? null : SystemMouseCursors.click,
                children: _inlineSpans(children, style, upper: upper),
              ),
            );
          case 'img' || 'input':
            break;
          default:
            spans.addAll(_inlineSpans(children, style, upper: upper));
        }
      }
    }
    return spans;
  }

  /// InlineCode with the AnnouncementModal class overrides.
  InlineSpan _inlineCode(String text, TextStyle parent) {
    final tokens = RaftRecipeTokens(t);
    final root = RaftInlineCodeRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: tokens,
    ).root;
    final recipeText = root.textStyle(tokens);
    final size = (parent.fontSize ?? 14) * .85;
    final style = recipeText.copyWith(
      fontSize: size,
      // Line height is inherited (`leading-relaxed` of the body).
      height: parent.height,
      leadingDistribution: TextLeadingDistribution.even,
      fontFamilyFallback: parent.fontFamilyFallback,
    );
    final elegant = !t.brutal;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: RaftRecipeBox(
        style: root,
        tokens: tokens,
        applyText: false,
        // `px-1` (elegant keeps `py-[1.5px]`).
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          // ds-allow: Web raft-ui/inline-code.tsx py-[1.5px]
          vertical: elegant ? 1.5 : 0,
        ),
        decorationOverride: (d) => d.copyWith(
          // `bg-layer-inset theme-brutal:bg-white` (dark keeps the
          // recipe's later `dark:bg-fill-muted`).
          color: t.brutal
              ? Colors.white
              : t.dark
              ? d.color
              : t.colors['layer-inset'],
          borderRadius: BorderRadius.circular(4),
        ),
        // Blink: the content area is the rounded ascent + descent; the
        // elegant `inline-flex` line box is the inherited line height with
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
          fontSize: (base.fontSize ?? 14) * .85,
          height: base.height,
          leadingDistribution: TextLeadingDistribution.even,
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
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            // ds-allow: Web raft-ui/inline-code.tsx py-[1.5px]
            vertical: t.brutal ? 0 : 1.5,
          ),
          decorationOverride: (d) => d.copyWith(
            color: t.brutal
                ? Colors.white
                : t.dark
                ? d.color
                : t.colors['layer-inset'],
            borderRadius: BorderRadius.circular(4),
          ),
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
                          upper: false,
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

/// Blink paints a box whose layout position is fractional (the modal card
/// centred at e.g. y = 296.5) at the whole CSS pixel (round half up), while
/// its layout rect (and so an element screenshot) keeps the fraction. Paint
/// only; descendants that snap their own text see the snapped origin.
class _CssPaintSnap extends SingleChildRenderObjectWidget {
  const _CssPaintSnap({super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCssPaintSnap();
}

class _RenderCssPaintSnap extends RenderProxyBox {
  Offset _delta = Offset.zero;

  Offset _snap() {
    final parent = this.parent;
    if (parent is! RenderBox || !attached) return Offset.zero;
    final origin =
        parent.localToGlobal(Offset.zero) +
        ((parentData is BoxParentData)
            ? (parentData! as BoxParentData).offset
            : Offset.zero);
    double round(double v) => (v + .5).floorToDouble() - v;
    return Offset(round(origin.dx), round(origin.dy));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _delta = _snap();
    super.paint(context, offset + _delta);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_delta.dx, _delta.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _delta,
        position: position,
        hitTest: (result, transformed) =>
            super.hitTestChildren(result, position: transformed),
      );
}

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
