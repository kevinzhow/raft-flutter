import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart';

/// Which look a parity case renders with.
///
/// This used to return only a `dark` bool, so every case painted the built-in
/// Raft pack and a "brutal" capture differed from Raft only by darkness. The
/// tests below therefore check the *pack*, not just the brightness -- brightness
/// alone cannot tell the three looks apart.
void main() {
  final official = <String, dynamic>{'id': 'components.ui.button.states'};
  final elegantNamed = <String, dynamic>{
    'id': 'components.ui.button.states.elegant',
  };
  ({String pack, bool dark}) byName(String name) =>
      parityThemeFor(official, override: name);

  test('official cases render the Raft pack', () {
    expect(parityThemeFor(official).pack, raftThemePackId);
    expect(parityThemeFor(elegantNamed).pack, raftThemePackId);
    // The historical `.elegant` suffix named the case, not the theme; the
    // official matrix is one look.
    expect(parityThemeFor(official).dark, isFalse);
  });

  test('supplemental runs select all three looks', () {
    expect(byName('brutal-light'), (pack: brutalThemePackId, dark: false));
    expect(byName('elegant-light'), (pack: elegantThemePackId, dark: false));
    expect(byName('elegant-dark'), (pack: elegantThemePackId, dark: true));
    expect(() => byName('elegant-black'), throwsArgumentError);
  });

  test('the two light looks are distinguishable, not just light', () {
    // The bug: both came back as "light" with no way to tell them apart.
    final brutal = byName('brutal-light');
    final elegant = byName('elegant-light');
    expect(brutal.dark, elegant.dark);
    expect(brutal.pack, isNot(elegant.pack));
  });

  test('extension cases name their theme', () {
    final dark = <String, dynamic>{
      'id': 'ext.case',
      'variants': [
        {
          'props': {'parityTheme': 'elegant-dark'},
        },
      ],
    };
    expect(parityThemeFor(dark).pack, elegantThemePackId);
    expect(parityThemeFor(dark).dark, isTrue);

    final brutal = <String, dynamic>{
      'id': 'ext.case',
      'variants': [
        {
          'props': {'parityTheme': 'brutal-light'},
        },
      ],
    };
    expect(parityThemeFor(brutal).pack, brutalThemePackId);
  });
  test('explicit Raft specimen modes never select the Elegant dark pack', () {
    for (final dark in [false, true]) {
      final visualCase = <String, dynamic>{
        'id': 'components.raft-ui.switch.states.${dark ? 'dark' : 'light'}',
        'variants': [
          {
            'props': {'parityTheme': dark ? 'raft-dark' : 'raft-light'},
          },
        ],
      };
      expect(parityThemeFor(visualCase), (pack: raftThemePackId, dark: dark));
    }
  });
}
