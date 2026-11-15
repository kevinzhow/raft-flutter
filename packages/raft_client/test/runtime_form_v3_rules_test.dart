// Runtime form v3 condition conformance.
//
// Source: raft-source packages/runtime-form/fixtures/v3.conditions.conformance.json
// and src/v3Rules.test.ts at tag v1.24.0-source.1 (public source mirror). The
// JSON is copied unchanged to test/fixtures/runtime_form/.
import 'dart:convert';
import 'dart:io';

import 'package:raft_client/src/runtime_form_v3_rules.dart';
import 'package:test/test.dart';

Directory fixtureDir() => Directory(
  [
    'test/fixtures/runtime_form',
    'packages/raft_client/test/fixtures/runtime_form',
    '../../packages/raft_client/test/fixtures/runtime_form',
  ].firstWhere((path) => Directory(path).existsSync()),
);

void main() {
  final table = jsonDecode(
    File('${fixtureDir().path}/v3.conditions.conformance.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (table['cases'] as List).cast<Map<String, dynamic>>();
  final unsupported = (table['unsupported'] as List)
      .cast<Map<String, dynamic>>();

  test('every condition case evaluates to its expected value', () {
    expect(cases.length, greaterThan(20));
    for (final entry in cases) {
      final name = entry['name'] as String;
      final condition = entry['condition'] as Map<String, dynamic>;
      final scope = runtimeFormV3ScopeKey(condition['scope']);
      expect(scope, isNotNull, reason: '$name: scope');
      expect(
        isSupportedRuntimeFormV3Schema(condition['schema']),
        isTrue,
        reason: '$name: supported',
      );
      final parsed = RuntimeFormV3Condition(
        scope!.key,
        Map<String, dynamic>.from(condition['schema'] as Map),
      );
      expect(
        parsed.evaluate(Map<String, dynamic>.from(entry['data'] as Map)),
        entry['expected'],
        reason: name,
      );
    }
  });

  test('every unsupported schema is reported unsupported', () {
    expect(unsupported, isNotEmpty);
    for (final entry in unsupported) {
      expect(
        isSupportedRuntimeFormV3Schema(entry['schema']),
        isFalse,
        reason: entry['name'] as String,
      );
    }
  });

  test(
    'every pattern in the served v3 fixtures is inside the portable subset',
    () {
      final patterns = <String>{};
      void collect(Object? value) {
        if (value is List) {
          value.forEach(collect);
        } else if (value is Map) {
          for (final entry in value.entries) {
            if (entry.key == 'pattern' && entry.value is String) {
              patterns.add(entry.value as String);
            }
            collect(entry.value);
          }
        }
      }

      for (final file in fixtureDir().listSync().whereType<File>().where(
        (f) => f.path.endsWith('.v3.json'),
      )) {
        collect(jsonDecode(file.readAsStringSync()));
      }
      expect(patterns, contains('^connection:'));
      for (final pattern in patterns) {
        expect(
          isPortableRuntimeFormV3Pattern(pattern),
          isTrue,
          reason: pattern,
        );
      }
    },
  );

  test(
    'scopes: # is the whole values, #/properties/<key> one field, else unknown',
    () {
      expect(runtimeFormV3ScopeKey('#')!.key, isNull);
      expect(
        runtimeFormV3ScopeKey('#/properties/providerId')!.key,
        'providerId',
      );
      for (final scope in <Object?>[
        '#/properties/',
        '#/properties/a/b',
        '/providerId',
        1,
        null,
      ]) {
        expect(runtimeFormV3ScopeKey(scope), isNull, reason: '$scope');
      }
    },
  );
}
