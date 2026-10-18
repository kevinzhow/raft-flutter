import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'banned_apis.dart';
import 'checks.dart';
import 'error_leak.dart';
import 'notice_state.dart';
import 'off_grid_spacing.dart';
import 'resource_release.dart';
import 'text_scale.dart';

/// `expr[key]!` in render code.
class AvoidRenderIndexAssertion extends AnalysisRule {
  AvoidRenderIndexAssertion()
    : super(
        name: indexAssertionRule,
        description:
            'No map-index null assertion (`m[k]!`) in widget-returning '
            'functions and builder closures.',
      );

  static const LintCode code = LintCode(
    indexAssertionRule,
    indexAssertionMessage,
    correctionMessage: indexAssertionCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    registry.addPostfixExpression(this, _Visitor(this));
  }
}

/// `.single` in render code.
class AvoidRenderSingle extends AnalysisRule {
  AvoidRenderSingle()
    : super(
        name: singleRule,
        description:
            'No `.single` in widget-returning functions and builder closures.',
      );

  static const LintCode code = LintCode(
    singleRule,
    singleMessage,
    correctionMessage: singleCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final visitor = _Visitor(this);
    registry.addPrefixedIdentifier(this, visitor);
    registry.addPropertyAccess(this, visitor);
  }
}

/// `firstWhere` / `lastWhere` / `singleWhere` without `orElse` in render code.
class AvoidRenderWhereWithoutOrElse extends AnalysisRule {
  AvoidRenderWhereWithoutOrElse()
    : super(
        name: whereRule,
        description:
            'No `firstWhere`/`lastWhere`/`singleWhere` without `orElse` in '
            'widget-returning functions and builder closures.',
      );

  static const LintCode code = LintCode(
    whereRule,
    whereMessage,
    correctionMessage: whereCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);
  final AnalysisRule rule;

  void _report(String _, AstNode node) => rule.reportAtNode(node);

  @override
  void visitPostfixExpression(PostfixExpression node) =>
      checkIndexAssertion(node, _report);

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) =>
      checkSingle(node, node.identifier, _report);

  @override
  void visitPropertyAccess(PropertyAccess node) =>
      checkSingle(node, node.propertyName, _report);

  @override
  void visitMethodInvocation(MethodInvocation node) =>
      checkWhere(node, _report);
}

/// A banned-API rule built from a [BannedApi] spec.
class BannedApiRule extends AnalysisRule {
  BannedApiRule(this.api)
    : code = LintCode(api.rule, api.message, correctionMessage: api.correction),
      super(name: api.rule, description: api.message);

  final BannedApi api;
  final LintCode code;

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final visitor = _BannedVisitor(this, api);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
    registry.addPrefixedIdentifier(this, visitor);
    registry.addPropertyAccess(this, visitor);
    if (api.typeReferences) registry.addNamedType(this, visitor);
    if (api.namedArguments.isNotEmpty) {
      registry.addNamedArgument(this, visitor);
    }
  }
}

class _BannedVisitor extends SimpleAstVisitor<void> {
  _BannedVisitor(this.rule, this.api);
  final AnalysisRule rule;
  final BannedApi api;

  void _report(String _, AstNode node) => rule.reportAtNode(node);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (api.typeReferences) return; // reported via the type name
    if (api.hit(node, node.constructorName.element)) _report(api.rule, node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (api.hit(node.methodName, node.methodName.element)) {
      _report(api.rule, node.methodName);
    }
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (api.matches(node.identifier.element)) _report(api.rule, node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (api.matches(node.propertyName.element)) _report(api.rule, node);
  }

  @override
  void visitNamedType(NamedType node) {
    if (api.matches(node.element)) _report(api.rule, node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    if (api.namedArguments.contains(node.name.lexeme)) {
      _report(api.rule, node);
    }
  }
}

/// Text of a caught exception read outside a log call.
class AvoidCaughtExceptionText extends AnalysisRule {
  AvoidCaughtExceptionText()
    : super(
        name: errorLeakRule,
        description:
            r'No exception text (`$e`, `e.toString()`, `e.message`) '
            'outside log calls.',
      );

  static const LintCode code = LintCode(
    errorLeakRule,
    errorLeakMessage,
    correctionMessage: errorLeakCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir ||
        !errorLeakScope(context.definingUnit.file.path)) {
      return;
    }
    final visitor = _ErrorLeakVisitor(this);
    registry.addCatchClause(this, visitor);
    registry.addFunctionExpression(this, visitor);
  }
}

class _ErrorLeakVisitor extends SimpleAstVisitor<void> {
  _ErrorLeakVisitor(this.rule);
  final AnalysisRule rule;

  void _report(String _, AstNode node) => rule.reportAtNode(node);

  @override
  void visitCatchClause(CatchClause node) =>
      checkCaughtException(node, _report);

  @override
  void visitFunctionExpression(FunctionExpression node) =>
      checkCaughtException(node, _report);
}

/// Imperative notice holders and `setError` calls in presentation code.
class AvoidImperativeNoticeState extends AnalysisRule {
  AvoidImperativeNoticeState()
    : super(
        name: noticeStateRule,
        description:
            'Notices, errors and warnings are CauseNotice values, not plain '
            'mutable fields or setError calls.',
      );

