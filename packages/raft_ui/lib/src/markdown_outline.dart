// Web `components/markdown/MarkdownOutline.tsx`: the Markdown file preview
// lists its h1-h3 headings in an "Outline" next to the document on wide
// screens (`xl`); an item scrolls the document to its heading.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'markdown_cjk_emphasis.dart';
import 'markdown_math.dart';

import 'localization.dart';
import 'theme.dart';
import 'tooltip.dart';

class RaftMarkdownOutlineItem {
  const RaftMarkdownOutlineItem({
    required this.id,
    required this.level,
    required this.sourceLine,
    required this.title,
  });

  /// The heading's slug; a repeated title gets `-2`, `-3`, ...
  final String id;

  /// 1..3.
  final int level;

  /// 1-based line of the `#` marker.
  final int sourceLine;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is RaftMarkdownOutlineItem &&
      other.id == id &&
      other.level == level &&
      other.sourceLine == sourceLine &&
      other.title == title;
  @override
  int get hashCode => Object.hash(id, level, sourceLine, title);
  @override
  String toString() => '$id/$level@$sourceLine: $title';
}

final _fenceOpen = RegExp(r'^ {0,3}(`{3,}|~{3,})');
final _atxHeading = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$');
final _closingHashes = RegExp(r'(?:^|[ \t]+)#+[ \t]*$');
final _setextUnderline = RegExp(r'^ {0,3}(=+|-+)[ \t]*$');
final _notParagraph = RegExp(
  r'^ {0,3}(?:[>#]|[-*+][ \t]|\d{1,9}[.)][ \t]|(?:[-*_][ \t]*){3,}$|`{3,}|~{3,}|\$\$)',
);

/// Web 1.24 `markdownHeadings` (shared markdownOutline.ts): the headings as
/// the Markdown parser reads them, ATX (`## Title`) and setext (`Title` over
/// `===` / `---`) alike, depth 1-3, each with the 1-based line it starts on
/// and its plain text (code and formulas as written, link and image text, no
/// markup or HTML tags).
List<RaftMarkdownOutlineItem> raftExtractMarkdownOutline(String markdown) {
  final seen = <String, int>{};
  final outline = <RaftMarkdownOutlineItem>[];
  void add(int level, int line, String raw) {
    if (level > 3) return;
    final title = _plainHeadingText(raw);
    if (title.isEmpty) return;
    final base = _slugifyHeading(title);
    final count = seen[base] ?? 0;
    seen[base] = count + 1;
    outline.add(
      RaftMarkdownOutlineItem(
        id: count == 0 ? base : '$base-${count + 1}',
        level: level,
        sourceLine: line,
        title: title,
      ),
    );
  }

  final lines = markdown.split(RegExp(r'\r?\n'));
  String? fence;
  int? paragraphStart;
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (fence != null) {
      final close = RegExp(
        '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}[ \\t]*\$',
      );
      if (close.hasMatch(line)) fence = null;
      continue;
    }
    final open = _fenceOpen.firstMatch(line);
    if (open != null) {
      fence = open.group(1);
      paragraphStart = null;
      continue;
    }
    if (line.trim().isEmpty) {
      paragraphStart = null;
      continue;
    }
    if (paragraphStart != null) {
      final underline = _setextUnderline.firstMatch(line);
      if (underline != null) {
        add(
          underline.group(1)!.startsWith('=') ? 1 : 2,
          paragraphStart + 1,
          lines.sublist(paragraphStart, index).join(' '),
        );
        paragraphStart = null;
        continue;
      }
    }
    final atx = _atxHeading.firstMatch(line);
    if (atx != null) {
      add(
        atx.group(1)!.length,
        index + 1,
        (atx.group(2) ?? '').replaceAll(_closingHashes, ''),
      );
      paragraphStart = null;
      continue;
    }
    // An indented line starts no paragraph (indented code) but continues one.
    if (paragraphStart == null &&
        (line.startsWith('    ') || line.startsWith('\t'))) {
      continue;
    }
    if (_notParagraph.hasMatch(line)) {
      paragraphStart = null;
      continue;
    }
    paragraphStart ??= index;
  }
  return outline;
}

