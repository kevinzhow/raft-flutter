import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'checks.dart';

/// Rule name (also the `// ignore: raft_lints/<name>` key).
const offGridSpacingRule = 'off_grid_spacing';

const offGridSpacingMessage =
    'This spacing value is not on the Web spacing grid (Tailwind '
    '--spacing: 0.25rem, so every step is a multiple of 2px: 2, 4, 6, 8, 10, '
    '12, 14, 16, 20, 24, 28, 32 ...).';
const offGridSpacingCorrection =
    "Use the Web class's grid step (RaftSpace.*); or, only when Web really "
    'uses that exact value, write '
    "'// ds-allow: Web <file> <class>' naming the Web source on the same line "
    'or the line above.';

/// Named arguments that carry a gap between siblings (`Row` / `Column` /
/// `Wrap` / `Flex` / `GridView` and raft_ui gap parameters).
const gapArguments = {
  'spacing',
  'runSpacing',
  'gap',
  'rowGap',
  'columnGap',
  'mainAxisSpacing',
  'crossAxisSpacing',
};

const _insetClasses = {'EdgeInsets', 'EdgeInsetsDirectional'};
const _insetNamed = {
  'horizontal',
  'vertical',
  'left',
  'top',
  'right',
  'bottom',
  'start',
  'end',
};

/// `// ds-allow: Web <file> <class>`: names the Web source file and the class
/// (or value) that fixes this exact number.
final _webAllow = RegExp(r'^//\s*ds-allow:\s*Web\s+\S+\s+\S+');

/// Whether [value] sits on the grid: 0 or a multiple of 2.
bool onGrid(double value) {
  final v = value.abs();
  return v == 0 || v % 2 == 0;
}

/// Numeric literals that are a spacing value directly: `8`, `-4`, `(6)`,
/// `a ? 8 : 5`. Arithmetic over tokens is not a literal and is skipped.
Iterable<Expression> _literals(Expression e) sync* {
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  switch (e) {
    case IntegerLiteral() || DoubleLiteral():
      yield e;
    case PrefixExpression(:final operator, :final operand)
        when operator.lexeme == '-':
      yield* _literals(operand);
    case ConditionalExpression(:final thenExpression, :final elseExpression):
      yield* _literals(thenExpression);
      yield* _literals(elseExpression);
    default:
      break;
  }
}

double? _numberOf(Expression e) {
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  return switch (e) {
    IntegerLiteral() => e.value?.toDouble(),
    DoubleLiteral() => e.value,
    PrefixExpression(:final operand) => _numberOf(operand),
    _ => null,
  };
}

/// Expressions in a spacing position of [node]: the EdgeInsets arguments, the
/// `width` / `height` of a child-less `SizedBox` (a spacer), and gap-like
/// named arguments.
Iterable<Expression> spacingExpressions(AstNode node) sync* {
  if (node is InstanceCreationExpression) {
    final element = node.constructorName.element;
    if (element == null ||
        !element.library.uri.toString().startsWith('package:flutter/')) {
      return;
    }
    final name = element.enclosingElement.name;
    final ctor = node.constructorName.name?.name;
    if (_insetClasses.contains(name)) {
      for (final a in node.argumentList.arguments) {
        if (a is NamedArgument) {
          if (_insetNamed.contains(a.name.lexeme)) yield a.argumentExpression;
        } else if (ctor == 'all' || ctor == 'fromLTRB' || ctor == 'fromSTEB') {
          yield a as Expression;
        }
      }
    } else if (name == 'SizedBox' && ctor == null) {
      final hasChild = node.argumentList.arguments.any(
        (a) => a is NamedArgument && a.name.lexeme == 'child',
      );
      if (hasChild) return;
      for (final a in node.argumentList.arguments) {
        if (a is NamedArgument &&
            (a.name.lexeme == 'width' || a.name.lexeme == 'height')) {
          yield a.argumentExpression;
        }
      }
    }
  } else if (node is NamedArgument && gapArguments.contains(node.name.lexeme)) {
    yield node.argumentExpression;
  }
}

/// A spacing literal in [node] that is not 0 or a multiple of 2 and is not
/// covered by a `// ds-allow: Web <file> <class>` comment.
///
/// [onValue] sees every spacing literal (on or off the grid, cited or not);
/// `bin/check.dart` uses it for the inventory counts.
void checkOffGridSpacing(
  AstNode node,
  Report report, {
  void Function(double value, bool cited)? onValue,
}) {
  for (final expression in spacingExpressions(node)) {
    for (final literal in _literals(expression)) {
      final value = _numberOf(literal);
      if (value == null) continue;
      final off = !onGrid(value);
      if (!off && onValue == null) continue;
      final cited = off && _isCited(literal, node);
      onValue?.call(value, cited);
      if (off && !cited) report(offGridSpacingRule, literal);
    }
  }
}

final _citationLines = Expando<Set<int>>('webAllowLines');

/// Whether a Web `ds-allow` comment covers the literal's line, the line where
/// the spacing call starts, or the line of the enclosing named argument /
/// variable / return (a standalone comment covers the line after it; a
/// trailing comment covers its own line).
bool _isCited(AstNode literal, AstNode call) {
  final unit = literal.root;
  if (unit is! CompilationUnit) return false;
  final lines = _citationLines[unit] ??= _collectCitationLines(unit);
  if (lines.isEmpty) return false;
  int lineOf(AstNode n) => unit.lineInfo.getLocation(n.offset).lineNumber;
  final candidates = {lineOf(literal), lineOf(call)};
  for (var n = call.parent; n != null; n = n.parent) {
    if (n is NamedArgument ||
        n is VariableDeclaration ||
        n is ReturnStatement) {
      candidates.add(lineOf(n));
      break;
    }
  }
  return candidates.any(lines.contains);
}

Set<int> _collectCitationLines(CompilationUnit unit) {
  final lines = <int>{};
  final lineInfo = unit.lineInfo;
  for (
    Token? t = unit.beginToken;
    t != null;
    t = t.type == TokenType.EOF ? null : t.next
  ) {
    for (Token? c = t.precedingComments; c != null; c = c.next) {
      if (!_webAllow.hasMatch(c.lexeme)) continue;
      final line = lineInfo.getLocation(c.offset).lineNumber;
      final previous = t.previous;
      final standalone =
          previous == null ||
          previous.type == TokenType.EOF ||
          lineInfo.getLocation(previous.end).lineNumber < line;
      lines.add(standalone ? line + 1 : line);
    }
  }
  return lines;
}
