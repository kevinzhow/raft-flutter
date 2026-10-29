import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'checks.dart';

const errorLeakRule = 'avoid_caught_exception_text';
const errorLeakMessage =
    'The text of a caught exception is read; it could reach a Text, toast or '
    'banner. Web shows the server error or the call site fallback, never an '
    'exception object.';
const errorLeakCorrection =
    'Route it through userErrorText(e, fallback: ...) and show it in '
    'RaftErrorBanner / RaftFormField(error:) / showRaftToast, or '
    "add '// ignore: raft_lints/$errorLeakRule -- <why it never reaches the UI>'.";

/// Where the rule applies: presentation code, i.e. the app and raft_ui. The
/// layers below (raft_client, raft_sync, the vendored packages) produce and
/// classify errors and may read exception text.
bool errorLeakScope(String path) {
  final p = path.replaceAll('\\', '/');
  return !p.contains('/packages/') || p.contains('/packages/raft_ui/');
}

/// Calls whose arguments are diagnostics, not UI.
const _sinkFunctions = {
  'debugPrint',
  'debugPrintStack',
  'logUserError',
  'print',
};
const _textMembers = {'message', 'error', 'response', 'stackTrace', 'toString'};

/// A `catch (e)` clause, or a `catchError` / `onError:` closure: reports every
/// use of the caught object that interpolates it, stringifies it, reads its
/// text-bearing members or passes it to a `Text`, unless the use is inside a
/// log call.
void checkCaughtException(AstNode node, Report report) {
  Element? caught;
  AstNode body;
  switch (node) {
    case CatchClause():
      caught = node.exceptionParameter?.declaredFragment?.element;
      body = node.body;
    case FunctionExpression():
      if (!_isErrorCallback(node)) return;
      final params = node.parameters?.parameters;
      if (params == null || params.isEmpty) return;
      caught = params.first.declaredFragment?.element;
      body = node.body;
    default:
      return;
  }
  if (caught == null) return;
  body.accept(_UseFinder(caught, report));
}

bool _isErrorCallback(FunctionExpression node) {
  final parent = node.parent;
  if (parent is NamedArgument) return parent.name.lexeme == 'onError';
  final list = _argumentListOf(node);
  final call = list?.parent;
  return list != null &&
      call is MethodInvocation &&
      call.methodName.name == 'catchError' &&
      list.arguments.first ==
          (node.parent is ArgumentList ? node : node.parent);
}

/// The argument list directly holding [node] as a positional argument.
ArgumentList? _argumentListOf(AstNode node) {
  final parent = node.parent;
  if (parent is ArgumentList) return parent;
  if (parent is Argument && parent is! NamedArgument) {
    final grand = parent.parent;
    return grand is ArgumentList ? grand : null;
  }
  return null;
}

class _UseFinder extends RecursiveAstVisitor<void> {
  _UseFinder(this.caught, this.report);
  final Element caught;
  final Report report;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element != caught || node.inDeclarationContext()) return;
    if (!_leaks(node) || _inSink(node)) return;
    report(errorLeakRule, node);
  }

  bool _leaks(SimpleIdentifier id) {
    final parent = id.parent;
    if (parent is InterpolationExpression) return true;
    if (parent is PrefixedIdentifier && parent.prefix == id) {
      return _textMembers.contains(parent.identifier.name);
    }
    if (parent is PropertyAccess && parent.target == id) {
      return _textMembers.contains(parent.propertyName.name);
    }
    if (parent is MethodInvocation && parent.target == id) {
      return parent.methodName.name == 'toString';
    }
    // Text(e)
    final list = _argumentListOf(id);
    final call = list?.parent;
    return list != null &&
        call is InstanceCreationExpression &&
        call.constructorName.type.name.lexeme == 'Text' &&
        list.arguments.first == (id.parent is ArgumentList ? id : id.parent);
  }

  bool _inSink(AstNode node) {
    for (AstNode? n = node.parent; n != null; n = n.parent) {
      if (n is Statement) {
        // Check enclosing calls only up to the statement that holds the use.
        return false;
      }
      if (n is FunctionExpressionInvocation) {
        // `debugPrint` is a top-level variable, so its call is not a MethodInvocation.
        final fn = n.function;
        if (fn is SimpleIdentifier && _sinkFunctions.contains(fn.name)) {
          return true;
        }
      }
      if (n is MethodInvocation) {
        final name = n.methodName.name;
        final target = n.target;
        if (target == null && _sinkFunctions.contains(name)) return true;
        if (target is SimpleIdentifier) {
          if (target.name == 'developer' && name == 'log') return true;
          if (target.name == 'FlutterError' && name == 'reportError') {
            return true;
          }
          if (target.name == 'Error' && name == 'throwWithStackTrace') {
            return true;
          }
        }
      }
    }
    return false;
  }
}
