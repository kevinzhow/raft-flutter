import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart';

/// Which pack and brightness a parity case renders with. Raft is the only
/// look; a theme name only selects the brightness.
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

  test('supplemental runs select the brightness in the Raft pack', () {
    expect(byName('brutal-light'), (pack: raftThemePackId, dark: false));
    expect(byName('brutal-dark'), (pack: raftThemePackId, dark: true));
    expect(byName('elegant-light'), (pack: raftThemePackId, dark: false));
    expect(byName('elegant-dark'), (pack: raftThemePackId, dark: true));
    expect(() => byName('elegant-black'), throwsArgumentError);
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
    expect(parityThemeFor(dark).pack, raftThemePackId);
    expect(parityThemeFor(dark).dark, isTrue);

    final brutal = <String, dynamic>{
      'id': 'ext.case',
      'variants': [
        {
          'props': {'parityTheme': 'brutal-light'},
        },
      ],
    };
    expect(parityThemeFor(brutal).pack, raftThemePackId);
    expect(parityThemeFor(brutal).dark, isFalse);
  });
  test('explicit Raft specimen modes select the Raft pack', () {
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
  test('capture labels retain the selected pack and brightness', () {
    expect(
      parityThemeLabel((pack: raftThemePackId, dark: false)),
      'raft-light',
    );
    expect(parityThemeLabel((pack: raftThemePackId, dark: true)), 'raft-dark');
  });
}
