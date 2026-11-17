import 'package:flutter/widgets.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_navigation.dart';
import 'management_support.dart' show cachedServerFlag;
import 'settings_search.dart';
import 'workspace_host_scope.dart';

/// The public-access setting shows once this flag is on for the server
/// (`PublicVisibilitySection.publicFlag`, Web PUBLIC_SERVER_FEATURE_FLAG_KEY).
const _publicServerFlag = 'public_server_v0';

/// What Settings search needs from the workspace (Web
/// useSettingsSearchSettings.ts): who this person is on the server, what
/// each page leaves out for them, and where a result and "Search everywhere"
/// lead. [open] pushes a location and says whether the keyboard started it.
SettingsSearchHost workspaceSettingsSearchHost(
  BuildContext context,
  WorkspaceController w, {
  required void Function(RaftLocation location, {bool fromKeyboard}) open,
}) {
  final role = w.server?.string('role');
  final slug = w.location.serverSlug;
  return SettingsSearchHost(
    serverName: w.server?.name ?? '',
    desktopApp: WorkspaceHostScope.nativeDesktopOf(context),
    // What each page shows only to some people, as the page itself decides it.
    shown: (id) => switch (id) {
      'public-access' =>
        role == 'owner' && cachedServerFlag(w, _publicServerFlag) == true,
      'leave-server' => role != null && role != 'owner',
      'invite-links' => w.can('inviteMembers'),
      // This app has no single sign-on section to land on.
      'single-sign-on' => false,
      _ => true,
    },
    open: (page, id, {required fromKeyboard}) => open(
      RaftLocation.at(
        serverSlug: slug,
        route: RaftRoute.settings,
        settingsPath: [WorkspaceNavigation.settingsRouteSlug(page)],
        fragment: id,
      ),
      fromKeyboard: fromKeyboard,
    ),
    searchEverywhere: (query) => open(
      RaftLocation.at(
        serverSlug: slug,
        route: RaftRoute.search,
        query: {'q': query},
      ),
    ),
  );
}
