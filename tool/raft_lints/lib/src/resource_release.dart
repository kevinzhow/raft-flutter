import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'checks.dart';

const resourceRule = 'avoid_unreleased_resource';
const resourceMessage =
    'An owned controller, timer, subscription or lifecycle observer is '
    'created here but never released in this file; a leak keeps a hidden '
    "page's tickers, listeners or native handles alive.";
const resourceCorrection =
    'dispose()/cancel()/close() it (or remove the observer/listener) in the '
    'same file, or '
    "add '// ignore: raft_lints/$resourceRule -- <who releases it>'.";

/// Classes whose instances must be released by their owner.
const _controllers = {
  'AnimationController',
  'ScrollController',
  'TextEditingController',
  'FocusNode',
  'FocusScopeNode',
  'PageController',
  'TabController',
  'TransformationController',
  'UndoHistoryController',
  'ValueNotifier',
  'StreamController',
};
const _releaseNames = {'dispose', 'cancel', 'close', 'stop'};

/// Whole-unit check: variables and fields initialised or assigned a controller
/// (fields only), a timer or a `.listen` subscription need a
/// `dispose/cancel/close/stop` on the same variable somewhere in the file, and
/// `addObserver` / image-stream `addListener` calls need as many removals.
void checkResourceRelease(CompilationUnit unit, Report report) {
  final scan = _Scan();
  unit.accept(scan);
  for (final owned in scan.owned) {
    if (!scan.released.contains(owned.variable)) {
      report(resourceRule, owned.node);
    }
  }
  if (scan.observerAdds.length > scan.observerRemoves) {
    for (final node in scan.observerAdds.skip(scan.observerRemoves)) {
      report(resourceRule, node);
    }
  }
  if (scan.imageAdds.length > scan.imageRemoves) {
    for (final node in scan.imageAdds.skip(scan.imageRemoves)) {
      report(resourceRule, node);
    }
  }
}

/// One element per variable: a field and its synthetic accessors, and the
/// member of a generic class as seen from inside it, are the same variable.
Element _canon(Element e) {
  if (e is GetterElement) e = e.variable;
  if (e is SetterElement) e = e.variable;
  if (e is VariableElement) e = e.baseElement;
  return e;
}

class _Owned {
  _Owned(this.variable, this.node);
  final Element variable;
  final AstNode node;
}

class _Scan extends RecursiveAstVisitor<void> {
  final owned = <_Owned>[];
  final released = <Element>{};
  final observerAdds = <AstNode>[];
  var observerRemoves = 0;
  final imageAdds = <AstNode>[];
  var imageRemoves = 0;

  static bool _isCreation(Expression e, Set<String> names, String library) {
    if (e is InstanceCreationExpression) {
      final element = e.constructorName.type.element;
      return element != null &&
          names.contains(element.name) &&
          (element.library?.uri.toString().startsWith(library) ?? false);
    }
    return false;
  }

  /// `Type(...)` is a controller (only counted for fields), a timer, or a
  /// `stream.listen(...)` subscription.
  void _consider(
    Element? variable,
    Expression? value,
    AstNode at, {
    required bool isField,
  }) {
    if (variable == null || value == null) return;
    variable = _canon(variable);
    var e = value;
    while (e is ParenthesizedExpression) {
      e = e.expression;
    }
    final isController =
        isField &&
        (_isCreation(e, _controllers, 'package:flutter/') ||
            _isCreation(e, {'StreamController'}, 'dart:async'));
    final isTimer =
        _isCreation(e, {'Timer'}, 'dart:async') ||
        (e is InstanceCreationExpression &&
            {
              'RaftIdleTimer',
              'RaftForegroundPeriodic',
            }.contains(e.constructorName.type.name.lexeme));
    final isListen =
        e is MethodInvocation &&
        e.methodName.name == 'listen' &&
        _isStreamSubscription(e.staticType);
    if (isController || isTimer || isListen) owned.add(_Owned(variable, at));
  }

  static bool _isStreamSubscription(DartType? type) =>
      type is InterfaceType &&
      (type.element.name == 'StreamSubscription' ||
          type.allSupertypes.any(
            (t) => t.element.name == 'StreamSubscription',
          ));

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent?.parent;
    final isField =
        parent is FieldDeclaration || parent is TopLevelVariableDeclaration;
    _consider(
      node.declaredFragment?.element,
      node.initializer,
      node,
      isField: isField,
    );
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Only `x = ...` / `this.x = ...` / `o.x = ...`; `map[k] = Timer(...)` is
    // a collection the owner empties (checked by review, not by name).
    if (node.leftHandSide is! IndexExpression) {
      final target = node.writeElement;
      final isField = target is SetterElement || target is FieldElement;
      _consider(target, node.rightHandSide, node, isField: isField);
    }
    super.visitAssignmentExpression(node);
  }

  Element? _target(Expression? e) {
    while (e is ParenthesizedExpression) {
      e = e.expression;
    }
    final element = switch (e) {
      SimpleIdentifier() => e.element,
      PrefixedIdentifier() => e.element,
      PropertyAccess() => e.propertyName.element,
      _ => null,
    };
    return element == null ? null : _canon(element);
  }

  void _release(Expression? target) {
    final element = _target(target);
    if (element != null) released.add(element);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (_releaseNames.contains(name)) _release(node.realTarget);
    final targetType = node.realTarget?.staticType;
    if (name == 'addObserver') observerAdds.add(node.methodName);
    if (name == 'removeObserver') observerRemoves++;
    if (targetType is InterfaceType &&
        targetType.element.name == 'ImageStream') {
      if (name == 'addListener') imageAdds.add(node.methodName);
      if (name == 'removeListener') imageRemoves++;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // A tear-off such as `controller.dispose`.
    if (_releaseNames.contains(node.identifier.name)) _release(node.prefix);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (_releaseNames.contains(node.propertyName.name)) {
      _release(node.realTarget);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    // `for (final c in [a, b]) c.dispose();`
    final parts = node.forLoopParts;
    if (parts is ForEachPartsWithDeclaration) {
      final list = parts.iterable;
      final loopVar = parts.loopVariable.declaredFragment?.element;
      final inner = _Scan();
      node.body.accept(inner);
      if (list is ListLiteral &&
          loopVar != null &&
          inner.released.contains(loopVar)) {
        for (final item in list.elements) {
          if (item is Expression) _release(item);
        }
      }
    }
    super.visitForStatement(node);
  }
}
