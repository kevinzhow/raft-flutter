import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart';

void main() {
  final brutal = <String, dynamic>{'id': 'components.ui.button.states'};
  final elegant = <String, dynamic>{
    'id': 'components.ui.button.states.elegant',
  };
  test('official themes retain the original case contract', () {
    expect(parityThemeFor(brutal), (RaftFamily.brutal, false));
    expect(parityThemeFor(elegant), (RaftFamily.elegant, false));
  });
  test('supplemental themes override both families and mode explicitly', () {
    for (final c in [brutal, elegant]) {
      expect(parityThemeFor(c, override: 'brutal-light'), (
        RaftFamily.brutal,
        false,
      ));
      expect(parityThemeFor(c, override: 'elegant-light'), (
        RaftFamily.elegant,
        false,
      ));
      expect(parityThemeFor(c, override: 'elegant-dark'), (
        RaftFamily.elegant,
        true,
      ));
      expect(
        () => parityThemeFor(c, override: 'elegant-black'),
        throwsArgumentError,
      );
    }
  });
}