  static const LintCode code = LintCode(
    noticeStateRule,
    noticeStateMessage,
    correctionMessage: noticeStateCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir ||
        !errorLeakScope(context.definingUnit.file.path)) {
      return;
    }
    final visitor = _NoticeVisitor(this);
    registry.addVariableDeclarationList(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

class _NoticeVisitor extends SimpleAstVisitor<void> {
  _NoticeVisitor(this.rule);
  final AnalysisRule rule;

  void _report(String _, AstNode node) => rule.reportAtNode(node);

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) =>
      checkNoticeField(node, _report);

  @override
  void visitMethodInvocation(MethodInvocation node) =>
      checkNoticeSetter(node, _report);
}

/// Owned controllers, timers, subscriptions and observers must be released.
class AvoidUnreleasedResource extends AnalysisRule {
  AvoidUnreleasedResource()
    : super(
        name: resourceRule,
        description:
            'A controller, timer, subscription or observer created in a file '
            'is released in that file.',
      );

  static const LintCode code = LintCode(
    resourceRule,
    resourceMessage,
    correctionMessage: resourceCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    registry.addCompilationUnit(this, _ResourceVisitor(this));
  }
}

class _ResourceVisitor extends SimpleAstVisitor<void> {
  _ResourceVisitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) =>
      checkResourceRelease(node, (_, n) => rule.reportAtNode(n));
}

/// `textScaleFactor` in any form; text sizes come from `TextScaler`.
class AvoidTextScaleFactor extends AnalysisRule {
  AvoidTextScaleFactor()
    : super(
        name: textScaleFactorRule,
        description:
            'No `textScaleFactor` (getter, `MediaQuery.textScaleFactorOf`, '
            '`textScaleFactor:` argument); use `TextScaler`.',
      );

  static const LintCode code = LintCode(
    textScaleFactorRule,
    textScaleFactorMessage,
    correctionMessage: textScaleFactorCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final visitor = _TextScaleVisitor(this);
    registry.addSimpleIdentifier(this, visitor);
    registry.addNamedArgument(this, visitor);
  }
}

class _TextScaleVisitor extends SimpleAstVisitor<void> {
  _TextScaleVisitor(this.rule);
  final AnalysisRule rule;

  void _report(String _, AstNode node) => rule.reportAtNode(node);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) =>
      checkTextScaleFactorReference(node, _report);

  @override
  void visitNamedArgument(NamedArgument node) =>
      checkTextScaleFactorArgument(node, _report);
}

/// A fixed-height box whose child is directly a text widget.
class AvoidFixedHeightText extends AnalysisRule {
  AvoidFixedHeightText()
    : super(
        name: fixedHeightTextRule,
        description:
            'No `SizedBox` / `Container` / `ConstrainedBox` with a fixed '
            'height whose child is directly a text widget.',
      );

  static const LintCode code = LintCode(
    fixedHeightTextRule,
    fixedHeightTextMessage,
    correctionMessage: fixedHeightTextCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir ||
        isLegacyFixedHeightTextFile(context.definingUnit.file.path)) {
      return;
    }
    registry.addInstanceCreationExpression(this, _FixedHeightVisitor(this));
  }
}

class _FixedHeightVisitor extends SimpleAstVisitor<void> {
  _FixedHeightVisitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) =>
      checkFixedHeightText(node, (_, n) => rule.reportAtNode(n));
}

/// `TextStyle(height: <pixel literal>)`.
class AvoidPixelTextHeight extends AnalysisRule {
  AvoidPixelTextHeight()
    : super(
        name: pixelTextHeightRule,
        description:
            '`TextStyle.height` is a ratio; no numeric literal above 3.',
      );

  static const LintCode code = LintCode(
    pixelTextHeightRule,
    pixelTextHeightMessage,
    correctionMessage: pixelTextHeightCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    registry.addNamedArgument(this, _PixelHeightVisitor(this));
  }
}

class _PixelHeightVisitor extends SimpleAstVisitor<void> {
  _PixelHeightVisitor(this.rule);
  final AnalysisRule rule;

  @override
  void visitNamedArgument(NamedArgument node) =>
      checkPixelTextHeight(node, (_, n) => rule.reportAtNode(n));
}

/// Spacing literals off the Web 2px grid.
class OffGridSpacing extends AnalysisRule {
  OffGridSpacing()
    : super(
        name: offGridSpacingRule,
        description:
            'EdgeInsets / spacer SizedBox / gap values are 0 or a multiple of '
            '2; an exception cites its Web source with '
            '`// ds-allow: Web <file> <class>`.',
      );

  static const LintCode code = LintCode(
    offGridSpacingRule,
    offGridSpacingMessage,
    correctionMessage: offGridSpacingCorrection,
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final visitor = _OffGridVisitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addNamedArgument(this, visitor);
  }
}

class _OffGridVisitor extends SimpleAstVisitor<void> {
  _OffGridVisitor(this.rule);
  final AnalysisRule rule;

  void _report(String _, AstNode node) => rule.reportAtNode(node);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) =>
      checkOffGridSpacing(node, _report);

  @override
  void visitNamedArgument(NamedArgument node) =>
      checkOffGridSpacing(node, _report);
}
