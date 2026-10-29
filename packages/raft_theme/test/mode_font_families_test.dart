import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

RaftThemePack fixture({
  Map<String, Object?> top = const {},
  Map<String, Object?> light = const {},
  Map<String, Object?> dark = const {},
}) => RaftThemePack.parse(
  jsonEncode({
    'format': 'raft-theme/1',
    'id': 'mode-font-fixture',
    'name': 'Mode font fixture',
    'version': '1.0.0',
    'extends': 'raft',
    ...top,
    'modes': {'light': light, 'dark': dark},
  }),
);
Map<String, Object?> font(String family) => {
  'family': family,
  'stack': [family, 'sans-serif'],
};
void main() {
  test('mode families precede top families and inherit missing roles from the base', () {
    final p = fixture(
      top: {
        'fonts': {'heading': font('Top Heading')},
      },
      light: {
        'fonts': {'sans': font('Light Body')},
      },
      dark: {
        'fonts': {'heading': font('Night Heading')},
      },
    );
    final light = p.resolve(dark: false, base: builtInRaftTheme).fonts;
    final dark = p.resolve(dark: true, base: builtInRaftTheme).fonts;
    expect(light['heading']!.family, 'Top Heading');
    expect(light['sans']!.family, 'Light Body');
    expect(light['mono']!.family, builtInRaftTheme.fonts['mono']!.family);
    expect(dark['heading']!.family, 'Night Heading');
    expect(dark['sans']!.family, builtInRaftTheme.fonts['sans']!.family);
    expect(dark['mono']!.stack, builtInRaftTheme.fonts['mono']!.stack);
  });
  test('font validation is identical at the top and mode positions', () {
    for (final bad in [
      {
        'sans': {'family': ''},
      },
      {
        'sans': {'family': 'Family', 'stack': 'bad'},
      },
      {
        'sans': {
          'family': 'Family',
          'stack': [1],
        },
      },
      {
        'sans': {'family': 'Family', 'asset': 1},
      },
    ]) {
      for (final atMode in [false, true]) {
        expect(
          () => fixture(
            top: atMode ? {} : {'fonts': bad},
            dark: atMode ? {'fonts': bad} : {},
          ),
          throwsA(
            predicate(
              (e) =>
                  e is RaftThemeException &&
                  e.where?.contains('.fonts.sans') == true,
            ),
          ),
        );
      }
    }
  });
  test('an existing asset declaration is retained at either position', () {
    final spec = {
      'sans': {
        'family': 'User Font',
        'stack': ['User Font'],
        'asset': 'fonts/body.ttf',
      },
    };
    final p = fixture(top: {'fonts': spec}, dark: {'fonts': spec});
    expect(p.resolve(dark: false).fonts['sans']!.asset, 'fonts/body.ttf');
    expect(p.resolve(dark: true).fonts['sans']!.asset, 'fonts/body.ttf');
  });
}
