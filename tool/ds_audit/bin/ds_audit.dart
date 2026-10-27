/// Emits design-system drift findings as JSON on stdout.
///
/// Usage (normally via `tool/ds-audit`):
/// `dart --packages=ROOT/.dart_tool/package_config.json
/// tool/ds_audit/bin/ds_audit.dart --root ROOT [PATH ...]`
///
/// Paths are files or directories relative to --root (default
/// apps/raft_flutter/lib). Each `--contract PREFIX` marks a directory (relative
/// to --root) scanned with the theme-contract rules instead of the app rules;
/// generated `*.g.dart` files there are excluded from the literal categories
/// and only their recipe constants are counted. Each `--bypass PREFIX` also
/// runs the bypass scan (raw Material/Cupertino controls, `bypass.*`) on the
/// files under that directory; `--bypass-allow JSON` is a map
/// `{file: {family: reason}}` of designated raft_ui wrapper files whose
/// findings are reported as allowlisted. `--families JSON` is a map
/// `{name: {family, file}}` of deprecated duplicate Raft components; the files
/// under the `--bypass` directories are also scanned for references to them
/// (`duplicate.<family>`). Exits 2 when a scanned file has
/// analysis errors, because unresolved code would silently undercount.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:ds_audit/bypass_audit.dart';
import 'package:ds_audit/contract_audit.dart';
import 'package:ds_audit/ds_audit.dart';
import 'package:ds_audit/family_audit.dart';
import 'package:ds_audit/ownership_inventory.dart';

