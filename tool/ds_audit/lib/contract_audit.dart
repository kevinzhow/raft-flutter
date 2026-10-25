/// Theme-contract scan for packages/raft_ui/lib (docs/theme-contract.md 7.3).
///
/// Components read only the theme pack. This visitor counts what bypasses it:
/// literal colours, font sizes, radii and stroke widths, branches on the theme
/// name, and direct use of the legacy two-valued `RaftRecipeTheme`. Decisions
/// come from resolved elements, never from source text. The exact rule of each
/// category is documented in docs/ds-migration.md ("Audit rules").
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'ds_audit.dart';

/// Category names, in the order they are documented.
const String categoryColor = 'contract.color_literal';
const String categoryFontSize = 'contract.font_size_literal';
const String categoryRadius = 'contract.radius_literal';
const String categoryStroke = 'contract.stroke_width_literal';
const String categoryThemeName = 'contract.theme_name_branch';
const String categoryLegacyRecipe = 'contract.legacy_recipe_theme';

/// Informational, never enforced: `const` variables in generated recipe files.
const String categoryGeneratedRecipeConstants = 'generated.recipe_constants';

/// Classes whose `id`/`name` is a theme name when compared.
const Set<String> themeHolderClasses = {
  'RaftThemePack',
  'RaftTokenSet',
  'RaftTokens',
  'RaftTheme',
};

/// Members whose value is a theme name (compared with `==`/`!=`/`switch`).
const Set<String> themeNameMembers = {
  'themeId',
  'packId',
  'builtInRaftThemeId',
  'raftThemePackId',
};

/// The only function allowed to pick a `RaftRecipeTheme` constant from tokens.
const String recipeThemeAdapter = 'raftRecipeTheme';

bool isGeneratedFile(String path) => path.endsWith('.g.dart');

/// Generated files whose `const` variables are counted (recipe tables).
bool isGeneratedRecipeFile(String path) =>
    isGeneratedFile(path) && path.contains('/recipes/');

/// Files that implement the recipe runtime itself may name the legacy enum.
bool isRecipeRuntimeFile(String path) => path.contains('/src/recipes/');

/// Counts `const` variables a generated recipe file declares: top-level
/// `const` variables and `static const` fields. Enum constants are not
/// counted.
int countGeneratedRecipeConstants(CompilationUnit unit) {
  var count = 0;
  for (final declaration in unit.declarations) {
    if (declaration is TopLevelVariableDeclaration &&
        declaration.variables.isConst) {
      count += declaration.variables.variables.length;
    } else if (declaration is ClassDeclaration) {
      final body = declaration.body;
      if (body is! BlockClassBody) continue;
      for (final member in body.members) {
        if (member is FieldDeclaration && member.fields.isConst) {
          count += member.fields.variables.length;
        }
      }
    }
  }
  return count;
}

num? _literalValue(AstNode node) => switch (node) {
  IntegerLiteral(:final value) => value,
  DoubleLiteral(:final value) => value,
  _ => null,
};

/// Geometry arithmetic the contract allows: `/ 2`, `* 2`, `+ 1`, `- 1`, `-1`.
bool _isGeometryArithmetic(Expression literal) {
  final value = _literalValue(literal);
  final parent = literal.parent;
  if (parent is BinaryExpression) {
    final type = parent.operator.type;
    final isRight = identical(parent.rightOperand, literal);
    if (value == 2 &&
        (type == TokenType.SLASH ||
            type == TokenType.TILDE_SLASH ||
            type == TokenType.STAR)) {
      return type == TokenType.STAR || isRight;
    }
    if (value == 1 && (type == TokenType.MINUS)) return isRight;
    if (value == 1 && (type == TokenType.PLUS)) return true;
  }
  return parent is PrefixExpression &&
      parent.operator.type == TokenType.MINUS &&
      value == 1;
}

/// True when [node] contains a numeric literal that is not allowed geometry
/// arithmetic, outside closures and index expressions.
bool containsContractLiteral(AstNode node) {
  final finder = _ContractLiteralFinder();
  node.accept(finder);
  return finder.found;
}

class _ContractLiteralFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    if (!_isGeometryArithmetic(node)) found = true;
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    if (!_isGeometryArithmetic(node)) found = true;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitIndexExpression(IndexExpression node) => node.target?.accept(this);
}

bool _isFlutterPainting(Element? e) =>
    e?.library?.uri.toString().startsWith('package:flutter/src/painting/') ??
    false;

String? _className(Element? e) => e is InterfaceElement ? e.name : null;

