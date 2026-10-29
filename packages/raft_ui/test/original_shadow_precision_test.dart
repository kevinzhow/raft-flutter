@Tags(['look-brutal', 'look-elegant'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final id in [elegantThemePackId, brutalThemePackId]) {
    for (final dark in [false, true]) {
      test('original shadow layer precision $id/$dark', () {
        final original = jsonDecode(
          File('../../tool/theme-adapters/original_shadows.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>;
        final column = id == brutalThemePackId && !dark
            ? 'brutal'
            : dark
            ? 'elegantDark'
            : 'elegantLight';
        final source = original['layers'][column] as Map<String, dynamic>;
        final actual = RaftTokens.theme(
          pack: packForThemeId(id),
          dark: dark,
        ).themeShadows;
        List<Object> layers(RaftShadow shadow) => [
          for (final layer in shadow.layers)
            [
              layer.inset,
              layer.offset,
              layer.blur,
              layer.spread,
              layer.color.a,
              layer.color.r,
              layer.color.g,
              layer.color.b,
            ],
        ];
        for (final entry in {
          'xs': actual.xs,
          'sm': actual.sm,
          'md': actual.md,
          'lg': actual.lg,
          'xl': actual.xl,
        }.entries) {
          final expected = [
            for (final row in source[entry.key] as List)
              [
                row['inset'],
                Offset(
                  (row['x'] as num).toDouble(),
                  (row['y'] as num).toDouble(),
                ),
                row['blur'],
                row['spread'],
                ...row['color'] as List,
              ],
          ];
          expect(layers(entry.value), expected);
        }
      });
    }
  }
  test('original Brutal dialog border is its line ink', () {
    final t = RaftTokens.theme(pack: packForThemeId(brutalThemePackId));
    expect(t.colors['line-dialog'], const Color(0xff141110));
  });
  test('Elegant primary ring retains a57 float channels', () {
    final t = RaftTokens.theme(pack: packForThemeId(elegantThemePackId));
    final color = t.colors['primary-edge']!;
    expect(color.a, closeTo(.7, 1e-12));
    expect(color.r, closeTo(.911064, 1e-12));
    expect(color.g, closeTo(.771008, 1e-12));
    expect(color.b, closeTo(.306022, 1e-12));
  });
  test('Elegant dark line retains a57 float channels', () {
    final t = RaftTokens.theme(
      pack: packForThemeId(elegantThemePackId),
      dark: true,
    );
    final color = t.colors['line-muted']!;
    expect(color.a, closeTo(.101961, 1e-12));
    expect(color.r, closeTo(.943439, 1e-12));
    expect(color.g, closeTo(.943439, 1e-12));
    expect(color.b, closeTo(.945814, 1e-12));
  });
}
