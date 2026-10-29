import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Whether [type] is a Flutter `Widget` (or `PreferredSizeWidget`, a sliver, a
/// `List<Widget>` / `Iterable<Widget>`, any of them nullable).
bool isWidgetLike(DartType? type) {
  if (type is! InterfaceType) return false;
  if (_isFlutterWidgetClass(type.element)) return true;
  if (type.isDartCoreList || type.isDartCoreIterable) {
    final args = type.typeArguments;
    return args.length == 1 && isWidgetLike(args.single);
  }
  return type.allSupertypes.any((t) => _isFlutterWidgetClass(t.element));
}

bool _isFlutterWidgetClass(InterfaceElement element) =>
    element.name == 'Widget' &&
    element.library.uri.toString().startsWith('package:flutter/');

final _builderName = RegExp(r'[bB]uilder$');

/// Whether [node] sits inside render code: the body (nested closures included)
/// of a function, method or getter declared with a widget return type, or of a
/// closure that returns a widget or is passed as a `...builder:` argument.
bool isInRenderCode(AstNode node) {
  for (AstNode? n = node.parent; n != null; n = n.parent) {
    switch (n) {
      case MethodDeclaration():
        if (isWidgetLike(n.declaredFragment?.element.returnType)) return true;
      case FunctionDeclaration():
        if (isWidgetLike(n.declaredFragment?.element.returnType)) return true;
      case FunctionExpression():
        if (n.parent is FunctionDeclaration) break; // handled above
        if (isWidgetLike(n.declaredFragment?.element.returnType)) return true;
        final parent = n.parent;
        if (parent is NamedArgument &&
            _builderName.hasMatch(parent.name.lexeme)) {
          return true;
        }
    }
  }
  return false;
}

/// The element a (possibly parenthesised) property or identifier resolves to.
Element? elementOf(Expression e) {
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  return switch (e) {
    SimpleIdentifier() => e.element,
    PrefixedIdentifier() => e.element,
    PropertyAccess() => e.propertyName.element,
    _ => null,
  };
}
