import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// `// ignore:` and `// ignore_for_file:` directives naming `raft_lints/<rule>`,
/// with the same placement rules as the analyzer: a trailing comment covers its
/// own line, a comment on a line of its own covers the next line. An optional
/// ` -- reason` suffix is ignored.
class Ignores {
  Ignores._(this._fileWide, this._lines);

  factory Ignores.of(CompilationUnit unit, String content) {
    final fileWide = <String>{};
    final lines = <int, Set<String>>{};
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
        final names = <String>{
          for (final part in m.group(2)!.split(' -- ').first.split(','))
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
        lines.putIfAbsent(standalone ? line + 1 : line, () => {}).addAll(names);
      }
    }
    return Ignores._(fileWide, lines);
  }

  final Set<String> _fileWide;
  final Map<int, Set<String>> _lines;

  bool isIgnored(String rule, int line) =>
      _fileWide.contains(rule) || (_lines[line]?.contains(rule) ?? false);
}
