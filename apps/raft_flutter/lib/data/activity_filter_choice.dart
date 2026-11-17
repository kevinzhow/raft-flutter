import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences.dart';

/// Web ThreadsInbox page size (inboxStore `PAGE_SIZE`); the server clamps at 100.
const activityPageSize = 50;

/// Web `ActivityFilterChoice`: what Activity's Filter menu offers. Pinned,
/// Saved and Artifacts are scopes over All, not read filters.
enum ActivityFilterChoice {
  all,
  unread,
  mentions,
  pinned,
  saved,
  artifacts;

  /// Unknown, retired (`done`, `dms`, `unfollowed`) or absent values are All.
  static ActivityFilterChoice parse(Object? raw) => values.firstWhere(
    (choice) => choice.name == raw,
    orElse: () => ActivityFilterChoice.all,
  );

  /// The choice for the `filter` and `scope` of a request (Web
  /// `activityFilterOf`); `unread_mentions` reads as its nearest, Mentions.
  static ActivityFilterChoice fromQuery(String filter, String? scope) {
    if (scope != null) return parse(scope);
    if (filter == 'unread_mentions') return mentions;
    return parse(filter);
  }

  bool get isScope => scope != null;

  /// The `scope` query value, or null for the read filters.
  String? get scope => switch (this) {
    pinned || saved || artifacts => name,
    _ => null,
  };

  /// The `filter` query value (the scopes read over All).
  String get readFilter => switch (this) {
    unread || mentions => name,
    _ => 'all',
  };

  /// `GET /channels/inbox` query of this choice, without the window.
  Map<String, String> get query => {
    'filter': readFilter,
    'scope': ?scope,
  };

  /// Empty-state copy, scope first, then mentions, then unread (Web
  /// ThreadsInbox). Keys of the zh catalog are these English strings.
  String get emptyTitle => switch (this) {
    pinned => 'No pinned conversations',
    saved => 'No saved threads',
    artifacts => 'No Artifacts here',
    mentions => 'No mentions',
    unread => 'No unread conversations',
    all => 'No conversations',
  };

  String get emptyDescription => switch (this) {
    pinned =>
      'Channels and DMs you pin in the sidebar show up here, with their threads.',
    saved => 'Save a message and its thread shows up here.',
    artifacts =>
      'Comment on an Artifact or follow it, and its new comments and versions show up here.',
    mentions =>
      'Channels, DMs, and threads where someone @mentions you will appear here.',
    _ => 'Channels, DMs, and followed threads stay here until they are done.',
  };
}

/// Web `activityFilterPreference`: the choice last made, kept per server under
/// `raft.activity.filter.<serverId>`. Reads use the preloaded
/// [DevicePreferences] so the first frame already shows the remembered list.
abstract final class ActivityFilterPreference {
  static const keyPrefix = 'raft.activity.filter.';

  static String key(String serverId) => '$keyPrefix$serverId';

  static ActivityFilterChoice read(String? serverId) {
    if (serverId == null || serverId.isEmpty) return ActivityFilterChoice.all;
    try {
      return ActivityFilterChoice.parse(
        DevicePreferences.current?.getString(key(serverId)),
      );
    } catch (_) {
      return ActivityFilterChoice.all;
    }
  }

  /// Remembers [choice]; All removes the key. Storage failures are ignored.
  static void write(String? serverId, ActivityFilterChoice choice) {
    if (serverId == null || serverId.isEmpty) return;
    final loaded = DevicePreferences.current;
    Future<void> store(SharedPreferences p) async {
      try {
        if (choice == ActivityFilterChoice.all) {
          await p.remove(key(serverId));
        } else {
          await p.setString(key(serverId), choice.name);
        }
      } catch (_) {
        /* optional local storage */
      }
    }

    if (loaded != null) {
      store(loaded);
    } else {
      SharedPreferences.getInstance().then(store, onError: (_) {});
    }
  }
}
