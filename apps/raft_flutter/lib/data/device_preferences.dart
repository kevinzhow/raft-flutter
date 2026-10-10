import 'dart:convert';

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
