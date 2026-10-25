import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_theme/src/contract_names.g.dart';

/// The test-only extreme user pack (tool/parity-ext/extreme_pack.py, docs/theme-contract.md section 8) must
/// pass the loader every user pack goes through, and must move every name the contract lets a pack set;
/// otherwise a hard-coded value could hide behind a role the pack never touched.
void main() {
  final pack = RaftThemePack.parse(
    File('../../apps/raft_flutter/test/parity/fixtures/extreme.theme.json')
        .readAsStringSync(),
    origin: 'extreme',
  );
  final raft = builtInRaftTheme;

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    final mine = pack.resolveIn({raft.id: raft}, dark: dark);
    final base = raft.resolve(dark: dark);

    test('$name: every colour role is set and differs from Raft', () {
      for (final role in raftColorRoles) {
        expect(mine.colors[role], isNotNull, reason: role);
        expect(mine.colors[role], isNot(base.colors[role]), reason: role);
      }
    });

    test('$name: every palette entry differs from Raft', () {
      for (final entry in base.palette.entries) {
        expect(mine.palette[entry.key], isNot(entry.value), reason: entry.key);
      }
    });

    test(
      '$name: every geometry token is set; radius and stroke follow the rule',
      () {
        for (final token in raftGeometryTokens) {
          final value = mine.geometry[token];
          final was = base.geometry[token]!;
          expect(value, isNotNull, reason: token);
          if (token.startsWith('radius.')) expect(value, anyOf(40, 31));
          if (token.startsWith('stroke.')) expect(value, anyOf(0, 0.75));
          // a zero size or spacing is a switch, not a length: it stays zero
          final zeroStays =
              was == 0 &&
              (token.startsWith('size.') || token.startsWith('space.'));
          if (!zeroStays && !token.startsWith('stroke.')) {
            expect(value, isNot(was), reason: token);
          }
        }
      },
    );

    test('$name: every type slot is larger and every shadow is off', () {
      for (final slot in raftTypeSlots) {
        expect(mine.type[slot]!.size, base.type[slot]!.size + 8, reason: slot);
      }
      for (final role in base.shadows.keys) {
        expect(mine.shadows[role], isEmpty, reason: role);
      }
    });
  }

  test('fonts are the pinned mono family and the pack extends Raft', () {
    expect(pack.extendsId, 'raft');
    expect(pack.builtIn, isFalse);
    for (final font in ['sans', 'heading', 'mono']) {
      expect(pack.fonts[font]!.family, 'Space Mono');
    }
  });
}
