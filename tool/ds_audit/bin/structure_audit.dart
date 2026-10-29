/// Syntax-only hotspot inventory. No network, resolution or generated assets.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';

class Inventory extends RecursiveAstVisitor<void> {
  final types = <String>{};
  final related = <String>{};
  final fields = <String>{};
  final parts = <String>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    types.add(node.namePart.typeName.lexeme);
    final parent = node.extendsClause?.superclass;
    if (parent != null) related.add(parent.name.lexeme);
    related.addAll(node.implementsClause?.interfaces.map((t) => t.name.lexeme) ?? []);
    related.addAll(node.withClause?.mixinTypes.map((t) => t.name.lexeme) ?? []);
    super.visitClassDeclaration(node);
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    types.add(node.name.lexeme);
    related.add(node.superclass.name.lexeme);
    related.addAll(node.implementsClause?.interfaces.map((t) => t.name.lexeme) ?? []);
    related.addAll(node.withClause.mixinTypes.map((t) => t.name.lexeme));
    super.visitClassTypeAlias(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final type = node.type;
    if (type is NamedType) {
      types.add(node.name.lexeme);
      related.add(type.name.lexeme);
    }
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    types.add(node.name.lexeme);
    related.addAll(node.onClause?.superclassConstraints.map((t) => t.name.lexeme) ?? []);
    related.addAll(node.implementsClause?.interfaces.map((t) => t.name.lexeme) ?? []);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final type = node.onClause?.extendedType;
    if (type is NamedType) related.add(type.name.lexeme);
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    // Class fields live inside a BlockClassBody in the pinned analyzer.
    final owner = node.thisOrAncestorOfType<CompilationUnitMember>();
    final name = switch (owner) {
      ClassDeclaration() => owner.namePart.typeName.lexeme,
      MixinDeclaration() => owner.name.lexeme,
      EnumDeclaration() => owner.namePart.typeName.lexeme,
      _ => null,
    };
    if (!node.isStatic && name != null) {
      for (final variable in node.fields.variables) {
        // Include final references: a final collection can still own mutable state.
        fields.add('$name.${variable.name.lexeme}');
      }
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    final primary = node.thisOrAncestorOfType<PrimaryConstructorDeclaration>();
    if (primary != null) fields.add('${primary.typeName.lexeme}.${node.name.lexeme}');
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final primary = node.thisOrAncestorOfType<PrimaryConstructorDeclaration>();
    if (primary != null && node.keyword != null && node.name != null) {
      fields.add('${primary.typeName.lexeme}.${node.name!.lexeme}');
    }
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null) throw FormatException('Part URI must be a string');
    parts.add(uri);
  }
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: structure_audit.dart ROOT CONFIG');
    exitCode = 2;
    return;
  }
  try {
    final root = Directory(args[0]).absolute;
    final lib = Directory('${root.path}/apps/raft_flutter/lib');
    final config = jsonDecode(File(args[1]).readAsStringSync()) as Map;
    final modules = config['modules'] as Map;
    final inventories = <String, Inventory>{};
    final metrics = <String, Map<String, int>>{};
    final names = <String, String>{};
    for (final entity in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.substring(root.path.length + 1).replaceAll('\\', '/');
      final source = entity.readAsStringSync();
      final parsed = parseString(
        content: source,
        path: entity.path,
        // Count primary-constructor fields too; enabling parser syntax does
        // not enable the feature in production builds or replace analysis.
        featureSet: FeatureSet.latestLanguageVersion(flags: ['primary-constructors']),
        throwIfDiagnostics: false,
      );
      final errors = parsed.errors.where((e) => e.severity == Severity.error);
      if (errors.isNotEmpty) {
        throw FormatException('$relative: ${errors.first}');
      }
      final inventory = Inventory();
      parsed.unit.accept(inventory);
      inventories[relative] = inventory;
      names[entity.absolute.uri.normalizePath().toString()] = relative;
      var tokens = 0;
      for (var token = parsed.unit.beginToken; !token.isEof; token = token.next!) {
        tokens++;
      }
      metrics[relative] = {
        'lines': const LineSplitter().convert(source).length,
        'tokens': tokens,
        for (final field in inventory.fields) 'field.$field': 1,
      };
    }
    final report = <String, Object>{};
    for (final entry in modules.entries) {
      final module = entry.value as Map;
      final files = <String>{module['root'] as String};
      files.addAll((module['companions'] as List? ?? []).cast<String>());
      final types = <String>{};
      var changed = true;
      while (changed) {
        final count = (files.length, types.length);
        for (final file in files.toList()) {
          final inventory = inventories[file];
          if (inventory == null) throw FormatException('Missing module source: $file');
          types.addAll(inventory.types);
          for (final part in inventory.parts) {
            final uri = File('${root.path}/$file').absolute.uri.resolve(part).normalizePath();
            final path = names[uri.toString()];
            if (path == null) throw FormatException('$file: part outside scanned lib or missing: $part');
            files.add(path);
          }
        }
        for (final file in inventories.entries) {
          if (file.value.related.any(types.contains)) files.add(file.key);
        }
        changed = count != (files.length, types.length);
      }
      final totals = <String, int>{};
      for (final file in files) {
        for (final metric in metrics[file]!.entries) {
          totals.update(metric.key, (n) => n + metric.value, ifAbsent: () => metric.value);
        }
      }
      report[entry.key as String] = {
        'files': files.toList()..sort(),
        'types': types.toList()..sort(),
        'metrics': Map.fromEntries(totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      };
    }
    stdout.writeln(jsonEncode({'version': 1, 'modules': report}));
  } catch (error) {
    stderr.writeln('structure-audit: $error');
    exitCode = 2;
  }
}
