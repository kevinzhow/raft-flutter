import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// `// ignore:` and `// ignore_for_file:` directives naming `raft_lints/<rule>`,
/// with the same placement rules as the analyzer: a trailing comment covers its
/// own line, a comment on a line of its own covers the next line. The text
/// after the first ` -- ` is the reason, kept for rules that check it.
class Ignores {
  Ignores._(this._fileWide, this._lines);

  factory Ignores.of(CompilationUnit unit, String content) {
    final fileWide = <String>{};
    final lines = <int, Map<String, String>>{};
    final lineInfo = unit.lineInfo;
    final directive = RegExp(r'^//\s*(ignore|ignore_for_file)\s*:\s*(.*)$');
    for (
      Token? t = unit.beginToken;
      t != null;
      t = t.type == TokenType.EOF ? null : t.next
    ) {
      for (Token? c = t.precedingComments; c != null; c = c.next) {
        final m = directive.firstMatch(c.lexeme);
        if (m == null) continue;
        final body = m.group(2)!;
        final split = body.indexOf(' -- ');
        final reason = split < 0 ? '' : body.substring(split + 4).trim();
        final names = <String>{
          for (final part
              in (split < 0 ? body : body.substring(0, split)).split(','))
            if (part.trim().startsWith('raft_lints/'))
              part.trim().substring('raft_lints/'.length),
        };
        if (names.isEmpty) continue;
        if (m.group(1) == 'ignore_for_file') {
          fileWide.addAll(names);
          continue;
        }
        final line = lineInfo.getLocation(c.offset).lineNumber;
        final lineStart = lineInfo.getOffsetOfLine(line - 1);
        final standalone = content
            .substring(lineStart, c.offset)
            .trim()
            .isEmpty;
        final rules = lines.putIfAbsent(standalone ? line + 1 : line, () => {});
        for (final name in names) {
          rules[name] = reason;
        }
      }
    }
    return Ignores._(fileWide, lines);
  }

  final Set<String> _fileWide;
  final Map<int, Map<String, String>> _lines;

  bool isIgnored(String rule, int line) =>
      _fileWide.contains(rule) || (_lines[line]?.containsKey(rule) ?? false);

  /// The reason of the `// ignore:` covering [line] for [rule] (`''` when it
  /// has none), or null when no line-level ignore covers it.
  String? lineReason(String rule, int line) => _lines[line]?[rule];
}
