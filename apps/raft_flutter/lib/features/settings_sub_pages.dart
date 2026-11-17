import 'package:flutter/material.dart';

import '../data/raft_location.dart';

/// A level-2 page of a Settings tab, opened from a row inside the tab
/// (`/settings/account/delete`, Web `SettingsPanel` › `DeleteAccountPage`).
/// On a desktop width its header reads `<tab> › <title>` and the tab name
/// leads back; on a phone it is a pushed page with the plain title, and Back
/// returns to the parent tab, not to the Settings list
/// (SettingsSubPageTitle.tsx, SettingsPanel `onMobileBack`).
class SettingsSubPage {
  const SettingsSubPage({
    required this.id,
    required this.parentTab,
    required this.title,
  });

  /// `<tab>/<slug>`: the settings path after `/settings/` (`account/delete`).
  final String id;

  /// The tab it belongs to (`account`): highlighted in the list and the
  /// breadcrumb's link target.
  final String parentTab;

  /// The title, English source text (`Delete account`); the zh catalog is
  /// keyed by it.
  final String title;

  /// The last segment of [id].
  String get slug => id.substring(id.indexOf('/') + 1);
}

/// Every level-2 page, by id. Web has one: Account › Delete account. The
/// host that knows the workspace (WorkspaceSettings) builds its body.
const List<SettingsSubPage> settingsSubPages = [
  SettingsSubPage(
    id: 'account/delete',
    parentTab: 'account',
    title: 'Delete account',
  ),
];

/// The registered page at `/settings/<tab>/<slug>`, or null (a path with no
/// sub-page is the tab itself, as Web's `subPage === "delete"` test).
SettingsSubPage? settingsSubPageFor(String tab, String? slug) {
  if (slug == null || slug.isEmpty) return null;
  for (final page in settingsSubPages) {
    if (page.parentTab == tab && page.slug == slug) return page;
  }
  return null;
}

/// The registered page with this id (`account/delete`), or null.
SettingsSubPage? settingsSubPageById(String id) {
  for (final page in settingsSubPages) {
    if (page.id == id) return page;
  }
  return null;
}

/// What a sub-page's [SettingsSubPage.builder] and the rows that open it read
/// from the Settings surface around them.
class SettingsSubPageScope extends InheritedWidget {
  const SettingsSubPageScope({
    super.key,
    required this.open,
    this.query = const {},
    required super.child,
  });

  /// Opens the sub-page [id] with these query parameters (pushes it).
  final void Function(String id, Map<String, String> query) open;

  /// The open sub-page's query parameters.
  final Map<String, String> query;

  static SettingsSubPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsSubPageScope>();

  @override
  bool updateShouldNotify(SettingsSubPageScope old) =>
      query != old.query || open != old.open;
}

/// Opens the level-2 page [id] (`account/delete`) over its parent tab, with
/// the query parameters it reads ([SettingsSubPageScope.query]). Call it from
/// a row inside the Settings tab; an id nobody registered fails loudly rather
/// than leaving the row dead.
void openSettingsSubPage(
  BuildContext context,
  String id, {
  Map<String, String> query = const {},
}) {
  final page = settingsSubPageById(id);
  if (page == null) {
    throw ArgumentError.value(id, 'id', 'No settings sub-page is registered');
  }
  final scope = SettingsSubPageScope.maybeOf(context);
  if (scope == null) {
    throw FlutterError(
      'openSettingsSubPage($id) was called outside a Settings surface '
      '(no SettingsSubPageScope above this context).',
    );
  }
  scope.open(id, query);
}

/// The location of the sub-page [id] on [serverSlug].
RaftLocation settingsSubPageLocation(
  String serverSlug,
  SettingsSubPage page, {
  Map<String, String> query = const {},
}) => RaftLocation.at(
  serverSlug: serverSlug,
  route: RaftRoute.settings,
  settingsPath: page.id.split('/'),
  query: query,
);
