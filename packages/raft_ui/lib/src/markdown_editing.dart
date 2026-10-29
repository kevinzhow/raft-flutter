import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'composer_composing_text.dart' show RaftComposerEditingController;
import 'message_content_tokens.dart' show MessageContentSemantic;
import 'theme.dart';

// Markdown editing operations (pure functions over a TextEditingValue).
// Wire format stays Markdown text; every operation only inserts or removes
// Markdown characters, so the draft is identical in both views.
// ---------------------------------------------------------------------------

abstract final class RaftMarkdownFormat {
  static TextSelection _selection(TextEditingValue v) => v.selection.isValid
      ? v.selection
      : TextSelection.collapsed(offset: v.text.length);

  /// Length of the run of [ch] ending just before [at] (scanning left) or
  /// starting at [at] (scanning right).
  static int _run(String text, int at, String ch, {required bool left}) {
    var n = 0;
    while (left
        ? at - n - 1 >= 0 && text[at - n - 1] == ch
        : at + n < text.length && text[at + n] == ch) {
      n++;
    }
    return n;
  }

  /// Toggles an inline [mark] (`**`, `*`, `~~`, `` ` ``) around the selection.
  /// A selection already wrapped in exactly this mark is unwrapped; `*` inside
  /// `**` adds italic, and `**` inside `***` removes only the bold.
  static TextEditingValue wrap(
    TextEditingValue v,
    String mark, {
    String placeholder = 'text',
  }) {
    final text = v.text, sel = _selection(v);
    final start = sel.start, end = sel.end, n = mark.length;
    final ch = mark[0], single = mark.split('').every((c) => c == ch);
    final marked =
        start >= n &&
        end + n <= text.length &&
        text.substring(start - n, start) == mark &&
        text.substring(end, end + n) == mark;
    final runs = (
      _run(text, start, ch, left: true),
      _run(text, end, ch, left: false),
    );
    final exact =
        !single ||
        (runs.$1 == n && runs.$2 == n) ||
        (ch == '*' && runs.$1 == 3 && runs.$2 == 3);
    if (marked && exact) {
      final next = text
          .replaceRange(end, end + n, '')
          .replaceRange(start - n, start, '');
      return TextEditingValue(
        text: next,
        selection: TextSelection(baseOffset: start - n, extentOffset: end - n),
      );
    }
    final inner = sel.isCollapsed ? placeholder : text.substring(start, end);
    return TextEditingValue(
      text: text.replaceRange(start, end, '$mark$inner$mark'),
      selection: TextSelection(
        baseOffset: start + n,
        extentOffset: start + n + inner.length,
      ),
    );
  }

