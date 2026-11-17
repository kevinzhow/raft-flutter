import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves from before Elegant and Brutal were deleted keep `raft.theme` (the theme
/// id) and old `raft.mode` values. Raft is the only look: the theme id is ignored,
/// `raft.mode` still gives Light / Dark / System, and saving drops the stale key.
Future<SharedPreferences> _prefs(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  return SharedPreferences.getInstance();
}

void main() {
  const modes = {
    'dark': ThemeMode.dark,
    'light': ThemeMode.light,
    'system': ThemeMode.system,
    // Retired mode values: Brutal had no dark look, Elegant had both.
    'brutal': ThemeMode.light,
    'elegantLight': ThemeMode.light,
    'elegantDark': ThemeMode.dark,
  };

  for (final theme in ['elegant', 'brutal']) {
    for (final entry in modes.entries) {
      test(
        'raft.theme=$theme with raft.mode=${entry.key} reads as ${entry.value.name}',
        () async {
          final p = await _prefs({'raft.theme': theme, 'raft.mode': entry.key});
          final appearance = storedAppearance(p);
          expect(appearance.mode, entry.value);
          // The pack is Raft whatever the stored id said.
          expect(appearance.pack.id, raftThemePackId);
        },
      );
    }
  }

  testWidgets(
    'a stored legacy theme paints the Raft tokens in the stored mode',
    (tester) async {
      final raftLight = RaftTokens.theme(pack: packForThemeId(raftThemePackId));
      final raftDark = RaftTokens.theme(
        dark: true,
        pack: packForThemeId(raftThemePackId),
      );
      for (final theme in ['elegant', 'brutal']) {
        for (final (mode, dark) in [('light', false), ('dark', true)]) {
          final p = await _prefs({'raft.theme': theme, 'raft.mode': mode});
          final appearance = storedAppearance(p);
          // The app builds its themes from `appearance.pack` (app_viewport.dart).
          final built = RaftTokens.theme(dark: dark, pack: appearance.pack);
          final expected = dark ? raftDark : raftLight;
          expect(built.ink, expected.ink, reason: '$theme $mode');
          expect(built.radius, expected.radius, reason: '$theme $mode');
          expect(built.border, expected.border, reason: '$theme $mode');
          expect(built.dark, dark, reason: '$theme $mode');
          expect(
            raftTheme(dark: dark, pack: appearance.pack),
            isA<ThemeData>(),
          );
        }
      }
    },
  );

  test('a missing theme key and mode key read as System in Raft', () async {
    final p = await _prefs({});
    expect(storedAppearance(p).mode, ThemeMode.system);
    expect(storedAppearance(p).pack.id, raftThemePackId);
  });

  test('saving the appearance removes the stale raft.theme key', () async {
    for (final theme in ['elegant', 'brutal']) {
      final p = await _prefs({
        'raft.theme': theme,
        'raft.mode': 'elegantDark',
        'raft.light': theme,
      });
      await saveAppearance(p, storedAppearance(p));
      expect(p.containsKey('raft.theme'), isFalse, reason: theme);
      expect(p.containsKey('raft.light'), isFalse, reason: theme);
      // The old mode value is rewritten as the mode it meant.
      expect(p.getString('raft.mode'), 'dark', reason: theme);
      expect(storedAppearance(p).mode, ThemeMode.dark, reason: theme);
    }
  });
}
