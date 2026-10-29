/// Resolved design-system ownership inventory. References are not mount proof.
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// One shared accumulator for the scanner's existing resolved-unit sessions.
class OwnershipInventory {
  OwnershipInventory(this.relativePath, {this.canonicalFunctions = const {}});

  final String? Function(String) relativePath;
  final Map<String, String> canonicalFunctions;
  final declarations = <String, Map<String, Object?>>{};
  final references = <Map<String, Object?>>[];
  final recipeCalls = <Map<String, Object?>>[];
  final paintUses = <Map<String, Object?>>[];
  final dynamicEdges = <Map<String, Object?>>[];
  final stateUses = <String, Map<String, Object?>>{};
  final recipes = <String, Map<String, Object?>>{};
  final stateAtoms = <String, String>{};
  final files = <String>{};

  String? relative(String? path) {
    if (path == null) return null;
    return relativePath(path);
  }

  String? fileOf(Element? e) =>
      relative(e?.firstFragment.libraryFragment?.source.fullName);

  String? idOf(Element? e) {
    if (e is ConstructorElement) e = e.enclosingElement;
    if (e == null || e.name == null) return null;
    final file = fileOf(e);
    if (file == null) return null;
    if (e is LocalFunctionElement) {
      // Local functions belong to fragments: their enclosingElement is null
      // in analyzer 12.1. Follow the resolved lexical fragment chain instead,
      // including real offsets so nested/block-local names cannot collide.
      final scopes = <String>[];
      for (
        Fragment? scope = e.firstFragment;
        scope != null && scope is! LibraryFragment;
        scope = scope.enclosingFragment
      ) {
        scopes.add(
          '${scope.element.kind.name}:${scope.name ?? '<anonymous>'}@${scope.offset}',
        );
      }
      return '$file#local-function:${scopes.reversed.join('/')}';
    }
    if (e is InterfaceElement) return '$file#class:${e.name}';
    if (e is TopLevelFunctionElement ||
        e is PropertyAccessorElement && e.enclosingElement is LibraryElement) {
      return '$file#function:${e.name}';
    }
    if (e is ExecutableElement && e.enclosingElement is InterfaceElement) {
      return '$file#method:${e.enclosingElement!.name}.${e.name}';
    }
    if (e is ExecutableElement && e.enclosingElement is ExtensionElement) {
      final parent = e.enclosingElement as ExtensionElement;
      final name =
          parent.name ?? 'extension(${parent.extendedType.getDisplayString()})';
      return '$file#method:$name.${e.name}';
    }
    return null;
  }

  bool frameworkType(InterfaceElement e, String name) =>
      e.name == name && e.library.uri.toString().startsWith('package:flutter/');

  bool subtype(InterfaceElement e, String name) =>
      frameworkType(e, name) ||
      e.allSupertypes.any((t) => frameworkType(t.element, name));

  bool widgetType(DartType? type) {
    if (type is! InterfaceType) return false;
    if (subtype(type.element, 'Widget')) return true;
    if ((type.isDartCoreList ||
            type.isDartCoreIterable ||
            type.element.name == 'Future' &&
                type.element.library.uri.toString() == 'dart:async') &&
        type.typeArguments.length == 1) {
      return widgetType(type.typeArguments.single);
    }
    return false;
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'files': files.toList()..sort(),
    'declarations': [
      for (final id in declarations.keys.toList()..sort()) declarations[id],
    ],
    'references': references,
    'recipeCalls': recipeCalls,
    'paintUses': paintUses,
    'dynamicEdges': dynamicEdges,
    'stateUses': [
      for (final id in stateUses.keys.toList()..sort()) stateUses[id],
    ],
    'recipes': recipes,
    'stateAtoms': stateAtoms,
    'mountEvidence': 'NOT_PROVEN_BY_RESOLVED_REFERENCES',
  };
}

/// Generated metadata is parsed from the generator's literal contract, not
/// guessed from identifiers in callers. Generated tables remain unedited.
class RecipeMetadataVisitor extends RecursiveAstVisitor<void> {
  RecipeMetadataVisitor(this.inventory, this.file);
  final OwnershipInventory inventory;
  final String file;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    String? name;
    final axes = <String, List<String>>{};
    for (final member
        in node.body.childEntities.whereType<FieldDeclaration>()) {
      for (final field in member.fields.variables) {
        final value = field.initializer;
        if (field.name.lexeme == 'recipeName' && value is StringLiteral) {
          name = value.stringValue;
        }
        if (field.name.lexeme == 'axes' && value is ListLiteral) {
          for (final axis
              in value.elements.whereType<InstanceCreationExpression>()) {
            final args = axis.argumentList.arguments;
            if (args.length < 2 ||
                args[0] is! StringLiteral ||
                args[1] is! ListLiteral) {
              continue;
            }
            final key = (args[0] as StringLiteral).stringValue;
            if (key != null) {
              axes[key] = [
                for (final v
                    in (args[1] as ListLiteral).elements
                        .whereType<StringLiteral>())
                  if (v.stringValue != null) v.stringValue!,
              ];
            }
          }
        }
      }
    }
    if (name != null) inventory.recipes[name] = {'file': file, 'axes': axes};
    super.visitClassDeclaration(node);
  }
}

