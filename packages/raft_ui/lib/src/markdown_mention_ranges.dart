import 'package:markdown/markdown.dart' as md;

import 'markdown_math.dart';
import 'message_markdown.dart';
import 'message_ref_target.dart';

final _handle = RegExp(r'^[\p{L}\p{N}_-]+$', unicode: true);
const _cjk =
    r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]';
final _escapedAngle = RegExp(
  '$raftEscapeMark<@[\\p{L}\\p{N}_-]+>',
  unicode: true,
);
final _bareWebUrl = RegExp(r'https?://[^\s<>]+');
final _mentionContinuation = RegExp('(?!$_cjk)[\\p{L}\\p{N}_-]', unicode: true);

bool raftStructuredMentionAppears(String text, String name) =>
    raftStructuredMentionMatcher(text)(name);

bool Function(String) raftStructuredMentionMatcher(String text) {
  late final nodes = raftParseMarkdown(text, RaftMarkdownMode.message);
  return (name) {
    final mention = '@$name';
    if (!text.contains(mention) || !_handle.hasMatch(name)) return false;

    bool appears(md.Node node) {
      if (node is md.Text) {
        final visible = node.text
            .replaceAll(_escapedAngle, '')
            .replaceAll(_bareWebUrl, ' ');
        var start = visible.indexOf(mention);
        while (start >= 0) {
          final end = start + mention.length;
          if (_mentionContinuation.matchAsPrefix(visible, end) == null) {
            return true;
          }
          start = visible.indexOf(mention, end);
        }
        return false;
      }
      if (node is! md.Element) return false;
      switch (node.tag) {
        case 'a':
          final target = raftParseRefTarget(node.attributes['href'] ?? '');
          return node.attributes[raftAngleLinkAttribute] == '1' &&
              target?.kind == RaftRefKind.user &&
              target?.text == '@$name';
        case 'blockquote':
        case 'pre':
        case 'code':
        case 'img':
        case raftMathDisplayTag:
          return false;
        default:
          return node.children?.any(appears) ?? false;
      }
    }

    return nodes.any(appears);
  };
}
