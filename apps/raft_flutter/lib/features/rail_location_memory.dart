import 'dart:async';

import 'package:raft_client/raft_client.dart';

import '../data/device_preferences.dart';
import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_navigation.dart';

/// The rail modes that remember where the user was (Web
/// `useTabRouteMemory.classifyRouteForTab`). Search and Activity are not
/// memorized: every entry starts at their canonical landing, and Search must
/// never overwrite the Chat slot.
const memorizedRailModes = {
  'chat',
  'tasks',
  'members',
  'computers',
  'settings',
};

/// Which memorized rail mode a location belongs to, or null (Search, Activity,
/// unknown) when it belongs to none and must leave every slot alone.
String? railModeOfLocation(RaftLocation location) => switch (location.route) {
  RaftRoute.home ||
  RaftRoute.channel ||
  RaftRoute.dm ||
  RaftRoute.saved => 'chat',
  RaftRoute.tasks => 'tasks',
  RaftRoute.members ||
  RaftRoute.agent ||
  RaftRoute.human ||
  RaftRoute.memberGraph => 'members',
  RaftRoute.computers || RaftRoute.computer => 'computers',
  RaftRoute.settings || RaftRoute.releaseNotes => 'settings',
  _ => null,
};

/// Web `useTabRouteMemory` + `useRailMode.selectRailMode`: selecting a rail
/// mode returns to the last location visited in it (a profile, a computer, a
/// settings page, the open conversation and its thread) instead of its root.
///
/// One slot per account, server and mode, kept across restarts. Recording
/// follows every accepted location; the preferences are only written when a
/// slot changes. The phone's tab bar does not use it: a tab press there always
/// opens the tab root (docs/source-navigation-contract.md, PUSH rule 7).
class RailLocationMemory {
  RailLocationMemory();

  final _last = <String, String>{};

  String? _key(WorkspaceController w, String slug, String mode) {
    final user = w.client.user?.id;
    return user == null
        ? null
        : 'raft.rail-memory.v1.${Uri.encodeComponent(w.client.origin)}.$user.$slug.$mode';
  }

  /// Remembers [w]'s accepted location under its rail mode.
  void record(WorkspaceController w) {
    final slug = w.server?.string('slug');
    if (slug == null || slug.isEmpty) return;
    final location = w.location;
    if (location.serverSlug != slug) return;
    final mode = railModeOfLocation(location);
    final key = mode == null ? null : _key(w, slug, mode);
    if (key == null) return;
    final value = location.toString();
    if (_last[key] == value) return;
    _last[key] = value;
    unawaited(
      DevicePreferences.current?.setString(key, value).catchError((_) => false),
    );
  }

  /// The remembered location of [mode] for the open workspace, or null when
  /// nothing valid is stored: a slot that no longer belongs to its mode, to
  /// this server, or to a page this account may visit is dropped.
  RaftLocation? recall(WorkspaceController w, String mode) {
    final slug = w.server?.string('slug');
    final key = slug == null || slug.isEmpty ? null : _key(w, slug, mode);
    final prefs = DevicePreferences.current;
    final stored = key == null ? null : _last[key] ?? prefs?.getString(key);
    if (key == null || stored == null || stored.isEmpty) return null;
    RaftLocation? location;
    try {
      location = RaftLocation.parse(stored);
    } catch (_) {
      location = null;
    }
    if (location == null ||
        location.serverSlug != slug ||
        railModeOfLocation(location) != mode ||
        !w.canVisitSection(WorkspaceNavigation.sectionFor(location))) {
      _last.remove(key);
      unawaited(prefs?.remove(key).catchError((_) => false));
      return null;
    }
    return location;
  }

  /// A rail press on [section]: returns true when it went to the remembered
  /// location (or stayed on it), false when the caller should open the mode's
  /// root as before. A conversation opens through the channel path so its
  /// messages load; the thread beside it comes back with it.
  bool enter(WorkspaceController w, String section) {
    if (!memorizedRailModes.contains(section)) return false;
    final target = recall(w, section);
    if (target == null) return false;
    if (target == w.location) return true;
    // A phone-only page presentation has no place on the wide layout.
    final wide = target.withQuery({'channelPage': null});
    if ({RaftRoute.channel, RaftRoute.dm}.contains(wide.route)) {
      final id = wide.entityId;
      final channel = [
        ...w.channels,
        ...w.dms,
      ].where((c) => c.id == id).firstOrNull;
      if (channel == null) return false;
      unawaited(_openConversation(w, channel, wide));
      return true;
    }
    w.navigation.navigate(wide);
    w.notifyListeners();
    return true;
  }

  Future<void> _openConversation(
    WorkspaceController w,
    RaftChannel channel,
    RaftLocation target,
  ) async {
    try {
      await w.selectChannel(channel);
      final thread = target.thread;
      if (thread != null) {
        await w.openThreadIdentity(
          parentChannelId: thread.channelId,
          parentMessageId: thread.itemId,
          focusedMessageId: target.messageId,
        );
      }
    } catch (_) {
      // The conversation stays where selectChannel left it.
    }
  }
}