/// Visits only resolved runtime units, including private render owners and
/// tracked runtime path dependencies. No style allowlist is added by this pass.
class OwnershipVisitor extends RecursiveAstVisitor<void> {
  OwnershipVisitor(this.inventory, this.unit, this.file);
  final OwnershipInventory inventory;
  final ResolvedUnitResult unit;
  final String file;

  String? owner(AstNode node) {
    for (var n = node.parent; n != null; n = n.parent) {
      if (n is FunctionDeclaration) {
        final id = inventory.idOf(n.declaredFragment?.element);
        if (id != null) return id;
      }
      if (n is MethodDeclaration) {
        final id = inventory.idOf(n.declaredFragment?.element);
        if (id != null) return id;
      }
      if (n is ClassDeclaration) {
        return inventory.idOf(n.declaredFragment?.element);
      }
    }
    return null;
  }

  void declare(AstNode node, Element? e, String kind) {
    final id = inventory.idOf(e);
    if (id == null) return;
    inventory.declarations[id] = {
      'id': id,
      'file': file,
      'name': e!.name,
      'kind': kind,
      'line': unit.lineInfo.getLocation(node.offset).lineNumber,
      'public': e is! LocalFunctionElement && !e.name!.startsWith('_'),
      'owner': owner(node),
    };
  }

  void ensureOwner(AstNode node) {
    for (var n = node.parent; n != null; n = n.parent) {
      if (n is FunctionDeclaration) {
        final e = n.declaredFragment?.element;
        if (inventory.idOf(e) == null) continue;
        if (!inventory.declarations.containsKey(inventory.idOf(e))) {
          declare(n, e, 'render_or_state_owner');
        }
        return;
      }
      if (n is MethodDeclaration) {
        final e = n.declaredFragment?.element;
        if (inventory.idOf(e) == null) continue;
        if (!inventory.declarations.containsKey(inventory.idOf(e))) {
          declare(n, e, 'render_or_state_owner');
        }
        return;
      }
      if (n is ClassDeclaration) return;
    }
  }

  void reference(AstNode node, Element? element, {required String kind}) {
    if (element is ConstructorElement) element = element.enclosingElement;
    final id = inventory.idOf(element);
    if (id == null) return;
    ensureOwner(node);
    inventory.references.add({
      'owner': owner(node),
      'target': id,
      'kind': kind,
      'file': file,
      'line': unit.lineInfo.getLocation(node.offset).lineNumber,
    });
  }

  void stateAtom(AstNode node, String atom) {
    ensureOwner(node);
    final caller = owner(node) ?? '$file#unit';
    final id = '$caller|state:$atom';
    inventory.stateUses[id] = {
      'id': id,
      'owner': caller,
      'atom': atom,
      'file': file,
    };
  }

  void flagValues(CollectionElement element, AstNode call) {
    if (element is IfElement) {
      flagValues(element.thenElement, call);
      if (element.elseElement != null) flagValues(element.elseElement!, call);
    } else if (element is ForElement) {
      flagValues(element.body, call);
    } else if (element is SpreadElement) {
      flagValues(element.expression, call);
    } else if (element is SetOrMapLiteral) {
      for (final item in element.elements) {
        flagValues(item, call);
      }
    } else if (element is ListLiteral) {
      for (final item in element.elements) {
        flagValues(item, call);
      }
    } else if (element is StringLiteral && element.stringValue != null) {
      stateAtom(call, element.stringValue!);
    } else if (element is ConditionalExpression) {
      flagValues(element.thenExpression, call);
      flagValues(element.elseExpression, call);
    } else if (element is ParenthesizedExpression) {
      flagValues(element.expression, call);
    } else {
      Element? e;
      if (element is SimpleIdentifier) e = element.element;
      if (element is PrefixedIdentifier) e = element.element;
      if (element is PropertyAccess) e = element.propertyName.element;
      if (e is PropertyAccessorElement) e = e.variable;
      final value = e is VariableElement ? e.computeConstantValue() : null;
      final atom = value?.toStringValue();
      final collection = value?.toSetValue()?.toList() ?? value?.toListValue();
      if (atom != null) {
        stateAtom(call, atom);
      } else if (collection != null &&
          collection.every((v) => v.toStringValue() != null)) {
        for (final v in collection) {
          stateAtom(call, v.toStringValue()!);
        }
      } else {
        inventory.dynamicEdges.add({
          'owner': owner(call),
          'file': file,
          'line': unit.lineInfo.getLocation(call.offset).lineNumber,
          'status': 'UNRESOLVED_STATE_INPUT',
        });
      }
    }
  }