Future<void> main(List<String> argv) async {
  var root = Directory.current.path;
  final targets = <String>[];
  final contractPrefixes = <String>[];
  final bypassPrefixes = <String>[];
  final inventoryPrefixes = <String>[];
  var bypassAllow = <String, Map<String, String>>{};
  var families = <String, Map<String, String>>{};
  var canonicalFunctions = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    if (argv[i] == '--root') {
      root = argv[++i];
    } else if (argv[i] == '--contract') {
      contractPrefixes.add(argv[++i]);
    } else if (argv[i] == '--bypass') {
      bypassPrefixes.add(argv[++i]);
    } else if (argv[i] == '--inventory') {
      inventoryPrefixes.add(argv[++i]);
    } else if (argv[i] == '--canonical-functions') {
      canonicalFunctions = (jsonDecode(argv[++i]) as Map<String, Object?>)
          .cast<String, String>();
    } else if (argv[i] == '--bypass-allow') {
      bypassAllow = {
        for (final e in (jsonDecode(argv[++i]) as Map<String, Object?>).entries)
          e.key: (e.value as Map<String, Object?>).cast<String, String>(),
      };
    } else if (argv[i] == '--families') {
      families = {
        for (final e in (jsonDecode(argv[++i]) as Map<String, Object?>).entries)
          e.key: (e.value as Map<String, Object?>).cast<String, String>(),
      };
    } else {
      targets.add(argv[i]);
    }
  }
  final provider = PhysicalResourceProvider.INSTANCE;
  final context = provider.pathContext;
  root = context.normalize(context.absolute(root));
  if (targets.isEmpty) targets.add('apps/raft_flutter/lib');
  final included = [
    for (final t in targets) context.normalize(context.join(root, t)),
  ];
  final inventoryRoots = [
    for (final p in inventoryPrefixes) context.normalize(context.join(root, p)),
  ];
  final ownership = OwnershipInventory((file) {
    final path = context.normalize(context.absolute(file));
    return context.isWithin(root, path)
        ? context.relative(path, from: root).replaceAll('\\', '/')
        : null;
  }, canonicalFunctions: canonicalFunctions);
  final collection = AnalysisContextCollection(
    includedPaths: {...included, ...inventoryRoots}.toList(),
    resourceProvider: provider,
  );
  final contractRoots = [
    for (final p in contractPrefixes) context.normalize(context.join(root, p)),
  ];
  final bypassRoots = [
    for (final p in bypassPrefixes) context.normalize(context.join(root, p)),
  ];
  final duplicates = {
    for (final e in families.entries)
      e.key: DeprecatedDuplicate(
        e.value['family']!,
        context.normalize(context.join(root, e.value['file']!)),
      ),
  };
  final findings = <Finding>[];
  final generated = <String, int>{};
  final scanned = <String>[];
  final errors = <String>[];
  for (final analysis in collection.contexts) {
    final files = analysis.contextRoot.analyzedFiles().where(
      (f) => f.endsWith('.dart'),
    );
    for (final file in files.toList()..sort()) {
      final isStyle = included.any(
        (p) => file == p || context.isWithin(p, file),
      );
      final isInventory = inventoryRoots.any(
        (p) => file == p || context.isWithin(p, file),
      );
      if (!isStyle && !isInventory) {
        continue;
      }
      final isContract = contractRoots.any(
        (p) => file == p || context.isWithin(p, file),
      );
      final relative = context.relative(file, from: root).replaceAll('\\', '/');
      if ((isContract || isInventory && !isStyle) &&
          isGeneratedFile(relative)) {
        // Generated code is not audited for literals; recipe files only get
        // their constants counted (informational).
        if (isStyle) scanned.add(relative);
        if (isInventory) ownership.files.add(relative);
        final parsed = analysis.currentSession.getParsedUnit(file);
        if (parsed is! ParsedUnitResult) {
          errors.add('$file: not parseable');
        } else if (isGeneratedRecipeFile(relative)) {
          if (isStyle) {
            generated[relative] = countGeneratedRecipeConstants(parsed.unit);
          }
        }
        if (isInventory) {
          // Implicit constructor calls become precise after resolution. This
          // also inventories generated Widget code instead of letting a .g.dart
          // suffix hide a new component; literal style scopes stay unchanged.
          final resolved = await analysis.currentSession.getResolvedUnit(file);
          if (resolved is! ResolvedUnitResult) {
            errors.add('$relative: generated runtime input is not resolvable');
          } else {
            for (final d in resolved.diagnostics) {
              if (d.severity == Severity.error) {
                errors.add('$relative: ${d.message}');
              }
            }
            resolved.unit.accept(
              OwnershipVisitor(ownership, resolved, relative),
            );
            if (relative.startsWith('packages/raft_theme/lib/recipes/') &&
                !relative.startsWith(
                  'packages/raft_theme/lib/recipes/legacy/',
                )) {
              resolved.unit.accept(RecipeMetadataVisitor(ownership, relative));
            }
          }
        }
        continue;
      }
      final result = await analysis.currentSession.getResolvedUnit(file);
      if (result is! ResolvedUnitResult) {
        errors.add('$file: not resolvable');
        continue;
      }
      if (isStyle) scanned.add(relative);
      if (isInventory) {
        ownership.files.add(relative);
        result.unit.accept(OwnershipVisitor(ownership, result, relative));
      }
      for (final d in result.diagnostics) {
        if (d.severity == Severity.error) {
          final loc = result.lineInfo.getLocation(d.offset);
          errors.add('$relative:${loc.lineNumber}: ${d.message}');
        }
      }
      if (isStyle) {
        final AuditVisitorBase visitor = isContract
            ? ContractAuditVisitor(relative, result)
            : DsAuditVisitor(relative, result);
        result.unit.accept(visitor);
        findings.addAll(visitor.findings);
      }
      if (bypassRoots.any((p) => file == p || context.isWithin(p, file))) {
        final bypass = BypassAuditVisitor(
          relative,
          result,
          wrapperAllow: bypassAllow[relative] ?? const {},
        );
        result.unit.accept(bypass);
        findings.addAll(bypass.findings);
        if (duplicates.isNotEmpty) {
          final family = FamilyAuditVisitor(
            relative,
            result,
            duplicates,
            absolutePath: result.path,
          );
          result.unit.accept(family);
          findings.addAll(family.findings);
        }
      }
    }
  }
  await collection.dispose();
  stdout.writeln(
    const JsonEncoder.withIndent(' ').convert({
      'version': 1,
      'scanned': scanned,
      'errors': errors,
      'findings': [for (final f in findings) f.toJson()],
      'generated': {for (final e in generated.entries) e.key: e.value},
      if (inventoryPrefixes.isNotEmpty) 'ownership': ownership.toJson(),
    }),
  );
  if (errors.isNotEmpty) {
    stderr.writeln(
      'ds_audit: ${errors.length} analysis error(s); '
      'run tool/flutter pub get and fix them first:',
    );
    for (final e in errors.take(20)) {
      stderr.writeln('  $e');
    }
    exitCode = 2;
  }
}
