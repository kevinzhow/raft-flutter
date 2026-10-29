import 'package:shared_preferences/shared_preferences.dart';

import 'attachment_disk_cache.dart';
import 'device_preferences.dart';

/// The device preference behind Settings > Storage > Cache limit: the size cap
/// of the attachment cache, one of [attachmentCacheBudgetTiers]. Like the
/// layout choices it is read synchronously from the preloaded
/// [DevicePreferences], so the cache starts with the chosen cap and nothing
/// has to be re-trimmed after launch. Missing, unreadable or unknown values
/// mean the default ([attachmentCacheMaxBytes]).
class CacheBudget {
  CacheBudget._();

  static const preferenceKey = 'raft.cacheBudget';

  /// The chosen cap in bytes; always one of the tiers.
  static int stored([SharedPreferences? preferences]) {
    try {
      final value = (preferences ?? DevicePreferences.current)?.getInt(
        preferenceKey,
      );
      if (value != null && attachmentCacheBudgetTiers.contains(value)) {
        return value;
      }
    } catch (_) {
      // A value of another type: treated as unset.
    }
    return attachmentCacheMaxBytes;
  }

  /// Remembers [bytes] (a tier) for the next start; the default removes the
  /// key. Returns once written (or at once when no storage is available: the
  /// choice then lasts for this run only).
  static Future<void> save(int bytes) async {
    final preferences =
        DevicePreferences.current ?? await DevicePreferences.load();
    if (preferences == null) return;
    try {
      bytes == attachmentCacheMaxBytes
          ? await preferences.remove(preferenceKey)
          : await preferences.setInt(preferenceKey, bytes);
    } catch (_) {
      // Optional local storage.
    }
  }

  /// The label of a tier: `256 MB`, `1 GB`.
  static String label(int bytes) => bytes >= 1024 * 1024 * 1024
      ? '${bytes ~/ (1024 * 1024 * 1024)} GB'
      : '${bytes ~/ (1024 * 1024)} MB';
}