String _plainHeadingText(String raw) {
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [RaftMathTextSyntax(), ...raftCjkEmphasisSyntaxes()],
    encodeHtml: false,
  ).parseInline(raw);
  String text(List<md.Node> nodes) => [
    for (final node in nodes)
      switch (node) {
        md.Element(tag: 'img') => node.attributes['alt'] ?? '',
        md.Element(tag: 'code') => node.textContent,
        md.Element(:final children) => text(children ?? const []),
        md.Text(:final text) => text.replaceAll(RegExp(r'<[^>]*>'), ''),
        _ => '',
      },
  ].join();
  return text(nodes).replaceAll(RegExp(r'\s+'), ' ').trim();
}

// The exact Web sequence: lowercase, NFKD, replace every non-letter/number
// run with a hyphen, then trim. Combining marks become separators, not
// silently removed accents (e.g. éa -> e-a).
String _slugifyHeading(String title) {
  final slug = unorm
      .nfkd(title.toLowerCase())
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'section' : slug;
}

/// Width of the outline column (`xl:grid-cols-[16rem_…]`).
const raftMarkdownOutlineWidth = 256.0;

/// The `xl` breakpoint from which the outline shows.
const raftMarkdownOutlineBreakpoint = 1280.0;

/// Web `MarkdownOutlineNav`: `border-l border-line-hairline pl-4 text-footnote`.
class RaftMarkdownOutlineNav extends StatelessWidget {
  const RaftMarkdownOutlineNav({
    super.key,
    required this.outline,
    required this.onSelect,
  });
  final List<RaftMarkdownOutlineItem> outline;
  final ValueChanged<RaftMarkdownOutlineItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (outline.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final hint = t.colors['foreground-hint'] ?? t.colors['foreground-muted']!;
    final style = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
      color: t.colors['foreground-muted'],
    );
    return Semantics(
      container: true,
      label: raftText(context, 'Markdown outline'),
      child: Container(
        key: const ValueKey('markdown-outline'),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: t.colors['line-hairline']!)),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                raftText(context, 'Outline'),
                style: style.copyWith(fontWeight: FontWeight.w700, color: hint),
              ),
            ),
            for (final item in outline)
              Padding(
                key: ValueKey('outline-${item.id}'),
                padding: EdgeInsets.only(
                  left: switch (item.level) {
                    2 => 12.0,
                    3 => 24.0,
                    _ => 0.0,
                  },
                  bottom: 6,
                ),
                child: RaftTooltip(
                  message: item.title,
                  child: Semantics(
                    link: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(item),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The paragraph [item]'s heading was laid out as inside [root]: the
/// [occurrence]-th (0-based) paragraph whose text is the heading's text.
RenderParagraph? raftFindHeadingParagraph(
  RenderObject root,
  RaftMarkdownOutlineItem item,
  int occurrence,
) {
  String normalize(String text) => text
      .replaceAll(RegExp(r'[`*_~]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final wanted = normalize(item.title);
  var seen = 0;
  RenderParagraph? found;
  void visit(RenderObject object) {
    if (found != null) return;
    if (object is RenderParagraph &&
        normalize(object.text.toPlainText()) == wanted) {
      if (seen++ == occurrence) {
        found = object;
        return;
      }
    }
    object.visitChildren(visit);
  }

  visit(root);
  return found;
}

/// How many items before [item] share its title (which paragraph to take).
int raftHeadingOccurrence(
  List<RaftMarkdownOutlineItem> outline,
  RaftMarkdownOutlineItem item,
) {
  final index = outline.indexOf(item);
  var count = 0;
  for (var i = 0; i < index; i++) {
    if (outline[i].title == item.title) count++;
  }
  return count;
}

/// Scrolls [position] so [paragraph] is [margin] px below the top of its
/// viewport. False when it is not inside a scrolling viewport.
bool raftScrollToParagraph(
  ScrollPosition position,
  RenderParagraph paragraph, {
  // Web 1.24 heading `scroll-mt-6`.
  double margin = 24,
  Duration duration = const Duration(milliseconds: 250),
}) {
  final viewport = RenderAbstractViewport.maybeOf(paragraph);
  if (viewport == null) return false;
  final target =
      viewport.getOffsetToReveal(paragraph, 0).offset - math.max(0, margin);
  position.animateTo(
    target.clamp(position.minScrollExtent, position.maxScrollExtent),
    duration: duration,
    curve: Curves.easeOut,
  );
  return true;
}
