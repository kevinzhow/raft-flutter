import 'dart:math' as math;

import 'package:markdown/markdown.dart' as md;

import 'message_markdown.dart';
import 'message_ref_target.dart';

/// A reference is interactive only when its identity is supplied by the
/// current workspace projection. User text never supplies a target identity.
class RaftTextReference {
  const RaftTextReference({
    required this.text,
    required this.href,
    this.identityBacked = false,
    this.label,
  });
  final String text, href;
  final bool identityBacked;

  /// What the chip reads instead of [text]: Web shows a mention by the
  /// person's display name (`@Claude Assistant`), whatever handle was typed.
  final String? label;
}

/// What the message passes need besides the tree: the accepted reference
/// projection and the task resolvers. Web `MessageItem` builds the same set of
/// matchers (`messageRefsPlugin`).
class RaftTokenContext {
  const RaftTokenContext({
    this.references = const [],
    this.taskHref,
    this.knownTaskNumber,
    this.message = false,
  });
  final List<RaftTextReference> references;
  final String Function(int number)? taskHref;
  final bool Function(int number)? knownTaskNumber;

  /// Web `MessageItem`: also repairs generated Markdown and reads `<target>`
  /// refs.
  final bool message;

  bool get active => message || references.isNotEmpty || taskHref != null;
}

typedef _Match = ({int start, int end, String label, String href});

/// The identity-backed and free-text matches in [text] (Web's mention,
/// channel, thread, DM and task matchers), longest first at one start, none
/// overlapping.
List<_Match> _referenceMatches(String text, RaftTokenContext ctx) {
  final references = ctx.references;
  final taskHref = ctx.taskHref;
  final knownTaskNumber = ctx.knownTaskNumber;
  // Free-text `@name` handles the message can resolve (Web `isKnownHandle`).
  final knownHandles = {
    for (final r in references)
      if (r.text.startsWith('@') && r.text.length > 1) r.text.substring(1),
  };
  final matches = <_Match>[];

  for (final ref in references) {
    if (ref.text.isEmpty) continue;
    final pattern = RegExp(RegExp.escape(ref.text));
    for (final m in pattern.allMatches(text)) {
      final left = m.start == 0 ? '' : text.substring(m.start - 1, m.start);
      final right = m.end == text.length
          ? ''
          : text.substring(m.end, m.end + 1);
      // Conservative free-text grammar also protects emails and longer names.
      if (!ref.identityBacked &&
          left.isNotEmpty &&
          RegExp(r'[\p{L}\p{N}_@/]', unicode: true).hasMatch(left)) {
        continue;
      }
      final next = m.end == text.length
          ? ''
          : String.fromCharCode(
              text
                  .substring(m.end, math.min(m.end + 2, text.length))
                  .runes
                  .first,
            );
      if (next.isNotEmpty &&
          _handleContinuation.hasMatch(next) &&
          !_raftMentionBoundaryAllowed(
            ref,
            text,
            m.start,
            next,
            knownHandles,
          )) {
        continue;
      }
      if (right == '.' &&
          m.end + 1 < text.length &&
          RegExp(
            r'[\p{L}\p{N}_]',
            unicode: true,
          ).hasMatch(text.substring(m.end + 1, m.end + 2))) {
        continue;
      }
      if (ref.text.startsWith('@') &&
          (right == '~' || text.substring(0, m.start).endsWith('dm:'))) {
        continue;
      }
      // `#chan:shortId` / `dm:@peer:shortId` belong to the thread-ref
      // pass (Web runs it first); a plain `#design:` is still a channel.
      if ((ref.text.startsWith('#') || ref.text.startsWith('dm:')) &&
          (right == '~' ||
              (right == ':' &&
                  RegExp(
                    r'^:[0-9a-f]{6,8}(?![0-9a-z])',
                    caseSensitive: false,
                  ).hasMatch(text.substring(m.end))))) {
        continue;
      }
      matches.add((
        start: m.start,
        end: m.end,
        label: ref.label ?? m[0]!,
        href: ref.href,
      ));
    }
  }
  if (taskHref != null) {
    // Web createRaftBareTaskRefRegex: `task #N` always, bare `#N` only for
    // a known task.
    for (final m in RegExp(
      r'(?:^|(?<=[^\w/]))(task\s+)?#([1-9][0-9]*)\b',
      caseSensitive: false,
    ).allMatches(text)) {
      final number = int.parse(m[2]!);
      if (m[1] == null && !(knownTaskNumber?.call(number) ?? false)) {
        continue;
      }
      final start = m.end - m[2]!.length - 1;
      matches.add((
        start: start,
        end: m.end,
        label: '#${m[2]}',
        href: taskHref(number),
      ));
    }
  }
  matches.sort(
    (a, b) => a.start != b.start
        ? a.start.compareTo(b.start)
        : b.end.compareTo(a.end),
  );
  final result = <_Match>[];
  var cursor = 0;
  for (final m in matches) {
    if (m.start < cursor) continue;
    result.add(m);
    cursor = m.end;
  }
  return result;
}

