/// Family scan: references to deprecated duplicate Raft components.
///
/// The checked-in registry tool/ds-audit-families.json maps each design-system
/// family to its canonical component and lists the deprecated duplicates with
/// the file that declares them. Every reference to a deprecated class or
/// function outside that declaring file is a `duplicate.<family>` finding:
/// a constructor call, a type annotation, an `extends`/`implements` clause, a
/// static member access or a tear-off. Decisions come from resolved elements
/// (name plus declaring file), so a same-named class elsewhere never counts,
/// and mentions in comments, strings and import combinators never count.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'ds_audit.dart';

/// One deprecated duplicate: its family and the absolute declaring file.
class DeprecatedDuplicate {
  const DeprecatedDuplicate(this.family, this.declaringFile);
  final String family;
  final String declaringFile;
}

String? _declaringFile(Element element) =>
    element.firstFragment.libraryFragment?.source.fullName;

/// Collects `duplicate.<family>` findings from one resolved unit.
class FamilyAuditVisitor extends AuditVisitorBase {
  FamilyAuditVisitor(
    super.relativePath,
    super.unit,
    this.registry, {
    required String absolutePath,
  }) : _path = absolutePath;

  final Map<String, DeprecatedDuplicate> registry;
  final String _path;

  void _check(AstNode node, Element? element) {
    if (element is ConstructorElement) element = element.enclosingElement;
    if (element == null) return;
    final name = element.name;
    final entry = name == null ? null : registry[name];
    if (entry == null) return;
    if (element is! InterfaceElement && element is! TopLevelFunctionElement) {
      return;
    }
    final declared = _declaringFile(element);
    if (declared != entry.declaringFile || declared == _path) return;
    add(node, 'duplicate.${entry.family}', name!);
  }

  @override
  void visitNamedType(NamedType node) {
    _check(node, node.element);
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    // Constructor names (`RaftX.icon`) are counted through their NamedType.
    if ((element is InterfaceElement || element is TopLevelFunctionElement) &&
        !node.inDeclarationContext() &&
        node.thisOrAncestorOfType<NamespaceDirective>() == null &&
        node.thisOrAncestorOfType<CommentReference>() == null) {
      _check(node, element);
    }
    super.visitSimpleIdentifier(node);
  }
}
