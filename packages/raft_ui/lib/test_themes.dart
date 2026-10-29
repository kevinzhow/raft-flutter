/// Which looks the Dart tests exercise, and how a theme matrix is cut.
///
/// Owner decision 2026-10-25: the regular checks test the Raft look only, in light and
/// dark. The legacy looks (Elegant, Brutal; frozen at a57b9dab) have their own on-demand
/// suite, `tool/theme-suite`. The selection lives here and nowhere else:
///
/// * `RAFT_TEST_LOOKS` is a comma list of `raft`, `elegant`, `brutal`, or `all`.
///   Unset means [raftDefaultLooks], the Raft look. `RAFT_TEST_ALL_THEMES=1`
///   (`tool/check-project --all-themes`) means all looks.
/// * `RAFT_TEST_MODES` is `light`, `dark` or `all` (default). Only `tool/theme-suite`
///   sets it; a matrix whose variants name their mode honours it.
///
/// A test file is tied to a look in one of three ways, all of which `tool/theme_looks.py`
/// recognises, so the runners know which files carry legacy cases:
///
/// * `@Tags(['look-elegant'])` / `@Tags(['look-brutal'])` before `library;`: the whole
///   file is about that look. The default run skips it (the runner never loads it).
/// * `raftThemeMatrix(variants, look: ...)`: a loop over looks. Variants of a look that is
///   not selected are not declared, so the default run keeps the Raft variants only.
/// * `skip: raftLookSkip(raftLookElegant)` on one test: that case needs a legacy look.
///
/// A test that names no look runs under the Raft look (the default theme) and is not
/// touched by any of this. Matrices that cross themes with sizes are cut to an L on the
/// gate, see [raftMatrixCell]; `RAFT_TEST_TIER=full` (the nightly) runs the product.
///
/// This library is for test code only (it uses `dart:io`); do not import it from app code.
library;

import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;

/// The Raft look: the base pack, the only look the regular checks test.
const raftLookRaft = 'raft';

/// A legacy look (frozen at a57b9dab).
const raftLookElegant = 'elegant';

/// A legacy look (frozen at a57b9dab).
const raftLookBrutal = 'brutal';

/// Every look, Raft first.
const raftAllLooks = [raftLookRaft, raftLookElegant, raftLookBrutal];

/// The looks a run without `RAFT_TEST_LOOKS` exercises. `tool/theme_looks.py` carries the
/// same default (a host test compares the two).
const raftDefaultLooks = [raftLookRaft];

/// The environment variable that picks the looks.
const raftLooksVariable = 'RAFT_TEST_LOOKS';

/// The environment variable that picks the modes (`light`, `dark`, `all`).
const raftModesVariable = 'RAFT_TEST_MODES';

/// The environment variable that turns every look and variant on (`check-project --all-themes`).
const raftAllThemesVariable = 'RAFT_TEST_ALL_THEMES';

/// True when every look must run.
bool get raftAllThemes => Platform.environment[raftAllThemesVariable] == '1';

/// The looks selected by [env] (pure; [raftSelectedLooks] reads the process environment).
///
/// An unknown look name is an error: a typo must not silently run nothing.
Set<String> selectLooks(Map<String, String> env) {
  if (env[raftAllThemesVariable] == '1') return {...raftAllLooks};
  final raw = (env[raftLooksVariable] ?? '').trim().toLowerCase();
  if (raw.isEmpty) return {...raftDefaultLooks};
  if (raw == 'all') return {...raftAllLooks};
  final looks = {for (final part in raw.split(',')) part.trim()}..remove('');
  final unknown = looks.where((look) => !raftAllLooks.contains(look));
  if (unknown.isNotEmpty) {
    throw StateError(
      '$raftLooksVariable names unknown look(s) ${unknown.join(', ')}; '
      'use ${raftAllLooks.join(', ')} or all.',
    );
  }
  return looks;
}

/// The modes selected by [env]: `{false}` is light only, `{true}` dark only (pure).
Set<bool> selectModes(Map<String, String> env) {
  switch ((env[raftModesVariable] ?? '').trim().toLowerCase()) {
    case '' || 'all':
      return {false, true};
    case 'light':
      return {false};
    case 'dark':
      return {true};
    case final other:
      throw StateError(
        '$raftModesVariable must be light, dark or all, got $other.',
      );
  }
}

