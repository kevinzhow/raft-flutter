// Checks that the Dart cascade/var engine produces exactly the values the JS
// resolver (tool/recipes/lib/cascade.mjs) computed. The committed sample
// covers the first slot of every recipe; when `build/recipes/parity_cases.json`
// exists (after `tool/recipes/run`), all slots are checked.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/recipes.dart';

void main() {
  final files = [
    File('test/recipes/recipe_parity_cases.g.json'),
    File('../../build/recipes/parity_cases.json'),
  ];
  for (final file in files) {
    test('JS/Dart parity: ${file.path}', () {
      if (!file.existsSync()) {
        markTestSkipped('${file.path} not generated; run tool/recipes/run');
        return;
      }
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final cases = (data['cases'] as List).cast<Map<String, dynamic>>();
      expect(cases, isNotEmpty);
      final failures = <String>[];
      for (final c in cases) {
        final resolve = raftRecipes[c['recipe']]!;
        final props = (c['props'] as Map).map((k, v) => MapEntry(k as String, v as String?));
        final states = RaftRecipeStates(
          {...(c['flags'] as List).cast<String>()},
          (c['width'] as num?)?.toDouble(),
          (c['height'] as num?)?.toDouble(),
          (c['containerWidth'] as num?)?.toDouble(),
        );
        final style = resolve(props, states: states)[c['slot']]!;
        final actual = <String, Map<String, String>>{
          'self': _canon(style.properties),
          for (final e in style.targets.entries) e.key: _canon(e.value),
        };
        final expected = (c['expected'] as Map).map(
          (k, v) => MapEntry(k as String, (v as Map).map((p, x) => MapEntry(p as String, x as String))),
        );
        if (expected['self'] == null) expected['self'] = {};
        final where = '${c['recipe']}.${c['slot']} ${jsonEncode(props)} ${c['flags']}';
        for (final target in {...expected.keys, ...actual.keys}) {
          final e = expected[target] ?? const {};
          final a = actual[target] ?? const {};
          for (final p in {...e.keys, ...a.keys}) {
            if (e[p] != a[p]) failures.add('$where $target $p: expected ${e[p]} got ${a[p]}');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.take(20).join('\n'));
    });
  }
}

Map<String, String> _canon(Map<String, CssValue> m) => {
      for (final e in m.entries)
        if (!e.key.startsWith('--')) e.key: raftCssCanonical(e.value),
    };