final _handleContinuation = RegExp(r'[\p{L}\p{N}_-]', unicode: true);
final _cjkSuffixStart = RegExp(
  r'^[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
  unicode: true,
);
final _nonCjkHandleEnd = RegExp(r'[\p{Script=Latin}\p{N}_-]$', unicode: true);

/// Web `resolveRaftMentionHandle`: resolve a free-text mention [token] (the
/// run of letters, digits, `_` and `-` after `@`) against known handles. An
/// exact match wins. Otherwise the token is split only where the writing
/// system changes, a Latin letter, digit, `_` or `-` followed by Han, kana or
/// hangul (`@ops的`, `@opsさん`, `@ops와`); nothing is guessed inside one
/// script. A split that is a guess (two valid splits, or a longer known name
/// that is also a prefix of the token) stays unresolved. Returns the handle
/// and the glued suffix, or null.
({String handle, String suffix})? raftResolveMentionHandle(
  String token,
  bool Function(String handle) isKnownHandle,
) {
  if (isKnownHandle(token)) return (handle: token, suffix: '');
  final chars = token.runes.map(String.fromCharCode).toList();
  final splits = <({int length, String handle, String suffix})>[];
  for (var length = 1; length < chars.length; length += 1) {
    final handle = chars.sublist(0, length).join();
    final suffix = chars.sublist(length).join();
    if (!_nonCjkHandleEnd.hasMatch(handle)) continue;
    if (!_cjkSuffixStart.hasMatch(suffix)) continue;
    if (isKnownHandle(handle)) {
      splits.add((length: length, handle: handle, suffix: suffix));
    }
  }
  // `ops` and `ops君a` for `@ops君a的`: two members fit, so the split is a guess.
  if (splits.length != 1) return null;
  final split = splits.single;
  // A longer member name also fits (`ops` and `ops君` for `@ops君的`).
  for (var longer = split.length + 1; longer < chars.length; longer += 1) {
    if (isKnownHandle(chars.sublist(0, longer).join())) return null;
  }
  return (handle: split.handle, suffix: split.suffix);
}

/// Whether a reference may end right before [next], a character that would
/// otherwise continue the handle. A composer-resolved (identity-backed)
/// mention may be followed by Han, kana or hangul (`@Mona的`), never by Latin
/// letters, digits, `_` or `-`. Free text resolves through
/// [raftResolveMentionHandle].
bool _raftMentionBoundaryAllowed(
  RaftTextReference ref,
  String text,
  int start,
  String next,
  Set<String> knownHandles,
) {
  if (!ref.text.startsWith('@')) return false;
  if (ref.identityBacked) return _cjkSuffixStart.hasMatch(next);
  final token = RegExp(
    r'^[\p{L}\p{N}_-]+',
    unicode: true,
  ).firstMatch(text.substring(start + 1))?[0];
  if (token == null) return false;
  return raftResolveMentionHandle(token, knownHandles.contains)?.handle ==
      ref.text.substring(1);
}

/// A stretch of text while the passes run: its value and which characters
/// were written as backslash escapes.
class _Piece {
  _Piece(this.value, [Set<int>? escaped]) : escaped = escaped ?? {};
  final String value;
  final Set<int> escaped;

  _Piece slice(int from, int to) => _Piece(value.substring(from, to), {
    for (final i in escaped)
      if (i >= from && i < to) i - from,
  });
}

/// Tags whose text no pass touches: code, links (a ref the passes made is a
/// link too) and a search mark.
const _skippedTags = {'a', 'code', 'pre', 'mark'};

