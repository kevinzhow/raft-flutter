/// How the Dart tests cut a theme matrix.
///
/// Raft (light and dark) is the only look, so a matrix lists Raft variants only. The
/// selection lives here and nowhere else:
///
/// * `RAFT_TEST_MODES` is `light`, `dark` or `all` (default). Only `tool/theme-suite`
///   sets it; a matrix whose variants name their mode honours it.
/// * `RAFT_TEST_TIER=full` (the nightly) runs a theme x size matrix whole; the gate cuts
///   it to an L, see [raftMatrixCell].
///
/// This library is for test code only (it uses `dart:io`); do not import it from app code.
library;

import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;

/// The environment variable that picks the modes (`light`, `dark`, `all`).
const raftModesVariable = 'RAFT_TEST_MODES';

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

/// The environment variable that picks the test tier: `gate` (the default) or
/// `full`. `tool/check-project` sets it; the nightly runs `full`.
const raftTestTierVariable = 'RAFT_TEST_TIER';

/// True when a matrix that the gate cuts must run whole: the nightly
/// (`RAFT_TEST_TIER=full`).
bool get raftFullMatrix => Platform.environment[raftTestTierVariable] == 'full';

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
/// A variant is dropped when its mode is not selected ([raftModesVariable]). A variant's
/// mode comes from [dark], or is read from a `bool`, a [ThemeMode], or a name that
/// contains `dark`; a variant whose mode cannot be read is never dropped for it. With the
/// default environment this is the whole list, light and dark.
///
/// `full: true` marks a test that is ABOUT the mode difference (asserts per-mode colours,
/// contrast): it ignores [raftModesVariable] and keeps both modes.
List<T> raftThemeMatrix<T>(
  List<T> variants, {
  bool full = false,
  bool Function(T variant)? dark,
}) => filterThemeVariants(
  variants,
  modes: full ? {false, true} : selectModes(Platform.environment),
  dark: dark,
);

/// Pure rule behind [raftThemeMatrix].
List<T> filterThemeVariants<T>(
  List<T> variants, {
  required Set<bool> modes,
  bool Function(T variant)? dark,
}) {
  return [
    for (final variant in variants)
      if (_modeRuns(modes, dark == null ? _modeOf(variant) : dark(variant)))
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
