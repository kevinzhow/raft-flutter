import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart';

/// `tool/parity-ext/run regress` renders one extension case list in every look:
/// `<look>-case` forces the look and keeps the brightness the case names itself.
void main() {
  Map<String, dynamic> named(String theme) => {
    'id': 'components.shell.desktop.sidebar.default.x',
    'variants': [
      {
        'props': {'parityTheme': theme},
      },
    ],
  };

  test('raft-case renders every case name in the Raft pack', () {
    for (final entry in {
      'brutal-light': false,
      'elegant-light': false,
      'elegant-dark': true,
    }.entries) {
      expect(parityThemeFor(named(entry.key), override: 'raft-case'), (
        pack: raftThemePackId,
        dark: entry.value,
      ), reason: entry.key);
    }
  });

  test('elegant-case and brutal-case force the pack, brightness follows', () {
    expect(parityThemeFor(named('elegant-dark'), override: 'elegant-case'), (
      pack: elegantThemePackId,
      dark: true,
    ));
    expect(parityThemeFor(named('brutal-light'), override: 'brutal-case'), (
      pack: brutalThemePackId,
      dark: false,
    ));
  });

  test('an official case with no theme prop is light under <look>-case', () {
    final official = <String, dynamic>{'id': 'components.ui.button.states'};
    expect(parityThemeFor(official, override: 'raft-case'), (
      pack: raftThemePackId,
      dark: false,
    ));
  });

  test('the plain override names keep their meaning', () {
    expect(parityThemeFor(named('brutal-light'), override: 'elegant-dark'), (
      pack: elegantThemePackId,
      dark: true,
    ));
    expect(
      () => parityThemeFor(named('x'), override: 'unknown-case'),
      throwsArgumentError,
    );
  });
}