/// Collects theme-contract findings from one resolved compilation unit.
class ContractAuditVisitor extends AuditVisitorBase {
  ContractAuditVisitor(super.relativePath, super.unit);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final cls = node.constructorName.element?.enclosingElement;
    if (cls is InterfaceElement) _checkCreation(node, cls);
    super.visitInstanceCreationExpression(node);
  }

  void _checkCreation(InstanceCreationExpression node, InterfaceElement cls) {
    final name = cls.name ?? '';
    final ctor = node.constructorName.name?.name;
    final display = ctor == null ? name : '$name.$ctor';
    final library = cls.library.uri.toString();
    final args = node.argumentList.arguments;
    if (name == 'Color' && library == 'dart:ui') {
      if (args.any(containsContractLiteral)) add(node, categoryColor, display);
    } else if ((name == 'BorderRadius' || name == 'BorderRadiusDirectional') &&
        _isFlutterPainting(cls)) {
      if (ctor == 'circular' && args.any(containsContractLiteral)) {
        add(node, categoryRadius, display);
      }
    } else if (name == 'Radius' && library == 'dart:ui') {
      if ((ctor == 'circular' || ctor == 'elliptical') &&
          args.any(containsContractLiteral)) {
        add(node, categoryRadius, display);
      }
    } else if (_isFlutterPainting(cls) &&
        (name == 'BorderSide' || (name == 'Border' && ctor == 'all'))) {
      if (_namedHasLiteral(args, 'width')) add(node, categoryStroke, display);
    }
  }

  bool _namedHasLiteral(Iterable<Expression> args, String label) => args.any(
    (a) =>
        a is NamedExpression &&
        a.name.label.name == label &&
        containsContractLiteral(a.expression),
  );

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final owner = node.methodName.element?.enclosingElement;
    if (node.methodName.name == 'copyWith' &&
        _className(owner) == 'BorderSide' &&
        _namedHasLiteral(node.argumentList.arguments, 'width')) {
      add(node, categoryStroke, 'BorderSide.copyWith');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final label = node.name.label.name;
    if (label == 'fontSize' && containsContractLiteral(node.expression)) {
      add(node, categoryFontSize, 'fontSize:');
    } else if (label == 'strokeWidth' &&
        containsContractLiteral(node.expression)) {
      add(node, categoryStroke, 'strokeWidth:');
    }
    super.visitNamedExpression(node);
  }

  /// `paint..strokeWidth = 2` assigns a stroke width the same way.
  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final written = node.writeElement;
    if (written != null &&
        written.displayName == 'strokeWidth' &&
        containsContractLiteral(node.rightHandSide)) {
      add(node, categoryStroke, 'strokeWidth =');
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitNamedType(NamedType node) {
    if (node.element?.name == 'RaftFamily') {
      add(node, categoryThemeName, 'RaftFamily');
    }
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element != null && !node.inDeclarationContext()) {
      final name = element.displayName;
      if (element is InterfaceElement && name == 'RaftFamily') {
        add(node, categoryThemeName, 'RaftFamily');
      } else if (name == 'isElegant' || name == 'isBrutal') {
        add(node, categoryThemeName, name);
      } else if (name == 'transparent') {
        // Colors.transparent carries no colour.
      } else if (_className(element.enclosingElement) == 'Colors' &&
          element.library?.uri.toString().startsWith(
                'package:flutter/src/material/',
              ) ==
              true &&
          (element is PropertyAccessorElement || element is FieldElement)) {
        add(node, categoryColor, 'Colors.$name');
      } else if ((element is PropertyAccessorElement ||
              element is FieldElement) &&
          _className(element.enclosingElement) == 'RaftRecipeTheme' &&
          (name == 'elegant' || name == 'brutal') &&
          !_inRecipeThemeAdapter(node)) {
        add(node, categoryLegacyRecipe, 'RaftRecipeTheme.$name');
      }
    }
    super.visitSimpleIdentifier(node);
  }

  bool _inRecipeThemeAdapter(AstNode node) {
    if (isRecipeRuntimeFile(relativePath)) return true;
    for (AstNode? n = node; n != null; n = n.parent) {
      if (n is FunctionDeclaration && n.name.lexeme == recipeThemeAdapter) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final type = node.operator.type;
    if ((type == TokenType.EQ_EQ || type == TokenType.BANG_EQ) &&
        (_denotesThemeName(node.leftOperand) ||
            _denotesThemeName(node.rightOperand))) {
      add(node, categoryThemeName, 'theme name ${node.operator.lexeme}');
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    if (_denotesThemeName(node.expression)) {
      add(node, categoryThemeName, 'switch on theme name');
    }
    super.visitSwitchStatement(node);
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    if (_denotesThemeName(node.expression)) {
      add(node, categoryThemeName, 'switch on theme name');
    }
    super.visitSwitchExpression(node);
  }

  /// A theme name is a `RaftFamily` value, a theme-pack id constant, or the
  /// `id`/`name` of a theme holder.
  bool _denotesThemeName(Expression expression) {
    final e = expression is ParenthesizedExpression
        ? expression.unParenthesized
        : expression;
    final type = e.staticType;
    if (type is InterfaceType && type.element.name == 'RaftFamily') return true;
    SimpleIdentifier? member;
    Expression? target;
    if (e is PrefixedIdentifier) {
      member = e.identifier;
      target = e.prefix;
    } else if (e is PropertyAccess) {
      member = e.propertyName;
      target = e.target;
    } else if (e is SimpleIdentifier) {
      member = e;
    }
    if (member == null) return false;
    if (themeNameMembers.contains(member.name)) return true;
    final targetType = target?.staticType;
    return targetType is InterfaceType &&
        themeHolderClasses.contains(targetType.element.name) &&
        (member.name == 'id' || member.name == 'name');
  }
}
