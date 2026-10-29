import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'banned_apis.dart';
import 'error_leak.dart';
import 'notice_state.dart';
import 'off_grid_spacing.dart';
import 'resource_release.dart';
import 'render_scope.dart';
import 'text_scale.dart';

/// Rule names (also the `// ignore: raft_lints/<name>` keys).
const indexAssertionRule = 'avoid_render_index_assertion';
const singleRule = 'avoid_render_single';
const whereRule = 'avoid_render_where_without_or_else';

/// Message texts, shared by the plugin rules and the command-line runner.
const indexAssertionMessage =
    'Map-index null assertion in render code. State that async loading or '
    'server data can leave partial turns this into a red screen.';
const indexAssertionCorrection =
    'Publish state atomically, render a loading/fallback state, or add '
    "'// ignore: raft_lints/$indexAssertionRule -- <why it cannot be absent>'.";
const singleMessage =
    "'.single' in render code throws unless there is exactly one element.";
const singleCorrection =
    "Use 'firstOrNull' or a length check, or add "
    "'// ignore: raft_lints/$singleRule -- <why>'.";
const whereMessage =
    "'firstWhere' / 'lastWhere' / 'singleWhere' without 'orElse' in render "
    'code throws when nothing matches.';
const whereCorrection =
    "Pass 'orElse', use 'firstWhereOrNull', or add "
    "'// ignore: raft_lints/$whereRule -- <why>'.";

/// Reports [node] for the rule called [rule].
typedef Report = void Function(String rule, AstNode node);

/// `expr[key]!` inside render code. Exempt: an integer-literal index (a
/// RegExpMatch group or fixed tuple slot) and a lookup in the generated theme
/// token map (`RaftTokens.colors`).
void checkIndexAssertion(PostfixExpression node, Report report) {
  if (node.operator.type != TokenType.BANG) return;
  var operand = node.operand;
  while (operand is ParenthesizedExpression) {
    operand = operand.expression;
  }
  if (operand is! IndexExpression) return;
  if (operand.index is IntegerLiteral) return;
  if (_isThemeTokenLookup(operand)) return;
  if (!isInRenderCode(node)) return;
  report(indexAssertionRule, node);
}

bool _isThemeTokenLookup(IndexExpression index) {
  final target = index.realTarget;
  final element = elementOf(target);
  if (element == null || element.name != 'colors') return false;
  final owner = element.enclosingElement;
  return owner is InterfaceElement && owner.name == 'RaftTokens';
}

/// `.single` on an SDK iterable inside render code.
void checkSingle(AstNode node, SimpleIdentifier property, Report report) {
  if (property.name != 'single') return;
  final element = property.element;
  if (element is! GetterElement) return;
  if (!element.library.isInSdk) return;
  if (!isInRenderCode(node)) return;
  report(singleRule, property);
}

/// `firstWhere` / `lastWhere` / `singleWhere` on an SDK iterable without
/// `orElse:` inside render code.
void checkWhere(MethodInvocation node, Report report) {
  final name = node.methodName.name;
  if (name != 'firstWhere' && name != 'lastWhere' && name != 'singleWhere') {
    return;
  }
  final element = node.methodName.element;
  if (element is! MethodElement || !element.library.isInSdk) return;
  final hasOrElse = node.argumentList.arguments.any(
    (a) => a is NamedArgument && a.name.lexeme == 'orElse',
  );
  if (hasOrElse) return;
  if (!isInRenderCode(node)) return;
  report(whereRule, node.methodName);
}

/// Runs every check over a resolved unit (used by the command-line runner;
/// the plugin registers the same functions per node type instead).
class AllChecksVisitor extends RecursiveAstVisitor<void> {
  AllChecksVisitor(this.report, {required String path, this.onSpacingValue})
    : _errorLeakScope = errorLeakScope(path),
      _fixedHeightScope = !isLegacyFixedHeightTextFile(path);
  final Report report;

  /// Sees every spacing literal (inventory counts in bin/check.dart).
  final void Function(double value, bool cited)? onSpacingValue;
  final bool _errorLeakScope;
  final bool _fixedHeightScope;

  @override
  void visitPostfixExpression(PostfixExpression node) {
    checkIndexAssertion(node, report);
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    checkSingle(node, node.identifier, report);
    checkBannedApi(node, node.identifier.element, report);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    checkSingle(node, node.propertyName, report);
    checkBannedApi(node, node.propertyName.element, report);
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    checkWhere(node, report);
    if (_errorLeakScope) checkNoticeSetter(node, report);
    checkBannedApi(node.methodName, node.methodName.element, report);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    checkBannedApi(node, node.constructorName.element, report);
    if (_fixedHeightScope) checkFixedHeightText(node, report);
    checkOffGridSpacing(node, report, onValue: onSpacingValue);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitNamedType(NamedType node) {
    checkBannedTypeName(node, report);
    super.visitNamedType(node);
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    checkResourceRelease(node, report);
    super.visitCompilationUnit(node);
  }

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    if (_errorLeakScope) checkNoticeField(node, report);
    super.visitVariableDeclarationList(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (_errorLeakScope) checkCaughtException(node, report);
    super.visitCatchClause(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (_errorLeakScope) checkCaughtException(node, report);
    super.visitFunctionExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    checkTextScaleFactorReference(node, report);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    checkBannedNamedArgument(node, report);
    checkTextScaleFactorArgument(node, report);
    checkPixelTextHeight(node, report);
    checkOffGridSpacing(node, report, onValue: onSpacingValue);
    super.visitNamedArgument(node);
  }
}
