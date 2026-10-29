import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'checks.dart';
import 'render_scope.dart';

/// Rule names (also the `// ignore: raft_lints/<name>` keys).
const textScaleFactorRule = 'avoid_text_scale_factor';
const fixedHeightTextRule = 'avoid_fixed_height_text';
const pixelTextHeightRule = 'avoid_pixel_text_height';

const textScaleFactorMessage =
    'textScaleFactor is deprecated and cannot express non-linear system text '
    'scaling.';
const textScaleFactorCorrection =
    'Read MediaQuery.textScalerOf(context) and call .scale(fontSize), or pass '
    "'textScaler:' instead of 'textScaleFactor:'; or add "
    "'// ignore: raft_lints/$textScaleFactorRule -- <why>'.";

const fixedHeightTextMessage =
    'A box with a fixed height whose child is text clips or overflows when '
    'the user raises the system text size.';
const fixedHeightTextCorrection =
    'Let the box grow with the text: use a minimum height '
    '(ConstrainedBox / BoxConstraints(minHeight:), Container(constraints:)), '
    'or add '
    "'// ignore: raft_lints/$fixedHeightTextRule -- <why the text cannot grow>'.";

const pixelTextHeightMessage =
    'TextStyle.height is a ratio of the font size, not pixels; a value above 3 '
    'is a pixel line height and would multiply the line box.';
const pixelTextHeightCorrection =
    'Pass the ratio (lineHeightPx / fontSize), or add '
    "'// ignore: raft_lints/$pixelTextHeightRule -- <why>'.";

const _scaleFactorNames = {
  'textScaleFactor',
  'textScaleFactorOf',
  'maybeTextScaleFactorOf',
};

/// A reference to `textScaleFactor` / `MediaQuery.textScaleFactorOf` /
/// `MediaQuery.maybeTextScaleFactorOf`, whichever class declares it (the
/// `MediaQueryData`, `TextScaler` and `TextScaler` subclasses included).
/// Declarations (a `TextScaler` subclass implementing the getter) are not
/// references.
void checkTextScaleFactorReference(SimpleIdentifier node, Report report) {
  if (!_scaleFactorNames.contains(node.name)) return;
  if (node.inDeclarationContext()) return;
  report(textScaleFactorRule, node);
}

/// `textScaleFactor:` passed to `Text`, `RichText`, `TextPainter`,
/// `EditableText` and friends.
void checkTextScaleFactorArgument(NamedArgument node, Report report) {
  if (node.name.lexeme == 'textScaleFactor') {
    report(textScaleFactorRule, node);
  }
}

// ---------------------------------------------------------------------------
// avoid_fixed_height_text

const _heightBoxes = {'SizedBox', 'Container', 'AnimatedContainer'};
const _constraintBoxes = {'Container', 'AnimatedContainer', 'ConstrainedBox'};
const _flutterTextWidgets = {
  'Text',
  'SelectableText',
  'TextField',
  'TextFormField',
};

/// Files that already had a fixed-height box directly around text when
/// `avoid_fixed_height_text` landed (CSS line-box parity heights such as 16.5
/// or 11 * 1.25, and fixed-size badge / glyph chips). Repo-relative path
/// suffixes; the rule does not run on these files. The list is empty: every
/// surface was fixed (minimum height, `RaftScaled.lineBox`, or a justified
/// ignore); do not add entries.
const legacyFixedHeightTextFiles = <String>[];

/// Whether [path] is on the [legacyFixedHeightTextFiles] list.
bool isLegacyFixedHeightTextFile(String path) {
  final p = path.replaceAll('\\', '/');
  return legacyFixedHeightTextFiles.any(p.endsWith);
}

/// A `SizedBox` / `Container` / `AnimatedContainer` with a numeric-literal or
/// const `height:`, or a `ConstrainedBox` / `Container` / `AnimatedContainer`
/// with `constraints:` capping or fixing the height, whose `child:` is
/// directly a text widget (`Text`, `Text.rich`, `SelectableText`, `TextField`,
/// `RaftCssText`). A `maxHeight: double.infinity` and a minimum height are fine.
void checkFixedHeightText(InstanceCreationExpression node, Report report) {
  final box = _flutterClassName(node);
  if (box == null) return;
  if (!_heightBoxes.contains(box) && !_constraintBoxes.contains(box)) return;
  final child = _namedArgument(node.argumentList, 'child');
  if (child == null || !_isTextWidget(child)) return;
  var fixed = false;
  if (_heightBoxes.contains(box)) {
    final height = _namedArgument(node.argumentList, 'height');
    fixed = height != null && isConstNumeric(height);
  }
  if (!fixed && _constraintBoxes.contains(box)) {
    final constraints = _namedArgument(node.argumentList, 'constraints');
    fixed = constraints != null && _constraintsFixHeight(constraints);
  }
  if (fixed) report(fixedHeightTextRule, node);
}

