import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/test_themes.dart';

const _packs = [
  ('raft', false),
  ('raft', true),
  ('brutal', false),
  ('elegant', false),
  ('elegant', true),
];

void main() {
  group('look selection', () {
    test('the default is the Raft look only', () {
      expect(selectLooks({}), {'raft'});
      expect(selectLooks({raftLooksVariable: ''}), {'raft'});
      expect(raftDefaultLooks, ['raft']);
    });

    test('a comma list, all, and the all-themes switch', () {
      expect(selectLooks({raftLooksVariable: 'elegant'}), {'elegant'});
      expect(selectLooks({raftLooksVariable: ' Elegant , brutal '}), {
        'elegant',
        'brutal',
      });
      expect(selectLooks({raftLooksVariable: 'all'}), {...raftAllLooks});
      expect(selectLooks({raftAllThemesVariable: '1'}), {...raftAllLooks});
      expect(
        selectLooks({raftAllThemesVariable: '1', raftLooksVariable: 'raft'}),
        {...raftAllLooks},
      );
    });

    test('an unknown look is an error, not an empty run', () {
      expect(
        () => selectLooks({raftLooksVariable: 'elegent'}),
        throwsStateError,
      );
    });

    test('modes', () {
      expect(selectModes({}), {false, true});
      expect(selectModes({raftModesVariable: 'all'}), {false, true});
      expect(selectModes({raftModesVariable: 'light'}), {false});
      expect(selectModes({raftModesVariable: 'DARK'}), {true});
      expect(() => selectModes({raftModesVariable: 'dim'}), throwsStateError);
    });

    test('the process environment decides raftLookSkip', () {
      final selected = raftSelectedLooks;
      expect(raftLookSkip(raftLookRaft), !selected.contains('raft'));
      expect(raftLookSkip(raftLookElegant), !selected.contains('elegant'));
      expect(
        raftLookSkip(raftLookElegant, raftLookBrutal),
        !selected.contains('elegant') && !selected.contains('brutal'),
        reason: 'a comparison runs when either look is selected',
      );
    });
  });

  group('raftLookOf', () {
    test('names and pack ids map to a look', () {
      expect(raftLookOf('raft'), 'raft');
      expect(raftLookOf('elegant'), 'elegant');
      expect(raftLookOf('elegant-dark'), 'elegant');
      expect(raftLookOf('brutal-light'), 'brutal');
      expect(raftLookOf('Brutal'), 'brutal');
      expect(raftLookOf('light'), 'raft');
      expect(raftLookOf('a-user-pack'), 'raft');
    });
  });

  group('filterThemeVariants', () {
    List<(String, bool)> run(
      Set<String> looks, {
      Set<bool> modes = const {false, true},
    }) => filterThemeVariants(
      _packs,
      looks: looks,
      modes: modes,
      look: (v) => raftLookOf(v.$1),
      dark: (v) => v.$2,
    );

    test('Raft only keeps light and dark Raft, no legacy variant', () {
      expect(run({'raft'}), [('raft', false), ('raft', true)]);
    });

    test('a legacy look keeps all of its variants and nothing else', () {
      expect(run({'elegant'}), [('elegant', false), ('elegant', true)]);
      expect(run({'brutal'}), [('brutal', false)]);
    });

    test('all looks keep the whole list in order', () {
      expect(run({...raftAllLooks}), _packs);
    });

    test('a mode narrows every look', () {
      expect(run({...raftAllLooks}, modes: {true}), [
        ('raft', true),
        ('elegant', true),
      ]);
      expect(run({'brutal'}, modes: {true}), isEmpty);
    });

    test('variants without a look extractor are the Raft look', () {
      expect(
        filterThemeVariants(
          [false, true],
          looks: {'elegant'},
          modes: {false, true},
        ),
        isEmpty,
      );
      expect(
        filterThemeVariants([false, true], looks: {'raft'}, modes: {false}),
        [false],
      );
    });

    test('the mode is read from bool, ThemeMode and names', () {
      List<Object> keep(List<Object> variants) =>
          filterThemeVariants(variants, looks: {'raft'}, modes: {true});
      expect(keep([false, true]), [true]);
      expect(keep([ThemeMode.light, ThemeMode.dark]), [ThemeMode.dark]);
      expect(keep(['light', 'dark', 'Dark mode']), ['dark', 'Dark mode']);
      expect(keep([42]), [42], reason: 'a variant with no readable mode stays');
    });
  });

  test('raftThemeMatrix reads the environment', () {
    final all = raftThemeMatrix(
      _packs,
      look: (v) => raftLookOf(v.$1),
      dark: (v) => v.$2,
    );
    expect(all.every((v) => raftSelectedLooks.contains(v.$1)), isTrue);
    expect(
      raftThemeMatrix([false, true], full: true),
      raftSelectedLooks.contains('raft') ? hasLength(2) : isEmpty,
      reason: 'a variant with no look is the Raft look',
    );
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
        Platform.environment[raftTestTierVariable] == 'full' || raftAllThemes,
      );
      expect(raftMatrixCell(theme: 1, size: 1), raftFullMatrix);
      expect(raftMatrixCell(theme: 0, size: 2), isTrue);
    });
  });
}
