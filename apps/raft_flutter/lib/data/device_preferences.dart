import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:raft_ui/raft_ui.dart' show RaftAppearance;
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronous view of the device preferences, preloaded once at app start so
/// the first frame can already use saved layout choices (panel widths,
/// sidebar disclosure, last evaluated feature flags) instead of laying out
/// defaults and jumping once SharedPreferences resolves.
///
/// When nothing was preloaded (a test or a preview that did not call [load])
/// every synchronous read reports "unknown" and callers keep their defaults.
class DevicePreferences {
  DevicePreferences._();
  static SharedPreferences? _current;

  /// The preloaded instance, or null before [load] completed.
  static SharedPreferences? get current => _current;

  /// Loads (or re-adopts) the preferences; failures leave them unavailable.
  static Future<SharedPreferences?> load() async {
    try {
      return _current = await SharedPreferences.getInstance();
    } catch (_) {
      return _current;
    }
  }

  /// Adopts an instance a caller already loaded.
  static void adopt(SharedPreferences preferences) => _current = preferences;

  /// Forgets the preloaded instance (tests).
  static void reset() => _current = null;
}

/// Last evaluated feature flags per server identity, so navigation that
/// depends on a flag renders its final shape on the first frame and the
/// fresh evaluation replaces the value in place. Only booleans keyed by flag
/// name are kept; the scope (origin, principal, server, role) is part of the
/// storage key.
class FeatureFlagMemory {
  FeatureFlagMemory._();
  static String _key(Iterable<Object?> scope) =>
      'raft:feature-flags:${jsonEncode(scope.toList())}';

  /// The last evaluated [flag] under [scope], or null when never evaluated.
  static bool? read(Iterable<Object?> scope, String flag) {
    final raw = DevicePreferences.current?.getString(_key(scope));
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      final flagValue = value is Map ? value[flag] : null;
      return flagValue is bool ? flagValue : null;
    } catch (_) {
      return null;
    }
  }

  /// Remembers the evaluated [flags] under [scope] (merged with earlier ones).
  static void write(Iterable<Object?> scope, Map<String, bool> flags) {
    final preferences = DevicePreferences.current;
    if (preferences == null) return;
    final key = _key(scope);
    var merged = <String, bool>{};
    try {
      final old = preferences.getString(key);
      final value = old == null ? null : jsonDecode(old);
      if (value is Map) {
        merged = {
          for (final e in value.entries)
            if (e.key is String && e.value is bool) e.key as String: e.value,
        };
      }
    } catch (_) {}
    merged.addAll(flags);
    preferences.setString(key, jsonEncode(merged));
  }
}

/// The key that held the old theme family (`brutal` | `elegant`), retired when the
/// app briefly had a single look. Theme choice is back, but under
/// [appearanceThemeKey] with theme-pack ids, so this key is dropped rather than
/// read: its values name families, not packs.
const retiredAppearanceThemeKey = 'raft.light';

/// The mode a stored `raft.mode` value means. Besides `light` | `dark` | `system`
/// it reads the retired theme ids: `brutal` and `elegantLight` are Light,
/// `elegantDark` is Dark. Unknown values mean no value.
ThemeMode? storedThemeMode(String? value) => switch (value) {
  'light' || 'brutal' || 'elegantLight' => ThemeMode.light,
  'dark' || 'elegantDark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  _ => null,
};

/// The appearance stored by the Appearance settings (`raft.mode`), read
/// synchronously so the very first built MaterialApp already uses the chosen
/// mode. A missing, unknown or unavailable value falls back to the default
/// (System). The retired `raft.light` family key is ignored: every earlier
/// family (Brutal, Elegant) is the one Raft look now, and `raft.mode` already
/// said Light, Dark or System.
RaftAppearance storedAppearance([SharedPreferences? preferences]) {
  final p = preferences ?? DevicePreferences.current;
  String? read(String key) {
    try {
      return p?.getString(key);
    } catch (_) {
      return null;
    }
  }

  const defaults = RaftAppearance();
  final storedTheme = read(appearanceThemeKey);
  return RaftAppearance(
    mode: storedThemeMode(read('raft.mode')) ?? defaults.mode,
    // An id naming no built-in theme is kept as written and resolved to the
    // Raft look at paint time, so a returning user sees their stored choice
    // rather than having it silently rewritten to 'raft'.
    themeId: storedTheme == null || storedTheme.isEmpty
        ? defaults.themeId
        : storedTheme,
  );
}

/// The stored theme id (`raft.theme`): which built-in theme to paint with,
/// independent of the Light / Dark / System choice in `raft.mode`.
const appearanceThemeKey = 'raft.theme';

/// Writes the appearance the settings page chose: the light/dark mode and the
/// theme id on their own keys, so choosing one never rewrites the other.
///
/// Kept here, next to [storedAppearance] and the retired-key cleanup, so the app
/// root only calls it; `app_root.dart` is a size-capped hotspot and this
/// persistence is not root logic.
Future<void> saveAppearance(
  SharedPreferences preferences,
  RaftAppearance appearance,
) async {
  await preferences.setString('raft.mode', appearance.mode.name);
  await preferences.setString(appearanceThemeKey, appearance.themeId);
  // The retired `raft.light` key must not come back; the native splash reads it.
  await preferences.remove(retiredAppearanceThemeKey);
}

/// Drops the retired `raft.light` key once, so the native launch screens (which
/// still read it) fall back to their default light canvas. Failures are ignored.
Future<void> retireStoredAppearanceTheme(SharedPreferences preferences) async {
  try {
    if (preferences.containsKey(retiredAppearanceThemeKey)) {
      await preferences.remove(retiredAppearanceThemeKey);
    }
  } catch (_) {}
}