  void stateArguments(
    AstNode node,
    FunctionTypedElement? e,
    ArgumentList args,
  ) {
    final type = e?.returnType;
    if (type is! InterfaceType ||
        type.element.name != 'RaftRecipeStates' ||
        inventory.fileOf(type.element) !=
            'packages/raft_theme/lib/recipes/recipe_runtime.dart') {
      return;
    }
    final positional = e!.formalParameters
        .where((p) => p.isPositional)
        .toList();
    var index = 0;
    for (final arg in args.arguments) {
      final parameter = arg is NamedExpression
          ? arg.element
          : index < positional.length
          ? positional[index++]
          : null;
      final type = parameter?.type;
      if (type is InterfaceType &&
          type.element.library.uri.toString() == 'dart:core' &&
          const {'Iterable', 'List', 'Set'}.contains(type.element.name) &&
          type.typeArguments.length == 1 &&
          type.typeArguments.single.isDartCoreString) {
        flagValues(arg is NamedExpression ? arg.expression : arg, node);
      } else if (type?.isDartCoreBool == true && parameter?.name != null) {
        // This is an exact resolved state-helper input, not a guessed CSS
        // selector. Applicability remains unknown until its source is reviewed.
        stateAtom(node, 'argument:${inventory.idOf(e)}:${parameter!.name}');
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName.element;
    final e = constructor?.enclosingElement;
    if (e != null && inventory.subtype(e, 'Widget')) {
      reference(node, e, kind: 'constructor_call');
    }
    if (e != null &&
        (e.library.uri.toString().startsWith('package:flutter/') ||
            e.library.uri.toString() == 'dart:ui') &&
        const {
          'Container',
          'ColoredBox',
          'DecoratedBox',
          'CustomPaint',
          'BoxDecoration',
          'ShapeDecoration',
          'TextStyle',
          'Border',
          'BorderSide',
          'BorderRadius',
          'Color',
        }.contains(e.name)) {
      inventory.paintUses.add({
        'owner': owner(node),
        'ownerClass': inventory.idOf(
          node
              .thisOrAncestorOfType<ClassDeclaration>()
              ?.declaredFragment
              ?.element,
        ),
        'file': file,
        'name': e.name,
        'line': unit.lineInfo.getLocation(node.offset).lineNumber,
      });
    }
    stateArguments(node, constructor, node.argumentList);
    if (e != null &&
        e.library.uri.toString().startsWith('package:flutter/') &&
        const {
          'OverlayEntry',
          'RawDialogRoute',
          'DialogRoute',
          'PageRouteBuilder',
        }.contains(e.name)) {
      surfaceOwner(node);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final e = node.element;
    if (e is InterfaceElement && inventory.subtype(e, 'Widget')) {
      reference(node, e, kind: 'type');
    }
    super.visitNamedType(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final caller = owner(node);
    if (caller != null && inventory.declarations.containsKey(caller)) {
      inventory.dynamicEdges.add({
        'owner': caller,
        'file': file,
        'line': unit.lineInfo.getLocation(node.offset).lineNumber,
        'status': 'UNRESOLVED_DYNAMIC_DELEGATION',
      });
    }
    super.visitFunctionExpressionInvocation(node);
  }

  void surfaceOwner(AstNode node) {
    for (var n = node.parent; n != null; n = n.parent) {
      if (n is FunctionDeclaration &&
          inventory.idOf(n.declaredFragment?.element) != null) {
        declare(n, n.declaredFragment?.element, 'surface_factory');
        return;
      }
      if (n is MethodDeclaration &&
          inventory.idOf(n.declaredFragment?.element) != null) {
        declare(n, n.declaredFragment?.element, 'surface_factory');
        return;
      }
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e != null) {
      if (inventory.subtype(e, 'Widget')) {
        declare(node, e, 'widget');
      } else if (inventory.subtype(e, 'State') ||
          inventory.subtype(e, 'CustomPainter') ||
          inventory.subtype(e, 'RenderObject')) {
        declare(node, e, 'paint_owner');
      }
      final id = inventory.idOf(e);
      if (id != null && inventory.declarations.containsKey(id)) {
        for (final parent in e.allSupertypes) {
          if (inventory.frameworkType(parent.element, 'State') &&
              parent.typeArguments.length == 1 &&
              parent.typeArguments.single is InterfaceType) {
            inventory.declarations[id]!['stateFor'] = inventory.idOf(
              (parent.typeArguments.single as InterfaceType).element,
            );
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e is TopLevelFunctionElement &&
        inventory.canonicalFunctions[e.name] == file) {
      declare(node, e, 'surface_factory');
    } else if (e != null && inventory.widgetType(e.returnType)) {
      declare(node, e, 'builder');
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e != null && inventory.widgetType(e.returnType)) {
      declare(node, e, 'builder');
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e != null &&
        e.enclosingElement is InterfaceElement &&
        e.enclosingElement!.name == 'RaftRecipeStates' &&
        inventory.fileOf(e) ==
            'packages/raft_theme/lib/recipes/recipe_runtime.dart') {
      final atom = e.computeConstantValue()?.toStringValue();
      if (atom != null && e.name != null) inventory.stateAtoms[e.name!] = atom;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var e = node.element;
    if (node.inDeclarationContext() ||
        node.thisOrAncestorOfType<NamespaceDirective>() != null ||
        node.thisOrAncestorOfType<CommentReference>() != null) {
      super.visitSimpleIdentifier(node);
      return;
    }
    if (e is ConstructorElement) e = e.enclosingElement;
    if (e is InterfaceElement && inventory.subtype(e, 'Widget') ||
        e is FunctionTypedElement && inventory.widgetType(e.returnType)) {
      final target = inventory.idOf(e);
      if (target != null) {
        reference(node, e, kind: 'identifier');
      }
    }
    final variable = e is PropertyAccessorElement ? e.variable : e;
    if (variable is VariableElement &&
        variable.enclosingElement is InterfaceElement &&
        variable.enclosingElement!.name == 'RaftRecipeStates' &&
        inventory.fileOf(variable) ==
            'packages/raft_theme/lib/recipes/recipe_runtime.dart') {
      final atom = variable.computeConstantValue()?.toStringValue();
      if (atom != null) {
        inventory.stateAtoms[variable.name!] = atom;
        stateAtom(node, atom);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final e = node.methodName.element;
    if (e is FunctionTypedElement && inventory.widgetType(e.returnType)) {
      reference(node, e, kind: 'function_call');
    }
    stateArguments(
      node,
      e is FunctionTypedElement ? e : null,
      node.argumentList,
    );
    final targetFile = inventory.fileOf(e);
    final method = e?.name;
    if ((method == 'resolve' || method == 'resolveProps') &&
        targetFile != null &&
        (targetFile.startsWith('packages/raft_theme/lib/recipes/') ||
            targetFile.startsWith('packages/raft_ui/lib/src/recipes/'))) {
      ensureOwner(node);
      inventory.recipeCalls.add({
        'owner': owner(node),
        'file': file,
        'targetFile': targetFile,
        'target': inventory.idOf(e),
        'method': method,
        'line': unit.lineInfo.getLocation(node.offset).lineNumber,
        'namedArguments': [
          for (final a
              in node.argumentList.arguments.whereType<NamedExpression>())
            a.name.label.name,
        ],
        'dynamicApplicability': 'UNRESOLVED_UNTIL_REVIEWED',
      });
    }
    if (e == null || e is FormalParameterElement || e is LocalVariableElement) {
      final caller = owner(node);
      if (caller != null && inventory.declarations.containsKey(caller)) {
        inventory.dynamicEdges.add({
          'owner': caller,
          'file': file,
          'line': unit.lineInfo.getLocation(node.offset).lineNumber,
          'status': 'UNRESOLVED_DYNAMIC_DELEGATION',
        });
      }
    }
    // A Future-returning function that opens a surface is also an entry owner.
    // Match the resolved canonical function/file via the registry later; never
    // interpret a same-named local function as a Material or Raft entry.
    final flutterSurface =
        e != null &&
        e.library?.uri.toString().startsWith('package:flutter/') == true &&
        (const {
              'showDialog',
              'showAdaptiveDialog',
              'showGeneralDialog',
              'showCupertinoDialog',
              'showMenu',
              'showModalBottomSheet',
              'showBottomSheet',
              'showCupertinoModalPopup',
            }.contains(e.name) ||
            e.enclosingElement?.name == 'NavigatorState' &&
                const {
                  'push',
                  'pushNamed',
                  'pushReplacement',
                  'pushReplacementNamed',
                  'pushAndRemoveUntil',
                  'pushNamedAndRemoveUntil',
                }.contains(e.name));
    if (e != null &&
        (flutterSurface ||
            e.name != null &&
                e.name!.startsWith('show') &&
                targetFile != null &&
                targetFile.startsWith('packages/raft_ui/lib/'))) {
      surfaceOwner(node);
      inventory.references.add({
        'owner': owner(node),
        'target': inventory.idOf(e),
        'file': file,
        'line': unit.lineInfo.getLocation(node.offset).lineNumber,
        'kind': 'surface_factory_candidate',
        'mountStatus': 'unresolved',
      });
    }
    super.visitMethodInvocation(node);
  }
}