  /// Adds or removes a line prefix on every selected line. [ordered] numbers
  /// the lines `1.`, `2.`, ...
  static TextEditingValue linePrefix(
    TextEditingValue v,
    String prefix, {
    bool ordered = false,
  }) {
    final text = v.text, sel = _selection(v);
    final lineStart = sel.start == 0
        ? 0
        : text.lastIndexOf('\n', sel.start - 1) + 1;
    // A selection that ends right after a newline does not include the next line.
    final last = !sel.isCollapsed && text[sel.end - 1] == '\n'
        ? sel.end - 1
        : sel.end;
    var lineEnd = text.indexOf('\n', last);
    if (lineEnd < 0) lineEnd = text.length;
    final lines = text.substring(lineStart, lineEnd).split('\n');
    final marker = ordered ? RegExp(r'^\d+\. ') : RegExp(RegExp.escape(prefix));
    final all = lines.every((l) => marker.hasMatch(l));
    final out = [
      for (final (i, l) in lines.indexed)
        all
            ? l.replaceFirst(marker, '')
            : '${ordered ? '${i + 1}. ' : prefix}$l',
    ].join('\n');
    return TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, out),
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + out.length,
      ),
    );
  }

  /// Cycles the heading level of the caret line: none -> ## -> ### -> none.
  static TextEditingValue heading(TextEditingValue v) {
    final text = v.text, sel = _selection(v);
    final lineStart = sel.start == 0
        ? 0
        : text.lastIndexOf('\n', sel.start - 1) + 1;
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);
    final m = RegExp(r'^(#{1,6}) ').firstMatch(line);
    final level = m == null ? 0 : m[1]!.length;
    final next = level == 0 ? 2 : (level == 2 ? 3 : 0);
    final body = m == null ? line : line.substring(m[0]!.length);
    final out = next == 0 ? body : '${'#' * next} $body';
    return TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, out),
      selection: TextSelection.collapsed(offset: lineStart + out.length),
    );
  }

  static TextEditingValue codeBlock(TextEditingValue v) {
    final text = v.text, sel = _selection(v);
    final inner = sel.isCollapsed ? 'code' : text.substring(sel.start, sel.end);
    final lead = sel.start == 0 || text[sel.start - 1] == '\n' ? '' : '\n';
    final open = '$lead```\n';
    return TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, '$open$inner\n```\n'),
      selection: TextSelection(
        baseOffset: sel.start + open.length,
        extentOffset: sel.start + open.length + inner.length,
      ),
    );
  }

  static TextEditingValue link(TextEditingValue v) {
    final text = v.text, sel = _selection(v);
    final label = sel.isCollapsed
        ? 'link text'
        : text.substring(sel.start, sel.end);
    const url = 'https://';
    final next = '[$label]($url)';
    return TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, next),
      selection: TextSelection(
        baseOffset: sel.start + label.length + 3,
        extentOffset: sel.start + label.length + 3 + url.length,
      ),
    );
  }

  static TextEditingValue insert(TextEditingValue v, String snippet) {
    final sel = _selection(v);
    return TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, snippet),
      selection: TextSelection.collapsed(offset: sel.start + snippet.length),
    );
  }

  /// Inserts the trigger character [mark] (`@`, `#`) so the composer's
  /// suggestion list opens: a space goes before it unless the caret already
  /// follows whitespace or the start of the draft.
  static TextEditingValue trigger(TextEditingValue v, String mark) {
    final sel = _selection(v);
    final lead = sel.start == 0 || RegExp(r'\s').hasMatch(v.text[sel.start - 1])
        ? ''
        : ' ';
    return insert(v, '$lead$mark');
  }

  static const rule = '\n\n---\n\n';
  static const table = '\n| Column | Column |\n| --- | --- |\n|  |  |\n';
}

// ---------------------------------------------------------------------------
// Live-styled Markdown source. The text stays the source (markers visible and
// dimmed); only TextSpan styles change, never the characters or their count.
// Styling is skipped while an IME composition is active, so the composing
// range and its underline are exactly the platform's.
// ---------------------------------------------------------------------------

class RaftMarkdownEditingController extends RaftComposerEditingController {
  RaftMarkdownEditingController({super.text});

  /// Styling is on only while the expanded editor shows the draft; the inline
  /// composer keeps today's plain text.
  bool get styled => _styled;
  bool _styled = false;
  set styled(bool value) {
    if (_styled == value) return;
    _styled = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = value.composing.isValid && !value.composing.isCollapsed;
    if (!_styled || composing || style == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      children: _markdownSpans(text, style, RaftTokens.of(context)),
    );
  }
}

final _fenceLine = RegExp(r'^\s*(```|~~~)');
final _headingLine = RegExp(r'^(#{1,6})(\s+)(.*)$');
final _quoteLine = RegExp(r'^(\s*>+\s?)(.*)$');
final _listLine = RegExp(r'^(\s*(?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?)(.*)$');
final _inline = RegExp(
  r'(`[^`\n]+`)'
  r'|(\*\*[^*\n]+\*\*)'
  r'|(~~[^~\n]+~~)'
  r'|((?<![*\w])\*[^*\s][^*\n]*\*(?![*\w]))'
  r'|((?<![_\w])_[^_\s][^_\n]*_(?![_\w]))'
  r'|(\[[^\]\n]*\]\([^)\n]*\))'
  r'|(https?://[^\s]+)'
  r'|((?<![\w/@])@[\w.-]+)'
  r'|((?<![\w&#])#[\w-]+)',
);