final _literalNewline = RegExp(r'\\n');
final _strongWithSpace = RegExp(r'\*\*([^*\n]*?\S)([ \t]+)\*\*');
final _angleTarget = RegExp(r'<([^<>\n]+)>');
final _dmBefore = RegExp(r'dm:@[\w.-]+$');

/// Runs Web's message passes over [nodes], a freshly parsed tree, in place:
/// `unwrapDmKindStrikethrough`, link refs, `repairGeneratedMarkdown` and the
/// `remarkMessageTokens` matchers. Code, links and escapes are skipped because
/// the tree already knows where they are.
List<md.Node> raftApplyMessageTokens(
  List<md.Node> nodes,
  RaftTokenContext ctx,
) {
  if (!ctx.active) return nodes;
  return _TokenPass(ctx).children(nodes);
}

class _TokenPass {
  _TokenPass(this.ctx);
  final RaftTokenContext ctx;
  late final Map<String, RaftTextReference> byText = {
    for (final r in ctx.references) r.text: r,
  };
  late final Map<String, RaftTextReference> byLowerText = {
    for (final r in ctx.references) r.text.toLowerCase(): r,
  };

  /// The link and label for [target], or null (Web renders a plain span).
  (String, String)? refFor(RaftRefTarget target) {
    if (target.kind == RaftRefKind.task) {
      final href = ctx.taskHref?.call(target.taskNumber!);
      return href == null ? null : (href, target.text);
    }
    final ref = byText[target.text] ?? byLowerText[target.text.toLowerCase()];
    return ref == null ? null : (ref.href, ref.label ?? target.text);
  }

  md.Node refNode(String href, String label) =>
      md.Element('a', [RaftClaimedText(label)])..attributes['href'] = href;

  List<md.Node> children(List<md.Node> input) {
    final mapped = <md.Node>[];
    for (final node in input) {
      if (node is md.Element) {
        if (ctx.message && node.tag == 'del') {
          final prev = mapped.isEmpty ? null : mapped.last;
          if (node.attributes[raftSingleTildeAttribute] == '1' &&
              prev is md.Text &&
              prev is! RaftClaimedText &&
              _dmBefore.hasMatch(prev.text)) {
            mapped
              ..add(md.Text('~'))
              ..addAll(children(node.children ?? const <md.Node>[]))
              ..add(md.Text('~'));
            continue;
          }
        }
        if (ctx.message &&
            node.tag == 'a' &&
            node.attributes[raftAngleLinkAttribute] == '1') {
          final replaced = _angleLink(node);
          if (replaced != null) {
            mapped.add(replaced);
            continue;
          }
        }
        if (node.children != null) {
          mapped.add(
            raftCopyElement(
              node,
              _skippedTags.contains(node.tag)
                  ? _stripMarks(node.children!)
                  : children(node.children!),
            ),
          );
          continue;
        }
      }
      mapped.add(node);
    }
    // Text in one parent is joined first so a token is not missed because the
    // parser split it in two.
    final out = <md.Node>[];
    var run = <md.Text>[];
    void flush() {
      if (run.isEmpty) return;
      out.addAll(_textRun(run));
      run = [];
    }

    for (final node in mapped) {
      if (node is md.Text && node is! RaftClaimedText) {
        run.add(node);
      } else {
        flush();
        out.add(node);
      }
    }
    flush();
    return out;
  }

  /// The escape marks in a subtree no pass reads (code, link labels).
  List<md.Node> _stripMarks(List<md.Node> nodes) => [
    for (final node in nodes)
      if (node is md.Text)
        md.Text(raftStripEscapeMarks(node.text))
      else if (node is md.Element && node.children != null)
        raftCopyElement(node, _stripMarks(node.children!))
      else
        node,
  ];

  /// `[label](<target>)` and `<scheme:target>`: the parser made these links;
  /// only the angle-bracket forms are refs. A target no projection resolves is
  /// its label as plain text.
  md.Node? _angleLink(md.Element link) {
    final href = link.attributes['href'];
    final target = href == null ? null : raftParseRefTarget(href);
    if (target == null ||
        target.kind == RaftRefKind.computer ||
        target.kind == RaftRefKind.app) {
      return null;
    }
    final autolink =
        link.children?.length == 1 &&
        link.children!.single is md.Text &&
        link.children!.single.textContent == href;
    final resolved = refFor(target);
    final label = autolink
        ? resolved?.$2 ?? target.text
        : raftStripEscapeMarks(link.textContent);
    return resolved == null
        ? RaftClaimedText(label)
        : refNode(resolved.$1, label);
  }

