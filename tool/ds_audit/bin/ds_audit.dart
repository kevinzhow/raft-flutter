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
/// and only their recipe constants are counted. Exits 2 when a scanned file has
/// analysis errors, because unresolved code would silently undercount.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:ds_audit/contract_audit.dart';
import 'package:ds_audit/ds_audit.dart';

Future<void> main(List<String> argv) async {
  var root = Directory.current.path;
  final targets = <String>[];
  final contractPrefixes = <String>[];
  for (var i = 0; i < argv.length; i++) {
    if (argv[i] == '--root') {
      root = argv[++i];
    } else if (argv[i] == '--contract') {
      contractPrefixes.add(argv[++i]);
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
  final collection = AnalysisContextCollection(
    includedPaths: included,
    resourceProvider: provider,
  );
  final contractRoots = [
    for (final p in contractPrefixes) context.normalize(context.join(root, p)),
  ];
  final findings = <Finding>[];
  final generated = <String, int>{};
  final scanned = <String>[];
  final errors = <String>[];
  for (final analysis in collection.contexts) {
    final files = analysis.contextRoot.analyzedFiles().where(
      (f) => f.endsWith('.dart'),
    );
    for (final file in files.toList()..sort()) {
      if (!included.any((p) => file == p || context.isWithin(p, file))) {
        continue;
      }
      final isContract = contractRoots.any(
        (p) => file == p || context.isWithin(p, file),
      );
      final relative = context.relative(file, from: root).replaceAll('\\', '/');
      if (isContract && isGeneratedFile(relative)) {
        // Generated code is not audited for literals; recipe files only get
        // their constants counted (informational).
        scanned.add(relative);
        final parsed = analysis.currentSession.getParsedUnit(file);
        if (parsed is! ParsedUnitResult) {
          errors.add('$file: not parseable');
        } else if (isGeneratedRecipeFile(relative)) {
          generated[relative] = countGeneratedRecipeConstants(parsed.unit);
        }
        continue;
      }
      final result = await analysis.currentSession.getResolvedUnit(file);
      if (result is! ResolvedUnitResult) {
        errors.add('$file: not resolvable');
        continue;
      }
      scanned.add(relative);
      for (final d in result.diagnostics) {
        if (d.severity == Severity.error) {
          final loc = result.lineInfo.getLocation(d.offset);
          errors.add('$relative:${loc.lineNumber}: ${d.message}');
        }
      }
      final AuditVisitorBase visitor = isContract
          ? ContractAuditVisitor(relative, result)
          : DsAuditVisitor(relative, result);
      result.unit.accept(visitor);
      findings.addAll(visitor.findings);
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
