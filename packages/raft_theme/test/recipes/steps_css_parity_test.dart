import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/recipes/recipe_runtime.dart';
import 'package:raft_theme/recipes/steps_css.g.dart';

Object? _canonical(Object? v) {
  if (v is num) return (v * 1000000).round() / 1000000;
  if (v is List) return v.map(_canonical).toList();
  if (v is Map)
    return {
      for (final e in v.entries)
        // CssColor.toJson intentionally omits its original spelling. ARGB is
        // still compared exactly; no paint or cascade property is excluded.
        if (e.value != null && !(v['t'] == 'color' && e.key == 'src'))
          e.key: _canonical(e.value),
    };
  return v;
}

bool deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map)
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && deepEquals(a[k], b[k]));
  if (a is List && b is List)
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => deepEquals(a[i], b[i]));
  return a == b;
}

// Flutter's test engine does not implement Isolate package-URI resolution.
// Follow this workspace's actual package_config instead; never infer a fixture
// from the test process's cwd or choose another generated version.
File _stepsFixture() {
  var directory = Directory.current.absolute;
  while (true) {
    final configFile = File.fromUri(
      directory.uri.resolve('.dart_tool/package_config.json'),
    );
    if (configFile.existsSync()) {
      final config = jsonDecode(configFile.readAsStringSync()) as Map;
      final package = (config['packages'] as List).cast<Map>().singleWhere(
        (entry) => entry['name'] == 'raft_theme',
      );
      final packageRoot = Directory.fromUri(
        configFile.uri.resolve(package['rootUri'] as String),
      );
      return File.fromUri(
        packageRoot.uri.resolve('test/recipes/steps_css_cases.g.json'),
      );
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Workspace package_config.json not found');
    }
    directory = parent;
  }
}

void main() {
  test('published Steps CSS Node/Dart parity covers every slot/configuration/environment', () {
    final data = jsonDecode(_stepsFixture().readAsStringSync()) as Map;
    expect(data['source']['sha256'], RaftStepsCssRecipe.sourceSha256);
    final cases = data['cases'] as List;
    expect(cases.length, 3072);
    final pool = data['stylePool'] as List;
    final failures = <String>[];
    for (var index = 0; index < cases.length; index++) {
      final c = cases[index] as Map;
      final config = c['config'] as Map;
      final slots = RaftStepsCssRecipe.resolve(
        status: RaftStepsCssStatus.values.byName(config['status'] as String),
        orientation: RaftStepsCssOrientation.values.byName(
          config['orientation'] as String,
        ),
        last: config['last'] as bool,
        clickable: config['clickable'] as bool,
        disabled: config['disabled'] as bool,
        states: RaftRecipeStates(
          (c['flags'] as List).cast<String>().toSet(),
          (c['width'] as num?)?.toDouble(),
        ),
      );
      for (final name in RaftStepsCssRecipe.slotNames) {
        final actual = _canonical({
          for (final e in slots[name]!.properties.entries)
            e.key: e.value.toJson(),
        });
        final expected = _canonical(pool[c['expected'][name] as int]);
        if (!deepEquals(actual, expected))
          failures.add('$index $name expected=$expected actual=$actual');
      }
    }
    expect(failures, isEmpty, reason: failures.take(10).join('\n'));
  });
}