  List<md.Node> _textRun(List<md.Text> run) {
    final buffer = StringBuffer();
    final escaped = <int>{};
    for (final text in run) {
      final value = text.text;
      if (!value.contains(raftEscapeMark)) {
        buffer.write(value);
        continue;
      }
      for (var i = 0; i < value.length; i++) {
        if (value[i] == raftEscapeMark) {
          escaped.add(buffer.length);
        } else {
          buffer.write(value[i]);
        }
      }
    }
    var pieces = <Object>[_Piece(buffer.toString(), escaped)];
    if (ctx.message) {
      pieces = _merge(_apply(pieces, _literalNewlines));
      pieces = _apply(pieces, _strongs);
      pieces = _apply(pieces, _angleRefs);
    }
    pieces = _apply(pieces, _references);
    return [
      for (final p in pieces)
        if (p is _Piece) md.Text(p.value) else p as md.Node,
    ];
  }

  List<Object> _apply(
    List<Object> pieces,
    List<Object>? Function(_Piece) stage,
  ) {
    final out = <Object>[];
    for (final p in pieces) {
      final replaced = p is _Piece ? stage(p) : null;
      if (replaced == null) {
        out.add(p);
      } else {
        out.addAll(replaced);
      }
    }
    return out;
  }

  List<Object> _merge(List<Object> pieces) {
    final out = <Object>[];
    for (final p in pieces) {
      if (p is _Piece && out.isNotEmpty && out.last is _Piece) {
        final prev = out.removeLast() as _Piece;
        out.add(
          _Piece(prev.value + p.value, {
            ...prev.escaped,
            for (final i in p.escaped) i + prev.value.length,
          }),
        );
      } else {
        out.add(p);
      }
    }
    return out;
  }

  /// Splits [p] at each match [replace] accepts; null when none is.
  List<Object>? _split(
    _Piece p,
    RegExp pattern,
    List<Object>? Function(RegExpMatch match, bool escaped) replace,
  ) {
    final out = <Object>[];
    var cursor = 0;
    var changed = false;
    for (final m in pattern.allMatches(p.value)) {
      if (m.end == m.start) continue;
      final replacement = replace(m, p.escaped.contains(m.start));
      if (replacement == null) continue;
      if (m.start > cursor) out.add(p.slice(cursor, m.start));
      out.addAll(replacement);
      cursor = m.end;
      changed = true;
    }
    if (!changed) return null;
    if (cursor < p.value.length) out.add(p.slice(cursor, p.value.length));
    return out;
  }

  /// A literal backslash-n (as some LLM output arrives) becomes a newline.
  List<Object>? _literalNewlines(_Piece p) =>
      _split(p, _literalNewline, (_, _) => [_Piece('\n')]);

  /// `- **Registration: **203 users`: CommonMark does not let the space before
  /// `**` close the strong span; make it the strong span the writer meant.
  List<Object>? _strongs(_Piece p) => _split(p, _strongWithSpace, (m, escaped) {
    if (escaped) return null;
    final strong = md.Element('strong', children([md.Text(m[1]!)]));
    return [strong, _Piece(m[2]!)];
  });

  /// `<target>`: `\<target>` is the escape; it stays literal text and no later
  /// matcher may claim part of it.
  List<Object>? _angleRefs(_Piece p) => _split(p, _angleTarget, (m, escaped) {
    final target = raftParseRefTarget(m[1]!);
    if (target == null) return null;
    if (escaped) return [RaftClaimedText(m[0]!)];
    if (target.kind == RaftRefKind.computer || target.kind == RaftRefKind.app) {
      return null;
    }
    final resolved = refFor(target);
    return [
      resolved == null
          ? RaftClaimedText(target.text)
          : refNode(resolved.$1, resolved.$2),
    ];
  });

  List<Object>? _references(_Piece p) {
    if (ctx.references.isEmpty && ctx.taskHref == null) return null;
    final matches = _referenceMatches(p.value, ctx);
    if (matches.isEmpty) return null;
    final out = <Object>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) out.add(p.slice(cursor, m.start));
      out.add(refNode(m.href, m.label));
      cursor = m.end;
    }
    if (cursor < p.value.length) out.add(p.slice(cursor, p.value.length));
    return out;
  }
}
