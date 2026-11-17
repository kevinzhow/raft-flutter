import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/test_themes.dart';

const _packs = [('raft', false), ('raft', true)];

void main() {
  group('mode selection', () {
    test('modes', () {
      expect(selectModes({}), {false, true});
      expect(selectModes({raftModesVariable: 'all'}), {false, true});
      expect(selectModes({raftModesVariable: 'light'}), {false});
      expect(selectModes({raftModesVariable: 'DARK'}), {true});
      expect(() => selectModes({raftModesVariable: 'dim'}), throwsStateError);
    });
  });

  group('filterThemeVariants', () {
    List<(String, bool)> run({Set<bool> modes = const {false, true}}) =>
        filterThemeVariants(_packs, modes: modes, dark: (v) => v.$2);

    test('the whole list stays in order', () {
      expect(run(), _packs);
    });

    test('a mode narrows the list', () {
      expect(run(modes: {true}), [('raft', true)]);
      expect(run(modes: {false}), [('raft', false)]);
    });

    test('the mode is read from bool, ThemeMode and names', () {
      List<Object> keep(List<Object> variants) =>
          filterThemeVariants(variants, modes: {true});
      expect(keep([false, true]), [true]);
      expect(keep([ThemeMode.light, ThemeMode.dark]), [ThemeMode.dark]);
      expect(keep(['light', 'dark', 'Dark mode']), ['dark', 'Dark mode']);
      expect(keep([42]), [42], reason: 'a variant with no readable mode stays');
    });
  });

  test('raftThemeMatrix reads the environment', () {
    expect(raftThemeMatrix(_packs, dark: (v) => v.$2), isNotEmpty);
    expect(raftThemeMatrix([false, true], full: true), hasLength(2));
  });

  group('theme x size L-shape', () {
    int count({required bool full, int themes = 3, int sizes = 3}) => [
      for (var t = 0; t < themes; t++)
        for (var z = 0; z < sizes; z++)
          if (matrixCellRuns(full: full, theme: t, size: z)) (t, z),
    ].length;

    test('the gate runs the default theme at every size and the others at the first', () {
      expect(
        count(full: false),
        3 + 2,
      ); // default theme x 3 sizes, 2 themes x phone
      expect(matrixCellRuns(full: false, theme: 0, size: 2), isTrue);
      expect(matrixCellRuns(full: false, theme: 1, size: 0), isTrue);
      expect(matrixCellRuns(full: false, theme: 1, size: 1), isFalse);
      expect(matrixCellRuns(full: false, theme: 2, size: 2), isFalse);
    });

    test('the full tier runs the whole product', () {
      expect(count(full: true), 9);
    });

    test('the tier comes from the environment', () {
      expect(
        raftFullMatrix,
        Platform.environment[raftTestTierVariable] == 'full',
      );
      expect(raftMatrixCell(theme: 1, size: 1), raftFullMatrix);
      expect(raftMatrixCell(theme: 0, size: 2), isTrue);
    });
  });
}