/// The looks this run exercises.
Set<String> get raftSelectedLooks => selectLooks(Platform.environment);

/// Whether [look] is exercised by this run.
bool raftLookSelected(String look) => raftSelectedLooks.contains(look);

/// The `skip:` value of a test that needs [look] (or [other]): true when none of them is
/// selected. A test about two looks (a comparison) runs when either is selected. It is a
/// `bool` because `testWidgets` takes no reason string.
///
/// `testWidgets('...', body, skip: raftLookSkip(raftLookElegant))`.
bool raftLookSkip(String look, [String? other]) =>
    !raftLookSelected(look) && !(other != null && raftLookSelected(other));

/// The look a pack id or case name belongs to: `elegant-dark` and `elegant` are Elegant.
/// Anything that is neither Elegant nor Brutal is the Raft look.
String raftLookOf(String name) {
  final lower = name.toLowerCase();
  for (final look in [raftLookElegant, raftLookBrutal]) {
    if (lower.startsWith(look)) return look;
  }
  return raftLookRaft;
}

/// The environment variable that picks the test tier: `gate` (the default) or
/// `full`. `tool/check-project` sets it; the nightly runs `full`.
const raftTestTierVariable = 'RAFT_TEST_TIER';

/// True when a matrix that the gate cuts must run whole: the nightly
/// (`RAFT_TEST_TIER=full`) and every all-themes run.
bool get raftFullMatrix =>
    Platform.environment[raftTestTierVariable] == 'full' || raftAllThemes;

/// Whether the cell ([theme], [size]) of a theme x size matrix runs in this tier.
///
/// The gate runs an L: the default theme (index 0) at every size, and every
/// other theme at the first size (the phone, the cheapest and the one that
/// carries the most layout code). The full tier runs the whole product.
/// Declare the tests in the same loop order either way so names do not change.
bool raftMatrixCell({required int theme, required int size}) =>
    matrixCellRuns(full: raftFullMatrix, theme: theme, size: size);

/// The pure rule behind [raftMatrixCell].
bool matrixCellRuns({
  required bool full,
  required int theme,
  required int size,
}) => full || theme == 0 || size == 0;

/// The variants of [variants] this run declares tests for.
///
/// A variant is dropped when its look is not selected ([raftSelectedLooks]) or its mode is
/// not ([raftModesVariable]). [look] names a variant's look (`look: raftLookOf` for pack
/// ids, `look: (v) => raftLookOf(v.$1)` for records); without it every variant is the Raft
/// look. A variant's mode comes from [dark], or is read from a `bool`, a [ThemeMode], or a
/// name that contains `dark`; a variant whose mode cannot be read is never dropped for it.
/// With the default environment this is the whole Raft list, light and dark.
///
/// `full: true` marks a test that is ABOUT the mode difference (asserts per-mode colours,
/// contrast): it ignores [raftModesVariable] and keeps both modes. It never brings back a
/// look that is not selected.
List<T> raftThemeMatrix<T>(
  List<T> variants, {
  bool full = false,
  String Function(T variant)? look,
  bool Function(T variant)? dark,
}) => filterThemeVariants(
  variants,
  looks: raftSelectedLooks,
  modes: full ? {false, true} : selectModes(Platform.environment),
  look: look,
  dark: dark,
);

/// Pure rule behind [raftThemeMatrix].
List<T> filterThemeVariants<T>(
  List<T> variants, {
  required Set<String> looks,
  required Set<bool> modes,
  String Function(T variant)? look,
  bool Function(T variant)? dark,
}) {
  return [
    for (final variant in variants)
      if (looks.contains(look == null ? raftLookRaft : look(variant)) &&
          _modeRuns(modes, dark == null ? _modeOf(variant) : dark(variant)))
        variant,
  ];
}

bool _modeRuns(Set<bool> modes, bool? dark) =>
    dark == null || modes.contains(dark);

bool? _modeOf(Object? variant) => switch (variant) {
  final bool dark => dark,
  ThemeMode.dark => true,
  ThemeMode.light => false,
  final String name when name.toLowerCase().contains('dark') => true,
  final String name when name.toLowerCase().contains('light') => false,
  _ => null,
};
