// Entry point for the Flutter `android` provider. Driven by tool/parity; a
// plain `flutter test` (no PARITY_SHARED_DIR) skips it.
//
// Env:
//   PARITY_SHARED_DIR   raft-source packages/visual-testing/shared
//   PARITY_RESULT_ROOT  <out>/visual-testing-results (writes android/)
//   PARITY_CASES        optional comma list of ids / globs (`components.ui.*`)
//   PARITY_RUN_INFO     optional JSON merged into metadata.flutter
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'case_map.dart';
import 'parity_harness.dart';

void main() {
  final env = Platform.environment;
  final sharedDir = env['PARITY_SHARED_DIR'];
  final resultRoot = env['PARITY_RESULT_ROOT'];
  if (sharedDir == null || resultRoot == null) {
    test('parity capture (set PARITY_SHARED_DIR/PARITY_RESULT_ROOT)', () {}, skip: true);
    return;
  }
  final manifest =
      json.decode(File('$sharedDir/sharedCases.json').readAsStringSync())
          as Map<String, dynamic>;
  final fixtures = <String, dynamic>{};
  for (final file in Directory(sharedDir).listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (!name.endsWith('.json')) continue;
    fixtures[name.substring(0, name.length - 5)] = json.decode(
      file.readAsStringSync(),
    );
  }
  final patterns = (env['PARITY_CASES'] ?? '')
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .map((p) => RegExp('^${RegExp.escape(p).replaceAll(r'\*', '.*')}\$'))
      .toList();
  bool skipped(Map c) {
    final s = c['skip'];
    return s == true || (s is Map && s['enabled'] != false);
  }

  final selected = (manifest['cases'] as List)
      .cast<Map<String, dynamic>>()
      .where((c) => !skipped(c) && c['baselineStatus'] != 'pending')
      .where(
        (c) =>
            patterns.isEmpty ||
            patterns.any((p) => p.hasMatch(c['id'] as String)),
      )
      .toList();
  final runInfo = env['PARITY_RUN_INFO'] == null
      ? <String, dynamic>{}
      : json.decode(env['PARITY_RUN_INFO']!) as Map<String, dynamic>;
  final outputDir = Directory('$resultRoot/android')
    ..createSync(recursive: true);
  final captured = <String, Map<String, dynamic>>{};
  final shardIndex = int.tryParse(env['PARITY_SHARD_INDEX'] ?? '') ?? 0;
  final shardTotal = int.tryParse(env['PARITY_SHARD_TOTAL'] ?? '') ?? 1;

  setUpAll(() async {
    await loadParityFonts();
  });
  tearDownAll(() {
    if (shardIndex == 0) {
      // Full explicit coverage map for every case in the manifest.
      File('$resultRoot/android-case-map.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          for (final c in (manifest['cases'] as List).cast<Map>())
            c['id']: switch ((parityCases[c['id']], parityUncovered[c['id']])) {
              (final ParityCase m?, _) => {
                'status': 'mapped',
                'widgets': m.widgets,
                if (m.notes.isNotEmpty) 'notes': m.notes,
              },
              (_, final ParityUncovered u?) => {
                'status': u.gap.name,
                'reason': u.reason,
              },
              _ => {
                'status': ParityGap.harnessTodo.name,
                'reason': 'No Flutter builder mapped yet.',
              },
            },
        }),
      );
    }
    File(
      '${outputDir.path}/../android-coverage.shard$shardIndex.json',
    ).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'shard': '$shardIndex/$shardTotal',
        'selected': [
          for (final (i, c) in selected.indexed)
            if (i % shardTotal == shardIndex) c['id'],
        ],
        'captured': captured.keys.toList(),
      }),
    );
  });

  for (final (i, visualCase) in selected.indexed) {
    if (i % shardTotal != shardIndex) continue;
    final id = visualCase['id'] as String;
    final mapping = parityCases[id];
    if (mapping == null) continue;
    testWidgets('parity $id', (t) async {
      final meta = await captureParityCase(
        t,
        visualCase: visualCase,
        mapping: mapping,
        fixtures: fixtures,
        outputDir: outputDir,
        runInfo: runInfo,
      );
      captured[id] = meta;
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
