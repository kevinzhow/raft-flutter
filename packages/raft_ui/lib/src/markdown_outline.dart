// Web `components/markdown/MarkdownOutline.tsx`: the Markdown file preview
// lists its h1-h3 headings in an "Outline" next to the document on wide
// screens (`xl`); an item scrolls the document to its heading.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

final _fence = RegExp(r'^\s*(```|~~~)');
final _atxHeading = RegExp(r'^(#{1,3})\s+(.+?)\s*$');
final _trailingHashes = RegExp(r'\s+#+\s*$');

/// Web `extractMarkdownOutline`.
List<RaftMarkdownOutlineItem> raftExtractMarkdownOutline(String markdown) {
  final seen = <String, int>{};
  final outline = <RaftMarkdownOutlineItem>[];
  var inFence = false;
  final lines = markdown.split(RegExp(r'\r?\n'));
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (_fence.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence || line.startsWith('    ')) continue;
    final match = _atxHeading.firstMatch(line);
    if (match == null) continue;
    final title = _cleanHeadingText(match.group(2)!);
    if (title.isEmpty) continue;
    final base = _slugifyHeading(title);
    final count = seen[base] ?? 0;
    seen[base] = count + 1;
    outline.add(
      RaftMarkdownOutlineItem(
        id: count == 0 ? base : '$base-${count + 1}',
        level: match.group(1)!.length,
        sourceLine: index + 1,
        title: title,
      ),
    );
  }
  return outline;
}

String _cleanHeadingText(String raw) => raw
    .replaceAll(_trailingHashes, '')
    .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'[`*_~]'), '')
    .trim();

// `String.prototype.normalize("NFKD")` drops accents through the slug regex
// (the combining mark is not a letter); the Latin-1 and Latin Extended-A
// letters are mapped to their base letters to the same effect.
const _accents = {
  'àáâãäåāăą': 'a',
  'çćĉċč': 'c',
  'ďđ': 'd',
  'èéêëēĕėęě': 'e',
  'ĝğġģ': 'g',
  'ĥħ': 'h',
  'ìíîïĩīĭįı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĺļľŀł': 'l',
  'ñńņňŉ': 'n',
  'òóôõöøōŏő': 'o',
  'ŕŗř': 'r',
  'śŝşš': 's',
  'ţťŧ': 't',
  'ùúûüũūŭůűų': 'u',
  'ŵ': 'w',
  'ýÿŷ': 'y',
  'źżž': 'z',
};
final _accentMap = {
  for (final entry in _accents.entries)
    for (final rune in entry.key.runes) String.fromCharCode(rune): entry.value,
};

String _slugifyHeading(String title) {
  final folded = title
      .toLowerCase()
      .split('')
      .map((c) => _accentMap[c] ?? c)
      .join();
  final slug = folded
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
  double margin = 16,
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
