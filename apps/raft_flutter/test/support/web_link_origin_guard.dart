import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

/// Finds browser-route expressions that still contain an API origin.
/// Relative API paths and in-app Uri(path: ...) locations are not Web URLs.
/// Follow lexical initializer aliases; a name or comment cannot exempt a file.
List<int> bareApiWebLinks(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final bindings = _Bindings();
  unit.accept(bindings);
  final links = _Links(bindings.nodes);
  unit.accept(links);
  return links.offsets.toList()..sort();
}

class _Bindings extends RecursiveAstVisitor<void> {
  final nodes = <AstNode>[];
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    nodes.add(node);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    nodes.add(node);
    super.visitSimpleFormalParameter(node);
  }
}

class _Links extends GeneralizingAstVisitor<void> {
  _Links(this.bindings);
  final List<AstNode> bindings;
  final offsets = <int>{};
  static final route = RegExp(
    r'(^|https?://[^/]+)(/join/|/integration-invites/|/s/|/download($|[?#]))',
  );

  AstNode? scope(AstNode node) {
    for (var p = node.parent; p != null; p = p.parent) {
      if (p is Block ||
          p is MethodDeclaration ||
          p is FunctionExpression ||
          p is ClassDeclaration ||
          p is CompilationUnit) {
        return p;
      }
    }
    return null;
  }

  AstNode? binding(SimpleIdentifier use) {
    final parent = use.parent;
    if (parent is PropertyAccess && parent.propertyName == use ||
        parent is PrefixedIdentifier && parent.identifier == use ||
        parent is MethodInvocation && parent.methodName == use) {
      return null;
    }
    for (var owner = use.parent; owner != null; owner = owner.parent) {
      final matches = bindings.where((node) {
        final name = switch (node) {
          VariableDeclaration() => node.name.lexeme,
          SimpleFormalParameter() => node.name?.lexeme,
          _ => null,
        };
        return name == use.name &&
            scope(node) == owner &&
            (owner is ClassDeclaration ||
                owner is CompilationUnit ||
                node.offset < use.offset);
      }).toList()..sort((a, b) => b.offset.compareTo(a.offset));
      if (matches.isNotEmpty) return matches.first;
    }
    return null;
  }

  String? member(AstNode? node) => switch (node) {
    PropertyAccess() => node.propertyName.name,
    PrefixedIdentifier() => node.identifier.name,
    _ => null,
  };

  bool apiClient(Expression? node, [Set<AstNode>? visited]) {
    final seen = visited ?? <AstNode>{};
    if (node == null || !seen.add(node)) return false;
    // WorkspaceController.client is the application's API client field.
    if (member(node) == 'client') return true;
    if (node is! SimpleIdentifier) return false;
    final declared = binding(node);
    if (declared is SimpleFormalParameter) {
      return declared.type?.toSource() == 'RaftClient';
    }
    if (declared is VariableDeclaration) {
      if ((declared.parent as VariableDeclarationList).type?.toSource() ==
          'RaftClient') {
        return true;
      }
      return apiClient(declared.initializer, seen);
    }
    return false;
  }

  bool apiOrigin(AstNode node, [Set<AstNode>? visited]) {
    final seen = visited ?? <AstNode>{};
    if (!seen.add(node)) return false;
    // Only this actual resolver call clears API-origin provenance. Merely
    // mentioning its name elsewhere in the file has no effect.
    if (node is MethodInvocation &&
        node.methodName.name == 'originFor' &&
        node.target is SimpleIdentifier &&
        (node.target as SimpleIdentifier).name == 'ContentLinks') {
      return false;
    }
    final environmentArguments = switch (node) {
      InstanceCreationExpression()
          when node.constructorName.type.name.lexeme == 'String' &&
              node.constructorName.name?.name == 'fromEnvironment' =>
        node.argumentList.arguments,
      MethodInvocation()
          when node.target?.toSource() == 'String' &&
              node.methodName.name == 'fromEnvironment' =>
        node.argumentList.arguments,
      _ => null,
    };
    if (environmentArguments?.firstOrNull is SimpleStringLiteral &&
        (environmentArguments!.first as SimpleStringLiteral).value ==
            'RAFT_ORIGIN') {
      return true;
    }
    if (node is SimpleStringLiteral) {
      final uri = Uri.tryParse(node.value);
      if (uri?.scheme == 'https' &&
          const {'api.raft.build', 'api.slock.ai'}.contains(uri?.host)) {
        return true;
      }
    }
    if (node is PropertyAccess &&
            node.propertyName.name == 'origin' &&
            apiClient(node.target) ||
        node is PrefixedIdentifier &&
            node.identifier.name == 'origin' &&
            apiClient(node.prefix)) {
      return true;
    }
    if (node is SimpleIdentifier) {
      final declared = binding(node);
      if (declared is VariableDeclaration &&
          declared.initializer != null &&
          apiOrigin(declared.initializer!, seen)) {
        return true;
      }
    }
    return node.childEntities.whereType<AstNode>().any(
      (child) => apiOrigin(child, seen),
    );
  }

  bool webPath(AstNode node) {
    final literal = switch (node) {
      SimpleStringLiteral() => node.value,
      InterpolationString() => node.value,
      _ => null,
    };
    if (literal != null && route.hasMatch(literal)) return true;
    return node.childEntities.whereType<AstNode>().any(webPath);
  }

  bool badLink(Expression node) {
    if (node is SimpleStringLiteral) return webPath(node) && apiOrigin(node);
    if (node is StringInterpolation) {
      final first = node.elements.first;
      final prefix = first is InterpolationString ? first.value : '';
      if (prefix.startsWith('/')) return false;
      final origins = node.elements.whereType<InterpolationExpression>();
      final literalOrigin = Uri.tryParse(prefix);
      final apiPrefix =
          literalOrigin?.scheme == 'https' &&
          const {
            'api.raft.build',
            'api.slock.ai',
          }.contains(literalOrigin?.host);
      return webPath(node) &&
          (apiPrefix ||
              origins.isNotEmpty && apiOrigin(origins.first.expression));
    }
    if (node is BinaryExpression && node.operator.lexeme == '+') {
      Expression first = node;
      while (first is BinaryExpression && first.operator.lexeme == '+') {
        first = first.leftOperand;
      }
      return webPath(node) && apiOrigin(first);
    }
    if (node is MethodInvocation &&
        node.target?.toSource() == 'ContentLinks' &&
        node.methodName.name == 'messageUrl') {
      return node.argumentList.arguments.whereType<NamedExpression>().any(
        (argument) =>
            argument.name.label.name == 'origin' &&
            apiOrigin(argument.expression),
      );
    }
    if (node is MethodInvocation &&
        node.target != null &&
        const {
          'replace',
          'resolve',
          'resolveUri',
        }.contains(node.methodName.name)) {
      final paths = node.argumentList.arguments.where(
        (argument) =>
            node.methodName.name != 'replace' ||
            argument is NamedExpression && argument.name.label.name == 'path',
      );
      return paths.any(webPath) && apiOrigin(node.target!);
    }
    return false;
  }

  @override
  void visitExpression(Expression node) {
    if (badLink(node)) offsets.add(node.offset);
    super.visitExpression(node);
  }
}
