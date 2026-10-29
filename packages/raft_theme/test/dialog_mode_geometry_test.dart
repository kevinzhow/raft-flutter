import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

void main() {
  test('mode geometry overrides survive parsing and base resolution', () {
    final p = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'dialog-modes',
        'name': 'Dialog modes',
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          'light': {
            'geometry': {'space.dialogBodyTop': 20},
          },
          'dark': {
            'geometry': {'space.dialogBodyTop': 10},
          },
        },
      }),
    );
    expect(
      p
          .resolve(dark: false, base: builtInRaftTheme)
          .geometry['space.dialogBodyTop'],
      20,
    );
    expect(
      p
          .resolve(dark: true, base: builtInRaftTheme)
          .geometry['space.dialogBodyTop'],
      10,
    );
    expect(
      builtInElegantTheme
          .resolve(dark: true, base: builtInRaftTheme)
          .geometry['space.dialogBodyTop'],
      10,
    );
    expect(
      builtInBrutalTheme
          .resolve(dark: true, base: builtInRaftTheme)
          .geometry['space.dialogBodyTop'],
      10,
    );
  });
}
