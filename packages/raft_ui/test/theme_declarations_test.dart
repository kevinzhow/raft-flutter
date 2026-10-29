import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/src/theme.dart';

void main() {
  final pack = RaftThemePack.parse(
    jsonEncode({
      'format': raftThemePackFormat,
      'id': 'user:declarations',
      'name': {'en': 'Explicit declarations'},
      'version': '1',
      'extends': 'raft',
      'modes': {
        'light': {
          'geometry': {'space.dialogBodyTop': 6},
        },
        'dark': {
          'geometry': {'space.dialogBodyTop': 11},
        },
      },
    }),
  );

  test('built-in defaults do not become user declarations', () {
    for (final builtIn in builtInThemes.values) {
      for (final dark in [false, true]) {
        expect(
          RaftTokens.theme(pack: builtIn, dark: dark).themeOverrides,
          isNull,
        );
      }
    }
  });
  test(
    'explicit default values survive resolution independently of omissions',
    () {
      final light = RaftTokens.theme(pack: pack);
      final dark = RaftTokens.theme(pack: pack, dark: true);
      expect(light.themeOverrides!.geometry, {'space.dialogBodyTop': 6});
      expect(dark.themeOverrides!.geometry, {'space.dialogBodyTop': 11});
      expect(light.themeValues!.geometry.containsKey('radius.dialog'), isTrue);
      expect(
        light.themeOverrides!.geometry.containsKey('radius.dialog'),
        isFalse,
      );
    },
  );
  test('a token copy retains the declared mode values', () {
    final source = RaftTokens.theme(pack: pack);
    expect(
      source.copyWith(colors: {...source.colors}).themeOverrides,
      same(source.themeOverrides),
    );
  });
}
