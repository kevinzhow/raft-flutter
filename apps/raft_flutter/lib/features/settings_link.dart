import 'package:flutter/widgets.dart' show Widget;

import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';

/// What the settings location says beyond its tab: the level-2 page open over
/// it (`/settings/account/delete`, with its query) and the `#<id>` section the
/// tab opens scrolled to. [revision] is the navigation revision that opened a
/// section, so opening the same one again is a new jump
/// (useScrollToSettingsSection's `key`). Compared by value, so the settings
/// surface rebuilds only when the link changes.
class SettingsLink {
  const SettingsLink({
    this.subPage,
    this.query = const {},
    this.anchor,
    this.revision = 0,
  });

  factory SettingsLink.of(WorkspaceController controller) {
    final location = controller.location;
    final fragment = location.uri.fragment;
    return SettingsLink(
      subPage: location.settingsPath.elementAtOrNull(1),
      query: location.uri.queryParameters,
      anchor: fragment.isEmpty ? null : fragment,
      revision: fragment.isEmpty ? 0 : controller.navigation.revision,
    );
  }

  /// The slug of the level-2 page (`delete`), if one is open.
  final String? subPage;
  final Map<String, String> query;
  final String? anchor;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is SettingsLink &&
      other.subPage == subPage &&
      other.anchor == anchor &&
      other.revision == revision &&
      other.query.length == query.length &&
      query.entries.every((e) => other.query[e.key] == e.value);

  @override
  int get hashCode => Object.hash(subPage, anchor, revision, query.length);
}

/// Pushes a location from inside Settings (a sub-page, a search result, the
/// global search) while the surface that built the callback still owns the
/// page ([allowed]).
void Function(RaftLocation) settingsLocationOpener(
  WorkspaceController controller, {
  required bool allowed,
}) => (location) {
  if (!allowed) return;
  controller.navigation.navigate(location, kind: RaftNavigationKind.push);
  controller.notifyListeners();
};

/// The account tab's built page, kept while its inputs are unchanged (the
/// settings surface's cache, one per workspace view).
class AccountSettingsCache {
  Object? inputs;
  Widget? widget;
}

final _accountSettingsCache = Expando<AccountSettingsCache>();

AccountSettingsCache accountSettingsCacheOf(Object key) =>
    _accountSettingsCache[key] ??= AccountSettingsCache();

void clearWorkspaceSettingsCache(Object key) {
  final cache = _accountSettingsCache[key];
  if (cache == null) return;
  cache.inputs = null;
  cache.widget = null;
}