List<InlineSpan> _markdownSpans(String text, TextStyle base, RaftTokens t) {
  final dim = t.colors['foreground-placeholder']!;
  final link = MessageContentSemantic(t).link;
  final quote = MessageContentSemantic(t).quote;
  final mono = base.copyWith(
    fontFamily: t.monoFont,
    fontFamilyFallback: null,
    backgroundColor: t.colors['fill-muted'],
  );
  TextSpan marker(String s, [TextStyle? over]) => TextSpan(
    text: s,
    style: (over ?? base).copyWith(color: dim),
  );

  List<InlineSpan> inline(String s, TextStyle style) {
    final out = <InlineSpan>[];
    var cursor = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > cursor) {
        out.add(TextSpan(text: s.substring(cursor, m.start), style: style));
      }
      final g = m[0]!;
      if (m[1] != null) {
        out
          ..add(marker('`', style))
          ..add(TextSpan(text: g.substring(1, g.length - 1), style: mono))
          ..add(marker('`', style));
      } else if (m[2] != null) {
        out
          ..add(marker('**', style))
          ..add(
            TextSpan(
              text: g.substring(2, g.length - 2),
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
          )
          ..add(marker('**', style));
      } else if (m[3] != null) {
        out
          ..add(marker('~~', style))
          ..add(
            TextSpan(
              text: g.substring(2, g.length - 2),
              style: style.copyWith(decoration: TextDecoration.lineThrough),
            ),
          )
          ..add(marker('~~', style));
      } else if (m[4] != null || m[5] != null) {
        final mark = g[0];
        out
          ..add(marker(mark, style))
          ..add(
            TextSpan(
              text: g.substring(1, g.length - 1),
              style: style.copyWith(fontStyle: FontStyle.italic),
            ),
          )
          ..add(marker(mark, style));
      } else if (m[6] != null) {
        final close = g.indexOf('](');
        out
          ..add(marker('[', style))
          ..add(
            TextSpan(
              text: g.substring(1, close),
              style: style.copyWith(color: link),
            ),
          )
          ..add(marker(g.substring(close), style));
      } else {
        out.add(
          TextSpan(
            text: g,
            style: style.copyWith(
              color: link,
              fontWeight: m[7] == null ? FontWeight.w600 : null,
            ),
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < s.length) {
      out.add(TextSpan(text: s.substring(cursor), style: style));
    }
    return out;
  }

  final spans = <InlineSpan>[];
  var fenced = false;
  final lines = text.split('\n');
  for (final (i, line) in lines.indexed) {
    final nl = i == lines.length - 1 ? '' : '\n';
    if (_fenceLine.hasMatch(line)) {
      fenced = !fenced;
      spans.add(
        TextSpan(
          text: line,
          style: mono.copyWith(color: dim),
        ),
      );
    } else if (fenced) {
      spans.add(TextSpan(text: line, style: mono));
    } else if (_headingLine.firstMatch(line) case final m?) {
      final style = base.copyWith(fontWeight: FontWeight.w700);
      spans
        ..add(marker('${m[1]}${m[2]}', style))
        ..addAll(inline(m[3]!, style));
    } else if (_quoteLine.firstMatch(line) case final m?) {
      spans
        ..add(marker(m[1]!))
        ..addAll(inline(m[2]!, base.copyWith(color: quote)));
    } else if (_listLine.firstMatch(line) case final m?) {
      spans
        ..add(marker(m[1]!, base.copyWith(fontWeight: FontWeight.w700)))
        ..addAll(inline(m[2]!, base));
    } else {
      spans.addAll(inline(line, base));
    }
    if (nl.isNotEmpty) spans.add(TextSpan(text: nl, style: base));
  }
  return spans;
}

/// Format shortcuts of the expanded editor: Ctrl/Cmd+B bold, I italic, K link,
/// Shift+X strikethrough. [apply] receives the operation to run on the draft.
Map<ShortcutActivator, VoidCallback> raftMarkdownShortcuts(
  void Function(TextEditingValue Function(TextEditingValue)) apply,
) => {
  for (final (key, shift, op)
      in <
        (LogicalKeyboardKey, bool, TextEditingValue Function(TextEditingValue))
      >[
        (
          LogicalKeyboardKey.keyB,
          false,
          (v) => RaftMarkdownFormat.wrap(v, '**'),
        ),
        (
          LogicalKeyboardKey.keyI,
          false,
          (v) => RaftMarkdownFormat.wrap(v, '*'),
        ),
        (LogicalKeyboardKey.keyK, false, RaftMarkdownFormat.link),
        (
          LogicalKeyboardKey.keyX,
          true,
          (v) => RaftMarkdownFormat.wrap(v, '~~'),
        ),
      ]) ...{
    SingleActivator(key, control: true, shift: shift): () => apply(op),
    SingleActivator(key, meta: true, shift: shift): () => apply(op),
  },
};