String? _flutterClassName(InstanceCreationExpression node) {
  final element = node.constructorName.element;
  if (element == null) return null;
  final owner = element.enclosingElement;
  if (!element.library.uri.toString().startsWith('package:flutter/')) {
    return null;
  }
  return owner.name;
}

Expression? _namedArgument(ArgumentList args, String name) {
  for (final a in args.arguments) {
    if (a is NamedArgument && a.name.lexeme == name) {
      return _unwrap(a.argumentExpression);
    }
  }
  return null;
}

Expression _unwrap(Expression e) {
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  return e;
}

bool _isTextWidget(Expression e) {
  if (e is! InstanceCreationExpression) return false;
  final element = e.constructorName.element;
  final name = element?.enclosingElement.name;
  if (name == null) return false;
  if (name == 'RaftCssText') return true;
  return _flutterTextWidgets.contains(name) &&
      element!.library.uri.toString().startsWith('package:flutter/');
}

bool _constraintsFixHeight(Expression e) {
  if (e is! InstanceCreationExpression) return false;
  if (_flutterClassName(e) != 'BoxConstraints') return false;
  final ctor = e.constructorName.name?.name;
  final args = e.argumentList;
  switch (ctor) {
    case null:
      final max = _namedArgument(args, 'maxHeight');
      return max != null && isConstNumeric(max);
    case 'tightFor' || 'tightForFinite' || 'expand':
      final height = _namedArgument(args, 'height');
      return height != null && isConstNumeric(height);
  }
  return false;
}

/// A numeric literal, a const numeric variable, or arithmetic over them.
/// `double.infinity` / `double.maxFinite` are not a fixed height.
bool isConstNumeric(Expression e) {
  e = _unwrap(e);
  switch (e) {
    case IntegerLiteral() || DoubleLiteral():
      return true;
    case PrefixExpression(:final operator, :final operand):
      return operator.lexeme == '-' && isConstNumeric(operand);
    case BinaryExpression(
      :final operator,
      :final leftOperand,
      :final rightOperand,
    ):
      return const {'+', '-', '*', '/', '~/'}.contains(operator.lexeme) &&
          isConstNumeric(leftOperand) &&
          isConstNumeric(rightOperand);
    case SimpleIdentifier() || PrefixedIdentifier() || PropertyAccess():
      final type = e.staticType;
      if (type == null || !(type.isDartCoreInt || type.isDartCoreDouble)) {
        return false;
      }
      var element = elementOf(e);
      if (element is GetterElement) {
        element = element.variable;
      }
      if (element is! VariableElement || !element.isConst) return false;
      final owner = element.enclosingElement;
      return !(owner is InterfaceElement && owner.library.isInSdk);
  }
  return false;
}

// ---------------------------------------------------------------------------
// avoid_pixel_text_height

/// `TextStyle(height: 20)` / `style.copyWith(height: 18.0)`: a numeric literal
/// above 3 where a ratio is expected.
void checkPixelTextHeight(NamedArgument node, Report report) {
  if (node.name.lexeme != 'height') return;
  final value = _unwrap(node.argumentExpression);
  final number = switch (value) {
    IntegerLiteral() => value.value?.toDouble(),
    DoubleLiteral() => value.value,
    _ => null,
  };
  if (number == null || number <= 3) return;
  final call = node.parent?.parent;
  final DartType? type;
  if (call is InstanceCreationExpression) {
    type = call.constructorName.type.type;
  } else if (call is MethodInvocation && call.methodName.name == 'copyWith') {
    type = call.realTarget?.staticType;
  } else {
    return;
  }
  if (type is! InterfaceType) return;
  final element = type.element;
  final lib = element.library.uri.toString();
  if (element.name == 'TextStyle' &&
      (lib.startsWith('package:flutter/') || lib == 'dart:ui')) {
    report(pixelTextHeightRule, node);
  }
}
