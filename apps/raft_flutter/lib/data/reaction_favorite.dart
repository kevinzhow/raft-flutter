import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';

// The hover toolbar's reaction button shows the person's most-used reaction
// (Web 1.24 reactionFavorite.ts, Feishu-style): a click adds it, resting on the
// button opens every reaction. Usage is counted per user, per device, best
// effort: a storage failure only falls back to 👍.

const defaultFavoriteReaction = '👍';

/// Kept emoji; past it the least-used (then oldest) is dropped.
const reactionUsageLimit = 32;

/// One emoji's use count and the order of its last use (higher is newer).
typedef ReactionUsageEntry = ({int count, int lastUsedAt});
typedef ReactionUsage = Map<String, ReactionUsageEntry>;

/// The storage key for one person on one server origin (Web keys
/// `raft:reaction-usage:<userId>` in the origin's own localStorage).
String reactionUsageStorageKey(String origin, String userId) =>
    'raft:reaction-usage:${jsonEncode([origin, userId])}';

/// Reads stored usage; anything malformed counts as no usage.
ReactionUsage parseReactionUsage(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! Map) return {};
    return {
      for (final MapEntry(:key, :value) in parsed.entries)
        if (key is String &&
            value is Map &&
            value['count'] is num &&
            (value['count'] as num) > 0 &&
            value['lastUsedAt'] is num)
          key: (
            count: (value['count'] as num).toInt(),
            lastUsedAt: (value['lastUsedAt'] as num).toInt(),
          ),
    };
  } catch (_) {
    return {};
  }
}

String encodeReactionUsage(ReactionUsage usage) => jsonEncode({
  for (final MapEntry(:key, :value) in usage.entries)
    key: {'count': value.count, 'lastUsedAt': value.lastUsedAt},
});

/// Most count wins; a tie goes to the most recent; no usage means 👍.
String pickFavoriteReaction(ReactionUsage usage) {
  var favorite = defaultFavoriteReaction;
  ReactionUsageEntry? best;
  for (final MapEntry(key: emoji, value: entry) in usage.entries) {
    if (best == null ||
        entry.count > best.count ||
        (entry.count == best.count && entry.lastUsedAt > best.lastUsedAt)) {
      favorite = emoji;
      best = entry;
    }
  }
  return favorite;
}

/// One more use of [emoji]. Past [reactionUsageLimit] emoji the least-used
/// other one (the oldest among equals) goes, so a new emoji can still come in.
ReactionUsage addReactionUsage(ReactionUsage usage, String emoji, int now) {
  final next = {
    ...usage,
    emoji: (count: (usage[emoji]?.count ?? 0) + 1, lastUsedAt: now),
  };
  final others = next.entries.where((e) => e.key != emoji).toList();
  if (others.length < reactionUsageLimit) return next;
  others.sort(
    (a, b) => a.value.count != b.value.count
        ? a.value.count.compareTo(b.value.count)
        : a.value.lastUsedAt.compareTo(b.value.lastUsedAt),
  );
  for (final entry in others.take(others.length - reactionUsageLimit + 1)) {
    next.remove(entry.key);
  }
  return next;
}

/// This run's counts per person, read from storage on first use: a toolbar
/// reads the favorite each time it shows, so that read stays in memory.
final _usageCache = <String, ReactionUsage>{};

ReactionUsage _read(String key) {
  try {
    return parseReactionUsage(DevicePreferences.current?.getString(key));
  } catch (_) {
    return {};
  }
}

/// Counts one more [emoji] (a reaction the person added, from anywhere).
void recordReactionUsage(String origin, String? userId, String emoji) {
  if (userId == null || userId.isEmpty) return;
  final key = reactionUsageStorageKey(origin, userId);
  final next = addReactionUsage(
    _usageCache[key] ?? _read(key),
    emoji,
    DateTime.now().millisecondsSinceEpoch,
  );
  _usageCache[key] = next;
  Future<void> write(SharedPreferences preferences) async {
    try {
      await preferences.setString(key, encodeReactionUsage(next));
    } catch (_) {
      // Best effort: the next launch just doesn't learn from this reaction.
    }
  }

  final loaded = DevicePreferences.current;
  if (loaded != null) {
    write(loaded);
  } else {
    SharedPreferences.getInstance().then(write, onError: (_) {});
  }
}

/// The favorite as of now. A toolbar reads it when it shows and keeps it
/// while it shows, so the button never changes under the pointer.
String currentFavoriteReaction(String origin, String? userId) {
  if (userId == null || userId.isEmpty) return defaultFavoriteReaction;
  final key = reactionUsageStorageKey(origin, userId);
  return pickFavoriteReaction(_usageCache[key] ??= _read(key));
}

/// Tests: forget this run's counts, as a new launch would.
void resetReactionUsageCacheForTests() => _usageCache.clear();
